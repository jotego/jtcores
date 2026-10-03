#!/bin/bash
# Build the GnG regression test ROM set
# Usage: ./build.sh [--run]
#   --run  launch MAME after building
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
SRC="$SCRIPT_DIR/reg_test.s"

mkdir -p "$BUILD_DIR"

# ── Step 1: Assemble the 6809 program ──
echo "=== Assembling reg_test.s ==="
lwasm "$SRC" \
    --output="$BUILD_DIR/reg_test.bin" \
    --list="$BUILD_DIR/reg_test.lst" \
    --format=raw

BIN_SIZE=$(wc -c < "$BUILD_DIR/reg_test.bin" | tr -d ' ')
echo "    Binary size: $BIN_SIZE bytes"

if [ "$BIN_SIZE" -ne 40960 ]; then
    echo "ERROR: expected 40960 bytes (\$6000-\$FFFF), got $BIN_SIZE"
    exit 1
fi

# ── Step 2: Split binary into gg3.bin + gg4.bin ──
python3 "$SCRIPT_DIR/split_rom.py" "$BUILD_DIR"

# gg5.bin = banks 0-3 (32 KB, unused)
python3 -c "import sys; sys.stdout.buffer.write(b'\\xff' * 0x8000)" > "$BUILD_DIR/gg5.bin"

# ── Step 3: Generate graphics and stub ROMs ──
echo "=== Generating graphics ROMs ==="
python3 "$SCRIPT_DIR/gen_roms.py" "$BUILD_DIR"

# ── Step 4: Pack into regtest.zip ──
echo "=== Packing regtest.zip ==="
(cd "$BUILD_DIR" && zip -q -j regtest.zip \
    gg1.bin gg2.bin gg3.bin gg4.bin gg5.bin \
    gg6.bin gg7.bin gg8.bin gg9.bin gg10.bin gg11.bin \
    gg12.bin gg13.bin gg14.bin gg15.bin gg16.bin gg17.bin \
    tbp24s10.14k 63s141.2e gg-pal10l8.bin)

echo "=== Done: $BUILD_DIR/regtest.zip ==="
ls -lh "$BUILD_DIR/regtest.zip"

# ── Optional: run in MAME ──
if [ "${1:-}" = "--run" ]; then
    MAME="${MAME:-$HOME/Emus/mame0276-arm64/mame}"
    if [ ! -x "$MAME" ]; then
        echo "ERROR: MAME not found at $MAME"
        echo "Set MAME env var to your mame binary path"
        exit 1
    fi
    echo "=== Launching MAME ==="
    ln -sf regtest.zip "$BUILD_DIR/gng.zip"
    "$MAME" gng -rompath "$BUILD_DIR" -window -nofilter -skip_gameinfo
fi
