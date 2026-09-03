#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/skyrpex/potrace.git src
cd src

TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
TARGET=aarch64-linux-android
export CC="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang"
export CXX="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export CFLAGS="-O2 -fPIC"
export LDFLAGS=""

./configure \
  --host="$TARGET" \
  --prefix="$OUTPUT_DIR" \
  --with-libpotrace \
  --disable-zlib \
  --disable-graphics

make -j$(nproc)
make install
echo "Potrace built"
ls -lh "$OUTPUT_DIR/lib/"libpotrace*
