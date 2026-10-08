module FDM_d_ff	(
				input d,
				input ck,
				output reg q,
				output reg q_bar
				);

parameter TUP_CK_TO_Q = 2;
parameter TDN_CK_TO_Q = 2;
parameter TUP_CK_TO_XQ = 2;
parameter TDN_CK_TO_XQ = 2;

always @(posedge ck) begin
    if (d) begin
        #TUP_CK_TO_Q q <= d;
        #TUP_CK_TO_XQ q_bar <= d;
    end
    else begin
        #TDN_CK_TO_Q q <= d;
        #TDN_CK_TO_XQ q_bar <= d;
    end 
end

endmodule