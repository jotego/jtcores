#!/bin/bash

# Creates a reversed folder structure
CORES="gng 1943 1942 commando gunsmoke vulgus biocom tora"

for i in hdl mist mister ver; do
    mkdir -p $JTROOT/$i
    cd $JTROOT/$i
    for j in $CORES; do
        if [ -e $JTROOT/$j/$i ]; then
            ln -f -s $JTROOT/$j/$i $j
        fi
    done
    echo $JTROOT/$i
done

for j in $CORES; do
    if [ -e $JTROOT/rom/$j ]; then
        ln -f -s $JTROOT/rom/$j $JTROOT/$j/rom
    fi
done