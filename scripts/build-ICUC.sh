#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 --branch release-75-1 https://github.com/unicode-org/icu.git src

TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
TARGET=aarch64-linux-android

# Create LICENSE files to avoid install errors
touch src/icu4c/LICENSE
touch src/icu4c/source/LICENSE

# Phase 1: Build host ICU tools
mkdir -p "$BUILD_DIR/host-build/source"
cd src/icu4c/source
cp -a . "$BUILD_DIR/host-build/source/"
cd "$BUILD_DIR/host-build/source"
touch ../LICENSE
chmod +x configure install-sh config.guess config.sub mkinstalldirs
./configure --prefix="$BUILD_DIR/host-install"
make -j$(nproc)
make install
cd "$BUILD_DIR/src/icu4c/source"

# Phase 2: Cross-compile ICU for Android
export CC="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang"
export CXX="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export CFLAGS="--sysroot=$TOOLCHAIN/sysroot -O2 -fPIC -include time.h"
export CXXFLAGS="$CFLAGS -std=c++17 -include time.h"
export LDFLAGS="--sysroot=$TOOLCHAIN/sysroot"

./configure \
  --host="$TARGET" \
  --prefix="$OUTPUT_DIR" \
  --with-cross-build="$BUILD_DIR/host-build/source" \
  --enable-static \
  --enable-shared \
  --disable-tests \
  --disable-samples \
  --with-data-packaging=shared \
  --disable-extras \
  --disable-icuio \
  --disable-layout \
  --disable-layoutex \
  --disable-dyload

make -j$(nproc)
make install
echo "ICUC built"
ls -lh "$OUTPUT_DIR/lib/"libicu*
