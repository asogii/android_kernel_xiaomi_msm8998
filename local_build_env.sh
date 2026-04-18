#!/bin/bash

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

# Arch 专用补丁参数：处理现代编译器对旧内核代码的严苛检查
export KCFLAGS="-Wno-error -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -fcommon -Wno-unused-command-line-argument"

# 定义一键配置函数
kconfig() {
    # 1. 先生成基础配置
    make vendor/xiaomi/mi8998_defconfig
    # 2. 合并 chiron 的特定配置
    # 注：部分仓库支持这种合并，如果失败，请看下文的“手动合并”
    scripts/kconfig/merge_config.sh -m .config arch/arm64/configs/vendor/xiaomi/chiron.config
    # 3. 重新生成最终的 .config
    make olddefconfig
}

alias kbuild='make -j$(nproc)'
alias kclean='make mrproper'

echo "--- Android Kernel Build Env Loaded ---"
echo "Use 'kconfig' to generate config, 'kbuild' to start."
