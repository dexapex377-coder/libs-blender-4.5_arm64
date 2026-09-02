#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/KhronosGroup/OpenCOLLADA.git src
cd src

# Force LibXml2 and PCRE to be found by setting the variables before cmake
# Option 1: patch CMakeLists.txt to bypass the error on non-Windows
python3 << 'PYEOF'
with open("CMakeLists.txt", "r") as f:
    lines = f.readlines()

new_lines = []
skip_until_endif = False
inside_libxml_find = False
inside_pcre_find = False

i = 0
while i < len(lines):
    line = lines[i]

    # For LibXml2 block: replace the non-Windows error with set()
    if 'find_package(LibXml2)' in line:
        new_lines.append('# ' + line)
        i += 1
        continue

    if 'find_package(PCRE)' in line:
        new_lines.append('# ' + line)
        i += 1
        continue

    # Replace ERROR: LibXml2 with set()
    if 'message("ERROR: LibXml2 not found' in line:
        new_lines.append('\t\tset(LIBXML2_FOUND TRUE)\n')
        new_lines.append('\t\tset(LIBXML2_INCLUDE_DIR "")\n')
        new_lines.append('\t\tset(LIBXML2_LIBRARIES "")\n')
        i += 1
        continue

    # Replace ERROR: PCRE with set()
    if 'message("ERROR: PCRE not found' in line:
        new_lines.append('\tset(PCRE_FOUND TRUE)\n')
        new_lines.append('\tset(PCRE_INCLUDE_DIR "")\n')
        new_lines.append('\tset(PCRE_LIBRARIES "")\n')
        i += 1
        continue

    new_lines.append(line)
    i += 1

with open("CMakeLists.txt", "w") as f:
    f.writelines(new_lines)
print("Patched CMakeLists.txt")
PYEOF

COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DCMAKE_CXX_FLAGS="-include time.h"
  -DOPENCOLLADA_BUILD_TESTS=OFF -DOPENCOLLADA_BUILD_TOOLS=OFF
  -DOPENCOLLADA_BUILD_VIEWER=OFF
)
cmake -B build -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build
cmake -B build-static -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "OpenCOLLADA built"
ls -lh "$OUTPUT_DIR/lib/"libOpenCOLLADA*
