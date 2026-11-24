// Utility module for scaling the bit depth of a signal
// Factored out of the scandoubler by AMR, and adjusted to cope with 
// output bit depth being less than input depth

module scandoubler_scaledepth #(
parameter IN_DEPTH = 6,
          OUT_DEPTH = 6
)(
	input [IN_DEPTH-1:0] d,
	output wire [OUT_DEPTH-1:0] q
);	

localparam m = OUT_DEPTH < IN_DEPTH ? 1 : OUT_DEPTH/IN_DEPTH;
localparam n = OUT_DEPTH < IN_DEPTH ? 0 : OUT_DEPTH%IN_DEPTH;
localparam o = OUT_DEPTH < IN_DEPTH ? OUT_DEPTH : IN_DEPTH; 

// Generate the constant branches so tools never elaborate a zero-width slice.
generate
    if (n>0) begin : g_remainder
        assign q = { {m{d[IN_DEPTH-1 -:o]}}, d[IN_DEPTH-1 -:n] };
    end else begin : g_whole
        assign q = {m{d[IN_DEPTH-1 -:o]}};
    end
endgenerate

endmodule
