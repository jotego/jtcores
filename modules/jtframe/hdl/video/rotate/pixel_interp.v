module pixel_interp #(parameter signalwidth=8, parameter fracwidth = 8)
(
	input clk,
	input blank,
	input [fracwidth-1:0] frac,
	input [signalwidth-1:0] in,
	input [signalwidth-1:0] in_prev,
	output [signalwidth-1:0] out
);

reg [fracwidth:0] invfrac;
reg [fracwidth:0] frac_d;

reg [signalwidth+fracwidth:0] in_scaled;
reg [signalwidth+fracwidth:0] in_prev_scaled;

reg [signalwidth+fracwidth:0] sum;

always @(posedge clk) begin
	invfrac <=1'b1 + {1'b0,~frac};
	frac_d <= {1'b0,frac};

	in_scaled<=invfrac*in;
	in_prev_scaled<=frac_d*in_prev;

	sum<=in_scaled+in_prev_scaled;
end

assign out=blank ? {signalwidth{1'b0}} : sum[signalwidth+fracwidth-1:fracwidth];

endmodule

