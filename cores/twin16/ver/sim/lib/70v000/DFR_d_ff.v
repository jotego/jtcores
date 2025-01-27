module DFR_d_ff(
				input clk,
				input rst,
				input d,
				output reg q,
				output reg q_bar
				);

always @(posedge clk or posedge rst)
begin
	if(rst)
	begin
		q <= 0;
		q_bar <= 1;  	
	end
	else
	begin
		q <= d;
		q_bar <= ~d;
	end
end

endmodule