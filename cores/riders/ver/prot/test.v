`timescale 1ns/1ps

module test;

integer data;
integer i18,ib0,ic8;
integer D12=12,D8=8,D6=6,D4=4, D31=32'h1f, D64=32'h40,D3F=32'h3f;

always @* begin
	data = -i18;
	data = ((data / D8 - D4) & D31)*D64;
	data = data + ((ib0 + ic8) - D6) / D8; // + D12;
	// data = data + ((((ib0 + ic8) - D6) / D8 + D12) & D3F);
	// data = ((data / 8 - 4) & 32'h1f) * 32'h40;
	// data = data + ((((ib0 + ic8) - 6) / 8 + 12) & 32'h3f);
end

reg [15:0] cmd, odma, v0, v1, v2;
reg signed [15:0] vx, vsum, calc;
reg c;

always @* begin
    vx = -i18[15:0];
    // vx = (vx>>>3)+(vx[0]&vx[15]);
    vx = vx/8;
    vx = vx-16'd4;
    vx = vx&16'h1f;
    vx = { 5'd0, vx[4:0],6'd0 };
    vsum = ib0[15:0]+ic8[15:0]-16'd6;
    c = vsum[0]&vsum[15];
    vsum = (vsum>>>3);//+{15'd0,vsum[0]&vsum[15]}; //+16'd12;
    vx = vsum+c;
    vx = vx + vsum;
end

initial begin
	$dumpfile("test.lxt");
	$dumpvars;
	$dumpon;
end

integer k;

initial begin
	// {i18,ib0,ic8}={32'd0,32'd0,32'd0};
	// #100
	// {i18,ib0,ic8}={-32'd234,-32'd1234,-32'd3442};
	// $display("%d <-> %d",data,vx);
	// #100
	// {i18,ib0,ic8}={32'd234,-32'd1234,-32'd3442};
	// $display("%d <-> %d",data,vx);
	// #100
	// {i18,ib0,ic8}={32'd3234,-32'd234,32'd3442};
	// $display("%d <-> %d",data,vx);
	// #100
	// {i18,ib0,ic8}={32'd124,32'd9234,-32'd13442};
	// $display("%d <-> %d",data,vx);
	// #100
	// {i18,ib0,ic8}={32'd234,-32'd1234,32'd30442};
	// $display("%d <-> %d",data,vx);
	// #100
	// {i18,ib0,ic8}={32'd23004,-32'd1234,-32'd31442};
	// $display("%d <-> %d",data,vx);
	// #100
	for(k=1;k<100;k=k+1) begin
		i18 = ($random)%3767;
		ib0 = ($random)%3767;
		ic8 = ($random)%3767;
		#10
		$display("#%0d\t%5d <-> %5d",k,data,vx);
		if(data!=vx) begin
			$display("%d,%d,%d",i18,ib0,ic8);
			$finish;
		end
	end
	#10
	$finish;
end
endmodule