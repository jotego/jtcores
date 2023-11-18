#!/bin/bash
git config --global --add safe.directory /jtcores
cd /jtcores
export JTROOT=$(pwd)
export JTFRAME=$JTROOT/modules/jtframe

source $JTFRAME/bin/setprj.sh
export PATH=$PATH:/usr/local/go/bin

CORENAME=$1

BETAKEY="$2"
if [ -z "$BETAKEY" ]; then
    BETAKEY=`printf "%04X%04X" $RANDOM $RANDOM`
    echo "WARNING: remote compilation with no beta key. Assigning random one"
fi

export JTUTIL=/jtutil
mkdir $JTUTIL
printf "%08x" 0x$BETAKEY | xxd -r -p > $JTUTIL/beta.bin

if [ -e $CORES/$CORENAME/cfg/macros.def ]; then
    jtframe mra --skipROM $CORENAME
    # Remote builds have red OSD. beta key is enabled for cores listed in beta.yaml
    jtseed 3 $CORENAME -mister --nodbg -d JTFRAME_OSDCOLOR=0x30
fi
