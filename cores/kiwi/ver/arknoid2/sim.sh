#!/bin/bash

SDIR=`pwd`
cd ../../firmware
if ! asl -cpu 8042 arknoid2.s -l > $SDIR/asl.log; then
    cat $SDIR/asl.log
    exit 1
fi
p2bin arknoid2.p || exit $?
cd -

jtsim -sysname kiwi $*
