#!/bin/bash

iverilog test.v ../../hdl/ram/jtframe_ram.v \
    ../../hdl/neptuno/data_io_mc2.sv -g2005-sv  \
 -o simx && simx -fst
rm -f simx