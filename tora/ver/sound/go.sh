#!/bin/bash

function add_dir {
    if [ ! -d "$1" ]; then
        echo "ERROR: add_dir (sim.sh) failed because $1 is not a directory"
        exit 1
    fi
    for i in $(cat $1/$2); do
        if [ "$i" = "-sv" ]; then 
            # ignore statements that iVerilog cannot understand
            continue; 
        fi
        fn="$1/$i"
        if [ ! -e "$fn" ]; then
            (>&2 echo "Cannot find file $fn")
            exit 1
        fi
        echo $fn
    done
}

iverilog -f gather.f \
    $(add_dir $JTGNG/modules/jt12/hdl jt03.f) \
    $JTGNG/modules/jtframe/hdl/cpu/tv80/tv80s.v \
    $JTGNG/modules/jtframe/hdl/cpu/tv80/tv80_reg.v \
    $JTGNG/modules/jtframe/hdl/cpu/tv80/tv80n.v \
    $JTGNG/modules/jtframe/hdl/cpu/tv80/tv80_mcode.v \
    $JTGNG/modules/jtframe/hdl/cpu/tv80/tv80_core.v \
    $JTGNG/modules/jtframe/hdl/cpu/tv80/tv80_alu.v \
    test.v -s test \
    -o sim -DSIMULATION && sim -lxt