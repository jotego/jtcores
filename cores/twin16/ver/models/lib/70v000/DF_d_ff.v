module DF_d_ff(
				input clk,
				input rst,
				input set,
				input d,
				output reg q,
				output reg q_bar
				);

always @(posedge clk or posedge rst or posedge set)
begin
	if(rst)
	begin
		q <= 0;
		q_bar <= 1;  	
	end
	else if(set)
	begin
		q <= 1;
		q_bar <= 0;  	
	end	
	else
	begin
		q <= d;
		q_bar <= ~d; 
	end
end

endmodule
