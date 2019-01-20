#!/bin/bash

# This batch will create the release file and copy the data to a SD card
# after a synthesis run.
# This suits my development cycle but it is not an essential part of
# Ghosts'n Goblins core at all.

# Create release
cp mist/quartus/jtgng.rbf core.rbf
zip -9 --junk-paths releases/gng-mist-dev.zip rom/gngrom.py core.rbf README.txt 
rm core.rbf 
# Copy file
if [ ! -e /media/jtejada/MIST ]; then
    exit 0
fi

cp -v mist/quartus/jtgng.rbf /media/jtejada/MIST/core.rbf
# and ROM
cd rom
gngrom.py $*
cd ..
cp -v rom/JTGNG.rom /media/jtejada/MIST 