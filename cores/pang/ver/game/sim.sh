#!/bin/bash

eval `jtcfgstr -core pang -output bash`

if [ ! -e rom.bin ]; then
    ln -s $ROM/pang.rom rom.bin || exit $?
fi

jtsim -mist -sysname pang $*
# rm -f test.vcd
# mkfifo test.vcd
# vcd2fst -p test.vcd test.fst&
# obj_dir/sim --trace -frame 1
# rm -f test.vcd