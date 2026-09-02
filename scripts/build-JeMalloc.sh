#!/bin/bash
# Build JeMalloc for Android ARM64
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 --branch 5.3.0 https://github.com/jemalloc/jemalloc.git src
cd src
./autogen.sh
TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
TARGET=aarch64-linux-android
./configure \
  --host="$TARGET" \
  --prefix="$OUTPUT_DIR" \
  --enable-shared --enable-static \
  CC="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang" \
  CXX="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang++" \
  CFLAGS="--sysroot=$TOOLCHAIN/sysroot -O2 -fPIC" \
  LDFLAGS="--sysroot=$TOOLCHAIN/sysroot" \
  --with-jemalloc-prefix=je_ \
  --disable-initial-exec-tls
make -j$(nproc)
make install
echo "JeMalloc built"
