#!/bin/bash

# 建议：如果编译报出大量未知的语法错误，请将此处的 clang 路径降级为 r416183b (Clang 12)
export PATH="$HOME/toolchains/clang-android/clang-r547379/bin:$PATH"

# 基础架构与交叉编译器配置 (建议使用 GCC 4.9 的路径)
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-none-eabi- # 如果关闭了VDSO，这个32位工具链其实用不到

# 全局环境变量注入，用于修复外部驱动头文件缺失
export INJECT_INCLUDES="-I${PWD}/drivers/bluetooth -I${PWD}/sound/soc/msm -I${PWD}/drivers/gpu/msm -I${PWD}/drivers/input/misc/vl53L0 -I${PWD}/drivers/media/platform/msm/camera_v2/common -I${PWD}/drivers/media/platform/msm/camera_v2/isp -I${PWD}/drivers/media/platform/msm/camera_v2/sensor -I${PWD}/drivers/media/platform/msm/camera_v2/sensor/io -I${PWD}/drivers/platform/msm/mhi -I${PWD}/drivers/platform/msm/ipa/ipa_v3 -I${PWD}/drivers/platform/msm/ipa/ipa_v2"
export KCFLAGS="-Wno-error $INJECT_INCLUDES"
export KCPPFLAGS="$INJECT_INCLUDES"

kconfig() {
    # 1. 生成基础配置 (原脚本为 in-tree 编译，即未指定 O=out)
    make vendor/xiaomi/mi8998_defconfig

    # 2. 合并 chiron 专有机型配置
    scripts/kconfig/merge_config.sh -m .config arch/arm64/configs/vendor/xiaomi/chiron.config

    echo "--- 正在注入 SukiSU/SuSFS 配置並修復編譯選項 ---"

    # 3. 强制关闭导致 4.4 链接器报错的 32位 VDSO
    sed -i 's/CONFIG_COMPAT_VDSO=y/# CONFIG_COMPAT_VDSO is not set/g' .config
    sed -i 's/CONFIG_VDSO32=y/# CONFIG_VDSO32 is not set/g' .config
    echo "CONFIG_COMPAT_VDSO=n" >> .config
    echo "CONFIG_VDSO32=n" >> .config

    # 4. 强制开启 KernelSU 及 SuSFS 全套特性
    cat <<EOF >> .config
CONFIG_KSU=y
CONFIG_KSU_MANUAL_HOOK=y
<<<<<<< HEAD
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

    # 5. 強制關閉 KPROBES 及其關聯項 (手動 Patch 模式的鐵律)
    sed -i 's/CONFIG_KPROBES=y/# CONFIG_KPROBES is not set/g' .config
    sed -i 's/CONFIG_HAVE_KPROBES=y/# CONFIG_HAVE_KPROBES is not set/g' .config
    sed -i 's/CONFIG_KPROBE_EVENTS=y/# CONFIG_KPROBE_EVENTS is not set/g' .config

    # 6. 关闭 LTO (旧版内核开启 LTO 极易产生链接错误)
    sed -i 's/CONFIG_LTO_CLANG=y/# CONFIG_LTO_CLANG is not set/g' .config
    echo "CONFIG_LTO_NONE=y" >> .config

    # 7. 讓內核重新整理並生效配置
    make olddefconfig
}

# 修正编译命令，将 CC 和 LD 等核心参数直接传递给 make，复刻 GitHub Actions 的行为
alias kbuild='make -j$(nproc) CC="clang" LD="ld.lld" CLANG_TRIPLE="aarch64-linux-gnu-"'
alias kclean='make mrproper'

echo "--- Local Clang Build Env Loaded (with Path Injection & SuSFS configs) ---"
echo "Injected Paths: $INJECT_INCLUDES"
