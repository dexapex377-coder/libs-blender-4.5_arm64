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
# Override the broken FindTBB.cmake with a wrapper that uses cmake config mode
cat > cmake/FindTBB.cmake << 'FINDTBB'
find_package(TBB CONFIG HINTS "${TBB_DIR}" "${CMAKE_PREFIX_PATH}/lib/cmake/TBB" "$ENV{TBB_ROOT}/lib/cmake/TBB")
if(TBB_FOUND)
  set(TBB_INCLUDE_DIR "${TBB_IMPORTED_INCLUDE_DIR}" CACHE PATH "")
  if(NOT TBB_INCLUDE_DIR)
    find_path(TBB_INCLUDE_DIR tbb/tbb.h HINTS "${CMAKE_PREFIX_PATH}/include")
  endif()
  set(TBB_VERSION "2021.13.0")
  set(TBB_ROOT "${CMAKE_PREFIX_PATH}" CACHE PATH "")
  add_library(TBB::tbb ALIAS TBB::tbb) if(NOT TARGET TBB::tbb)
    foreach(_tbb_comp tbb tbbmalloc)
      if(TARGET TBB::${_tbb_comp})
        add_library(TBB ALIAS TBB::${_tbb_comp})
        break()
      endif()
    endforeach()
  endif()
else()
  message(FATAL_ERROR "TBB not found via config. Set TBB_DIR.")
endif()
FINDTBB
cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" \
  -DCMAKE_CXX_FLAGS="-include $PWD/force_includes.h" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOPENPGL_BUILD_TESTS=OFF -DOPENPGL_BUILD_EXAMPLES=OFF \
  -DTBB_DIR="$OUTPUT_DIR/lib/cmake/TBB" \
  -DBUILD_SHARED_LIBS=ON
cmake --build build -j$(nproc)
cmake --install build
cmake -B build-static \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" \
  -DCMAKE_CXX_FLAGS="-include $PWD/force_includes.h" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOPENPGL_BUILD_TESTS=OFF -DOPENPGL_BUILD_EXAMPLES=OFF \
  -DTBB_DIR="$OUTPUT_DIR/lib/cmake/TBB" \
  -DBUILD_SHARED_LIBS=OFF
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "Openpgl built"
ls -lh "$OUTPUT_DIR/lib/"libopenpgl*
