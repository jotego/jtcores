#!/bin/bash

jtsim -video 50 -d DUMP_RAM | grep -v MMR | grep -v Interrupts | \
    sed "s/TOP.game_test.u_game.u_game[^ ]*//" | \
    sed '/ADC/d' | \
    sed '/^[a-zA-Z]/d' > writes.sim

