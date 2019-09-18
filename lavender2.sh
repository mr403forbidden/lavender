#!/usr/bin/env bash
#
# Copyright (C) 2019 @alanndz (Telegram and Github)
# SPDX-License-Identifier: GPL-3.0-or-later
#
# New Automatic Build for lavender
#
#

# Default Settings
RELEASE_STATUS=0
KERNEL_NAME="HeartAttack"
CODENAME="EAS-Test"
KERNEL_VERSION=""
CONFIG_FILE="lavender-miui_defconfig"
DEVICES="lavender"
TARGET_ROM="miui"
TARGET_ARCH=arm64
DEVELOPER="root"
HOST="Anonymous"


# COMPILER
# 0 = STOCK 4.9
# 1 = GNU 8.3
COMPILER=0
# USECLANG
# 0
# 1 = CLANG
# 2 = DRAGONTC
USECLANG=1
JOBS="-j$(($(nproc --all) + 4))"

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

#####

if [ $RELEASE_STATUS -eq 1 ]; then
	if [ "${CODENAME}" ]; then
		KVERSION="${CODENAME}-${KERNEL_VERSION}"
	else
		KVERSION="${CODENAME}"
	fi
	ZIP_NAME="${KERNEL_NAME}-${KVERSION}-${DEVICES}-$(date "+%H%M-%d%m%Y").zip"
elif [ $RELEASE_STATUS -eq 0 ]; then
	KVERSION="${CODENAME}-$(git log --pretty=format:'%h' -1)-$(date "+%H%M")"
	ZIP_NAME="${KERNEL_NAME}-${CODENAME}-${DEVICES}-$(git log --pretty=format:'%h' -1)-$(date "+%H%M").zip"
fi

if [ ! -d "${BUILDLOG}" ]; then
 	rm -rf "${BUILDLOG}"
fi

####

function make_zip () {
	cd ${ZIP_DIR}/
	make clean &>/dev/null
	if [ ! -f ${IMAGE} ]; then
        	echo -e "Build failed :P";
        	sendInfo "$(echo -e "Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")";
	        sendInfo "$(echo -e "Kernel compilation failed")";
			sendStick "${BUILD_FAIL}"
			sendLog
        	exit 1;
	fi
	echo "**** Copying zImage ****"
	cp ${IMAGE} ${ZIP_DIR}/zImage
	make ZIP="${ZIP_NAME}" normal &>/dev/null
}

function clean_outdir() {
    make ARCH=$TARGET_ARCH O=${OUTDIR} clean
    make mrproper
    rm -rf ${OUTDIR}/*
}

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

# Export
PATH="${TOOLDIR}/clang/bin:${TOOLCHAIN64}/bin:${PATH}:${TOOLCHAIN32}/bin:${PATH}"

BUILD_START=$(date +"%s")
DATE=`date`

sendInfo "<b>---- HeartAttack New Kernel ----</b>" \
    "<b>Device:</b> Lavender or REDMI NOTE 7" \
    "<b>Version:</b> <code>${KVERSION}</code>" \
    "<b>Kernel Version:</b> <code>$(make kernelversion)</code>" \
    "<b>Commit:</b> <code>$(git log --pretty=format:'%h : %s' -1)</code>" \
    "<b>Started on:</b> <code>$(hostname)</code>" \
    "<b>Compiler:</b> <code>${CLANG_VERSION}</code>" \
    "<b>Started at</b> <code>$DATE</code>"

clean_outdir

function compile_clang() {
    make ARCH=arm64 O="${OUTDIR}" "${CONFIG_FILE}"
    make -j$(nproc --all) O="${OUTDIR}" \
                          ARCH=arm64 \
                          CC=clang \
                          CLANG_TRIPLE=aarch64-linux-gnu- \
                          CROSS_COMPILE=aarch64-linux-android- \
                          CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                          LOCALVERSION="-${KVERSION}" \
                          KBUILD_BUILD_USER="${DEVELOPER}" \
                          KBUILD_BUILD_HOST="${HOST}"
}

compile_clang 2>&1 | tee "${BUILDLOG}"

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

cd ${ZIP_DIR}/
make clean &>/dev/null
strip_module

make_zip
# sendInfo "$(echo -e "NOTE!!! INSTALL on ROM ${CODENAME} ONLY!!!")" 
sendZip
sendLog
sendInfo "$(echo -e "Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")"
sendStick "${BUILD_SUCCESS}"
