#!/bin/bash

# Preparare a gray palette so we can get
# some graphics output without the main CPU
if [ ! -e pal.hex ]; then
    (python <<END
for k in range(256):
    print "0000"
    print "4440"
    print "BBB0"
    print "FFF0"
END
) > pal.hex
fi

MIST=-mist
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
done

export MEM_CHECK_TIME=280_000_000
# 280ms to load the ROM ~17 frames
export CONVERT_OPTIONS="-resize 300%"
export YM2151=1
export I8051=1

# Generic simulation script from JTFRAME
$JTFRAME/bin/sim.sh $MIST \
    -sysname biocom \
    -d JT51_NODEBUG -d VIDEO_START=1 $*

if [ -e jt51.log ]; then
    $JTGNG/modules/jt51/bin/log2txt < jt51.log >/tmp/x
  #  mv /tmp/x jt51.log
fi
