#!/bin/bash
# Build OpenColorIO for Android ARM64
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-28}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Fix NDK r29 libc++ bug
PTHREAD_H="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/c++/v1/__thread/support/pthread.h"
python3 -c "
import sys
h = sys.argv[1]
with open(h) as f:
    lines = f.readlines()
if any('_OBL_NANOSLEEP_FIX' in l for l in lines):
    print('Already patched'); sys.exit(0)
target = -1
for i, line in enumerate(lines):
    if 'nanosleep(' in line:
        target = i; break
if target < 0:
    print('WARNING: nanosleep not found'); sys.exit(0)
decl = [
    '// _OBL_NANOSLEEP_FIX\n',
    '#ifdef __cplusplus\n',
    'extern \"C\" {\n',
    '#endif\n',
    'int nanosleep(const struct timespec *, struct timespec *);\n',
    '#ifdef __cplusplus\n',
    '}\n',
    '#endif\n',
    '\n',
]
for j, l in enumerate(decl):
    lines.insert(target + j, l)
with open(h, 'w') as f:
    f.writelines(lines)
print(f'Patched {h}: inserted nanosleep decl before line {target+1}')
" "$PTHREAD_H"

git clone --depth 1 --branch v2.3.2 https://github.com/AcademySoftwareFoundation/OpenColorIO.git src
cd src
COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DOCIO_BUILD_APPS=OFF -DOCIO_BUILD_TESTS=OFF -DOCIO_BUILD_PYGLUE=OFF
  -DOCIO_BUILD_GPUDELEGATES=OFF -DOCIO_INSTALL_EXT_DIR=OFF
  -DOCIO_USE_SSE2=OFF -DOCIO_USE_SSE4=OFF -DOCIO_USE_AVX=OFF -DOCIO_USE_AVX2=OFF
  -DUSE_PYTHON=OFF
  -DCMAKE_DISABLE_FIND_PACKAGE_expat=TRUE
  -DCMAKE_DISABLE_FIND_PACKAGE_yaml-cpp=TRUE
  -DCMAKE_DISABLE_FIND_PACKAGE_pystring=TRUE
  -DCMAKE_DISABLE_FIND_PACKAGE_minizip-ng=TRUE
  -DCMAKE_DISABLE_FIND_PACKAGE_pybind11=TRUE
  -DCMAKE_DISABLE_FIND_PACKAGE_Python=TRUE
)
# Shared
cmake -B build -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build
# Static
cmake -B build-static -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "OpenColorIO built"
