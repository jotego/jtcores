module DFF_d_ff(
				input clk,
				input d,
				output reg q,
				output reg q_bar
				);

always @(posedge clk)
begin
	begin
		#1
		q <= d;
		q_bar <= ~d;
	end
end

endmodule