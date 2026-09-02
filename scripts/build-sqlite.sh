#!/bin/bash
# Build sqlite for Android ARM64
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
wget -q "https://www.sqlite.org/2024/sqlite-autoconf-3450100.tar.gz" -O sqlite.tar.gz
tar xzf sqlite.tar.gz
cd sqlite-autoconf-3450100

CC="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android${API_LEVEL}-clang"
CXX="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android${API_LEVEL}-clang++"
SYSROOT="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

./configure --host=aarch64-linux-android \
  CC="$CC" CXX="$CXX" \
  --prefix="$OUTPUT_DIR" \
  --enable-shared --enable-static \
  CFLAGS="--sysroot=$SYSROOT -O2 -fPIC" \
  LDFLAGS="--sysroot=$SYSROOT"
make -j$(nproc)
make install
echo "sqlite built"
