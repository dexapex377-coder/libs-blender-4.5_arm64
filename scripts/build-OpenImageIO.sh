#!/bin/bash
# Build OpenImageIO for Android ARM64
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-28}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Fix NDK r29 nanosleep: declare function only (no struct forward decl - it shadows global timespec)
PTHREAD_H="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/c++/v1/__thread/support/pthread.h"
python3 -c "
import sys
h = sys.argv[1]
with open(h) as f: content = f.read()
if '_OBL_NANOSLEEP_FIX' in content: print('Already patched'); sys.exit(0)
idx = content.find('while (nanosleep')
if idx < 0: print('WARNING: not found'); sys.exit(0)
content = content[:idx] + 'int nanosleep(const struct timespec *, struct timespec *);\n// _OBL_NANOSLEEP_FIX\n' + content[idx:]
with open(h, 'w') as f: f.write(content)
print(f'Patched {h}')
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
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DBUILD_SHARED_LIBS=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOIIO_BUILD_TOOLS=OFF -DOIIO_BUILD_TESTS=OFF \
  -DUSE_PYTHON=OFF -DUSE_OPENGL=OFF -DUSE_QT=OFF \
  -DUSE_LIBHEIF=OFF -DUSE_LIBRAW=OFF -DUSE_OPENSSL=OFF \
  -DUSE_GIF=OFF -DUSE_MAGIC=OFF \
  -DOIIO_BUILD_PLUGINS=ON \
  -DUSE_PUGIXML=ON -DUSE_OPENEXR=ON -DUSE_JPEG=ON \
  -DUSE_PNG=ON -DUSE_TIFF=ON -DUSE_WEBP=ON -DUSE_OPENJPEG=ON \
  -DUSE_FFMPEG=OFF -DUSE_OPENCOLORIO=OFF -DUSE_OPENVDB=OFF
cmake --build build -j$(nproc)
cmake --install build
cmake -B build-static \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOIIO_BUILD_TOOLS=OFF -DOIIO_BUILD_TESTS=OFF \
  -DUSE_PYTHON=OFF -DUSE_OPENGL=OFF -DUSE_QT=OFF \
  -DUSE_LIBHEIF=OFF -DUSE_LIBRAW=OFF -DUSE_OPENSSL=OFF \
  -DUSE_GIF=OFF -DUSE_MAGIC=OFF \
  -DOIIO_BUILD_PLUGINS=ON \
  -DUSE_PUGIXML=ON -DUSE_OPENEXR=ON -DUSE_JPEG=ON \
  -DUSE_PNG=ON -DUSE_TIFF=ON -DUSE_WEBP=ON -DUSE_OPENJPEG=ON \
  -DUSE_FFMPEG=OFF -DUSE_OPENCOLORIO=OFF -DUSE_OPENVDB=OFF
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "OpenImageIO built"
ls -lh "$OUTPUT_DIR/lib/"libOpenImageIO*
