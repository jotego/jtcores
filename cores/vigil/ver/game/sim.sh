#!/bin/bash

if [ ! -e rom.bin ]; then
    ln -s $ROM/vigilant.rom rom.bin || exit $?
fi

rm -rf obj_dir
$JTFRAME/bin/jtsim -mist -sysname vigil $*