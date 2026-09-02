#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/KhronosGroup/OpenCOLLADA.git src
cd src
sed -i 's/find_package(LibXml2)/#find_package(LibXml2)/' CMakeLists.txt
sed -i 's/find_package(PCRE)/#find_package(PCRE)/' CMakeLists.txt
# Force LIBXML2/PCRE to use bundled sources by setting vars directly
sed -i '/message.*ERROR.*LibXml2/i\)\nif (NOT DEFINED LIBXML2_FOUND)\n  set(LIBXML2_FOUND TRUE)\n  set(LIBXML2_INCLUDE_DIR "")\n  set(LIBXML2_LIBRARIES "")\nendif()' CMakeLists.txt
# Better approach: patch the else branches to not error
cat > /tmp/fix_opencollada.py << 'PYEOF'
import re
with open("CMakeLists.txt", "r") as f:
    content = f.read()
# Fix LibXml2: on non-Windows, set LIBXML2_FOUND to avoid error
old = 'else ()\n\t\tmessage("ERROR: LibXml2 not found, please install xml2 library (for Debian libxml2-dev)")\n\tendif ()'
new = 'else ()\n\t\tset(LIBXML2_FOUND TRUE)\n\t\tset(LIBXML2_INCLUDE_DIR "")\n\t\tset(LIBXML2_LIBRARIES "")\n\tendif ()'
content = content.replace(old, new)
# Fix PCRE: on non-Windows/Apple, set PCRE_FOUND
old = 'else ()\n\tmessage("ERROR: PCRE not found, please install pcre library")\nendif ()'
new = 'else ()\n\tset(PCRE_FOUND TRUE)\n\tset(PCRE_INCLUDE_DIR "")\n\tset(PCRE_LIBRARIES "")\nendif ()'
content = content.replace(old, new)
with open("CMakeLists.txt", "w") as f:
    f.write(content)
PYEOF
python3 /tmp/fix_opencollada.py
COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_FIND_ROOT_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DCMAKE_CXX_FLAGS="-include time.h"
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
