#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 --branch release-75-1 https://github.com/unicode-org/icu.git src
cd src/icu4c/source

TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x8_64"
TARGET=aarch64-linux-android
export CC="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang"
export CXX="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"

export CFLAGS="--sysroot=$TOOLCHAIN/sysroot -O2 -fPIC"
export CXXFLAGS="$CFLAGS -std=c++17"
export LDFLAGS="--sysroot=$TOOLCHAIN/sysroot"

./configure \
  --host="$TARGET" \
  --prefix="$OUTPUT_DIR" \
  --enable-static \
  --disable-shared \
  --disable-tests \
  --disable-samples \
  --with-data-packaging=static \
  --disable-extras \
  --disable-icuio \
  --disable-layout \
  --disable-layoutex \
  --disable-dyload

make -j$(nproc)
make install
echo "ICUC built"
