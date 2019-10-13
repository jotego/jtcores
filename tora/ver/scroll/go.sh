#!/bin/bash

iverilog test.v $JTGNG/modules/jtgng_{timer,sh,tile4}.v \
    $JTGNG/1943/hdl/jt1943_scroll.v \
    -D SIMULATION \
    -o sim \
    && sim -lxt