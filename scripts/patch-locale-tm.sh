#!/bin/bash
# Patch NDK r29 libc++ <locale> to define std::tm before it's used
# The issue: <locale> uses tm (unqualified, inside namespace std) but never
# includes <ctime> or <time.h>. We add the include AND a using declaration
# right before _LIBCPP_BEGIN_NAMESPACE_STD.
set -euo pipefail
NDK_DIR="$1"
LOCALE_H="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/c++/v1/locale"
if [ ! -f "$LOCALE_H" ]; then echo "locale.h not found: $LOCALE_H"; exit 0; fi
if grep -q '_OBL_TM_FIX' "$LOCALE_H"; then echo "Already patched"; exit 0; fi

python3 -c "
with open('$LOCALE_H') as f:
    content = f.read()

# Method: add #include <time.h> and a forward decl + full definition of struct tm
# right after the include guard. This is the most reliable approach.
old = '#define _LIBCPP_LOCALE'
new = '''#define _LIBCPP_LOCALE

// _OBL_TM_FIX: <locale> uses std::tm but never includes <time.h>
// Include time.h and ctime to fully define struct tm
#include <time.h>
#if __cplusplus >= 201103L
#include <ctime>
#else
struct tm {
    int tm_sec; int tm_min; int tm_hour; int tm_mday;
    int tm_mon; int tm_year; int tm_wday; int tm_yday;
    int tm_isdst; long int tm_gmtoff; const char* tm_zone;
};
namespace std { using ::tm; }
#endif'''

if old not in content:
    print('ERROR: include guard not found')
    import sys; sys.exit(1)

content = content.replace(old, new, 1)

with open('$LOCALE_H', 'w') as f:
    f.write(content)
print('Patched locale.h: added struct tm definition and includes')
"
