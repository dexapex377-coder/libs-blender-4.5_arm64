#!/bin/bash
# Build OpenImageIO for Android ARM64
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-28}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Fix NDK r29 libc++ bug: nanosleep undeclared in __thread/support/pthread.h
# Insert extern "C" nanosleep forward-decl right before the call (not at top to avoid breaking tm)
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
    '// _OBL_NANOSLEEP_FIX: nanosleep undeclared in NDK r29 libc++\n',
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

git clone --depth 1 --branch v2.5.16.0 https://github.com/AcademySoftwareFoundation/OpenImageIO.git src
cd src
mkdir -p build
cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" \
  -DBUILD_SHARED_LIBS=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOIIO_BUILD_TOOLS=OFF -DOIIO_BUILD_TESTS=OFF \
  -DUSE_PYTHON=OFF -DUSE_OPENGL=OFF -DUSE_QT=OFF \
  -DUSE_LIBHEIF=OFF -DUSE_LIBRAW=OFF -DUSE_OPENSSL=OFF \
  -DUSE_GIF=OFF -DUSE_MAGIC=OFF \
  -DOIIO_BUILD_PLUGINS=ON \
  -DUSE_PUGIXML=ON \
  -DUSE_OPENEXR=ON \
  -DUSE_JPEG=ON \
  -DUSE_PNG=ON \
  -DUSE_TIFF=ON \
  -DUSE_WEBP=ON \
  -DUSE_OPENJPEG=ON \
  -DUSE_FFMPEG=OFF \
  -DUSE_OPENCOLORIO=OFF \
  -DUSE_OPENVDB=OFF
cmake --build build -j$(nproc)
cmake --install build
# Also build static version
cmake -B build-static \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOIIO_BUILD_TOOLS=OFF -DOIIO_BUILD_TESTS=OFF \
  -DUSE_PYTHON=OFF -DUSE_OPENGL=OFF -DUSE_QT=OFF \
  -DUSE_LIBHEIF=OFF -DUSE_LIBRAW=OFF -DUSE_OPENSSL=OFF \
  -DUSE_GIF=OFF -DUSE_MAGIC=OFF \
  -DOIIO_BUILD_PLUGINS=ON \
  -DUSE_PUGIXML=ON \
  -DUSE_OPENEXR=ON \
  -DUSE_JPEG=ON \
  -DUSE_PNG=ON \
  -DUSE_TIFF=ON \
  -DUSE_WEBP=ON \
  -DUSE_OPENJPEG=ON \
  -DUSE_FFMPEG=OFF \
  -DUSE_OPENCOLORIO=OFF \
  -DUSE_OPENVDB=OFF
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "OpenImageIO built"
ls -lh "$OUTPUT_DIR/lib/"libOpenImageIO*
