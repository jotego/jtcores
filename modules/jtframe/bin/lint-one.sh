#!/bin/bash
# use lint-one.sh core -u JTFRAME_SKIP
# for cores in development phase

CORE=$1
shift
if [ -z "$TARGET" ]; then
    TARGET=mister
fi

eval `jtframe cfgstr $CORE --output bash --target $TARGET $*`

if [[ ! -e $CORES/$CORE/cfg/macros.def || -e $CORES/$CORE/cfg/skip || -v JTFRAME_SKIP ]]; then
    echo "Skipping $CORE"
    exit 0
fi

cd $CORES/$CORE
TEST_FOLDER=ver/lint
rm -rf $TEST_FOLDER
mkdir -p $TEST_FOLDER
cd $TEST_FOLDER

if [ ! -e rom.bin ]; then
    # dummy ROM
    dd if=/dev/zero of=rom.bin count=1 2> /dev/null
    DELROM=
fi

jtsim -lint -$TARGET $*
rm -rf $TEST_FOLDER