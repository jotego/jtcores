module SH_regram (
	input         clock,
	input  [31:0] data,
	input  [ 4:0] rdaddress,
	input  [ 4:0] wraddress,
	input         wren,
	output [31:0] q
);

	integer i;

	(* ramstyle = "MLAB, no_rw_check" *) reg [31:0] mem[0:31];

	assign q = mem[rdaddress];

	initial begin
		for (i=0; i<32; i=i+1) begin
			mem[i] = 32'h0;
		end
	end

	always @(posedge clock) begin
		if (wren) begin
			mem[wraddress] <= data;
		end
	end

endmodule
