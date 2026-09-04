#!/bin/bash
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
git clone --depth 1 https://github.com/OpenPathGuidingLibrary/openpgl.git src
cd src

rm -f cmake/FindTBB.cmake

# Find actual TBB include dir — need "tbb/tbb.h" to resolve
# TBB 2021.13 installs headers to both include/tbb/ and include/oneapi/tbb/
TBB_INC="$OUTPUT_DIR/include"
if [ -f "$TBB_INC/tbb/tbb.h" ]; then
  TBB_INCLUDE_DIR="$TBB_INC"
elif [ -f "$TBB_INC/oneapi/tbb/tbb.h" ]; then
  TBB_INCLUDE_DIR="$TBB_INC/oneapi"
else
  echo "ERROR: TBB headers not found under $TBB_INC"
  find "$TBB_INC" -name "tbb.h" 2>/dev/null
  exit 1
fi
echo "TBB include dir: $TBB_INCLUDE_DIR"

# Create a fake TBBConfig.cmake that find_package(TBB CONFIG) will find
TBB_CMAKE_DIR="$OUTPUT_DIR/lib/cmake/TBB"
mkdir -p "$TBB_CMAKE_DIR"
cat > "$TBB_CMAKE_DIR/TBBConfig.cmake" << TEOF
# Minimal TBB config for Android ARM64 cross-compilation
set(TBB_FOUND TRUE)
set(TBB_tbb_FOUND TRUE)
set(TBB_INCLUDE_DIRS "$TBB_INCLUDE_DIR")
set(TBB_LIBRARIES TBB::tbb TBB::tbbmalloc)

if(NOT TARGET TBB::tbb)
  add_library(TBB::tbb SHARED IMPORTED GLOBAL)
  set_target_properties(TBB::tbb PROPERTIES
    IMPORTED_LOCATION "$OUTPUT_DIR/lib/libtbb.so"
    INTERFACE_INCLUDE_DIRECTORIES "$TBB_INCLUDE_DIR"
  )
endif()
if(NOT TARGET TBB::tbbmalloc)
  add_library(TBB::tbbmalloc SHARED IMPORTED GLOBAL)
  set_target_properties(TBB::tbbmalloc PROPERTIES
    IMPORTED_LOCATION "$OUTPUT_DIR/lib/libtbbmalloc.so"
  )
endif()
TEOF
cat > "$TBB_CMAKE_DIR/TBBConfigVersion.cmake" << 'VEOF'
set(PACKAGE_VERSION "2021.13")
if("${PACKAGE_FIND_VERSION}" VERSION_GREATER "2021.13")
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
  if("${PACKAGE_FIND_VERSION}" VERSION_EQUAL "2021.13")
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
endif()
VEOF
echo "Created fake TBBConfig.cmake at $TBB_CMAKE_DIR"

cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOPENPGL_BUILD_TESTS=OFF -DOPENPGL_BUILD_EXAMPLES=OFF \
  -DOPENPGL_TBB_ROOT="$OUTPUT_DIR" \
  -DTBB_DIR="$TBB_CMAKE_DIR" 2>&1 | tail -20
cmake --build build -j$(nproc)
cmake --install build

cmake -B build-static \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOPENPGL_BUILD_TESTS=OFF -DOPENPGL_BUILD_EXAMPLES=OFF \
  -DOPENPGL_TBB_ROOT="$OUTPUT_DIR" \
  -DTBB_DIR="$TBB_CMAKE_DIR" 2>&1 | tail -5
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "Openpgl built"
ls -lh "$OUTPUT_DIR/lib/"libopenpgl*
