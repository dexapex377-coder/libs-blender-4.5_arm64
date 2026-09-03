#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/KhronosGroup/OpenCOLLADA.git src
cd src

# Patch CMakeLists.txt: use bundled LibXml2/PCRE on ALL platforms (not just Win32)
python3 << 'PYEOF'
with open("CMakeLists.txt", "r") as f:
    c = f.read()

# LibXml2: replace Win32-only bundled fallback with all-platform
c = c.replace(
    'else ()  # if xml2 not found building its local copy from ./Externals\n'
    '\t\tif (WIN32)\n'
    '\t\t\tmessage("WARNING: Native LibXml2 not found, taking LibXml from ./Externals")\n'
    '\t\t\tadd_subdirectory(${EXTERNAL_LIBRARIES}/LibXML)\n'
    '\t\t\tset(LIBXML2_INCLUDE_DIR\n'
    '\t\t\t\t${libxml_include_dirs}\n'
    '\t\t\t)\n'
    '\t\t\tset(LIBXML2_LIBRARIES xml)\n'
    '\t\telse ()\n'
    '\t\t\tmessage("ERROR: LibXml2 not found, please install xml2 library (for Debian libxml2-dev)")\n'
    '\t\tendif ()\n'
    '\tendif ()',
    'else ()\n'
    '\t\tmessage("WARNING: Native LibXml2 not found, using bundled from ./Externals")\n'
    '\t\tadd_subdirectory(${EXTERNAL_LIBRARIES}/LibXML)\n'
    '\t\tset(LIBXML2_INCLUDE_DIR ${libxml_include_dirs})\n'
    '\t\tset(LIBXML2_LIBRARIES xml)\n'
    '\tendif ()'
)

# PCRE: replace Win32/Apple-only bundled fallback with all-platform
c = c.replace(
    'else ()  # if pcre not found building its local copy from ./Externals\n'
    '\tif (WIN32 OR APPLE)\n'
    '\t\tmessage("WARNING: Native PCRE not found, taking PCRE from ./Externals")\n'
    '\t\tadd_definitions(-DPCRE_STATIC)\n'
    '\t\tadd_subdirectory(${EXTERNAL_LIBRARIES}/pcre)\n'
    '\t\tset(PCRE_INCLUDE_DIR ${libpcre_include_dirs})\n'
    '\t\tset(PCRE_LIBRARIES pcre)\n'
    '\telse ()\n'
    '\t\tmessage("ERROR: PCRE not found, please install pcre library")\n'
    '\tendif ()',
    'else ()\n'
    '\tmessage("WARNING: Native PCRE not found, using bundled from ./Externals")\n'
    '\tadd_definitions(-DPCRE_STATIC)\n'
    '\tadd_subdirectory(${EXTERNAL_LIBRARIES}/pcre)\n'
    '\tset(PCRE_INCLUDE_DIR ${libpcre_include_dirs})\n'
    '\tset(PCRE_LIBRARIES pcre)\n'
    '\tendif ()'
)

with open("CMakeLists.txt", "w") as f:
    f.write(c)
print("Patched CMakeLists.txt")
PYEOF

# Fix tr1/unordered_map → unordered_map (deprecated in modern C++)
sed -i 's|#include <tr1/unordered_map>|#include <unordered_map>|g' COLLADABaseUtils/include/COLLADABUhash_map.h
sed -i 's|std::tr1::|std::|g' COLLADABaseUtils/include/COLLADABUhash_map.h

# Add POSIX headers to xmlIO.c (read, close, getcwd)
sed -i '/#include <libxml\/parser.h>/a #include <unistd.h>' Externals/LibXML/xmlIO.c

COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DCMAKE_CXX_FLAGS="-include time.h -std=c++14"
  -DOPENCOLLADA_BUILD_TESTS=OFF -DOPENCOLLADA_BUILD_TOOLS=OFF
  -DOPENCOLLADA_BUILD_VIEWER=OFF
)

cmake -B build -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build

cmake -B build-static -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "OpenCOLLADA built"
ls -lh "$OUTPUT_DIR/lib/"libOpenCOLLADA*
