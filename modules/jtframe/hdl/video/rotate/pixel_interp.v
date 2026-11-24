module pixel_interp #(parameter signalwidth=8, parameter fracwidth = 8)
(
	input clk,
	input ce,
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
reg [signalwidth-1:0] in_d, in_prev_d;
reg [2:0] blank_d;

// Advance in output pixels, rather than system clocks. In particular, a
// fractional pixel enable may alternate between three and four clocks.
always @(posedge clk) if (ce) begin
    in_d <= in;
    in_prev_d <= in_prev;
    blank_d <= {blank_d[1:0], blank};
	invfrac <=1'b1 + {1'b0,~frac};
	frac_d <= {1'b0,frac};

	in_scaled<=invfrac*in_d;
	in_prev_scaled<=frac_d*in_prev_d;

	sum<=in_scaled+in_prev_scaled;
end

assign out=blank_d[2] ? {signalwidth{1'b0}} : sum[signalwidth+fracwidth-1:fracwidth];

endmodule

