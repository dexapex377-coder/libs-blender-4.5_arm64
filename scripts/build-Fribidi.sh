#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 https://github.com/fribidi/fribidi.git src
cd src
TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
TARGET=aarch64-linux-android
cat > /tmp/fribidi_cross.txt << MESONEOF
[binaries]
c = '$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang'
cpp = '$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang++'
ar = '$TOOLCHAIN/bin/llvm-ar'
strip = '$TOOLCHAIN/bin/llvm-strip'
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8a'
endian = 'little'
MESONEOF
meson setup build \
  --cross-file /tmp/fribidi_cross.txt \
  --prefix="$OUTPUT_DIR" \
  --default-library=both \
  -Dtests=false -Ddocs=false
ninja -C build
ninja -C build install
echo "Fribidi built"
ls -lh "$OUTPUT_DIR/lib/"libfribidi*
