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

rm -f cmake/FindTBB.cmake

# CAUSE: NDK r26d forces CMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY.
# Every form of find_package(TBB) fails because CMake filters paths through sysroot.
# Even include(TBBConfig.cmake) fails because TBBConfig internally calls find_dependency().
# FIX: Create TBB::tbb imported target manually from known install paths.
python3 << 'PYEOF'
with open("CMakeLists.txt") as f:
    lines = f.readlines()

new_lines = []
skip_block = False
replaced = False
for line in lines:
    stripped = line.strip()
    # Start replacement at SET(OPENPGL_TBB_COMPONENT "tbb"...)
    if 'SET(OPENPGL_TBB_COMPONENT "tbb"' in stripped and not replaced:
        new_lines.append('# Cross-compile fix: NDK r26d FIND_ROOT_PATH_MODE_PACKAGE=ONLY\n')
        new_lines.append('# find_package(TBB) is impossible — create targets manually.\n')
        new_lines.append('set(OPENPGL_TBB_COMPONENT "tbb" CACHE STRING "The TBB component/library name.")\n')
        new_lines.append('if(NOT TBB_DIR)\n')
        new_lines.append('  set(TBB_DIR "$ENV{TBB_DIR}")\n')
        new_lines.append('endif()\n')
        new_lines.append('if(NOT TBB_DIR)\n')
        new_lines.append('  message(FATAL_ERROR "TBB_DIR not set. Pass -DTBB_DIR=/path/to/lib/cmake/TBB")\n')
        new_lines.append('endif()\n')
        new_lines.append('# Import TBB targets directly (bypass find_package)\n')
        new_lines.append('if(NOT TARGET TBB::tbb)\n')
        new_lines.append('  add_library(TBB::tbb SHARED IMPORTED)\n')
        new_lines.append('  set_target_properties(TBB::tbb PROPERTIES\n')
        new_lines.append('    IMPORTED_LOCATION "${TBB_DIR}/../../../lib/libtbb.so"\n')
        new_lines.append('    INTERFACE_INCLUDE_DIRECTORIES "${TBB_DIR}/../../../include"\n')
        new_lines.append('  )\n')
        new_lines.append('  add_library(TBB::tbbmalloc SHARED IMPORTED)\n')
        new_lines.append('  set_target_properties(TBB::tbbmalloc PROPERTIES\n')
        new_lines.append('    IMPORTED_LOCATION "${TBB_DIR}/../../../lib/libtbbmalloc.so"\n')
        new_lines.append('  )\n')
        new_lines.append('endif()\n')
        new_lines.append('set(TBB_FOUND TRUE)\n')
        new_lines.append('set(TBB_INCLUDE_DIR "${TBB_DIR}/../../../include")\n')
        new_lines.append('message(STATUS "Openpgl: TBB targets created from ${TBB_DIR}")\n')
        skip_block = True
        replaced = True
        continue
    # Skip the original TBB block (SET...TBB_COMPONENT through endif())
    if skip_block:
        if stripped == 'endif()':
            skip_block = False
        continue
    # Skip the original FIND_PACKAGE(TBB REQUIRED...)
    if 'FIND_PACKAGE(TBB REQUIRED' in stripped and replaced:
        continue
    new_lines.append(line)

with open("CMakeLists.txt", "w") as f:
    f.writelines(new_lines)
print("Patched Openpgl: TBB targets created manually (no find_package)")
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
