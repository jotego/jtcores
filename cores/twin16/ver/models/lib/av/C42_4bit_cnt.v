module C42_4bit_cnt
(
	input ck,
	input cl_n,
	output reg [3:0] q
);

always @(posedge ck or negedge cl_n)begin
	if(!cl_n) begin
		q <= 0;
	end
	else begin
		q <= q + 1'b1;
	end
end

endmodule