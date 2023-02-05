#!/bin/bash

if [ -e vram.bin ]; then
    dd if=vram.bin of=vram_lo.bin count=2
    dd if=vram.bin of=vram_hi.bin count=2 skip=2
fi

if [ -e objram.bin ]; then
    dd if=objram.bin of=obj1.bin count=2
    dd if=objram.bin of=obj2.bin count=2 skip=2
fi

if [ ! -e rom.bin ]; then
    ln -s $ROM/rocnrope.rom rom.bin || exit 1
fi

jtsim -mist -sysname roc -load -verilator $*
