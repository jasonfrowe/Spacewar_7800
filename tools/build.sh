#!/bin/sh
# Build Spacewar 7800 with 7800basic and mark with AstroCart math unit header
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BASDIR="${bas7800dir:-$ROOT/tools/7800basic}"
if [ ! -d "$BASDIR" ]; then
    BASDIR="$HOME/Software/Atari7800/7800basic"
fi
WORK="$ROOT/build/work"

# 1. Generate graphics
python3 "$ROOT/tools/mkgfx.py"

# 2. Setup build directory
rm -rf "$WORK"
mkdir -p "$WORK" "$ROOT/build"
cp -R "$ROOT/src/." "$WORK/"
if [ -d "$ROOT/src/asm" ]; then
    cp "$ROOT/src/asm/"*.asm "$WORK/" 2>/dev/null || true
fi

# 3. Compile with 7800basic
cd "$WORK"
rm -f spacewar.bas.bin spacewar.bas.a78
bas7800dir="$BASDIR" PATH="$BASDIR:$PATH" sh "$BASDIR/7800basic.sh" spacewar.bas > build.log 2>&1 || true

if [ ! -f spacewar.bas.a78 ] || grep -q -i -E "Fatal assembly error|Compilation failed" build.log; then
    grep -i -E -B2 -A2 "error|unresolved|failed" build.log | head -40
    echo "BUILD FAILED (see build/work/build.log)"
    exit 1
fi

# 4. Copy outputs and apply math unit signature
cp spacewar.bas.a78 "$ROOT/build/spacewar.a78"
cp spacewar.bas.bin "$ROOT/build/spacewar.bin"
python3 "$ROOT/tools/a78math.py" "$ROOT/build/spacewar.a78"

grep -E "bytes of ROM space left|used as zone memory|bytes left in the 7800basic reserved area" build.log || true
echo "SUCCESS: Built build/spacewar.a78 (MathUnit enabled)"
