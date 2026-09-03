#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-28}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Fix NDK r29 libc++ bug: nanosleep undeclared in __thread/support/pthread.h
PTHREAD_H="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/c++/v1/__thread/support/pthread.h"
if [ -f "$PTHREAD_H" ] && ! grep -q 'extern "C" int nanosleep' "$PTHREAD_H"; then
  sed -i '/while (nanosleep/i #include <time.h>\nextern "C" { int nanosleep(const struct timespec*, struct timespec*); }' "$PTHREAD_H"
  echo "Patched NDK pthread.h for nanosleep"
fi

git clone --depth 1 --branch v24.11 https://github.com/PixarAnimationStudios/OpenUSD.git src
cd src
COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DPXR_BUILD_TESTS=OFF -DPXR_BUILD_EXAMPLES=OFF -DPXR_BUILD_TUTORIALS=OFF
  -DPXR_BUILD_IMAGING=OFF -DPXR_BUILD_USD_TOOLS=OFF -DPXR_BUILD_DOCUMENTATION=OFF
  -DPXR_ENABLE_PTEX_SUPPORT=OFF -DPXR_ENABLE_OPENVDB_SUPPORT=OFF
  -DPXR_ENABLE_USD_VALIDATION=OFF -DPXR_BUILD_OPENSUBDIV_SUPPORT=OFF
)
# Static
cmake -B build -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build
# Shared
cmake -B build-shared -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build-shared -j$(nproc)
cmake --install build-shared
echo "OpenUSD built"
ls -lh "$OUTPUT_DIR/lib/"libusd*
