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
# FIX: Create TBB::tbb imported target manually using OPENPGL_LIBS_DIR passed as cmake var.
python3 << 'PYEOF'
with open("CMakeLists.txt") as f:
    lines = f.readlines()

new_lines = []
skip_block = False
replaced = False
for line in lines:
    stripped = line.strip()
    if 'SET(OPENPGL_TBB_COMPONENT "tbb"' in stripped and not replaced:
        new_lines.append('# Cross-compile fix: NDK r26d FIND_ROOT_PATH_MODE_PACKAGE=ONLY\n')
        new_lines.append('set(OPENPGL_TBB_COMPONENT "tbb" CACHE STRING "The TBB component/library name.")\n')
        new_lines.append('if(NOT OPENPGL_LIBS_DIR)\n')
        new_lines.append('  message(FATAL_ERROR "OPENPGL_LIBS_DIR not set")\n')
        new_lines.append('endif()\n')
        new_lines.append('set(_tbb_inc "${OPENPGL_LIBS_DIR}/include")\n')
        new_lines.append('set(_tbb_lib "${OPENPGL_LIBS_DIR}/lib")\n')
        new_lines.append('message(STATUS "Openpgl: TBB lib=${_tbb_lib} inc=${_tbb_inc}")\n')
        new_lines.append('if(NOT TARGET TBB::tbb)\n')
        new_lines.append('  add_library(TBB::tbb SHARED IMPORTED GLOBAL)\n')
        new_lines.append('  set_target_properties(TBB::tbb PROPERTIES\n')
        new_lines.append('    IMPORTED_LOCATION "${_tbb_lib}/libtbb.so"\n')
        new_lines.append('    INTERFACE_INCLUDE_DIRECTORIES "${_tbb_inc}"\n')
        new_lines.append('  )\n')
        new_lines.append('  add_library(TBB::tbbmalloc SHARED IMPORTED GLOBAL)\n')
        new_lines.append('  set_target_properties(TBB::tbbmalloc PROPERTIES\n')
        new_lines.append('    IMPORTED_LOCATION "${_tbb_lib}/libtbbmalloc.so"\n')
        new_lines.append('  )\n')
        new_lines.append('endif()\n')
        new_lines.append('set(TBB_FOUND TRUE)\n')
        new_lines.append('set(TBB_INCLUDE_DIR "${_tbb_inc}")\n')
        new_lines.append('set(TBB_INCLUDE_DIRS "${_tbb_inc}")\n')
        new_lines.append('include_directories("${_tbb_inc}")\n')
        skip_block = True
        replaced = True
        continue
    if skip_block:
        if stripped == 'endif()':
            skip_block = False
        continue
    if 'FIND_PACKAGE(TBB REQUIRED' in stripped and replaced:
        continue
    new_lines.append(line)

with open("CMakeLists.txt", "w") as f:
    f.writelines(new_lines)
print("Patched Openpgl: TBB targets created manually (no find_package)")
PYEOF

COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_CXX_FLAGS="-include $PWD/force_includes.h -I$OUTPUT_DIR/include"
  -DCMAKE_HAVE_LIBC_PTHREAD=ON
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DOPENPGL_BUILD_TESTS=OFF -DOPENPGL_BUILD_EXAMPLES=OFF
  -DOPENPGL_LIBS_DIR="$OUTPUT_DIR"
)

cmake -B build -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}" 2>&1 | tail -20
cmake --build build -j$(nproc)
cmake --install build

cmake -B build-static -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}" 2>&1 | tail -5
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "Openpgl built"
ls -lh "$OUTPUT_DIR/lib/"libopenpgl*
