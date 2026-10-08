module FDR_4bit_dff
	(
		input [3:0] d,
		input ck,
		input cl_n,
		output reg [3:0] q
	);

always @(posedge ck or cl_n) begin
	if(!cl_n) begin
		q <= 0;
	end
	else begin
		q <= d;
	end
end

endmodule