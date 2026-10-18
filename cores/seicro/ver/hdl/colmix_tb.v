// Author: Andrea Bogazzi
`timescale 1ns/1ps
module colmix_tb;

reg clk=0, pxl_cen=0, hblankn=1, vblankn=1;
reg [7:0] scr_pxl=0, obj_pxl=0, pal_data=0;
reg [3:0] gfx_en=15;
wire [5:0] pal_addr;
wire [3:0] red, green, blue;
wire LHBL, LVBL;
integer checked=0;

always #5 clk=~clk;
always @(posedge clk) pal_data <= pal_addr==6'h16 ? 8'h49 : 8'hff;

jtseicro_colmix dut(
    .clk      ( clk      ),
    .pxl_cen  ( pxl_cen  ),
    .hblankn  ( hblankn  ),
    .vblankn  ( vblankn  ),
    .scr_pxl  ( scr_pxl  ),
    .obj_pxl  ( obj_pxl  ),
    .gfx_en   ( gfx_en   ),
    .pal_addr ( pal_addr ),
    .pal_data ( pal_data ),
    .red      ( red      ),
    .green    ( green    ),
    .blue     ( blue     ),
    .LHBL     ( LHBL     ),
    .LVBL     ( LVBL     )
);

task draw;
    input [7:0] scr, obj;
    input [3:0] enables;
    input hb, vb;
    input [5:0] address;
    input [11:0] rgb;
    begin
        @(negedge clk);
        scr_pxl=scr;
        obj_pxl=obj;
        gfx_en=enables;
        hblankn=hb;
        vblankn=vb;
        pxl_cen=1;
        @(negedge clk); pxl_cen=0;
        repeat(4) @(negedge clk);
        if(pal_addr!==address || {red,green,blue}!==rgb ||
            LHBL!==hb || LVBL!==vb)
            $fatal(1,"Colmix case=%0d address=%h/%h RGB=%h/%h blank=%b%b/%b%b",
                checked,pal_addr,address,{red,green,blue},rgb,LHBL,LVBL,hb,vb);
        checked=checked+1;
        repeat(3) @(negedge clk);
    end
endtask

initial begin
    repeat(8) @(negedge clk);
    draw(8'hf0,8'h70,4'hf,1,1,6'h00,12'h000);
    draw(8'h31,8'h70,4'hf,1,1,6'h0d,12'hfff);
    draw(8'h31,8'h52,4'hf,1,1,6'h16,12'h225);
    draw(8'h31,8'h52,4'h1,1,1,6'h0d,12'hfff);
    draw(8'h31,8'h52,4'h0,1,1,6'h00,12'h000);
    draw(8'h30,8'h52,4'h1,1,1,6'h00,12'h000);
    draw(8'h31,8'h52,4'h8,1,1,6'h16,12'h225);
    draw(8'h31,8'h50,4'hf,1,1,6'h0d,12'hfff);
    draw(8'h31,8'h52,4'hf,0,1,6'h16,12'h000);
    draw(8'h31,8'h52,4'hf,1,0,6'h16,12'h000);
    draw(8'h31,8'h52,4'hf,1,1,6'h16,12'h225);
    draw(8'hf0,8'h70,4'hf,1,1,6'h00,12'h000);
    $display("PASS colmix: %0d cases, nonblack palette zero, transparent pixels, layer masks, priority, blanking and recovery",checked);
    $finish;
end

initial begin
    #10000;
    $fatal(1,"Colmix test timeout");
end

endmodule
