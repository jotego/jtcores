#!/bin/bash

# This batch will create the release file and copy the data to a SD card
# after a synthesis run.
# This suits my development cycle but it is not an essential part of
# Ghosts'n Goblins core at all.

# Create release
cp gng/quartus/jtgng.rbf core.rbf
zip -9 --junk-paths releases/gng-mist-dev.zip rom/gngrom.py core.rbf README.txt 
rm core.rbf 

cp 1942/mist/jt1942.rbf core.rbf
zip -9 --junk-paths releases/1942-mist-dev.zip rom/1942rom.py core.rbf README.txt 
# Copy file
if [ ! -e /media/jtejada/MIST ]; then
    exit 0
fi

cp -v gng/quartus/jtgng.rbf /media/jtejada/MIST/gng.rbf
cp -v 1942/mist/jt1942.rbf  /media/jtejada/MIST/core.rbf
# and ROM
cd rom/gngroms
../gngrom.py $*
cp -v JTGNG.rom /media/jtejada/MIST 
cd ../1942
../1942rom.py
cp -v JT1942.rom /media/jtejada/MIST 
cd ../..