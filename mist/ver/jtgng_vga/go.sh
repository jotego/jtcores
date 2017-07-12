#!/bin/bash

iverilog jtgng_vga_test.v ../../hdl/{jtgng_vga.v,jtgng_timer.v} -o sim && sim -lxt
