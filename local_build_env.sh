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
    # 1. 生成基礎配置
    make vendor/xiaomi/mi8998_defconfig
    
    # 2. 合併 chiron 專有機型配置
    scripts/kconfig/merge_config.sh -m .config arch/arm64/configs/vendor/xiaomi/chiron.config
    
    echo "--- 正在注入 SukiSU 配置並關閉 KPROBES ---"
    
    # 3. 強制開啟 KernelSU
    echo "CONFIG_KSU=y" >> .config
    
    # 4. 強制關閉 KPROBES 及其關聯項 (這是手動 Patch 模式的鐵律，避免音量鍵觸發安全模式)
    sed -i 's/CONFIG_KPROBES=y/# CONFIG_KPROBES is not set/g' .config
    sed -i 's/CONFIG_HAVE_KPROBES=y/# CONFIG_HAVE_KPROBES is not set/g' .config
    sed -i 's/CONFIG_KPROBE_EVENTS=y/# CONFIG_KPROBE_EVENTS is not set/g' .config
    
    # 5. 讓內核重新整理並生效配置
    make olddefconfig
}

alias kbuild='make -j$(nproc)'
alias kclean='make mrproper'

echo "--- AOSP Clang Build Env Loaded (with Path Injection!) ---"
echo "Injected Paths: $INJECT_INCLUDES"
