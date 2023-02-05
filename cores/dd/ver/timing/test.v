`timescale 1ns/1ps

module test;

reg  clk, pxl_cen, rst;
wire cen6;

initial begin
    clk = 1'b0;
    forever #10.417 clk=~clk;
end

initial begin
    rst = 1'b1;
    #300 rst=1'b0;
    #(40_000_000) $finish;
end

jtframe_cen48 u_cen(
    .clk    ( clk       ),    // 48 MHz
    .cen6   ( cen6      )
);

wire [7:0] VPOS, HPOS;
wire       VBL, HBL, VS, HS;

jtdd_timing uut(
    .clk     ( clk       ),
    .rst     ( rst       ),
    .pxl_cen ( cen6      ),
    .flip    ( 1'b0      ),
    .VPOS    ( VPOS      ),
    .HPOS    ( HPOS      ),
    .VBL     ( VBL       ),
    .HBL     ( HBL       ),
    .VS      ( VS        ),
    .HS      ( HS        )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end

endmodule