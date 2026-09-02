#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 --branch 1.5.10 https://github.com/anholt/libepoxy.git src
cd src
TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
TARGET=aarch64-linux-android
export CC="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang"
export CXX="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang++"

pip install meson ninja 2>/dev/null || true
cat > /tmp/epoxy_cross.txt << MESONEOF
[binaries]
c = '$CC'
cpp = '$CXX'
ar = '$TOOLCHAIN/bin/llvm-ar'
strip = '$TOOLCHAIN/bin/llvm-strip'
pkgconfig = '/usr/bin/pkg-config'
[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8a'
endian = 'little'
[properties]
sys_root = '$TOOLCHAIN/sysroot'
MESONEOF

meson setup build \
  --cross-file /tmp/epoxy_cross.txt \
  --prefix="$OUTPUT_DIR" \
  --default-library=shared \
  -Dtests=false
ninja -C build
ninja -C build install

meson setup build-static \
  --cross-file /tmp/epoxy_cross.txt \
  --prefix="$OUTPUT_DIR" \
  --default-library=static \
  -Dtests=false
ninja -C build-static
ninja -C build-static install

echo "Epoxy built"
ls -lh "$OUTPUT_DIR/lib/"libepoxy*
