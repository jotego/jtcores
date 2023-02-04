#!/bin/bash

echo Press q to exit the character preview
echo use a very low size font on the terminal
echo to see the characters

DUMP=DUMP

while [ $# -gt 0 ]; do
	if [ $1 = "-now" ]; then DUMP=NODUMP; shift; fi
done

iverilog scr_tb.v \
	../../hdl/{jt_gng_a5.v,jt_gng_b7.v,jt_gng_b8.v,jt_gng_b9.v} \
	../../hdl/{jt74.v,M58725.v,jt_gng_b1.v,M2114x2.v} -s scr_tb -DSCR_TEST -D$DUMP -o sim \
&& sim -lxt
# | tee s | less -S