#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-28}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Fix NDK r29 libc++ bug: nanosleep undeclared in __thread/support/pthread.h
PTHREAD_H="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/c++/v1/__thread/support/pthread.h"
python3 << PYEOF
import os, sys
h = "$PTHREAD_H"
if not h or not os.path.exists(h):
    print(f"pthread.h not found: {h}"); sys.exit(0)
with open(h) as f: c = f.read()
if "_OBL_NANOSLEEP_DECL" in c:
    print("Already patched")
else:
    decl = '// _OBL_NANOSLEEP_DECL: nanosleep undeclared in NDK r29 libc++ pthread.h\n#ifndef _OBL_NANOSLEEP_DECL\n#define _OBL_NANOSLEEP_DECL\n#ifdef __cplusplus\nextern "C" {\n#endif\nint nanosleep(const struct timespec *, struct timespec *);\n#ifdef __cplusplus\n}\n#endif\n#endif\n\n'
    c = decl + c
    with open(h, 'w') as f: f.write(c)
    print(f"Patched {h}: added nanosleep decl at top")
PYEOF

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
