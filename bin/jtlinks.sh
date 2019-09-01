#!/bin/bash

# Creates a reversed folder structure

cd $JTGNG_ROOT

for i in hdl mist mister; do
    mkdir -p $JTGNG_ROOT/$i
    cd $JTGNG_ROOT/$i
    for j in 1943 1942 commando gunsmoke; do
        ln -f -s $JTGNG_ROOT/$j/$i $j
    done
done

echo "Symbolic links created"
