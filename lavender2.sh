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
TELEGRAM_TOKEN=$(openssl enc -base64 -d <<< ODg4MDY2NDQ4OkFBRks2STZWSnVfdFpNNTFjNzFNOFhMdW1sdXFyZ1UxbFpF)
CHAT_ID=$(openssl enc -base64 -d <<< NzA0MTI0OTU5)
export BUILD_FAIL="CAADBQAD5xsAAsZRxhW0VwABTkXZ3wcC"
export BUILD_SUCCESS="CAADBQADeQAD9kkAARtA3tu3hLOXJwI"
TELEGRAM=telegram/telegram

# Push kernel installer to channel
function push() {
    JIP="AnyKernel3/${FILENAME}"
	curl -F document=@$JIP  "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument" \
			-F chat_id="$CHAT_ID"
}

# Send the info up
function tg_channelcast() {
    "${TELEGRAM}" -c ${CHAT_ID} -H \
        "$(
            for POST in "${@}"; do
                echo "${POST}"
            done
        )"
}

function tg_sendstick() {
	curl -s -X POST https://api.telegram.org/bot$TELEGRAM_TOKEN/sendSticker -d sticker="${1}" -d chat_id=$CHAT_ID &>/dev/null
}

function sendLog() {
	curl -F chat_id="704124959" -F document=@"$BUILDLOG" https://api.telegram.org/bot$TELEGRAM_TOKEN/sendDocument &>/dev/null
}

###############
#             #
#  VARIABLES  #
#             #
###############

# Default Settings
CODENAME="MIUI"
# Main environtment
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
KERNEL_DIR=/root/android_kernel_xiaomi_lavender/
KERN_IMG=$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb
ZIP_DIR=$KERNEL_DIR/AnyKernel3
CONFIG_MIUI=lavender-miui_defconfig
PATH="${KERNEL_DIR}/android_prebuilts_clang_host_linux-x86_clang-5696680/bin:${KERNEL_DIR}/aarch64-linux-android-4.9/bin:${PATH}:${KERNEL_DIR}/arm-linux-androideabi-4.9/bin:${PATH}"

# Export
export ARCH=arm64
export KBUILD_BUILD_USER="root"
export KBUILD_BUILD_HOST="Anonymous"
export TZ=":Asia/Jakarta"

# Clone AnyKernel3
git clone https://github.com/rama982/AnyKernel3 -b lavender

# Clone Compiler
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 -b android-9.0.0_r39 --depth=1
git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 -b android-9.0.0_r39 --depth=1

# Clone Clang
git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-5696680
git clone --depth=1 https://github.com/NusantaraDevs/DragonTC

# Build start
make  O=out $CONFIG_MIUI $THREAD
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      CLANG_TRIPLE=aarch64-linux-gnu- \
                      CROSS_COMPILE=aarch64-linux-android- \
                      CROSS_COMPILE_ARM32=arm-linux-androideabi-

if ! [ -a $KERN_IMG ]; then
    tg_channelcast "<b>BuildCI report status:</b> There are build running but its error, please fix and remove this message!"
    exit 1
fi

cd $ZIP_DIR
make clean &>/dev/null
cd ..

# For MIUI Build
# Credit @adekmaulana
OUTDIR="$KERNEL_DIR/out/"
VENDOR_MODULEDIR="$KERNEL_DIR/AnyKernel3/modules/vendor/lib/modules"
STRIP="$KERNEL_DIR/aarch64-linux-android-4.9/bin$(echo "$(find "$KERNEL_DIR/aarch64-linux-android-4.9/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
            sed -e 's/gcc/strip/')"

for MODULES in $(find "${OUTDIR}" -name '*.ko'); do
    "${STRIP}" --strip-unneeded --strip-debug "${MODULES}" &> /dev/null
    "${OUTDIR}"/scripts/sign-file sha512 \
            "${OUTDIR}/certs/signing_key.pem" \
            "${OUTDIR}/certs/signing_key.x509" \
            "${MODULES}"
    find "${OUTDIR}" -name '*.ko' -exec cp {} "${VENDOR_MODULEDIR}" \;
    case ${MODULES} in
            */wlan.ko)
        cp "${MODULES}" "${VENDOR_MODULEDIR}/qca_cld3_wlan.ko" ;;
    esac
done

echo -e "\n(i) Done moving modules"
rm "${VENDOR_MODULEDIR}/wlan.ko"

cd $ZIP_DIR
cp $KERN_IMG $ZIP_DIR/zImage
make normal &>/dev/null
echo "Flashable zip generated under $ZIP_DIR."
FILENAME=$(echo HeartAttack*.zip)
cd ..

TOOLCHAIN=$(cat out/include/generated/compile.h | grep LINUX_COMPILER | cut -d '"' -f2)
UTS=$(cat out/include/generated/compile.h | grep UTS_VERSION | cut -d '"' -f2)
KERNEL=$(cat out/.config | grep Linux/arm64 | cut -d " " -f3)
PC=$(uname -a)
OS=$(cat /etc/*release)
BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

tg_sendstick

tg_channelcast "<b>New Nightly HeartAttack build is available!</b>" \
    "<b>Device :</b> <code>REDMI NOTE 7</code>" \
    "<b>PC Pengembang :</b> <code>${PC}</code>" \
    "<b>Kernel version :</b> <code>Linux ${KERNEL}</code>" \
    "<b>OS :</b> <code>${OS}</code>" \
    "<b>UTS version :</b> <code>${UTS}</code>" \
    "<b>Toolchain :</b> <code>${TOOLCHAIN}</code>" \
    "<b>Latest commit :</b> <code>$(git log --pretty=format:'"%h : %s"' -1)</code>"

tg_channelcast "$(echo -e "NOTE!!! INSTALL on ROM ${CODENAME} ONLY!!!")" 
push
sendLog
tg_channelcast "$(echo -e "Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")"
tg_sendstick "${BUILD_SUCCESS}"

