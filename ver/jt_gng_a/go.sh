#!/bin/bash

iverilog jt_gng_a_test.v \
	../../hdl/jt_gng_a*.v \
	../../hdl/{jt74.v,M58725.v,jt_gng_genram.v} \
	../../modules/mc6809/{mc6809.v,mc6809i.v} \
	-s jt_gng_a_test -o sim \
&& sim -lxt