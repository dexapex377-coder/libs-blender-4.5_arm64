#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/KhronosGroup/OpenCOLLADA.git src
cd src

# Patch: use bundled LibXml2/PCRE on all platforms (not just Win32)
python3 << 'PYEOF'
with open("CMakeLists.txt", "r") as f:
    content = f.read()

# Fix LibXml2: use bundled on all platforms
old = '''	else ()  # if xml2 not found building its local copy from ./Externals
		if (WIN32)
			message("WARNING: Native LibXml2 not found, taking LibXml from ./Externals")
			add_subdirectory(${EXTERNAL_LIBRARIES}/LibXML)
			set(LIBXML2_INCLUDE_DIR
				${libxml_include_dirs}
			)
			set(LIBXML2_LIBRARIES xml)
		else ()
			message("ERROR: LibXml2 not found, please install xml2 library (for Debian libxml2-dev)")
		endif ()
	endif ()'''

new = '''	else ()
		message("WARNING: Native LibXml2 not found, using bundled from ./Externals")
		add_subdirectory(${EXTERNAL_LIBRARIES}/LibXML)
		set(LIBXML2_INCLUDE_DIR ${libxml_include_dirs})
		set(LIBXML2_LIBRARIES xml)
	endif ()'''

content = content.replace(old, new)

# Fix PCRE: use bundled on all platforms
old = '''else ()  # if pcre not found building its local copy from ./Externals
	if (WIN32 OR APPLE)
		message("WARNING: Native PCRE not found, taking PCRE from ./Externals")
		add_definitions(-DPCRE_STATIC)
		add_subdirectory(${EXTERNAL_LIBRARIES}/pcre)
		set(PCRE_INCLUDE_DIR ${libpcre_include_dirs})
		set(PCRE_LIBRARIES pcre)
	else ()
		message("ERROR: PCRE not found, please install pcre library")
	endif ()
endif ()'''

new = '''else ()
	message("WARNING: Native PCRE not found, using bundled from ./Externals")
	add_definitions(-DPCRE_STATIC)
	add_subdirectory(${EXTERNAL_LIBRARIES}/pcre)
	set(PCRE_INCLUDE_DIR ${libpcre_include_dirs})
	set(PCRE_LIBRARIES pcre)
endif ()'''

content = content.replace(old, new)

with open("CMakeLists.txt", "w") as f:
    f.write(content)
print("Patched successfully")
PYEOF

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
  -DLIBXML_HTTP_ENABLED=OFF -DLIBXML_FTP_ENABLED=OFF
)
# Patch bundled LibXML: wrap wsockcompat.h with #ifdef _WIN32
cat > /tmp/fix_wsock.py << 'PYEOF'
import os
path = "Externals/LibXML/include/wsockcompat.h"
if os.path.exists(path):
    with open(path, "r") as f:
        content = f.read()
    if "#ifdef _WIN32" not in content.split("\n")[8:12]:
        with open(path, "w") as f:
            f.write('#ifndef _WIN32\n/* Not Windows - skip wsockcompat */\n#else\n' + content + '\n#endif\n')
        print("Patched wsockcompat.h")
    else:
        print("Already patched")
else:
    print("File not found")
PYEOF
python3 /tmp/fix_wsock.py
# Patch bundled nanohttp.c: add POSIX socket headers for Android
sed -i '/#include <libxml\/parser.h>/a #include <sys/types.h>\n#include <sys/socket.h>\n#include <sys/select.h>\n#include <netinet/in.h>\n#include <arpa/inet.h>\n#include <netdb.h>\n#include <unistd.h>\n#include <fcntl.h>\n#include <errno.h>' Externals/LibXML/nanohttp.c
# Also define LIBXML_HTTP_ENABLED=0 at top of nanohttp.c to skip HTTP entirely
sed -i '1i #define LIBXML_HTTP_ENABLED 0' Externals/LibXML/nanohttp.c
cmake -B build -DBUILD_SHARED_LIBS=ON "${COMMON_FLAGS[@]}"
cmake --build build -j$(nproc)
cmake --install build
cmake -B build-static -DBUILD_SHARED_LIBS=OFF "${COMMON_FLAGS[@]}"
cmake --build build-static -j$(nproc)
cmake --install build-static
echo "OpenCOLLADA built"
ls -lh "$OUTPUT_DIR/lib/"libOpenCOLLADA*
