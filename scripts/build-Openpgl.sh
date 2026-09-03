#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/OpenPathGuidingLibrary/openpgl.git src
cd src

rm -f cmake/FindTBB.cmake

# Create a fake TBBConfig.cmake that find_package(TBB CONFIG) will find
TBB_CMAKE_DIR="$OUTPUT_DIR/lib/cmake/TBB"
mkdir -p "$TBB_CMAKE_DIR"
cat > "$TBB_CMAKE_DIR/TBBConfig.cmake" << 'TEOF'
# Minimal TBB config for Android ARM64 cross-compilation
set(TBB_FOUND TRUE)
set(TBB_tbb_FOUND TRUE)
set(TBB_INCLUDE_DIRS "${CMAKE_CURRENT_LIST_DIR}/../../../include")
set(TBB_LIBRARIES TBB::tbb TBB::tbbmalloc)

if(NOT TARGET TBB::tbb)
  add_library(TBB::tbb SHARED IMPORTED GLOBAL)
  set_target_properties(TBB::tbb PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_LIST_DIR}/../../../lib/libtbb.so"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_CURRENT_LIST_DIR}/../../../include"
  )
endif()
if(NOT TARGET TBB::tbbmalloc)
  add_library(TBB::tbbmalloc SHARED IMPORTED GLOBAL)
  set_target_properties(TBB::tbbmalloc PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_LIST_DIR}/../../../lib/libtbbmalloc.so"
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
ls -la "$TBB_CMAKE_DIR/"

TBB_INC="$OUTPUT_DIR/include"

# Symlink TBB headers into source tree so compiler finds them without -I flags
mkdir -p third-party/tbb
ln -sf "$TBB_INC/tbb" third-party/tbb/tbb

cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOPENPGL_BUILD_TESTS=OFF -DOPENPGL_BUILD_EXAMPLES=OFF \
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
  -DTBB_DIR="$TBB_CMAKE_DIR" 2>&1 | tail -5
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "Openpgl built"
ls -lh "$OUTPUT_DIR/lib/"libopenpgl*
