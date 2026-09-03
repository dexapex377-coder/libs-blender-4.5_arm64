#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/KhronosGroup/OpenCOLLADA.git src
cd src

# LibXml2: replace the "else (WIN32)" block with "always use bundled"
sed -i '/else ()  # if xml2 not found building its local copy from ./Externals/,/endif ()/{
s/if (WIN32)/# ALL: use bundled LibXML/
s/message("WARNING: Native LibXml2 not found, taking LibXml from ./Externals")/message("Using bundled LibXML from ./Externals")/
/message("ERROR: LibXml2 not found/d
s/else ()  # if xml2 not found.*//d
}' CMakeLists.txt

# Simpler: just replace the entire error message lines
sed -i 's/message("ERROR: LibXml2 not found, please install xml2 library (for Debian libxml2-dev)")/message("Using bundled LibXML")/' CMakeLists.txt
sed -i 's/message("ERROR: PCRE not found, please install pcre library")/message("Using bundled PCRE")/' CMakeLists.txt

# Remove the if(WIN32) guard around LibXML bundled build
python3 -c "
import re
with open('CMakeLists.txt') as f:
    c = f.read()

# Fix LibXml2: remove if(WIN32)/else/endif, keep just the add_subdirectory
old = '''\t\tif (WIN32)
\t\t\tmessage(\"WARNING: Native LibXml2 not found, taking LibXml from ./Externals\")
\t\t\tadd_subdirectory(\${EXTERNAL_LIBRARIES}/LibXML)
\t\t\tset(LIBXML2_INCLUDE_DIR
\t\t\t\t\${libxml_include_dirs}
\t\t\t)
\t\t\tset(LIBXML2_LIBRARIES xml)
\t\telse ()
\t\t\tmessage(\"ERROR: LibXml2 not found, please install xml2 library (for Debian libxml2-dev)\")
\t\tendif ()'''
new = '''\t\tmessage(\"Using bundled LibXML\")
\t\tadd_subdirectory(\${EXTERNAL_LIBRARIES}/LibXML)
\t\tset(LIBXML2_INCLUDE_DIR \${libxml_include_dirs})
\t\tset(LIBXML2_LIBRARIES xml)'''
c = c.replace(old, new)

# Fix PCRE: remove if(WIN32 OR APPLE)/else/endif
old = '''\tif (WIN32 OR APPLE)
\t\tmessage(\"WARNING: Native PCRE not found, taking PCRE from ./Externals\")
\t\tadd_definitions(-DPCRE_STATIC)
\t\tadd_subdirectory(\${EXTERNAL_LIBRARIES}/pcre)
\t\tset(PCRE_INCLUDE_DIR \${libpcre_include_dirs})
\t\tset(PCRE_LIBRARIES pcre)
\telse ()
\t\tmessage(\"ERROR: PCRE not found, please install pcre library\")
\tendif ()'''
new = '''\tmessage(\"Using bundled PCRE\")
\tadd_definitions(-DPCRE_STATIC)
\tadd_subdirectory(\${EXTERNAL_LIBRARIES}/pcre)
\tset(PCRE_INCLUDE_DIR \${libpcre_include_dirs})
\tset(PCRE_LIBRARIES pcre)'''
c = c.replace(old, new)

with open('CMakeLists.txt', 'w') as f:
    f.write(c)
print('Patched CMakeLists.txt')
"

# Fix tr1/unordered_map → unordered_map (Android NDK has no tr1)
sed -i 's|#include <tr1/unordered_map>|#include <unordered_map>|g' COLLADABaseUtils/include/COLLADABUhash_map.h
sed -i 's|std::tr1::|std::|g' COLLADABaseUtils/include/COLLADABUhash_map.h

# Add missing POSIX headers to Externals LibXML
sed -i '1i #include <unistd.h>\n#include <fcntl.h>\n#include <sys/types.h>\n#include <sys/stat.h>' Externals/LibXML/xmlIO.c

COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
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
