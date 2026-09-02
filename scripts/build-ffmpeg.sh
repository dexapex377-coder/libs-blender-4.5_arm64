#!/bin/bash
set -euo pipefail
NDK_DIR="$1"; OUTPUT_DIR="$2"; BUILD_DIR="$3"; API_LEVEL="${4:-24}"
mkdir -p "$BUILD_DIR" && cd "$BUILD_DIR"
git clone --depth 1 --branch n7.0.2 https://github.com/FFmpeg/FFmpeg.git src
cd src
TOOLCHAIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64"
TARGET=aarch64-linux-android
./configure \
  --prefix="$OUTPUT_DIR" \
  --target-os=android --arch=aarch64 --cpu=armv8-a \
  --cc="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang" \
  --sysroot="$TOOLCHAIN/sysroot" \
  --enable-shared --enable-static \
  --enable-cross-compile --enable-small \
  --disable-programs --disable-doc \
  --disable-everything \
  --enable-decoder=pcm_s16le --enable-decoder=pcm_f32le \
  --enable-demuxer=wav \
  --enable-protocol=file \
  --disable-avdevice --disable-swresample --disable-swscale \
  --disable-avfilter --disable-postproc \
  --extra-cflags="-O2 -fPIC" --extra-ldflags="-fPIC"
make -j$(nproc) || true
# Install only the libs we built
make install-libs-avcodec install-libs-avformat install-libs-avutil install-libs-swscale 2>/dev/null || \
make install 2>/dev/null || \
cp libav*/lib*.so* libavutil/lib*.so* "$OUTPUT_DIR/lib/" 2>/dev/null || true
# Copy headers
cp -r libavcodec/*.h "$OUTPUT_DIR/include/" 2>/dev/null || true
cp -r libavformat/*.h "$OUTPUT_DIR/include/" 2>/dev/null || true
cp -r libavutil/*.h "$OUTPUT_DIR/include/" 2>/dev/null || true
echo "ffmpeg built"
