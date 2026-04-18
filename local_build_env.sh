#!/bin/bash

export PATH="$HOME/aosp-clang/bin:$PATH"
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-none-eabi-

export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export STRIP=llvm-strip
export READELF=llvm-readelf

export INJECT_INCLUDES="-I${PWD}/drivers/bluetooth -I${PWD}/sound/soc/msm -I${PWD}/drivers/gpu/msm -I${PWD}/drivers/input/misc/vl53L0 -I${PWD}/drivers/media/platform/msm/camera_v2/common -I${PWD}/drivers/media/platform/msm/camera_v2/isp -I${PWD}/drivers/media/platform/msm/camera_v2/sensor -I${PWD}/drivers/media/platform/msm/camera_v2/sensor/io -I${PWD}/drivers/platform/msm/mhi -I${PWD}/drivers/platform/msm/ipa/ipa_v3 -I${PWD}/drivers/platform/msm/ipa/ipa_v2"

# 把注入的路径塞进内核编译参数中
export KCFLAGS="-Wno-error $INJECT_INCLUDES"
export KCPPFLAGS="$INJECT_INCLUDES" # 有时候预处理器也需要这个参数

kconfig() {
    make vendor/xiaomi/mi8998_defconfig
    scripts/kconfig/merge_config.sh -m .config arch/arm64/configs/vendor/xiaomi/chiron.config
    make olddefconfig
}

alias kbuild='make -j$(nproc)'
alias kclean='make mrproper'

echo "--- AOSP Clang Build Env Loaded (with Path Injection!) ---"
echo "Injected Paths: $INJECT_INCLUDES"
