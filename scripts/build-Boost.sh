#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

if [ ! -f boost_1_84_0.tar.gz ]; then
  wget -q "https://archives.boost.io/release/1.84.0/source/boost_1_84_0.tar.gz" || \
  wget -q "https://boostorg.jfrog.io/artifactory/main/release/1.84.0/source/boost_1_84_0.tar.gz"
fi
tar xzf boost_1_84_0.tar.gz
cd boost_1_84_0

TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
TARGET=aarch64-linux-android

cat > user-config.jam << JAM
using clang : android : $TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang++ : <compileflags>"--sysroot=$TOOLCHAIN/sysroot" <archiver>$TOOLCHAIN/bin/llvm-ar <ranlib>$TOOLCHAIN/bin/llvm-ranlib ;
JAM

echo "=== Bootstrap ==="
./bootstrap.sh --with-toolset=clang 2>&1 | tail -5

echo "=== Building shared + static ==="
./b2 install \
  --prefix="$OUTPUT_DIR" \
  --with-iostreams --with-locale --with-filesystem \
  --with-thread --with-system --with-regex --with-date_time \
  --with-log --with-serialization --with-program_options \
  link=shared,static variant=release threading=multi \
  toolset=clang --ignore-site-config \
  -sNO_BZIP2=1 -sNO_ZLIB=1 -sNO_LZMA=1 -sNO_ZSTD=1 -sNO_PYTHON=1 2>&1 | tail -20
echo "Boost built"
ls -lh "$OUTPUT_DIR/lib/"libboost*
