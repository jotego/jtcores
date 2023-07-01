//
//
// Copyright (c) 2012-2013 Ludvig Strigeus
// Copyright (c) 2017,2018 Sorgelig
//
// This program is GPL Licensed. See COPYING for the full license.
//
//
////////////////////////////////////////////////////////////////////////////////////////////////////////

// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on

module Hq2x #(parameter LENGTH=32,  HALF_DEPTH=0,  // arbitrary default values
    DWIDTH = HALF_DEPTH ? 11 : 23
)(
	input             clk,

	input             ce_in,
	input  [DWIDTH:0] inputpixel,
	input             mono,
	input             disable_hq2x,
	input             reset_frame,
	input             reset_line,

	input             ce_out,
	input       [1:0] read_y,
	input             hblank,
	output [DWIDTH:0] outpixel
);

assign outpixel = inputpixel;

endmodule
