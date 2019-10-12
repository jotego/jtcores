#!/bin/bash

# Creates a reversed folder structure
CORES="gng 1943 1942 commando gunsmoke vulgus biocom tora"

for i in hdl mist mister ver; do
    mkdir -p $JTGNG/$i
    cd $JTGNG/$i
    for j in $CORES; do
        if [ -e $JTGNG/$j/$i ]; then
            ln -f -s $JTGNG/$j/$i $j
        fi
    done
    echo $JTGNG/$i
done

for j in $CORES; do
    if [ -e $JTGNG/rom/$j ]; then
        ln -f -s $JTGNG/rom/$j $JTGNG/$j/rom
    fi
done