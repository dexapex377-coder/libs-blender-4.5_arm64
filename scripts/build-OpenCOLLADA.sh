#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/KhronosGroup/OpenCOLLADA.git src
cd src

# CAUSE: str.replace() patterns used \n + spaces but file has \r\n + tabs.
# FIX: Use sed with flexible whitespace matching instead of exact Python str.replace().

# LibXml2: remove the if(WIN32)/else/endif guard, keep only the bundled fallback
# Match: if (WIN32) { ... } else { error } endif → just the bundled fallback
python3 << 'PYEOF'
import re
with open("CMakeLists.txt") as f:
    c = f.read()

# LibXml2 block: remove if(WIN32)/else/endif, keep just the add_subdirectory
c = re.sub(
    r'\t\tif\s*\(WIN32\)\s*\n'
    r'\t\t\tmessage\("WARNING: Native LibXml2 not found.*?\)\s*\n'
    r'\t\t\tadd_subdirectory\(\$\{EXTERNAL_LIBRARIES\}/LibXML\)\s*\n'
    r'\t\t\tset\(LIBXML2_INCLUDE_DIR\s*\n'
    r'\t\t\t\t\$\{libxml_include_dirs\}\s*\n'
    r'\t\t\t\)\s*\n'
    r'\t\t\tset\(LIBXML2_LIBRARIES xml\)\s*\n'
    r'\t\telse\s*\(\)\s*\n'
    r'\t\t\tmessage\("ERROR: LibXml2 not found.*?\)\s*\n'
    r'\t\tendif\s*\(\)',
    '\t\tmessage("Using bundled LibXML from ./Externals")\n'
    '\t\tadd_subdirectory(${EXTERNAL_LIBRARIES}/LibXML)\n'
    '\t\tset(LIBXML2_INCLUDE_DIR ${libxml_include_dirs})\n'
    '\t\tset(LIBXML2_LIBRARIES xml)',
    c
)

# PCRE block: remove if(WIN32 OR APPLE)/else/endif, keep just the add_subdirectory
c = re.sub(
    r'\tif\s*\(WIN32 OR APPLE\)\s*\n'
    r'\t\tmessage\("WARNING: Native PCRE not found.*?\)\s*\n'
    r'\t\tadd_definitions\(-DPCRE_STATIC\)\s*\n'
    r'\t\tadd_subdirectory\(\$\{EXTERNAL_LIBRARIES\}/pcre\)\s*\n'
    r'\t\tset\(PCRE_INCLUDE_DIR \$\{libpcre_include_dirs\}\)\s*\n'
    r'\t\tset\(PCRE_LIBRARIES pcre\)\s*\n'
    r'\telse\s*\(\)\s*\n'
    r'\t\tmessage\("ERROR: PCRE not found.*?\)\s*\n'
    r'\tendif\s*\(\)',
    '\tmessage("Using bundled PCRE from ./Externals")\n'
    '\tadd_definitions(-DPCRE_STATIC)\n'
    '\tadd_subdirectory(${EXTERNAL_LIBRARIES}/pcre)\n'
    '\tset(PCRE_INCLUDE_DIR ${libpcre_include_dirs})\n'
    '\tset(PCRE_LIBRARIES pcre)',
    c
)

with open("CMakeLists.txt", "w") as f:
    f.write(c)
print("Patched CMakeLists.txt (regex-based, handles any whitespace)")
PYEOF

# Fix wsockcompat.h: wrap entire file with #ifdef _WIN32 (only needed on Windows)
python3 << 'PYEOF2'
import os
path = "Externals/LibXML/include/wsockcompat.h"
if os.path.exists(path):
    with open(path, "r") as f:
        content = f.read()
    if "#ifdef _WIN32" not in content.split("\n")[0:3]:
        with open(path, "w") as f:
            f.write("#ifndef _WIN32\n/* Not Windows - skip wsockcompat */\n#else\n" + content + "\n#endif\n")
        print("Patched wsockcompat.h")
    else:
        print("Already patched")
PYEOF2

# Fix Windows line endings on ALL files first
find . -type f \( -name "*.h" -o -name "*.hpp" -o -name "*.cpp" -o -name "*.c" -o -name "CMakeLists.txt" \) -print0 | xargs -0 dos2unix 2>/dev/null || true

# Fix tr1/unordered_map and tr1/unordered_set → unordered_map/unordered_set in ALL files
find . \( -name "*.h" -o -name "*.hpp" -o -name "*.cpp" \) -print0 | xargs -0 sed -i 's|#include <tr1/unordered_map>|#include <unordered_map>|g' 2>/dev/null
find . \( -name "*.h" -o -name "*.hpp" -o -name "*.cpp" \) -print0 | xargs -0 sed -i 's|#include <tr1/unordered_set>|#include <unordered_set>|g' 2>/dev/null
find . \( -name "*.h" -o -name "*.hpp" -o -name "*.cpp" \) -print0 | xargs -0 sed -i 's|std::tr1::|std::|g' 2>/dev/null

# Fix std::hash specialization: libc++ uses __ndk1 ABI namespace
# COLLADABUHashFunctions.h does namespace std { template<> struct hash<...> }
# which fails with "not in a namespace enclosing '__ndk1'"
# Fix: use _LIBCPP_BEGIN_NAMESPACE_STD / _LIBCPP_END_NAMESPACE_STD macros
python3 << 'PYEOF3'
import re
path = "COLLADABaseUtils/include/COLLADABUHashFunctions.h"
with open(path) as f:
    c = f.read()
# Replace "namespace std {" with _LIBCPP_BEGIN_NAMESPACE_STD and matching "}" with _LIBCPP_END_NAMESPACE_STD
if '_LIBCPP_BEGIN_NAMESPACE_STD' not in c:
    c = c.replace('namespace std {', '_LIBCPP_BEGIN_NAMESPACE_STD')
    # Find and replace the matching closing brace for namespace std
    # The pattern: the hash struct definition ends with }; then }
    c = re.sub(r'(\};)\s*\n(\})\s*$', r'\1\n_LIBCPP_END_NAMESPACE_STD\n', c, count=1)
    with open(path, "w") as f:
        f.write(c)
    print("Patched COLLADABUHashFunctions.h for libc++ namespace")
else:
    print("Already patched")
PYEOF3

# Add missing POSIX headers to Externals LibXML
sed -i '1i #include <unistd.h>\n#include <fcntl.h>\n#include <sys/types.h>\n#include <sys/stat.h>' Externals/LibXML/xmlIO.c
sed -i '1i #include <unistd.h>\n#include <fcntl.h>\n#include <sys/types.h>\n#include <sys/stat.h>\n#include <sys/socket.h>\n#include <sys/select.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n#include <netdb.h>' Externals/LibXML/nanohttp.c

# Enable schema support in bundled LibXML (CMakeLists.txt defines)
# The undefined xmlSchema* symbols mean the schema module isn't being compiled
cat Externals/LibXML/CMakeLists.txt | grep -i "schema\|XML_SCHEMAS" | head -5 || true

# Skip DAEValidator and COLLADAValidator (tools, not libraries — fail on Android)
sed -i 's|^add_subdirectory(COLLADAValidator)|# add_subdirectory(COLLADAValidator) # skipped for Android|' CMakeLists.txt
sed -i 's|^add_subdirectory(DAEValidator)|# add_subdirectory(DAEValidator) # skipped for Android|' CMakeLists.txt

COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DCMAKE_CXX_FLAGS="-include time.h -std=c++14"
  -DOPENCOLLADA_BUILD_TESTS=OFF -DOPENCOLLADA_BUILD_TOOLS=OFF
  -DOPENCOLLADA_BUILD_VIEWER=OFF
  -DCMAKE_CXX_FLAGS="-include time.h -std=c++14 -Wno-error=unqualified-std-cast-call"
)

cmake -B build -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build

cmake -B build-static -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "OpenCOLLADA built"
ls -lh "$OUTPUT_DIR/lib/"libOpenCOLLADA*
