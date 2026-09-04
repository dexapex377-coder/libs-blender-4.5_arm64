#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-28}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Fix NDK r29 libc++ bug: nanosleep undeclared in __thread/support/pthread.h
# Strategy: create a wrapper time header that ensures nanosleep is always declared,
# then patch the NDK toolchain to force-include it
FIX_HEADER="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/_obl_time_fix.h"
cat > "$FIX_HEADER" << 'FIXEOF'
// _OBL: Force-include time.h + declare nanosleep for NDK r29 libc++ bug
#ifndef _OBL_TIME_FIX_H
#define _OBL_TIME_FIX_H
#include <time.h>
#ifdef __cplusplus
extern "C" {
#endif
// Re-declare nanosleep in case time.h hides it behind __ANDROID_API__ guards
int nanosleep(const struct timespec* __duration, struct timespec* __remainder);
#ifdef __cplusplus
}
#endif
#endif
FIXEOF

TOOLCHAIN="$NDK_DIR/build/cmake/android.toolchain.cmake"
if [ -f "$TOOLCHAIN" ] && ! grep -q '_OBL_TIME_FIX' "$TOOLCHAIN"; then
  echo '' >> "$TOOLCHAIN"
  echo '# _OBL_TIME_FIX' >> "$TOOLCHAIN"
  echo 'set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -include _obl_time_fix.h")' >> "$TOOLCHAIN"
  echo 'set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -include _obl_time_fix.h")' >> "$TOOLCHAIN"
  echo "Patched NDK toolchain for _obl_time_fix.h"
fi

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
