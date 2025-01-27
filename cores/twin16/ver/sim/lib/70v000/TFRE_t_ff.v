module TFRE_t_ff(
				input clk,
				input rst,
				input t_n,
				output reg q,
				output reg q_bar
				);

always @(posedge clk or posedge rst)
begin
	if (rst)
	begin
		q <= 0;
		q_bar <= 1;  	
	end
	else if (~t_n)
	begin
		q <= ~q;
		q_bar <= ~q_bar;
	end
end

endmodule