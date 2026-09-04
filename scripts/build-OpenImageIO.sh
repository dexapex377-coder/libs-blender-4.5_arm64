#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-28}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"

# Fix NDK r29 libc++ bug: nanosleep undeclared in __thread/support/pthread.h
# Create a wrapper toolchain that injects -include time.h via CMAKE_CXX_FLAGS_INIT
# This works because NDK toolchain reads CMAKE_CXX_FLAGS_INIT before setting CMAKE_CXX_FLAGS
WRAPPER="/tmp/obl_ndk_toolchain.cmake"
cat > "$WRAPPER" << WEOF
# Pre-set CMAKE_{C,CXX}_FLAGS_INIT so -include time.h is baked into the toolchain
set(CMAKE_C_FLAGS_INIT "-include time.h \${CMAKE_C_FLAGS_INIT}")
set(CMAKE_CXX_FLAGS_INIT "-include time.h \${CMAKE_CXX_FLAGS_INIT}")
include("$NDK_DIR/build/cmake/android.toolchain.cmake")
WEOF
echo "Created wrapper toolchain: $WRAPPER"
cat "$WRAPPER"

git clone --depth 1 --branch v2.5.16.0 https://github.com/AcademySoftwareFoundation/OpenImageIO.git src
cd src
mkdir -p build
cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE="/tmp/obl_ndk_toolchain.cmake" \
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
  -DCMAKE_TOOLCHAIN_FILE="/tmp/obl_ndk_toolchain.cmake" \
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
