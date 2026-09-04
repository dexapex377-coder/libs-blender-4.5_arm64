#!/bin/bash
# Build OpenImageIO for Android ARM64
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-28}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Fix NDK r29: nanosleep in global namespace not found from namespace std
# Use ::nanosleep (global scope qualifier) instead of nanosleep
PTHREAD_H="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/c++/v1/__thread/support/pthread.h"
python3 << PYEOF
import sys
h = "$PTHREAD_H"
with open(h) as f: c = f.read()
if "_OBL_SLEEP_FIX" in c:
    print("Already patched"); sys.exit(0)
old = 'inline _LIBCPP_HIDE_FROM_ABI void __libcpp_thread_sleep_for(const chrono::nanoseconds& __ns) {'
decl = """// _OBL_SLEEP_FIX: declare nanosleep (NDK r29 libc++ lookup bug)
#ifdef __cplusplus
extern "C" {
#endif
int nanosleep(const struct timespec*, struct timespec*);
#ifdef __cplusplus
}
#endif

"""
if old not in c:
    print("WARNING: function not found"); sys.exit(0)
c = c.replace(old, decl + old)
with open(h, 'w') as f: f.write(c)
print(f"Patched {h}: added nanosleep decl before sleep_for")
PYEOF

# Fix NDK r29 libc++ <locale>: add #include <time.h> for struct tm
bash "$SCRIPT_DIR/patch-locale-tm.sh" "$NDK_DIR"


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
  -DUSE_FFMPEG=OFF -DUSE_OPENCOLORIO=OFF -DUSE_OPENVDB=OFF \
  -DUSE_TBB=OFF
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
  -DUSE_FFMPEG=OFF -DUSE_OPENCOLORIO=OFF -DUSE_OPENVDB=OFF \
  -DUSE_TBB=OFF
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "OpenImageIO built"
ls -lh "$OUTPUT_DIR/lib/"libOpenImageIO*
