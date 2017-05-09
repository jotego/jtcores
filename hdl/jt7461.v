module jt74161(
	input cet,
	input cep,
	input pe_b,
	input cp,
	input mr_b,
	input [3:0] d,
	output [3:0] q,
	output tc
 );

assign tc = &{q, cet};

always @(posedge cp or negedge mr_b) 
	if( !mr_b )
		q <= 4'd0;
	else begin
		if(!pe_b) q <= d;
		else if( cep&&cet ) q <= q+4'd1;
	end

endmodule // jt74161