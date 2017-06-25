#!/bin/bash

iverilog rom_test.v ../../hdl/jtgng_rom.v ../common/mt48lc16m16a2.v -o sim && sim -lxt