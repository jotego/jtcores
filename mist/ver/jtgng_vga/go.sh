#!/bin/bash
# VGA Test

SIMPLL=NOSIMPLL

while [ $# -gt 0 ]; do
	if [ "$1" = "-pll" ]; then
		SIMPLL=SIMPLL
		echo Using PLL model
		shift
		continue
	fi
	echo "Unknown option $1"
	exit 1
done

iverilog jtgng_vga_test.v ../../hdl/jtgng_{vga,timer,vgabuf,pll0}.v \
	../common/altera_mf.v \
	-s jtgng_vga_test -o sim -D$SIMPLL \
	&& sim -lxt
