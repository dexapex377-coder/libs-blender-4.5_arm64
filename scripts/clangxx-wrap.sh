#!/bin/bash
# Clang wrapper: force-includes <time.h> to fix NDK r29 nanosleep bug in libc++ pthread.h
# This wrapper MUST be called with the real compiler path as first arg after setup
REAL_CXX="${OBL_REAL_CXX:?Set OBL_REAL_CXX to the real clang++ path}"
exec "$REAL_CXX" -include time.h "$@"
