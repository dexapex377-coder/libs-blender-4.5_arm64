#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/OpenPathGuidingLibrary/openpgl.git src
cd src
cat > force_includes.h << 'HDR'
#pragma once
#include <ctime>
#include <cstdint>
HDR
COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_CXX_FLAGS="-include $PWD/force_includes.h"
  -DCMAKE_HAVE_LIBC_PTHREAD=ON
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DOPENPGL_BUILD_TESTS=OFF -DOPENPGL_BUILD_EXAMPLES=OFF
  -DTBB_ROOT="$OUTPUT_DIR" \
  -DTBB_DIR="$OUTPUT_DIR/lib/cmake/TBB"
)
cmake -B build -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build
cmake -B build-static -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "Openpgl built"
ls -lh "$OUTPUT_DIR/lib/"libopenpgl*
