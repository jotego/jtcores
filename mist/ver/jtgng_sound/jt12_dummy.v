module jt12 (
	input			rst,		// rst should be at least 6 clk&cen cycles long
	input			clk,		// CPU clock
	input			cen,		// optional clock enable, it not needed leave as 1'b1
	input	[7:0]	din,
	input	[1:0]	addr,
	input			cs_n,
	input			wr_n,
	input			limiter_en,
	
	output	[7:0]	dout,
	output			irq_n,
	// combined output
	output	signed	[11:0]	snd_right,
	output	signed	[11:0]	snd_left,
	output			snd_sample,
	// multiplexed output
	output signed	[8:0]	mux_right,	
	output signed	[8:0]	mux_left,
	output			mux_sample
);

assign dout=8'd0, irq_n = 1'b1;
assign snd_right=12'd0;
assign snd_left =12'd0;
assign mux_right= 8'd0;
assign mux_left = 8'd0;
assign mux_sample = 1'b0, snd_sample = 1'b0;

endmodule // jt12