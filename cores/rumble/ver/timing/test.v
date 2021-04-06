// Side Arms Timing Model, Jose Tejada, 8/8/2020
// Street Fighter seems to fit with this model
// the horizontal count PROM is equal
// the vertical count PROM differs in the interrupt request bits

`timescale 1ns / 1ps

module test;

reg clk, rst, cen8;

initial begin
    clk=0;
    cen8=0;
    forever #31.25 clk=~clk;    // 16MHz
end

always @(posedge clk) cen8<=~cen8 & ~rst;

initial begin
    rst = 1;
    #50 rst=0;
end

wire LHBL, LVBL, intrq, hsync, vsync, sync;

jtframe_vtimer #(
    .HB_START ( 9'h1AF ),
    .HB_END   ( 9'h04F ),
    .HCNT_END ( 9'h1FF ),
    .VB_START ( 9'hF0  ),
    .VB_END   ( 9'h00  ),
    .VCNT_END ( 9'h10F  ),
    //.VS_START ( 9'h0   ),
    .VS_START ( 9'h0FF  ),
    //.VS_END   ( 9'h8   ),
    .HS_START ( 9'h1f0 ),
    //.HS_END   ( 9'h00b ),
    .HS_END   ( 9'h027 ),
    .H_VB     ( 9'h7   ),
    .H_VS     ( 9'h1FF ),
    .H_VNEXT  ( 9'h1FF ),
    .HINIT    ( 9'h0   )
) u_timer(
    .clk        ( clk   ),
    .pxl_cen    ( cen8  ),
    .vdump      (       ),
    .vrender    (       ),
    .vrender1   (       ),
    .H          (       ),
    .Hinit      (       ),
    .Vinit      (       ),
    .LHBL       (       ),
    .LVBL       (       ),
    .HS         (       ),
    .VS         (       )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,test);
    $dumpon;
end

initial begin
    #60_000_000 $finish;
end

endmodule
