/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=1, sub_reset_n=1, halt=0, vblank=0;
always #5 clk=~clk;
reg [15:0] address=0;
reg [7:0] data=8'h73;
reg mreq_n=0, iorq_n=1, m1_n=1, rd_n=0, wr_n=1, rfsh_n=1, busak_n=1;
wire [12:0] z80ram_addr;
wire [7:0] z80ram_din;
wire z80ram_we;
wire [8:1] road_addr;
wire [15:0] road_data;
wire [1:0] road_we;
integer i;
reg [15:0] expected;

jtapach3_roadcpu u_road (
    .rst             ( rst          ),
    .clk             ( clk          ),
    .cen             ( 1'b1         ),
    .sub_reset_n     ( sub_reset_n  ),
    .halt            ( halt         ),
    .vblank          ( vblank       ),
    .z80ram_addr     ( z80ram_addr  ),
    .z80ram_din      ( z80ram_din   ),
    .z80ram_dout     ( 8'hb5        ),
    .z80ram_we       ( z80ram_we    ),
    .road_x_ram_addr ( road_addr    ),
    .road_x_ram_din  ( road_data    ),
    .road_x_ram_we   ( road_we      )
);

initial begin
    force u_road.addr=address;
    force u_road.dout=data;
    force u_road.mreq_n=mreq_n;
    force u_road.iorq_n=iorq_n;
    force u_road.m1_n=m1_n;
    force u_road.rd_n=rd_n;
    force u_road.wr_n=wr_n;
    force u_road.rfsh_n=rfsh_n;
    force u_road.busak_n=busak_n;
    repeat (3) @(negedge clk);
    rst=0;
    if (u_road.u_cpu.rst_n!==0) $fatal(1,"Z80 released before 68000 reset");
    sub_reset_n=0;
    repeat (2) @(negedge clk);
    sub_reset_n=1;
    @(negedge clk);
    if (u_road.u_cpu.rst_n!==1) $fatal(1,"Z80 reset did not release");
    for (i=0;i<65536;i=i+1) begin
        address=i;
        #1;
        if (u_road.u_cpu.din !== (i<=16'h1fff ? 8'hb5 : 8'hff)) $fatal(1,"Z80 read %h",address);
        if (u_road.ram_cs !== (i<=16'h1fff)) $fatal(1,"Z80 RAM select %h",address);
        if (u_road.road_cs !== (i>=16'h8000)) $fatal(1,"road select %h",address);
    end
    rd_n=1; wr_n=0;
    for (i=0;i<65536;i=i+1) begin
        address=i; #1;
        if (z80ram_we !== (i<=16'h1fff)) $fatal(1,"Z80 write select %h",address);
        if (road_we !== (i>=16'h8000 ? 2'b11 : 2'b00)) $fatal(1,"road write select %h",address);
        expected = (i&16'h0800) ? (i|16'hf000) : (i&16'h0fff);
        if (road_data !== expected || road_addr!==data) $fatal(1,"road X mapping %h",address);
    end
    rfsh_n=0; #1;
    if (z80ram_we || |road_we) $fatal(1,"refresh decoded as write");
    rfsh_n=1; busak_n=0; #1;
    if (z80ram_we || |road_we) $fatal(1,"bus grant decoded as write");
    busak_n=1; wr_n=1;
    @(negedge clk); vblank=1;
    repeat (2) @(negedge clk);
    if (!u_road.irq) $fatal(1,"vblank IRQ missing");
    vblank=0; iorq_n=0; m1_n=0;
    repeat (2) @(negedge clk);
    if (u_road.irq) $fatal(1,"IRQ acknowledge did not clear");
    rst=1; address=16'h0010; mreq_n=0; wr_n=0; #1;
    if (z80ram_we || |road_we) $fatal(1,"reset allowed Z80 memory write");
    rst=0; wr_n=1;
    halt=1; #1;
    if (u_road.u_cpu.busrq_n!==0) $fatal(1,"Z80 halt request missing");
    $display("PASS Z80 16-bit read/write map, road offset, reset, halt and IRQ");
    $finish;
end
initial begin
    #1000000;
    $fatal(1,"road CPU test timed out");
end
endmodule
