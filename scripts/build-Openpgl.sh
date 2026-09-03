#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/OpenPathGuidingLibrary/openpgl.git src
cd src

rm -f cmake/FindTBB.cmake

cat > force_includes.h << 'HDR'
#pragma once
#include <ctime>
#include <cstdint>
HDR

# CAUSE: NDK r26d CMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY blocks find_package(TBB).
# FIX: Write a fake TBBConfig.cmake that creates TBB::tbb target directly.
# This file is found by find_package(TBB CONFIG) without needing find_dependency().
TBB_CMAKE_DIR="$OUTPUT_DIR/lib/cmake/TBB"
mkdir -p "$TBB_CMAKE_DIR"
cat > "$TBB_CMAKE_DIR/TBBConfig.cmake" << 'EOF'
# Minimal TBB config for cross-compilation (NDK r26d)
if(NOT TARGET TBB::tbb)
  add_library(TBB::tbb SHARED IMPORTED GLOBAL)
  set_target_properties(TBB::tbb PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_LIST_DIR}/../../../lib/libtbb.so"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/../../../include"
  )
endif()
if(NOT TARGET TBB::tbbmalloc)
  add_library(TBB::tbbmalloc SHARED IMPORTED GLOBAL)
  set_target_properties(TBB::tbbmalloc PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_LIST_DIR}/../../../lib/libtbbmalloc.so"
  )
endif()
set(TBB_FOUND TRUE)
set(TBB_INCLUDE_DIRS "${CMAKE_CURRENT_LIST_DIR}/../../../include")
set(TBB_LIBRARIES TBB::tbb)
EOF
cat > "$TBB_CMAKE_DIR/TBBConfigVersion.cmake" << 'EOF'
set(PACKAGE_VERSION "2021.13")
if("${PACKAGE_FIND_VERSION}" VERSION_GREATER "2021.13")
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
  if("${PACKAGE_FIND_VERSION}" VERSION_EQUAL "2021.13")
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
endif()
EOF
echo "Created fake TBBConfig.cmake at $TBB_CMAKE_DIR"

cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_CXX_FLAGS="-include time.h -include $PWD/force_includes.h" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOPENPGL_BUILD_TESTS=OFF -DOPENPGL_BUILD_EXAMPLES=OFF \
  -DTBB_DIR="$TBB_CMAKE_DIR" 2>&1 | tail -20
cmake --build build -j$(nproc)
cmake --install build

cmake -B build-static \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_CXX_FLAGS="-include time.h -include $PWD/force_includes.h" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOPENPGL_BUILD_TESTS=OFF -DOPENPGL_BUILD_EXAMPLES=OFF \
  -DTBB_DIR="$TBB_CMAKE_DIR" 2>&1 | tail -5
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "Openpgl built"
ls -lh "$OUTPUT_DIR/lib/"libopenpgl*
