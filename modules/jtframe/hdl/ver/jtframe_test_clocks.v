/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 30-12-2024 */

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

parameter TIMEOUT=100_000_000, MAXFRAMES=4;
initial begin
    rst=0;
    #30  rst=1;
    #300 rst=0;
    #TIMEOUT
    $display("FAIL: Timeout");
    $stop;
end

initial begin
    clk=0;
    forever #10.416 clk=~clk;   // 48 MHz
end

integer cnt=0;

always @(posedge clk) begin
    cnt<=cnt==7 ? 0 : cnt+1;
    pxl_cen <= cnt==7;  // 6MHz
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
