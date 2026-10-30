/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, fill=0;
always #5 clk=~clk;
reg [17:0] addr=0, next_addr=0, fill_addr=0;
reg [63:0] fill_data=0;
wire hit;
wire [63:0] data;
integer i;
function [63:0] value;
    input [17:0] a;
    begin value={10'd0,a,8'h39,10'd0,~a}; end
endfunction
jtapach3_objcache #(
    .AW        ( 2         )
) u_cache (
    .rst       ( rst       ),
    .clk       ( clk       ),
    .addr      ( addr      ),
    .next_addr ( next_addr ),
    .fill      ( fill      ),
    .fill_addr ( fill_addr ),
    .fill_data ( fill_data ),
    .hit       ( hit       ),
    .data      ( data      )
);
always @(negedge clk)
    if (!rst && hit && data!==value(addr)) $fatal(1,"false texture-cache hit addr=%h data=%h",addr,data);
initial begin
    repeat (4) @(negedge clk);
    rst=0;
    for (i=0;i<64;i=i+1) begin
        fill=1; fill_addr=i; fill_data=value(i); next_addr=i;
        @(negedge clk);
        fill=0; addr=i;
        repeat (2) @(negedge clk);
        if (!hit || data!==value(i)) $fatal(1,"missing texture-cache fill");
        next_addr=i^4;
        @(negedge clk);
        addr=i^4;
        if (hit) $fatal(1,"aliased cache tag");
        fill=1; fill_addr=i^4; fill_data=value(i^4);
        @(negedge clk);
        fill=0;
        repeat (2) @(negedge clk);
        if (!hit || data!==value(i^4)) $fatal(1,"missing replacement");
    end
    rst=1;
    repeat (3) @(negedge clk);
    if (hit) $fatal(1,"cache reset failed");
    $display("PASS synchronous texture cache: lookahead, alias replacement, concurrent fill/read and reset");
    $finish;
end
endmodule
