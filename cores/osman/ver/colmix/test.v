`timescale 1ns/1ps
module test;
reg clk=0;
always #5 clk=~clk;
reg [7:0] pf1a=0, pf1b=0, pf2a=0, pf2b=0;
reg [11:0] obj=0;
reg hv=0;
wire [9:0] addr;
jtosman_colmix dut(.clk(clk),.pxl_cen(1'b1),.LHBL(1'b1),.LVBL(1'b1),
    .pf1a_pxl(pf1a),.pf1b_pxl(pf1b),.pf2a_pxl(pf2a),.pf2b_pxl(pf2b),
    .obj_pxl(obj),.pal_addr(addr),.pal_data(16'd0),.palhi_data(16'd0),
    .pal888(hv),.red(),.green(),.blue());
integer mode, pri, opacity, size1, size2, count=0;
reg [7:0] pf1, pf2;
reg [9:0] expected;
initial begin
    // Compose pixels in the respective MAME back-to-front draw order.
    // Both tile sizes, every sprite priority, and transparent pens are covered.
    for(mode=0;mode<2;mode=mode+1)
    for(pri=0;pri<4;pri=pri+1)
    for(opacity=0;opacity<8;opacity=opacity+1)
    for(size1=0;size1<2;size1=size1+1)
    for(size2=0;size2<2;size2=size2+1) begin
        @(negedge clk);
        hv=mode;
        pf1=8'ha0 | (opacity[0] ? 8'h5 : 8'h0);
        pf2=8'hb0 | (opacity[1] ? 8'h6 : 8'h0);
        pf1a=size1==0 ? pf1 : 8'd0;
        pf1b=size1==1 ? pf1 : 8'd0;
        pf2a=size2==0 ? pf2 : 8'd0;
        pf2b=size2==1 ? pf2 : 8'd0;
        obj={1'b0,pri[1:0],5'h12,opacity[2] ? 4'h7 : 4'h0};
        if(mode==1) begin
            expected={2'b01,pf2}; // Heavy Smash PF2 TILEMAP_DRAW_OPAQUE
            if(opacity[2]) expected=10'h327;
            if(opacity[0]) expected={2'b00,pf1};
        end else begin
            expected=10'h100; // simpl156 fills palette pen 256
            if(opacity[2] && pri>=2) expected=10'h327;
            if(opacity[1]) expected={2'b01,pf2};
            if(opacity[2] && pri==1) expected=10'h327;
            if(opacity[0]) expected={2'b00,pf1};
            if(opacity[2] && pri==0) expected=10'h327;
        end
        @(posedge clk); #1;
        if(addr!==expected) $fatal(1,"mode=%0d pri=%0d opacity=%0d sizes=%0d/%0d expected=%h got=%h",mode,pri,opacity,size1,size2,expected,addr);
        count=count+1;
    end
    $display("PASS: %0d MAME draw-order combinations (Heavy Smash and simpl156)",count);
    $finish;
end
endmodule
