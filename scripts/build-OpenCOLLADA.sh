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

# Fix Windows line endings on ALL files first (dos2unix may not be available)
find . -type f \( -name "*.h" -o -name "*.hpp" -o -name "*.cpp" -o -name "*.c" -o -name "CMakeLists.txt" \) -print0 | xargs -0 sed -i 's/\r$//'

# Fix tr1/unordered_map and tr1/unordered_set → unordered_map/unordered_set in ALL files
# Use Python for reliability (handles tabs between # and include)
python3 << 'PYEOF_fix'
import os, re
fixes = [
    ('include <tr1/unordered_map>', 'include <unordered_map>'),
    ('include <tr1/unordered_set>', 'include <unordered_set>'),
    ('std::tr1::', 'std::'),
]
count = 0
for root, dirs, files in os.walk('.'):
    for fn in files:
        if fn.endswith(('.h', '.hpp', '.cpp', '.c')):
            path = os.path.join(root, fn)
            with open(path, 'rb') as f:
                raw = f.read()
            # Handle \r\n and BOM
            c = raw.decode('utf-8-sig', errors='replace')
            c = c.replace('\r\n', '\n').replace('\r', '\n')
            orig = c
            for old, new in fixes:
                c = c.replace(old, new)
            if c != orig:
                with open(path, 'w') as f:
                    f.write(c)
                count += 1
print(f"Fixed tr1 references in {count} files")
PYEOF_fix

# Fix std::hash specialization: libc++ uses __ndk1 ABI namespace
# The fix goes in COLLADABUhash_map.h where COLLADABU_HASH_NAMESPACE_OPEN is defined
python3 << 'PYEOF3'
path = "COLLADABaseUtils/include/COLLADABUhash_map.h"
with open(path) as f:
    lines = f.readlines()

# Find the Apple libc++ block and add Android libc++ before it
# The Apple block is: #elif (defined(__APPLE__) || defined(__FreeBSD__)) && defined(_LIBCPP_VERSION)
# We need to add: #elif defined(_LIBCPP_VERSION) BEFORE the Apple block
new_lines = []
added = False
for line in lines:
    if not added and '_LIBCPP_VERSION' in line and '__APPLE__' in line:
        # Insert our _LIBCPP_VERSION block BEFORE the Apple block
        new_lines.append('#elif defined(_LIBCPP_VERSION) && !defined(__APPLE__) && !defined(__FreeBSD__)\n')
        new_lines.append('    // Android NDK libc++ (uses __ndk1 ABI namespace)\n')
        new_lines.append('    #include <unordered_map>\n')
        new_lines.append('    #include <unordered_set>\n')
        new_lines.append('    #define COLLADABU_HASH_MAP std::unordered_map\n')
        new_lines.append('    #define COLLADABU_HASH_MULTIMAP std::unordered_multimap\n')
        new_lines.append('    #define COLLADABU_HASH_SET std::unordered_set\n')
        new_lines.append('    #define COLLADABU_HASH_NAMESPACE_OPEN std\n')
        new_lines.append('    #define COLLADABU_HASH_NAMESPACE_CLOSE\n')
        new_lines.append('    #define COLLADABU_HASH_FUN hash\n')
        added = True
    new_lines.append(line)

if added:
    with open(path, "w") as f:
        f.writelines(new_lines)
    print("Patched COLLADABUhash_map.h: added _LIBCPP_VERSION branch for Android libc++")
else:
    print("Already patched or Apple block not found")
PYEOF3

# Also need to fix the tr1 includes in COLLADABUhash_map.h for the GCC branch
# The GCC branch uses tr1/unordered_map which doesn't exist in libc++
# Our earlier find+sed already handled the includes, but the GCC define still
# points to std::tr1 which is wrong — however it's guarded by __GNUC__ so libc++
# (clang) won't hit it. The _LIBCPP_VERSION branch we added above takes priority.

# Add missing POSIX headers to Externals LibXML
sed -i '1i #include <unistd.h>\n#include <fcntl.h>\n#include <sys/types.h>\n#include <sys/stat.h>' Externals/LibXML/xmlIO.c
sed -i '1i #include <unistd.h>\n#include <fcntl.h>\n#include <sys/types.h>\n#include <sys/stat.h>\n#include <sys/socket.h>\n#include <sys/select.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n#include <netdb.h>' Externals/LibXML/nanohttp.c

# Enable schema support in bundled LibXML (CMakeLists.txt defines)
# The undefined xmlSchema* symbols mean the schema module isn't being compiled
cat Externals/LibXML/CMakeLists.txt | grep -i "schema\|XML_SCHEMAS" | head -5 || true

# Skip DAEValidator and COLLADAValidator (tools, not libraries — fail on Android)
sed -i 's|^add_subdirectory(COLLADAValidator)|# add_subdirectory(COLLADAValidator) # skipped for Android|' CMakeLists.txt
sed -i 's|^add_subdirectory(DAEValidator)|# add_subdirectory(DAEValidator) # skipped for Android|' CMakeLists.txt

# Android Bionic doesn't have sys/timeb.h — create stub with ftime()
SYSROOT_INC="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"
mkdir -p "$SYSROOT_INC/sys"
cat > "$SYSROOT_INC/sys/timeb.h" << 'TBEOF'
#ifndef _SYS_TIMEB_H_
#define _SYS_TIMEB_H_
#include <sys/time.h>
struct timeb {
    time_t time;
    unsigned short millitm;
    short timezone;
    short dstflag;
};
static inline int ftime(struct timeb *tp) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    tp->time = tv.tv_sec;
    tp->millitm = (unsigned short)(tv.tv_usec / 1000);
    tp->timezone = 0;
    tp->dstflag = 0;
    return 0;
}
#endif
TBEOF
echo "Created sys/timeb.h stub for Android"

COMMON_FLAGS=(
  -DCMAKE_TOOLCHAIN_FILE="$NDK_DIR/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$API_LEVEL"
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$OUTPUT_DIR"
  -DCMAKE_PREFIX_PATH="$OUTPUT_DIR"
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DCMAKE_CXX_FLAGS="-std=c++14 -Wno-error=unqualified-std-cast-call"
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
find "$OUTPUT_DIR/lib" -name "libOpenCOLLADA*" | head -10
