#!/bin/bash

# Creates a reversed folder structure

for i in hdl mist mister ver; do
    mkdir -p $JTGNG_ROOT/$i
    cd $JTGNG_ROOT/$i
    for j in 1943 1942 commando gunsmoke; do
        if [ -e $JTGNG_ROOT/$j/$i ]; then
            ln -f -s $JTGNG_ROOT/$j/$i $j
        fi
    done
    echo $JTGNG_ROOT/$i
done

for j in 1943 1942 commando gunsmoke; do
    if [ -e $JTGNG_ROOT/rom/$j ]; then
        ln -f -s $JTGNG_ROOT/rom/$j $JTGNG_ROOT/$j/rom
    fi
done