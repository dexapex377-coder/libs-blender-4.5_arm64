#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-28}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Fix NDK r29 libc++ bug: nanosleep undeclared in __thread/support/pthread.h
FIX_HEADER="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/_obl_time_fix.h"
cat > "$FIX_HEADER" << 'FIXEOF'
#ifndef _OBL_TIME_FIX_H
#define _OBL_TIME_FIX_H
#include <time.h>
#ifdef __cplusplus
extern "C" { int nanosleep(const struct timespec*, struct timespec*); }
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

git clone --depth 1 --branch v24.11 https://github.com/PixarAnimationStudios/OpenUSD.git src
cd src
COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DPXR_BUILD_TESTS=OFF -DPXR_BUILD_EXAMPLES=OFF -DPXR_BUILD_TUTORIALS=OFF
  -DPXR_BUILD_IMAGING=OFF -DPXR_BUILD_USD_TOOLS=OFF -DPXR_BUILD_DOCUMENTATION=OFF
  -DPXR_ENABLE_PTEX_SUPPORT=OFF -DPXR_ENABLE_OPENVDB_SUPPORT=OFF
  -DPXR_ENABLE_USD_VALIDATION=OFF -DPXR_BUILD_OPENSUBDIV_SUPPORT=OFF
)
# Static
cmake -B build -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build
# Shared
cmake -B build-shared -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build-shared -j$(nproc)
cmake --install build-shared
echo "OpenUSD built"
ls -lh "$OUTPUT_DIR/lib/"libusd*
