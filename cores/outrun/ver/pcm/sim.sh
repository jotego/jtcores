#!/bin/bash

main() {
    iverilog -D SIMULATION -D JTFRAME_MCLK=48000000 \
        test.v ../../hdl/jtoutrun_pcm.v $JTFRAME/hdl/ram/*.v \
        $CORES/s16/hdl/jts16_cen.v $JTFRAME/hdl/clocking/*.v \
        -s test -o sim || return $?
    vvp sim
    local sim_status=$?
    rm -f sim
    return $sim_status
}

main "$@"
