module prot(
	input  signed [15:0] v0, v1, v2,
	output reg signed [15:0] vcalc
);

reg signed [15:0] vx0,vx1,vx2,vx3,vsum,c;

always @* begin
	c = 0;
	vx0= -v0;
	c[0]  = vx0[15] & (|vx0[2:0]);
	vx1 = (vx0>>>3)+c;
	vx2 = vx1-16'd4;
	vx3 = {5'd0,vx2[4:0],6'd0};
	vsum = v1+v2-16'd6;
	c[0] = vsum[15] & (|vsum[2:0]);
	vcalc = vx3+(((vsum>>3)+c+16'd12)&16'h3f);
end

endmodule