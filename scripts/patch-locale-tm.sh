#!/bin/bash
# Patch NDK r29 libc++ <locale> to include <ctime> (fixes incomplete 'tm' type)
# <locale> uses 'tm' unqualified inside namespace std templates.
# <time.h> only defines ::tm (global). <ctime> imports it into std::.
set -euo pipefail
NDK_DIR="$1"
LOCALE_H="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include/c++/v1/locale"
if [ ! -f "$LOCALE_H" ]; then echo "locale.h not found: $LOCALE_H"; exit 0; fi
if grep -q '_OBL_TM_FIX' "$LOCALE_H"; then echo "Already patched"; exit 0; fi

python3 -c "
with open('$LOCALE_H') as f:
    lines = f.readlines()
out = []
patched = False
for line in lines:
    out.append(line)
    if not patched and line.strip() == '#define _LIBCPP_LOCALE':
        out.append('// _OBL_TM_FIX: <locale> uses std::tm but never includes <ctime>\n')
        out.append('#include <ctime>\n')
        out.append('#include <time.h>\n')
        patched = True
with open('$LOCALE_H', 'w') as f:
    f.writelines(out)
print('Patched locale.h: added #include <ctime> and <time.h>')
"
