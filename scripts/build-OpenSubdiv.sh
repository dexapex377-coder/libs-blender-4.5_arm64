#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 --branch v3_6_0 https://github.com/PixarAnimationStudios/OpenSubdiv.git src
cd src

TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
CC="$TOOLCHAIN/bin/aarch64-linux-android${API_LEVEL}-clang"
CXX="$TOOLCHAIN/bin/aarch64-linux-android${API_LEVEL}-clang++"
AR="$TOOLCHAIN/bin/llvm-ar"
INC="-I. -Iopensubdiv -Iopensubdiv/osd -Iopensubdiv/far -Iopensubdiv/vtr -Iopensubdiv/sdc -Iopensubdiv/hbr -Iopensubdiv/bfr -IglLoader"
CFLAGS="-O2 -fPIC -DANDROID -D__ANDROID_API__=$API_LEVEL -DOPENSUBDIV_VERSION_STRING=\"3.6.0\" $INC"
CXXFLAGS="$CFLAGS -std=c++17"

rm -rf "$BUILD_DIR/obj"
mkdir -p "$BUILD_DIR/obj"

compile_sources() {
    local dir="$1"
    local count=0
    while IFS= read -r f; do
        local obj="$BUILD_DIR/obj/$(echo $f | tr '/' '_').o"
        if $CXX $CXXFLAGS -c "$f" -o "$obj" 2>/dev/null; then
            count=$((count + 1))
        fi
    done < <(find "$dir" -name "*.cpp" \
        ! -name "*cl.cpp" ! -name "*cuda*" ! -name "*metal*" \
        ! -name "*vulkan*" ! -name "*dx*" ! -name "*d3d*" \
        ! -name "*cudaRuntime*" ! -name "*cudacommon*" 2>/dev/null)
    echo "  Compiled $count files from $dir"
}

echo "=== Compiling OpenSubdiv 3.6.0 CPU sources ==="
compile_sources "opensubdiv/osd"
compile_sources "opensubdiv/far"
compile_sources "opensubdiv/vtr"
compile_sources "opensubdiv/sdc"
compile_sources "opensubdiv/bfr"

$CXX $CXXFLAGS -c opensubdiv/version.cpp -o "$BUILD_DIR/obj/version.o" 2>/dev/null || true

echo "=== Creating static + shared libraries ==="
mkdir -p "$OUTPUT_DIR/lib" "$OUTPUT_DIR/include/opensubdiv"

$AR rcs "$OUTPUT_DIR/lib/libosdCPU.a" "$BUILD_DIR/obj/"*.o
$CXX -shared -o "$OUTPUT_DIR/lib/libosdCPU.so" "$BUILD_DIR/obj/"*.o -lm

echo "=== Copying headers ==="
for dir in osd far hbr sdc vtr bfr; do
  [ -d "opensubdiv/$dir" ] && cp -r "opensubdiv/$dir" "$OUTPUT_DIR/include/opensubdiv/" 2>/dev/null || true
done
find opensubdiv -maxdepth 1 -name "*.h" -exec cp {} "$OUTPUT_DIR/include/opensubdiv/" \; 2>/dev/null || true

echo "=== Done ==="
ls -lh "$OUTPUT_DIR/lib/libosdCPU"*
