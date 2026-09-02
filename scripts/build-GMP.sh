#!/bin/bash
# Build GMP for Android ARM64
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
wget -q "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz" -O gmp.tar.xz
tar xJf gmp.tar.xz
cd gmp-6.3.0

TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
TARGET=aarch64-linux-android

./configure \
  --host="$TARGET" \
  --prefix="$OUTPUT_DIR" \
  --enable-shared --enable-static \
  CC="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang" \
  CXX="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang++" \
  CFLAGS="--sysroot=$TOOLCHAIN/sysroot -O2 -fPIC" \
  CXXFLAGS="--sysroot=$TOOLCHAIN/sysroot -O2 -fPIC" \
  LDFLAGS="--sysroot=$TOOLCHAIN/sysroot" \
  --disable-assembly
make -j$(nproc)
make install
echo "GMP built"
