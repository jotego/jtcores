module k007787	(
				input clr_n,
				input clk2,
				input hflp,
				input p256vd,
				input [15:0] r,
				input [15:0] rx,
				output [3:0] ocd
				);

wire h1,h2,h1f;

FDO_d_ff d32  (
			   .d(h1),
			   .clk(clk2),
			   .reset_n(clr_n),
			   .q(),
			   .q_bar(h1)
				);

FDO_d_ff e44  (
			   .d(~(h1 ^ h2)),
			   .clk(clk2),
			   .reset_n(clr_n),
			   .q(h2),
			   .q_bar()
				);

endmodule