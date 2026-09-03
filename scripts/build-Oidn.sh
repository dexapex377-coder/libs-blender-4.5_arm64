#!/bin/bash
# Oidn requires ISPC compiler for CPU kernels — not available for Android cross-compile.
# This is optional for Blender (denoiser only). Skip gracefully.
set -euo pipefail
OUTPUT_DIR="$2"
echo "Oidn SKIPPED: requires ISPC compiler (not available for Android arm64 cross-compile)"
echo "Blender 4.5 builds fine without Oidn (denoiser is optional)"
# Create empty marker so workflow knows it was skipped
mkdir -p "$OUTPUT_DIR/lib" "$OUTPUT_DIR/include/OpenImageDenoise"
touch "$OUTPUT_DIR/lib/.oidn-skipped"
exit 0
