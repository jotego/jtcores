/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-10-2026 */
`timescale 1ns/1ps
module test;
reg clk=0, rst=0;
always #5 clk=~clk;
reg [23:1] address=0;
reg active=1, read_cycle=1;
reg [1:0] lane=3;
reg [2:0] fc=0;
reg [15:0] data=0;
wire rom_cs, ground_cs, ground_we;
wire test_as_n=~active, test_uds_n=~lane[1], test_lds_n=~lane[0];
wire [1:0] ground_dsn;
wire [1:0] shared_we, sprite_we, ctrl_we;
wire zram_we;
wire [7:0] zram_data;
integer i;
reg [15:0] expected;

jtapach3_sub u_sub (
    .rst               ( rst        ),
    .clk               ( clk        ),
    .halt              ( 1'b0       ),
    .vblank            ( 1'b0       ),
    .reset_n           (            ),
    .z80_halt          (            ),
    .rotate_data       (            ),
    .rotate_we         (            ),
    .road_z            (            ),
    .slave_rom_addr    (            ),
    .slave_rom_cs      ( rom_cs     ),
    .slave_rom_data    ( 16'h1234   ),
    .slave_rom_ok      ( 1'b1       ),
    .sharedram_addr    (            ),
    .sharedram_din     (            ),
    .sharedram_dout    ( 16'h5678   ),
    .sharedram_we      ( shared_we  ),
    .spriteram_addr    (            ),
    .spriteram_din     (            ),
    .spriteram_dout    ( 16'h9abc   ),
    .spriteram_we      ( sprite_we  ),
    .obj_ctrl_ram_addr (            ),
    .obj_ctrl_ram_din  (            ),
    .obj_ctrl_ram_dout ( 16'hdef0   ),
    .obj_ctrl_ram_we   ( ctrl_we    ),
    .ground_ram_addr   (            ),
    .ground_ram_cs     ( ground_cs  ),
    .ground_ram_we     ( ground_we  ),
    .ground_ram_din    (            ),
    .ground_ram_dsn    ( ground_dsn ),
    .ground_ram_data   ( 16'h1122   ),
    .ground_ram_ok     ( 1'b1       ),
    .m68k_z80ram_addr  (            ),
    .m68k_z80ram_din   ( zram_data  ),
    .m68k_z80ram_dout  ( 8'h33      ),
    .m68k_z80ram_we    ( zram_we    )
);

initial begin
    force u_sub.addr=address;
    force u_sub.as_n=test_as_n;
    force u_sub.uds_n=test_uds_n;
    force u_sub.lds_n=test_lds_n;
    force u_sub.rw=read_cycle;
    force u_sub.fc=fc;
    force u_sub.dout=data;
    force u_sub.write_seen=1'b0;
    for (i=0;i<8388608;i=i+1) begin
        address=i;
        #1;
        expected=16'hffff;
        if ((i*2)<=24'h07ffff) expected=16'h3412;
        else if ((i*2)>=24'h080000 && (i*2)<=24'h083fff) expected=16'h5678;
        else if ((i*2)>=24'h090000 && (i*2)<=24'h093fff) expected=16'h9abc;
        else if ((i*2)>=24'h09a000 && (i*2)<=24'h09a1ff) expected=16'hdef0;
        else if ((i*2)>=24'h0d0000 && (i*2)<=24'h0dffff) expected=16'h1122;
        else if ((i*2)>=24'h0e0000 && (i*2)<=24'h0e7fff) expected=16'h0033;
        if (u_sub.din !== expected) $fatal(1,"read %h got=%h expected=%h",{address,1'b0},u_sub.din,expected);
        if (rom_cs !== ((i*2)<=24'h07ffff)) $fatal(1,"ROM select %h",{address,1'b0});
        if (ground_cs !== ((i*2)>=24'h0d0000 && (i*2)<=24'h0dffff)) $fatal(1,"ground select %h",{address,1'b0});
    end
    read_cycle=0; data=16'habcd;
    address=24'h080000>>1; #1; if (shared_we!==3) $fatal(1,"shared write");
    address=24'h090000>>1; #1; if (sprite_we!==3) $fatal(1,"sprite write");
    address=24'h09a000>>1; #1; if (ctrl_we!==3) $fatal(1,"control write");
    address=24'h0d0000>>1; lane=2; #1; if (!ground_we || ground_dsn!==2'b01) $fatal(1,"ground high-byte write");
    lane=1; #1; if (!ground_we || ground_dsn!==2'b10) $fatal(1,"ground low-byte write");
    address=24'h0e0000>>1; lane=2; #1;
    if (!zram_we || zram_data!==8'hcd) $fatal(1,"Z80 bridge byte behavior");
    fc=7; #1;
    if (rom_cs || ground_cs || zram_we || |shared_we || |sprite_we || |ctrl_we) $fatal(1,"interrupt acknowledge decoded as memory");
    fc=0; address=24'h080000>>1; rst=1; #1;
    if (|shared_we) $fatal(1,"reset allowed shared RAM write");
    rst=0; active=0; #1;
    if (rom_cs || ground_cs || zram_we || |shared_we || |sprite_we || |ctrl_we) $fatal(1,"inactive bus selected");
    $display("PASS 68000 exhaustive 24-bit word reads, writes, byte lanes and interrupt acknowledge");
    $finish;
end
initial begin
    #10000000;
    $fatal(1,"68000 map test timed out");
end
endmodule
