#!/bin/bash
# jt960 smoke test, run inside the simulator container
cd "$(dirname "$0")"/../../../..

docker run --rm -v "$PWD":/jt -w /jt --entrypoint bash jotego/simulator:arm64 -c "
iverilog -g2012 -o /tmp/jt960_tb \
    -I cores/sysfl/hdl -I cores/sysfl/hdl/i960 \
    cores/sysfl/ver/i960/jt960_tb.v \
    cores/sysfl/hdl/i960/jt960.sv \
    cores/sysfl/hdl/i960/jt960_dec.sv \
    cores/sysfl/hdl/i960/jt960_alu.sv \
    cores/sysfl/hdl/i960/jt960_muldiv.sv \
    cores/sysfl/hdl/i960/jt960_rcache.sv \
    modules/jtframe/hdl/jtframe_edge.v \
&& vvp /tmp/jt960_tb"
