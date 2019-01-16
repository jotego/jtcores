#!/bin/bash
cd rom
go-mist.sh $*
cd ..
cp -v rom/JTGNG.rom /media/jtejada/MIST 
cp -v mist/quartus/jtgng.rbf /media/jtejada/MIST/core.rbf