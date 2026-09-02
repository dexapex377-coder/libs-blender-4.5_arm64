#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 --branch v2.13.5 https://github.com/GNOME/libxml2.git src
cd src

# Remove version scripts that reference undefined symbols (lld doesn't support --no-version-script)
find . -name "*.map" -delete 2>/dev/null || true
sed -i 's/set_target_properties(LibXml2 PROPERTIES LINK_FLAGS.*//' CMakeLists.txt 2>/dev/null || true

CMAKE_BASE=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR" -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_HAVE_LIBC_PTHREAD=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DLIBXML2_WITH_TESTS=OFF -DLIBXML2_WITH_PROGRAMS=OFF
  -DLIBXML2_WITH_ICONV=OFF -DLIBXML2_WITH_ICU=OFF
  -DLIBXML2_WITH_LZMA=OFF -DLIBXML2_WITH_ZLIB=OFF
  -DLIBXML2_WITH_PYTHON=OFF -DLIBXML2_WITH_HTML=ON
  -DLIBXML2_WITH_LEGACY=OFF -DLIBXML2_WITH_DEBUG=ON
)

# Static
cmake -B build -DBUILD_SHARED_LIBS=OFF "${CMAKE_BASE[@]}"
cmake --build build -j$(nproc)
cmake --install build

# Shared
cmake -B build-shared -DBUILD_SHARED_LIBS=ON "${CMAKE_BASE[@]}"
cmake --build build-shared -j$(nproc)
cmake --install build-shared

echo "LibXML built"
ls -lh "$OUTPUT_DIR/lib/"libxml2*
