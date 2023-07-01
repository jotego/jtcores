#!/bin/bash

HDLDIR=../../hdl/cpu/63701

for i in $HDLDIR/*.i; do
    ln -s -f $i
done

verilator -F $HDLDIR/jt63701.f ../../hdl/ram/jtframe_ram.v --cc
