// Fujitsu AV cell
// Buffer (Delay Cell)
// furrtek 2022

`timescale 1ns/100ps

module BD3(
	input INPT,
	output OUTPT
);

	assign #12 OUTPT = INPT;	// tmax = 11.8ns

endmodule
