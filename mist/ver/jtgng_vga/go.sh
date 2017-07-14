#!/bin/bash

iverilog jtgng_vga_test.v ../../hdl/{jtgng_vga.v,jtgng_timer.v,jtgng_vgabuf.v} \
	../common/altera_mf.v \
	-s jtgng_vga_test -o sim && sim -lxt
