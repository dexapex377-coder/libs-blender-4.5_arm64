#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 --branch v2021.13.0 https://github.com/oneapi-src/oneTBB.git src
cd src
COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DCMAKE_CXX_FLAGS="-include time.h"
  -DTBB_TEST=OFF -DTBB_STRICT=OFF -DTBB_ENABLE_IPO=OFF
  -DTBB_BUILD=ON -DTBBMALLOC_BUILD=ON -DTBBMALLOC_PROXY_BUILD=OFF
)
# Shared
cmake -B build -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build
# Static
cmake -B build-static -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "TBB built"
ls -lh "$OUTPUT_DIR/lib/"libtbb*
ls -lh "$OUTPUT_DIR/lib/cmake"/tbb/*.cmake
