# Toolchain overlay: adds -include ctime to fix NDK r29 libc++ <locale> tm incomplete type
# This file is included AFTER the real NDK toolchain

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -include ctime")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -include ctime")
