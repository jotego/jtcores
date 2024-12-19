module scandoubler_rgb_interp (
	input clk_sys,
	input blank,
	input [7:0] fraction,
	input [15:0] rgb_in,
	input [15:0] rgb_in_prev,
	output [15:0] rgb_out
);

pixel_interp #(.signalwidth(5),.fracwidth(8)) interp_red
(
	.clk(clk_sys),
	.blank(blank),
	.frac(fraction),
	.in(rgb_in[15:11]),
	.in_prev(rgb_in_prev[15:11]),
	.out(rgb_out[15:11])
);

pixel_interp #(.signalwidth(6),.fracwidth(8)) interp_green
(
	.clk(clk_sys),
	.blank(blank),
	.frac(fraction),
	.in(rgb_in[10:5]),
	.in_prev(rgb_in_prev[10:5]),
	.out(rgb_out[10:5])
);

pixel_interp #(.signalwidth(5),.fracwidth(8)) interp_blue
(
	.clk(clk_sys),
	.blank(blank),
	.frac(fraction),
	.in(rgb_in[4:0]),
	.in_prev(rgb_in_prev[4:0]),
	.out(rgb_out[4:0])
);

endmodule

