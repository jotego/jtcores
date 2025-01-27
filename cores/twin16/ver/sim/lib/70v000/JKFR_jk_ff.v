module	JKFR_jk_ff	(
					input j,
					input k,
					input ck,
					input rst,
					output reg q,
					output reg q_bar
					);

always @(posedge ck or posedge rst) begin
	if(rst) begin
		q <= 0;
		q_bar <= 1;  	
	end
	else begin
		case({j,k})
			2'b11: begin q <= q; q_bar <= q_bar; end
			2'b10: begin q <= 1'b0; q_bar <= 1'b1; end
			2'b01: begin q <= 1'b1; q_bar <= 1'b0; end
			2'b00: begin q <= ~q; q_bar <= ~q_bar; end
		endcase
	end
end

endmodule
