#!/bin/bash

export PATH="$HOME/toolchains/clang-android/clang-r547379/bin:$PATH"
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
    echo "CONFIG_KSU_MANUAL_HOOK=y" >> .config

    # 4. 强制开启 KernelSU 及 SuSFS 全套特性
    cat <<EOF >> .config
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y
CONFIG_KSU_MANUAL_HOOK_AUTO_SETUID_HOOK=n
CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK=n
CONFIG_KSU_MANUAL_HOOK_AUTO_INPUT_HOOK=n
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
CONFIG_THREAD_INFO_IN_TASK=y
EOF

    sed -i 's/CONFIG_KPROBES=y/# CONFIG_KPROBES is not set/g' .config
    sed -i 's/CONFIG_HAVE_KPROBES=y/# CONFIG_HAVE_KPROBES is not set/g' .config
    sed -i 's/CONFIG_KPROBE_EVENTS=y/# CONFIG_KPROBE_EVENTS is not set/g' .config

    # 关闭lto
    sed -i 's/CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/g' .config

    # 5. 讓內核重新整理並生效配置
    make olddefconfig
}

alias kbuild='make -j$(nproc)'
alias kclean='make mrproper'

echo "--- AOSP Clang Build Env Loaded (with Path Injection!) ---"
echo "Injected Paths: $INJECT_INCLUDES"
