#!/bin/bash
# jt37702 smoke test, run inside the simulator container
cd "$(dirname "$0")"/../../../..

docker run --rm -v "$PWD":/jt -w /jt --entrypoint bash jotego/simulator:arm64 -c "
iverilog -g2012 -DSIMULATION -o /tmp/jt37702_tb \
    cores/sysfl/ver/c75/jt37702_tb.v \
    cores/sysfl/hdl/c75/jt37702.sv \
    cores/sysfl/hdl/c75/jt37702_cpu.sv \
    cores/sysfl/hdl/c75/jt37702_per.sv \
    modules/jtframe/hdl/jtframe_edge.v \
&& vvp /tmp/jt37702_tb"
