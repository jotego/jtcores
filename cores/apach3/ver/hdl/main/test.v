/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=0;
always #5 clk=~clk;
reg [19:0] address=0;
reg [15:0] bank=0;
reg valid=1, read_cycle=1, write_cycle=0, interrupt_ack=0;
reg [1:0] lane=3;
wire [15:0] control;
wire master_cs, slave_cs, host_sel, host_rd, host_wr;
wire [14:0] host_addr;
wire [1:0] work_we, backup_we, video_we, palette_we, shared_we;
integer i;
reg [15:0] expected;

jtapach3_main u_main (
    .rst                ( rst        ),
    .clk                ( clk        ),
    .cen                ( 1'b0       ),
    .vblank             ( 1'b0       ),
    .dsw                ( 16'h5555   ),
    .control            ( control    ),
    .host_addr          ( host_addr  ),
    .host_sel           ( host_sel   ),
    .host_rd            ( host_rd    ),
    .host_wr            ( host_wr    ),
    .host_din           (            ),
    .host_dout          ( 8'h77      ),
    .host_ok            ( 1'b1       ),
    .workram_addr       (            ),
    .workram_din        (            ),
    .workram_dout       ( 16'h1111   ),
    .workram_we         ( work_we    ),
    .backup_addr        (            ),
    .backup_din         (            ),
    .backup_dout        ( 16'h2222   ),
    .backup_we          ( backup_we  ),
    .videoram_addr      (            ),
    .videoram_din       (            ),
    .videoram_dout      ( 16'h4444   ),
    .videoram_we        ( video_we   ),
    .palette_addr       (            ),
    .palette_din        (            ),
    .palette_dout       ( 16'h3333   ),
    .palette_we         ( palette_we ),
    .v30_shared_addr    (            ),
    .v30_shared_din     (            ),
    .v30_shared_dout    ( 16'h8888   ),
    .v30_shared_we      ( shared_we  ),
    .master_rom_addr    (            ),
    .master_rom_cs      ( master_cs  ),
    .master_rom_data    ( 16'h9999   ),
    .master_rom_ok      ( 1'b1       ),
    .v30_slave_rom_addr (            ),
    .v30_slave_rom_cs   ( slave_cs   ),
    .v30_slave_rom_data ( 16'h1234   ),
    .v30_slave_rom_ok   ( 1'b1       )
);

initial begin
    force u_main.addr=address;
    force u_main.addr_valid=valid;
    force u_main.rd=read_cycle;
    force u_main.wr=write_cycle;
    force u_main.inta=interrupt_ack;
    force u_main.lane=lane;
    force u_main.commit=1'b1;
    force u_main.control=bank;
    bank=16'h0018;
    for (i=0;i<1048576;i=i+1) begin
        address=i;
        #1;
        expected=16'hffff;
        if (i<=20'h03fff) expected=16'h1111;
        else if (i<=20'h07fff) expected=16'h2222;
        else if (i>=20'h08000 && i<=20'h08fff) expected=16'h3333;
        else if (i>=20'h0c000 && i<=20'h0dfff) expected=16'h4444;
        else if (i>=20'h0f000 && i<=20'h0f001) expected=16'h5555;
        else if (i>=20'h0f800 && i<=20'h0f801) expected=bank;
        else if (i>=20'h10000 && i<=20'h1ffff) expected=16'hff77;
        else if (i>=20'h20000 && i<=20'h2ffff) expected=16'h8888;
        else if (i>=20'h80000) expected=16'h9999;
        if (u_main.cpu_din !== expected) $fatal(1,"read %h got=%h expected=%h",address,u_main.cpu_din,expected);
        if (master_cs !== (i>=20'h80000)) $fatal(1,"master select %h",address);
        if (host_sel !== (i>=20'h10000 && i<=20'h1ffff)) $fatal(1,"sound select %h",address);
        if (slave_cs !== 0) $fatal(1,"slave ROM selected in shared bank");
    end
    bank=0; address=20'h20000; #1;
    if (!slave_cs || u_main.cpu_din!==16'h3412) $fatal(1,"slave ROM bridge");
    address=20'h2ffff; #1;
    if (!slave_cs || u_main.v30_slave_rom_addr!==15'h7fff) $fatal(1,"slave ROM last address");
    bank=7; #1;
    if (u_main.v30_slave_rom_addr!==18'h3ffff) $fatal(1,"slave ROM bank selection");
    interrupt_ack=1; #1;
    if (u_main.cpu_din!==16'h0032) $fatal(1,"interrupt vector");
    interrupt_ack=0; read_cycle=0; write_cycle=1;
    bank=16'h0018;
    address=20'h00000; #1; if (work_we!==3) $fatal(1,"work write");
    address=20'h04000; #1; if (backup_we!==3) $fatal(1,"backup write");
    address=20'h08000; #1; if (palette_we!==3) $fatal(1,"palette write");
    address=20'h0c000; #1; if (video_we!==3) $fatal(1,"video write");
    address=20'h20000; #1; if (shared_we!==3) $fatal(1,"shared write");
    address=20'h10000; lane=1; #1; if (!host_wr || host_addr!==0) $fatal(1,"sound low byte write");
    lane=2; #1; if (host_wr) $fatal(1,"sound high byte write");
    valid=0; #1; if (|work_we || |backup_we || |palette_we || |video_we || |shared_we || host_sel) $fatal(1,"invalid cycle selected");
    valid=1; address=20'h04000; lane=3; rst=1; #1;
    if (|backup_we) $fatal(1,"reset allowed a backup RAM write");
    address=20'h10000; lane=1; #1;
    if (host_sel || host_wr) $fatal(1,"reset allowed a sound host transfer");
    $display("PASS V30 exhaustive 20-bit reads, ROM banking, writes, lanes and IRQ vector");
    $finish;
end
initial begin
    #2000000;
    $fatal(1,"V30 map test timed out");
end
endmodule
