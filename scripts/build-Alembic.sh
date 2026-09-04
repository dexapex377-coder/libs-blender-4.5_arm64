#!/bin/bash
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
git clone --depth 1 --branch 1.8.5 https://github.com/alembic/alembic.git src
cd src
COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DALEMBIC_BUILD_TESTS=OFF -DALEMBIC_BUILD_EXAMPLES=OFF
  -DALEMBIC_BUILD_PYTHON=OFF
  -DALEMBIC_BUILD_HDF5=OFF
  -DUSE_HDF5=OFF
  -DUSE_PRMAN=OFF -DUSE_ARNOLD=OFF -DUSE_OPENGL=OFF -DUSE_MAYA=OFF -DUSE_PYALEMBIC=OFF
)

cmake -B build -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build

cmake -B build-static -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "Alembic built"
