/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1;
always #5 clk=~clk;
reg [11:0] index=0;
wire [7:0] color;
wire loaded, rom_cs;
wire [20:3] rom_addr;
reg [63:0] rom_data=0;
reg rom_ok=0, pending=0;
reg [17:0] held_addr;
integer delay_count=0, reads=0, i, j;
reg [7:0] expected;

jtapach3_objclut u_clut (
    .rst      ( rst      ),
    .clk      ( clk      ),
    .index    ( index    ),
    .color    ( color    ),
    .loaded   ( loaded   ),
    .rom_addr ( rom_addr ),
    .rom_cs   ( rom_cs   ),
    .rom_data ( rom_data ),
    .rom_ok   ( rom_ok   )
);

function [7:0] byte_value;
    input [8:0] word_index;
    input [2:0] lane;
    begin byte_value=(word_index*37)^(word_index>>3)^(lane*29); end
endfunction

always @(posedge clk) begin
    if (rst) begin rom_ok<=0; pending<=0; end
    else if (!rom_cs) begin rom_ok<=0; pending<=0; end
    else if (!pending && !rom_ok) begin
        if (rom_addr !== 18'h3fe00+reads) $fatal(1,"CLUT ROM address %h",rom_addr);
        held_addr<=rom_addr; pending<=1; delay_count<=reads%7; reads<=reads+1;
    end else if (pending) begin
        if (rom_addr!==held_addr) $fatal(1,"CLUT request changed while waiting");
        if (delay_count!=0) delay_count<=delay_count-1;
        else begin
            for (j=0;j<8;j=j+1) rom_data[j*8+:8]<=byte_value(held_addr[8:0],j);
            rom_ok<=1; pending<=0;
        end
    end
end

initial begin
    repeat (5) @(negedge clk);
    rst=0;
    while (!loaded) @(negedge clk);
    if (reads!=512) $fatal(1,"CLUT fetch count %0d",reads);
    for (i=0;i<4096;i=i+1) begin
        @(negedge clk); index=i;
        repeat (3) @(negedge clk);
        expected=byte_value(i>>3,(i&7)^1);
        if (color!==expected) $fatal(1,"CLUT index %h got %h expected %h",index,color,expected);
    end
    $display("PASS TZB215 CLUT 512 packed ROM words and 4096 palette entries");
    $finish;
end
initial begin
    #1000000;
    $fatal(1,"CLUT test timed out");
end
endmodule
