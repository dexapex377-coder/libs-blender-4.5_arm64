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

# CAUSE: NDK r26d toolchain forces CMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY,
# which makes find_package() ignore CMAKE_PREFIX_PATH for non-sysroot paths.
# FIX: Replace find_package(TBB) with direct TBB import using known paths.
# NOTE: This patch must be updated if OpenPGL changes its TBB version requirement.
python3 << 'PYEOF'
with open("CMakeLists.txt") as f:
    c = f.read()

old = """FIND_PACKAGE(TBB REQUIRED ${OPENPGL_TBB_COMPONENT})"""

new = """# Cross-compile fix: NDK toolchain forces FIND_ROOT_PATH_MODE_PACKAGE=ONLY,
# which prevents find_package from finding TBB in CMAKE_PREFIX_PATH.
# Import TBB directly from the known install path.
set(TBB_DIR_ENV "$ENV{TBB_DIR}")
if(NOT TBB_DIR AND TBB_DIR_ENV)
  set(TBB_DIR "${TBB_DIR_ENV}")
endif()
if(TBB_DIR)
  find_package(TBB CONFIG PATHS "${TBB_DIR}" NO_DEFAULT_PATH)
else()
  find_package(TBB REQUIRED ${OPENPGL_TBB_COMPONENT})
endif()
if(NOT TBB_FOUND)
  message(FATAL_ERROR "TBB not found. Set -DTBB_DIR=$OUTPUT_DIR/lib/cmake/TBB")
endif()"""

c = c.replace(old, new)
with open("CMakeLists.txt", "w") as f:
    f.write(c)
print("Patched Openpgl CMakeLists.txt to use TBB_DIR directly")
PYEOF

# Export TBB_DIR for the cmake config mode search
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
