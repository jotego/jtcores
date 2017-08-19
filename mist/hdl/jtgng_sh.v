`timescale 1ns / 1ps

module jtgng_sh #(parameter width=5, stages=24 )
(
	input 							clk,
	input		[width-1:0]			din,
   	output		[width-1:0]			drop
);

reg [stages-1:0] bits[width-1:0];

genvar i;
generate
	for (i=0; i < width; i=i+1) begin: bit_shifter
		always @(negedge clk) begin
			if( stages> 1 )
				bits[i] <= {bits[i][stages-2:0], din[i]};
			else
				bits[i] <= din[i];
		end
		assign drop[i] = bits[i][stages-1];
	end
endgenerate

endmodule
