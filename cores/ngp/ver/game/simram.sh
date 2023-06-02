#!/bin/bash

jtsim -video 51 -d DUMP_RAM $* | grep -v MMR | grep -v Interrupts | \
    sed "s/TOP.game_test.u_game.u_game[^ ]*//" | \
    sed '/ADC/d' | \
    sed '/^[a-zA-Z]/d' > writes.sim

sdiff -d writes.emu writes.sim > d

echo "Generate the emulation file with mameobj.sh. Then, run this command:"
echo "sdiff -d writes.emu writes.sim > d"