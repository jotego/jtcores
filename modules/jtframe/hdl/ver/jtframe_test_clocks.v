/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-12-2024 */

`timescale 1ns/1ps    

module jtframe_test_clocks(
    output reg rst,
    output reg clk,
    output reg pxl_cen=0,
    output     lhbl, lvbl, hs, vs,
    output     [ 8:0] h,
    output     [ 8:0] v,
    output reg [31:0] framecnt=0
);

parameter TIMEOUT=100_000_000, MAXFRAMES=4, PXLCLK=6;

localparam PXLEND = PXLCLK==6 ? 7 : 5;

initial begin
    if(PXLCLK!=6 && PXLCLK!=8) begin
        $display("PXLCLK can only be set to 6 or 8 (MHz)");
        $finish;
    end
end

initial begin
    rst=0;
    #30  rst=1;
    #300 rst=0;
    #TIMEOUT
    $display("FAIL: Timeout");
    $finish;
end

initial begin
    clk=0;
    forever #10.416 clk=~clk;   // 48 MHz
end

integer cnt=0;

always @(posedge clk) begin
    cnt<=cnt==PXLEND ? 0 : cnt+1;
    pxl_cen <= cnt==PXLEND;  // 6MHz or 8MHz
end

always @(negedge lvbl) begin
    framecnt<=framecnt+1;
    if(framecnt==MAXFRAMES) $finish;
end

jtframe_vtimer u_timer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( v         ),
    .vrender    (           ),    // 1 line ahead of vdump
    .vrender1   (           ),   // 2 lines ahead
    .H          ( h         ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ),
    .VS         ( vs        )
);

initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $dumpon;
end    

endmodule
