#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-28}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Fix NDK r29 libc++ bug: nanosleep undeclared in __thread/support/pthread.h
# Declare nanosleep WITHOUT including <time.h> (which breaks struct tm in <locale>)
PTHREAD_H="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/c++/v1/__thread/support/pthread.h"
python3 << PYEOF
import os, sys
h = "$PTHREAD_H"
if not h or not os.path.exists(h):
    print(f"pthread.h not found: {h}")
    sys.exit(0)
with open(h) as f:
    c = f.read()
if "_OBL_NANOSLEEP_DECL" in c:
    print("Already patched")
else:
    patch = """// _OBL_NANOSLEEP_DECL: nanosleep undeclared in NDK r29 libc++ pthread.h
#ifdef __cplusplus
extern "C" {
#endif
struct timespec;
int nanosleep(const struct timespec *__rqtp, struct timespec *__rmtp);
#ifdef __cplusplus
}
#endif
"""
    c = patch + c
    with open(h, 'w') as f:
        f.write(c)
    print(f"Patched {h}: added nanosleep declaration (no time.h include)")
PYEOF

git clone --depth 1 --branch v11.0.0 https://github.com/AcademySoftwareFoundation/openvdb.git src
cd src
COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DOPENVDB_BUILD_UNITTESTS=OFF -DOPENVDB_BUILD_DOCS=OFF
  -DOPENVDB_BUILD_EXAMPLES=OFF -DOPENVDB_BUILD_PYTHON=OFF
  -DOPENVDB_BUILD_TEST_TOOLS=OFF -DOPENVDB_BUILD_HOUDINI_PLUGIN=OFF
  -DOPENVDB_BUILD_MAYA_PLUGIN=OFF -DOPENVDB_BUILD_NANOVDB=OFF
  -DOPENVDB_USE_BLOSC=OFF
  -DUSE_PNG=ON -DUSE_ZLIB=ON -DUSE_EXR=ON
)
# Static
cmake -B build -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build
# Shared
cmake -B build-shared -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build-shared -j$(nproc)
cmake --install build-shared
echo "OpenVDB built"
