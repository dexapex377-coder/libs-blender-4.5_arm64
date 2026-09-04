#!/bin/bash
# Wrapper for NDK clang++ that adds -include ctime to fix NDK r29 <locale> incomplete tm
NDK_DIR="$NDK_WRAPPER_NDK_DIR"
REAL="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"
exec "$REAL" -include ctime "$@"
