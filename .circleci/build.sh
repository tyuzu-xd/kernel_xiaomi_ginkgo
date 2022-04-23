#!/usr/bin/env bash
echo "Cloning dependencies"
wget -O 64.zip https://github.com/mvaisakh/gcc-arm64/archive/85b79055a926ffa45ed7ce0005731d7bda4db137.zip;unzip 64.zip;mv gcc-arm64-85b79055a926ffa45ed7ce0005731d7bda4db137 gcc64
wget -O 32.zip https://github.com/mvaisakh/gcc-arm/archive/b9cada9f629b7b3f72b201c77d93042695de33fc.zip;unzip 32.zip;mv gcc-arm-b9cada9f629b7b3f72b201c77d93042695de33fc gcc32
git clone --depth=1 https://github.com/tzuyu-xd/AnyKernel3 AnyKernel
echo "Done"
# Main Declaration
function env() {
export DEFCONFIG=vendor/ginkgo-perf_defconfig
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz-dtb
TANGGAL=$(date +"%F-%S")
START=$(date +"%s")
KERNEL_DIR=$(pwd)
GCC64_DIR="${pwd}/gcc64"
GCC32_DIR="${pwd}/gcc32"
GCC_VER="$("$GCC64_DIR"/bin/aarch64-elf-gcc --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
GCC_VER32="$("$GCC32_DIR"/bin/arm-eabi-gcc --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
LLD_VER="$("$GCC64_DIR"/bin/ld.lld --version | head -n 1)"
export KBUILD_COMPILER_STRING="$GCC_VER"
export KBUILD_COMPILER_STRING32="$GCC_VER32 with $LLD_VER"
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_HOST=circleci
export KBUILD_BUILD_USER="tzuyu-xd"
}
# sticker plox
function sticker() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendSticker" \
        -d sticker="CAACAgEAAxkBAAEnKnJfZOFzBnwC3cPwiirjZdgTMBMLRAACugEAAkVfBy-aN927wS5blhsE" \
        -d chat_id=$TG_CHAT_ID
}
# Send info plox channel
function sendinfo() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="<b>• Ginkgo-Miui Kernel •</b>%0ABuild started on <code>Circle CI</code>%0AFor device <b>Xiaomi Redmi Note8/8T</b> (Ginkgo/Willow)%0Abranch <code>$(git rev-parse --abbrev-ref HEAD)</code>(master)%0AUnder commit <code>$(git log --pretty=format:'"%h : %s"' -1)</code>%0AUsing compiler: <code>${KBUILD_COMPILER_STRING}</code>%0AStarted on <code>$(date)</code>%0A<b>Build Status:</b>#Stable"
}
# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>Xiaomi Redmi Note 8/8T (Ginkgo/Willow)</b>"
}
# Fin Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="Build throw an error(s)"
    exit 1
}
# Compile plox
function compile() {
    make O=out ARCH=arm64 ${DEFCONFIG}
    make -j$(nproc --all) O=out \
                    CROSS_COMPILE=${GCC_ROOTDIR}/bin/aarch64-linux-android- \
                    CROSS_COMPILE_ARM32=${GCC_ROOTDIR32}/bin/arm-linux-androideabi- \
                    AR=${GCC_ROOTDIR}/bin/aarch64-elf-ar \
                    OBJDUMP=${GCC_ROOTDIR}/bin/aarch64-elf-objdump \
                    STRIP=${GCC_ROOTDIR}/bin/aarch64-elf-strip
    if ! [ -a "$IMAGE" ]; then
        finerr
        exit 1
    fi
    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel
    cp out/arch/arm64/boot/dtbo.img AnyKernel
}
# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 MIUI-kernel-ginkgo-${TANGGAL}.zip *
    cd ..
}
env
sticker
sendinfo
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
