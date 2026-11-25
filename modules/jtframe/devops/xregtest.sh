#!/bin/bash -e
# Run a regression test for a core using its open-source test ROM
# Called from the regression_tests GitHub Action
# Usage: xregtest.sh <core>

CORE=$1
if [ -z "$CORE" ]; then
    echo "Usage: xregtest.sh <core>"
    exit 1
fi

git config --global --add safe.directory /jtcores
cd /jtcores
export JTROOT=$(pwd)
export JTFRAME=$JTROOT/modules/jtframe
export MODULES=$JTROOT/modules
export CORES=$JTROOT/cores
export ROM=$JTROOT/rom
export JTBIN=$JTROOT/release
export PATH=$JTFRAME/bin:$PATH
source $JTFRAME/bin/setprj.sh > /dev/null 2>&1 || true

REGDIR=$CORES/$CORE/reg
VERDIR=$CORES/$CORE/ver/regtest

if [ ! -f "$REGDIR/regtest.mra" ]; then
    echo "ERROR: $REGDIR/regtest.mra not found"
    exit 1
fi
if [ ! -f "$REGDIR/build/regtest.zip" ]; then
    echo "ERROR: $REGDIR/build/regtest.zip not found"
    exit 1
fi
if [ ! -f "$REGDIR/golden/frames.crc" ]; then
    echo "ERROR: $REGDIR/golden/frames.crc not found (no golden reference)"
    exit 1
fi

echo "=== Regression test: $CORE ==="

# Step 1: Generate .rom from MRA + zip
echo "--- Generating .rom ---"
mkdir -p $ROM
jtutil rom "$REGDIR/regtest.mra" --path "$REGDIR/build"

# Step 2: Prepare simulation folder
echo "--- Preparing simulation ---"
mkdir -p "$VERDIR"
cd "$VERDIR"
ln -sf $ROM/regtest.rom rom.bin

# Link cab file
if [ -f "$REGDIR/reg_test.cab" ]; then
    ln -sf "$REGDIR/reg_test.cab" reg.cab
fi

# Step 3: Create SDRAM bank files
echo "--- Creating SDRAM banks ---"
rm -rf sdram_bank*.bin
jtutil sdram regtest

# Step 4: Run simulation
echo "--- Running simulation ---"
rm -rf frames
CAB_ARG=""
if [ -f reg.cab ]; then
    # Count cab frames for video dump length
    CAB_FRAMES=$(grep -c '^[0-9]' reg.cab 2>/dev/null || echo 210)
    CAB_ARG="reg.cab"
fi
jtsim -video ${CAB_FRAMES:-210} $CAB_ARG

# Step 5: Compare CRCs
echo "--- Comparing frame CRCs ---"
if [ ! -f frames/frames.crc ]; then
    echo "ERROR: No frames.crc produced by simulation"
    exit 2
fi

GOLDEN="$REGDIR/golden/frames.crc"
if diff -q "$GOLDEN" frames/frames.crc > /dev/null 2>&1; then
    echo "PASS: All $(wc -l < frames/frames.crc | tr -d ' ') frame CRCs match"
    exit 0
else
    echo "FAIL: Frame CRCs differ"
    diff "$GOLDEN" frames/frames.crc | head -20
    exit 1
fi
