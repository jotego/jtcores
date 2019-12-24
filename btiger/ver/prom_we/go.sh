#!/bin/bash

ROM=$JTGNG/rom/JTBTIGER.rom
GAME_ROM_LEN=$(stat -c%s $ROM)

if which ncverilog > /dev/null; then
ncverilog test.v ../../hdl/jtbtiger_prom_we.v  \
    +access+r \
    +define+ROM_LEN=$GAME_ROM_LEN +define+PROM_W=1 +define+SIMULATION \
    +define+ROM_PATH=\""$ROM"\" 
else
iverilog test.v ../../hdl/jtbtiger_prom_we.v  \
    -D ROM_LEN=$GAME_ROM_LEN -D PROM_W=1 -D SIMULATION \
    -D ROM_PATH=\""$ROM"\" \
    -o sim \
    && sim -lxt
fi
