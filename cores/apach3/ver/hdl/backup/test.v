/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0;
always #5 clk=~clk;
reg [13:1] cpu_addr=0;
reg [15:0] cpu_data=0;
reg [1:0] cpu_we=0;
wire [13:1] ram_addr;
wire [15:0] ram_din, ram_dout;
wire [1:0] ram_we;
reg [23:0] ioctl_addr=0;
reg [7:0] ioctl_dout=0;
reg ioctl_ram=0, ioctl_wr=0;
wire [7:0] ioctl_din;
integer i;

jtframe_ram16 #(
    .AW        ( 13 ),
    .LATCH_IN  (  0 ),
    .LATCH_OUT (  0 ),
    .ENDIAN    (  0 )
) u_backup (
    .clk  ( clk      ),
    .addr ( ram_addr ),
    .data ( ram_din  ),
    .we   ( ram_we   ),
    .q    ( ram_dout )
);

jtframe_ioctl_dump #(
    .DW0 ( 16 ),
    .AW0 ( 14 ),
    .AW1 (  0 ),
    .AW2 (  0 ),
    .AW3 (  0 ),
    .AW4 (  0 ),
    .AW5 (  0 ),
    .AW6 (  0 ),
    .AW7 (  0 )
) u_dump (
    .clk        ( clk        ),
    .dout0      ( ram_dout   ),
    .addr0      ( cpu_addr   ),
    .addr0_mx   ( ram_addr   ),
    .din0       ( cpu_data   ),
    .din0_mx    ( ram_din    ),
    .we0        ( cpu_we     ),
    .we0_mx     ( ram_we     ),
    .dout1      ( 8'd0       ),
    .addr1      ( 1'b0       ),
    .din1       ( 8'd0       ),
    .we1        ( 1'b0       ),
    .dout2      ( 8'd0       ),
    .addr2      ( 1'b0       ),
    .din2       ( 8'd0       ),
    .we2        ( 1'b0       ),
    .dout3      ( 8'd0       ),
    .addr3      ( 1'b0       ),
    .din3       ( 8'd0       ),
    .we3        ( 1'b0       ),
    .dout4      ( 8'd0       ),
    .addr4      ( 1'b0       ),
    .din4       ( 8'd0       ),
    .we4        ( 1'b0       ),
    .dout5      ( 8'd0       ),
    .addr5      ( 1'b0       ),
    .din5       ( 8'd0       ),
    .we5        ( 1'b0       ),
    .dout6      ( 8'd0       ),
    .addr6      ( 1'b0       ),
    .din6       ( 8'd0       ),
    .we6        ( 1'b0       ),
    .dout7      ( 8'd0       ),
    .addr7      ( 1'b0       ),
    .din7       ( 8'd0       ),
    .we7        ( 1'b0       ),
    .ioctl_addr ( ioctl_addr ),
    .ioctl_ram  ( ioctl_ram  ),
    .ioctl_aux  ( 8'h00      ),
    .ioctl_wr   ( ioctl_wr   ),
    .ioctl_din  ( ioctl_din  ),
    .ioctl_dout ( ioctl_dout )
);

function [7:0] pattern;
    input [13:0] address;
    begin pattern = (address*37) ^ (address>>5) ^ 8'ha5; end
endfunction

task restore_byte;
    input [23:0] address;
    input [7:0] value;
    begin
        @(negedge clk);
        ioctl_addr=address; ioctl_dout=value; ioctl_ram=1; ioctl_wr=1;
        repeat (3) @(negedge clk);
        ioctl_wr=0;
        repeat (2) @(negedge clk);
    end
endtask

task read_byte;
    input [23:0] address;
    input [7:0] value;
    begin
        @(negedge clk);
        ioctl_addr=address; ioctl_ram=1; ioctl_wr=0;
        repeat (4) @(negedge clk);
        if (ioctl_din !== value) $fatal(1,"backup %h got %h expected %h",address,ioctl_din,value);
    end
endtask

initial begin
    repeat (4) @(negedge clk);
    for (i=0;i<16384;i=i+1) restore_byte(i,0);
    @(negedge clk); ioctl_ram=0;
    for (i=0;i<8192;i=i+1) begin
        @(negedge clk); cpu_addr=i;
        repeat (3) @(negedge clk);
        if (ram_dout !== 0) $fatal(1,"factory backup word %h",i);
    end
    for (i=0;i<16384;i=i+1) restore_byte(i,pattern(i));
    for (i=0;i<16384;i=i+1) read_byte(i,pattern(i));
    @(negedge clk); ioctl_ram=0;
    for (i=0;i<8192;i=i+1) begin
        @(negedge clk); cpu_addr=i;
        repeat (3) @(negedge clk);
        if (ram_dout !== {pattern(2*i+1),pattern(2*i)}) $fatal(1,"CPU restored word %h",i);
    end
    for (i=0;i<8192;i=i+1) begin
        @(negedge clk);
        cpu_addr=i; cpu_data={pattern(2*i+1)^8'h5a,pattern(2*i)^8'h5a}; cpu_we=3;
    end
    @(negedge clk); cpu_we=0;
    for (i=0;i<16384;i=i+1) read_byte(i,pattern(i)^8'h5a);
    restore_byte(24'h4000,8'hff);
    read_byte(24'h4000,0);
    read_byte(0,pattern(0)^8'h5a);
    read_byte(24'h3fff,pattern(14'h3fff)^8'h5a);
    @(negedge clk);
    ioctl_ram=0; cpu_addr=13'h1fff; cpu_data=16'h42cd; cpu_we=2'b11;
    @(negedge clk);
    cpu_we=0;
    repeat (3) @(negedge clk);
    read_byte(24'h3ffe,8'hcd);
    read_byte(24'h3fff,8'h42);
    @(negedge clk); ioctl_ram=0; cpu_data=16'h1289; cpu_we=2'b01;
    @(negedge clk); cpu_we=0;
    read_byte(24'h3ffe,8'h89);
    read_byte(24'h3fff,8'h42);
    @(negedge clk); ioctl_ram=0; cpu_data=16'hab34; cpu_we=2'b10;
    @(negedge clk); cpu_we=0;
    read_byte(24'h3ffe,8'h89);
    read_byte(24'h3fff,8'hab);
    $display("PASS backup factory defaults, full CPU/ioctl round trip, boundary and independent byte lanes");
    $finish;
end
initial begin
    #5000000;
    $fatal(1,"backup test timed out");
end
endmodule
