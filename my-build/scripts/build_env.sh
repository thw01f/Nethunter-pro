#!/bin/bash
# Build environment for the crDroid-based NetHunter kernel (Nothing Phone 1 / spacewar)
# Source this before building:  source scripts/build_env.sh
#
# NOTE: the build tree must live under a path with NO spaces or colons.

export KERNEL_DIR="$HOME/kernel_build/crdroid_kernel"
export CLANG_DIR="$HOME/kernel_build/toolchain/clang-r416183b/clang-r416183b"
export PATH="$CLANG_DIR/bin:$PATH"

export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-
export LLVM=1
export LLVM_IAS=1

echo "KERNEL_DIR : $KERNEL_DIR"
echo "CLANG_DIR  : $CLANG_DIR"
echo "Clang      : $(clang --version 2>/dev/null | head -1)"
echo ""
echo "Expected clang: version 12.0.x (r416183b). If you see 18/21/22, fix CLANG_DIR / PATH."
