// Fujitsu AV cell
// 2:1 Selector
// furrtek 2022

`timescale 1ns/100ps

// Terminals and polarities checked ok
// S1 ignored because it should always be == ~S2
// See fujitsu_av_cells.svg for cell trace

module T2D(
	input A, B,
	input S2,
	output X
);

assign X = S2 ? ~A : ~B;	// tmax = 2.7ns

endmodule
