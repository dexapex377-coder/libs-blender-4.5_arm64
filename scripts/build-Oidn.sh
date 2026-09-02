#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 --branch v2.3.2 https://github.com/OpenImageDenoise/oidn.git src
cd src
# Remove ISPC entirely
rm -f cmake/oidn_ispc.cmake
sed -i 's/include(oidn_ispc.cmake)/# ISPC disabled for Android/' CMakeLists.txt
sed -i 's/include(oidn_ispc)/# ISPC disabled for Android/' CMakeLists.txt
find . -name "CMakeLists.txt" -exec sed -i 's/include(oidn_ispc)/# ISPC disabled for Android/g' {} \;
find . -name "CMakeLists.txt" -exec sed -i 's/ispc_target_add_sources/# ISPC disabled/g' {} \;
cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" \
  -DTBB_DIR="$OUTPUT_DIR/lib/cmake/tbb" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DBUILD_SHARED_LIBS=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DODNN_BUILD_TESTS=OFF -DODNN_BUILD_APPS=OFF -DODNN_BUILD_CLI=OFF \
  -DODNN_ISPC_SUPPORT=OFF -DODNN_OPENAPI_SUPPORT=OFF \
  -DODNN_GPUDCNN_SUPPORT=OFF -DODNN_TRAINING_SUPPORT=OFF
cmake --build build -j$(nproc)
cmake --install build

# Also build static
cmake -B build-static \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR" \
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" \
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR" \
  -DTBB_DIR="$OUTPUT_DIR/lib/cmake/TBB" \
  -DCMAKE_HAVE_LIBC_PTHREAD=ON \
  -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DODNN_BUILD_TESTS=OFF -DODNN_BUILD_APPS=OFF -DODNN_BUILD_CLI=OFF \
  -DODNN_ISPC_SUPPORT=OFF -DODNN_OPENAPI_SUPPORT=OFF \
  -DODNN_GPUDCNN_SUPPORT=OFF -DODNN_TRAINING_SUPPORT=OFF
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "Oidn built"
