module frac_interp #(parameter bitwidth=10, parameter fracwidth=16, parameter centre=1) (
	input clk,
	input reset_n,
	input [bitwidth-1:0] num, // Larger value
	input [bitwidth-1:0] den, // Smaller value
	input [bitwidth-1:0] limit, // Blank after this value is reached.
	input newfraction,
	output reg ready,
	input step_reset,
	input step_in,
	output reg step_out,
	output [bitwidth-1:0] whole,
	output reg [fracwidth-1:0] fraction,
	output blank
);

wire div_done;
wire [bitwidth+fracwidth-1:0] step;
wire [bitwidth+fracwidth-1:0] remain; /* not used */
	
unsigned_division #(.widthlog2(bitwidth+fracwidth)) div (
	.clk(clk),
	.reset_n(reset_n),
	.dividend({num,{fracwidth{1'b0}}}),
	.divisor({{fracwidth{1'b0}},den}),
	.quotient(step),
	.remainder(remain),
	.req(newfraction),
	.ack(div_done)
);

reg [bitwidth+fracwidth-1:0] spos;
wire [bitwidth-1:0] spos_whole = spos[bitwidth+fracwidth-1:fracwidth];
wire [fracwidth-1:0] spos_frac = spos[fracwidth-1:0];

reg [bitwidth-1:0] dpos;

reg [bitwidth-1:0] whole_i;
reg [bitwidth-1:0] offset;

always @(posedge clk) begin
	step_out<=1'b0;
	if (step_in) begin
		if(dpos>spos_whole) begin
			spos<=spos+step;
			fraction<=spos_frac;
			step_out<=1'b1;
			whole_i<=whole_i+1'd1;
		end else
			fraction<=0;
		if(|offset)
			offset<=offset-1'd1;
		else
			dpos<=dpos+1'b1;
	end
	if (newfraction || reset_n)
		ready <= 1'b0;

	if (centre && whole_i>limit) // HACK: Extend the span by one pixel when processing rows.
		offset<={bitwidth{1'b1}}; // Ensure the rest of the span is blanked

	if (!centre && whole_i==limit)
		offset<={bitwidth{1'b1}}; // Ensure the rest of the span is blanked

	if (step_reset || newfraction || !reset_n) begin
		spos<=0;
		dpos<=0;
		whole_i<=0;
		offset<=(centre && den>num) ? (den-num) >> 1 : {bitwidth{1'b0}};
	end
		
	if(div_done)
		ready<=1'b1;
end

assign whole=whole_i;

assign blank=|offset;

endmodule

