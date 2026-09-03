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

# Remove bundled FindTBB.cmake (it's broken for cross-compile anyway)
rm -f cmake/FindTBB.cmake

# CAUSE: NDK r26d toolchain forces CMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY,
# which prevents find_package(CONFIG) from searching CMAKE_PREFIX_PATH.
# Even passing -DTBB_DIR or -DCMAKE_PREFIX_PATH doesn't help.
# FIX: Bypass find_package entirely. Import TBB targets manually from known paths.
python3 << 'PYEOF'
import re
with open("CMakeLists.txt") as f:
    c = f.read()

# Replace the entire TBB find block with direct target import
old_block = """SET(OPENPGL_TBB_COMPONENT "tbb" CACHE STRING "The TBB component/library name.")

if (NOT ${OPENPGL_TBB_ROOT} STREQUAL "")
    set(TBB_FIND_PACKAGE_OPTION "NO_DEFAULT_PATH")
    set(TBB_ROOT ${OPENPGL_TBB_ROOT})
    list(APPEND CMAKE_PREFIX_PATH ${OPENPGL_TBB_ROOT})
endif()

FIND_PACKAGE(TBB REQUIRED ${OPENPGL_TBB_COMPONENT})"""

new_block = """# Cross-compile fix: NDK r26d forces FIND_ROOT_PATH_MODE_PACKAGE=ONLY,
# preventing find_package from finding TBB in CMAKE_PREFIX_PATH.
# Import TBB targets directly from TBB_DIR.
set(OPENPGL_TBB_COMPONENT "tbb" CACHE STRING "The TBB component/library name.")
if(NOT TBB_DIR)
  set(TBB_DIR "$ENV{TBB_DIR}")
endif()
if(NOT TBB_DIR)
  message(FATAL_ERROR "TBB_DIR not set. Pass -DTBB_DIR=$OUTPUT_DIR/lib/cmake/TBB")
endif()

# Include TBB config directly
include("${TBB_DIR}/TBBConfig.cmake" OPTIONAL RESULT TBB_CONFIG_RESULT)
if(NOT TBB_CONFIG_RESULT)
  message(FATAL_ERROR "Failed to include TBBConfig.cmake from ${TBB_DIR}")
endif()
set(TBB_FOUND TRUE)
set(TBB_INCLUDE_DIR "${TBB_DIR}/../../../include")
message(STATUS "TBB imported from ${TBB_DIR} (targets: TBB::tbb)")"""

c = c.replace(old_block, new_block)
with open("CMakeLists.txt", "w") as f:
    f.write(c)
print("Patched Openpgl CMakeLists.txt: TBB imported directly from TBB_DIR")
PYEOF

export TBB_DIR="$OUTPUT_DIR/lib/cmake/TBB"

COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_CXX_FLAGS="-include $PWD/force_includes.h"
  -DCMAKE_HAVE_LIBC_PTHREAD=ON
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DOPENPGL_BUILD_TESTS=OFF -DOPENPGL_BUILD_EXAMPLES=OFF
  -DTBB_DIR="$OUTPUT_DIR/lib/cmake/TBB"
)

cmake -B build -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}" 2>&1 | tail -20
cmake --build build -j$(nproc)
cmake --install build

cmake -B build-static -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}" 2>&1 | tail -5
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "Openpgl built"
ls -lh "$OUTPUT_DIR/lib/"libopenpgl*
