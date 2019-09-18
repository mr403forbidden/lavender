#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2018 Raphiel Rollerscaperers (raphielscape)
# Copyright (C) 2018 Rama Bondan Prakoso (rama982)
# CI Kernel Build Script

################
#              #
#   TELEGRAM   #
#              #
################

# Telegram Function
BOT_API_KEY=$(openssl enc -base64 -d <<< ODg4MDY2NDQ4OkFBRks2STZWSnVfdFpNNTFjNzFNOFhMdW1sdXFyZ1UxbFpF)
CHAT_ID=$(openssl enc -base64 -d <<< NzA0MTI0OTU5)
export BUILD_FAIL="CAADBQAD5xsAAsZRxhW0VwABTkXZ3wcC"
export BUILD_SUCCESS="CAADBQADeQAD9kkAARtA3tu3hLOXJwI"

function sendInfo() {
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d chat_id=$CHAT_ID -d "parse_mode=HTML" -d text="$(
            for POST in "${@}"; do
                echo "${POST}"
            done
        )" 
&>/dev/null
}
 
function sendZip() {
	curl -F chat_id="$CHAT_ID" -F document=@"$ZIP_DIR/$ZIP_NAME" https://api.telegram.org/bot$BOT_API_KEY/sendDocument
}
 
function sendStick() {
	curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="${1}" -d chat_id=$CHAT_ID &>/dev/null
}
 
function sendLog() {
	curl -F chat_id="704124959" -F document=@"$BUILDLOG" https://api.telegram.org/bot$BOT_API_KEY/sendDocument &>/dev/null
}

###############
#             #
#  VARIABLES  #
#             #
###############

# Location of Toolchain
KERNELDIR=$PWD
TOOLDIR=$KERNELDIR/.ToolBuild
ZIP_DIR="${TOOLDIR}/AnyKernel3"
OUTDIR="${KERNELDIR}/.Output"
IMAGE="${OUTDIR}/arch/arm64/boot/Image.gz-dtb"
BUILDLOG="${OUTDIR}/build-${CODENAME}-${DEVICES}.log"

# Download tool
git clone https://github.com/aln-project/AnyKernel3 -b "${DEVICES}-${TARGET_ROM}" ${ZIP_DIR}

if [ $COMPILER -eq 0 ]; then
    TOOLCHAIN32="${TOOLDIR}/stock32"
    TOOLCHAIN64="${TOOLDIR}/stock64"
    CC="aarch64-linux-android-"
    CC_ARM32="arm-linux-androideabi-"
    git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r39 --depth=1 "${TOOLCHAIN32}"
    git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r39 --depth=1 "${TOOLCHAIN64}"
elif [ $COMPILER -eq 1 ]; then
    if [[ ! -d ${TOOLDIR}/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabi && ! -d ${TOOLDIR}/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu ]]; then
        mkdir ${TOOLDIR}
        cd ${TOOLDIR}
        curl -O https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/8.3-2019.03/binrel/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabi.tar.xz
        tar xvf *.tar.xz
        rm *.tar.xz
        curl -O https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu-a/8.3-2019.03/binrel/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu.tar.xz
        tar xvf *.tar.xz
        rm *.tar.xz
        cd ${KERNELDIR}
    fi
    TOOLCHAIN32="${TOOLDIR}/gcc-arm-8.3-2019.03-x86_64-arm-linux-gnueabi"
    TOOLCHAIN64="${TOOLDIR}/gcc-arm-8.3-2019.03-x86_64-aarch64-linux-gnu"
    CC="aarch64-linux-gnu-"
    CC_ARM32="arm-linux-gnueabi-"
fi

if [ $USECLANG -eq 1 ]; then
    git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-5696680 "${TOOLDIR}/clang"
elif [ $USECLANG -eq 2 ]; then
    git clone --depth=1 https://github.com/NusantaraDevs/DragonTC "${TOOLDIR}/clang"
fi

CLANG_VERSION=$("${TOOLDIR}/clang/bin/clang" --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')

if ! [ -a $KERN_IMG ]; then
    sendInfo "<b>BuildCI report status:</b> There are build running but its error, please fix and remove this message!"
    exit 1
fi

cd $ZIP_DIR
make clean &>/dev/null
cd ..

# For MIUI Build
# Credit @adekmaulana
MODULEDIR="${ZIP_DIR}/modules/vendor/lib/modules/"
PRONTO="${MODULEDIR}pronto/pronto_wlan.ko"
STRIP="${TOOLCHAIN64}/bin/$(echo "$(find "${TOOLCHAIN64}/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
			sed -e 's/gcc/strip/')"

function strip_module () {
	# thanks to @adekmaulana
	for MOD in $(find "${OUTDIR}" -name '*.ko') ; do
		"${STRIP}" --strip-unneeded --strip-debug "${MOD}" #&>/dev/null
		"${KERNELDIR}/"/scripts/sign-file sha512 \
				"${OUTDIR}/signing_key.priv" \
				"${OUTDIR}/signing_key.x509" \
				"${MOD}"
		find "${OUTDIR}" -name '*.ko' -exec cp {} "${MODULEDIR}" \;
		case ${MOD} in
			*/wlan.ko)
				cp -ar "${MOD}" "${PRONTO}"
		esac
	done
	echo -e "\n(i) Done moving modules"
}


cd $ZIP_DIR
cp $KERN_IMG $ZIP_DIR/zImage
make normal &>/dev/null
echo "Flashable zip generated under $ZIP_DIR."
FILENAME=$(echo HeartAttack*.zip)
cd ..

TOOLCHAIN=$(cat out/include/generated/compile.h | grep LINUX_COMPILER | cut -d '"' -f2)
UTS=$(cat out/include/generated/compile.h | grep UTS_VERSION | cut -d '"' -f2)
KERNEL=$(cat out/.config | grep Linux/arm64 | cut -d " " -f3)

sendStick

sendInfo "<b>New Nightly HeartAttack build is available!</b>" \
    "<b>Device :</b> <code>REDMI NOTE 7</code>" \
    "<b>Kernel version :</b> <code>Linux ${KERNEL}</code>" \
    "<b>UTS version :</b> <code>${UTS}</code>" \
    "<b>Toolchain :</b> <code>${TOOLCHAIN}</code>" \
    "<b>Latest commit :</b> <code>$(git log --pretty=format:'"%h : %s"' -1)</code>"

push

# Build AOSP start
make  O=out $CONFIG_AOSP $THREAD
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      CROSS_COMPILE=aarch64-linux-android- \
                      CROSS_COMPILE_ARM32=arm-linux-androideabi-

if ! [ -a $KERN_IMG ]; then
    sendInfo "<b>BuildCI report status:</b> There are build running but its error, please fix and remove this message!"
    exit 1
fi

cd $ZIP_DIR
git checkout lavender-aosp
make clean &>/dev/null
cp $KERN_IMG $ZIP_DIR/zImage
make normal &>/dev/null
echo "Flashable zip generated under $ZIP_DIR."
FILENAME=$(echo HeartAttack*.zip)
cd ..

push

# Build end
