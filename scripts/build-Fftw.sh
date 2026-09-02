#!/bin/bash
# Build Fftw for Android ARM64
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
wget -q "https://www.fftw.org/fftw-3.3.10.tar.gz" -O fftw.tar.gz
tar xzf fftw.tar.gz
cd fftw-3.3.10

TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
TARGET=aarch64-linux-android

./configure \
  --host="$TARGET" \
  --prefix="$OUTPUT_DIR" \
  --enable-shared --enable-static \
  --enable-float \
  CC="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang" \
  CFLAGS="--sysroot=$TOOLCHAIN/sysroot -O2 -fPIC" \
  LDFLAGS="--sysroot=$TOOLCHAIN/sysroot"
make -j$(nproc)
make install
echo "Fftw built"
