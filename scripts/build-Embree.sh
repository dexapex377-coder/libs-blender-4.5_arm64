#!/bin/bash
# Build Embree for Android ARM64
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
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
    m = "#pragma once"
    if m in c:
        d = '// _OBL_NANOSLEEP_DECL\n#ifndef _OBL_NANOSLEEP_DECL\n#define _OBL_NANOSLEEP_DECL\n#ifdef __cplusplus\nextern "C" {\n#endif\nint nanosleep(const struct timespec *, struct timespec *);\n#ifdef __cplusplus\n}\n#endif\n#endif\n\n'
        c = c.replace(m, m + "\n" + d, 1)
        with open(h, 'w') as f: f.write(c)
        print(f"Patched {h}")
    else: print(f"WARNING: #pragma once not found")
PYEOF
git clone --depth 1 --branch v4.3.3 https://github.com/embree/embree.git src
cd src
cmake -B build \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" -DTBB_DIR="$OUTPUT_DIR/lib/cmake/TBB" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DEMBREE_TUTORIALS=OFF -DEMBREE_ISPC_SUPPORT=OFF -DEMBREE_SYCL_SUPPORT=OFF \
  -DEMBREE_CUDA_SUPPORT=OFF -DEMBREE_VK_SUPPORT=OFF -DEMBREE_STATIC_LIB=OFF
cmake --build build -j$(nproc)
cmake --install build

# Also build static
cmake -B build-static \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" -DTBB_DIR="$OUTPUT_DIR/lib/cmake/TBB" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DEMBREE_TUTORIALS=OFF -DEMBREE_ISPC_SUPPORT=OFF -DEMBREE_SYCL_SUPPORT=OFF \
  -DEMBREE_CUDA_SUPPORT=OFF -DEMBREE_VK_SUPPORT=OFF -DEMBREE_STATIC_LIB=OFF
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "Embree built"
