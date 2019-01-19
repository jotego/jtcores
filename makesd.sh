#!/bin/bash
cd rom
gngrom.py $*
cd ..
# FPGA core
mv -v mist/quartus/jtgng.rbf mist/core.rbf
cp -v mist/core.rbf /media/jtejada/MIST/core.rbf
# ROM file
cp -v rom/JTGNG.rom /media/jtejada/MIST 