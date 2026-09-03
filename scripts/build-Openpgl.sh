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
# find_package(TBB) can never find TBBConfig.cmake outside sysroot.
# FIX: Replace find_package with direct include() of TBBConfig.cmake.
python3 << 'PYEOF'
import re
with open("CMakeLists.txt") as f:
    c = f.read()

# Match the TBB component + find block with flexible whitespace
pattern = (
    r'SET\(OPENPGL_TBB_COMPONENT\s+"tbb".*?\)'  # line 1
    r'\s*\n'                                      # newline
    r'\s*\n'                                      # blank line
    r'if\s*\(NOT \$\{OPENPGL_TBB_ROOT\}\s+STREQUAL\s+""\)\s*\n'  # if block
    r'.*?endif\(\)'                               # until endif
    r'\s*\n'                                      # newline
    r'\s*\n'                                      # blank line
    r'FIND_PACKAGE\(TBB\s+REQUIRED\s+\$\{OPENPGL_TBB_COMPONENT\}\)'  # find_package
)

replacement = """# Cross-compile fix: NDK r26d forces FIND_ROOT_PATH_MODE_PACKAGE=ONLY,
# preventing find_package from finding TBB outside the sysroot.
# Import TBB targets directly via include() of TBBConfig.cmake.
set(OPENPGL_TBB_COMPONENT "tbb" CACHE STRING "The TBB component/library name.")
if(NOT TBB_DIR)
  set(TBB_DIR "$ENV{TBB_DIR}")
endif()
if(NOT TBB_DIR)
  message(FATAL_ERROR "TBB_DIR not set. Pass -DTBB_DIR=/path/to/lib/cmake/TBB")
endif()
list(PREPEND CMAKE_PREFIX_PATH "${TBB_DIR}/../../..")
find_package(TBB CONFIG REQUIRED PATHS "${TBB_DIR}/../../.." NO_DEFAULT_PATH COMPONENTS tbb)
set(TBB_FOUND TRUE)
message(STATUS "Openpgl: TBB imported from ${TBB_DIR}")"""

c_new = re.sub(pattern, replacement, c, flags=re.DOTALL)
if c_new == c:
    # Fallback: simpler line-by-line replacement
    lines = c.split('\n')
    new_lines = []
    skip_until_endif = False
    replaced = False
    for i, line in enumerate(lines):
        stripped = line.strip()
        if 'SET(OPENPGL_TBB_COMPONENT "tbb"' in stripped:
            # Start replacement
            new_lines.append('# Cross-compile fix: NDK r26d FIND_ROOT_PATH_MODE_PACKAGE=ONLY')
            new_lines.append('# Import TBB directly via find_package with explicit PATHS.')
            new_lines.append('set(OPENPGL_TBB_COMPONENT "tbb" CACHE STRING "The TBB component/library name.")')
            new_lines.append('if(NOT TBB_DIR)')
            new_lines.append('  set(TBB_DIR "$ENV{TBB_DIR}")')
            new_lines.append('endif()')
            new_lines.append('if(NOT TBB_DIR)')
            new_lines.append('  message(FATAL_ERROR "TBB_DIR not set. Pass -DTBB_DIR=/path/to/lib/cmake/TBB")')
            new_lines.append('endif()')
            new_lines.append('find_package(TBB CONFIG REQUIRED PATHS "${TBB_DIR}" NO_DEFAULT_PATH COMPONENTS tbb)')
            new_lines.append('set(TBB_FOUND TRUE)')
            new_lines.append('message(STATUS "Openpgl: TBB imported from ${TBB_DIR}")')
            skip_until_endif = True
            replaced = True
            continue
        if skip_until_endif:
            if stripped.startswith('endif()') or stripped == 'endif()':
                skip_until_endif = False
            continue
        if 'FIND_PACKAGE(TBB REQUIRED' in stripped and replaced:
            continue  # skip the original find_package
        new_lines.append(line)
    c_new = '\n'.join(new_lines)

with open("CMakeLists.txt", "w") as f:
    f.write(c_new)
print("Patched Openpgl CMakeLists.txt for TBB cross-compile")
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
