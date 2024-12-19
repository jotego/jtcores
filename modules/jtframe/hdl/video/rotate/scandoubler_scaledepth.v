// Utility module for scaling the bit depth of a signal
// Factored out of the scandoubler by AMR, and adjusted to cope with 
// output bit depth being less than input depth

module scandoubler_scaledepth (
	input [IN_DEPTH-1:0] d,
	output wire [OUT_DEPTH-1:0] q
);	
parameter IN_DEPTH = 6;
parameter OUT_DEPTH = 6;

localparam m = OUT_DEPTH < IN_DEPTH ? 1 : OUT_DEPTH/IN_DEPTH;
localparam n = OUT_DEPTH < IN_DEPTH ? 0 : OUT_DEPTH%IN_DEPTH;
localparam o = OUT_DEPTH < IN_DEPTH ? OUT_DEPTH : IN_DEPTH; 

reg[OUT_DEPTH-1:0] scaled;

always @(*) begin
/*  Verilator lint_off SELRANGE */
/*  Verilator lint_off WIDTH */
	if (m>0) begin
		if (n>0) begin
			scaled = { {m{d[IN_DEPTH-1 -:o]}}, d[IN_DEPTH-1 -:n] };
		end else begin
			scaled = { {m{d[IN_DEPTH-1 -:o]}} };
		end
	end
/*  Verilator lint_on SELRANGE */
/*  Verilator lint_on WIDTH */
end

assign q=scaled;

endmodule

