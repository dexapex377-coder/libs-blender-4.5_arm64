#!/bin/bash
# Build OpenEXR for Android ARM64
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

PTHREAD_H="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/c++/v1/__thread/support/pthread.h"
python3 << PYEOF
import sys
h = "$PTHREAD_H"
with open(h) as f: c = f.read()
if "_OBL_SLEEP_FIX" in c:
    print("Already patched"); sys.exit(0)
old = 'while (nanosleep(&__ts, &__ts) == -1 && errno == EINTR)\n    ;'
new = 'while (::nanosleep(&__ts, &__ts) == -1 && errno == EINTR)\n    ;'
if old not in c:
    print("WARNING: nanosleep call not found"); sys.exit(0)
c = c.replace(old, '// _OBL_SLEEP_FIX\n' + new)
with open(h, 'w') as f: f.write(c)
print(f"Patched {h}: nanosleep -> ::nanosleep")
PYEOF
git clone --depth 1 --branch v3.2.4 https://github.com/AcademySoftwareFoundation/openexr.git src
cd src
cmake -B build \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DBUILD_TOOLS=OFF -DOPENEXR_INSTALL_EXAMPLES=OFF -DOPENEXR_INSTALL_DOCS=OFF \
  -DOPENEXR_INSTALL_UTILS=OFF -DOPENEXR_FORCE_INTERNAL_IMATH=OFF
cmake --build build -j$(nproc)
cmake --install build

# Also build shared
cmake -B build-shared \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DBUILD_TOOLS=OFF -DOPENEXR_INSTALL_EXAMPLES=OFF -DOPENEXR_INSTALL_DOCS=OFF \
  -DOPENEXR_INSTALL_UTILS=OFF -DOPENEXR_FORCE_INTERNAL_IMATH=OFF
cmake --build build-shared -j$(nproc)
cmake --install build-shared
echo "OpenEXR built"
