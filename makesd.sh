#!/bin/bash
cd rom
gngrom.py $*
cd ..
# Create release
cp mist/quartus/jtgng.rbf core.rbf
zip -9 releases/gng-mist-dev.zip core.rbf README.txt 
rm core.rbf
# Copy file
cp -v mist/quartus/jtgng.rbf /media/jtejada/MIST/core.rbf
cp -v rom/JTGNG.rom /media/jtejada/MIST 