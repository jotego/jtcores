/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi. andreabogazzi79@gmail.com
    Version: 1.0
    Date: 17-06-2026 */

// metafox / arbalest I/O - protection sub-CPU (65C02 @ 2 MHz).
// It reads the cabinet inputs and exchanges them with the main 68000 through
// the shared RAM, plus does bankswitch + coin lockout.
//
// metafox_sub_map:
//   0x0000-0x01ff internal RAM      0x0800/0x0801 soundlatch 0/1 (main comm)
//   0x1000 COINS r / bank+lockout w 0x1002 P1   0x1006 P2
//   0x5000-0x57ff shared RAM        0x7000-0x7fff ROM
//   0x8000-0xbfff banked ROM        0xc000-0xffff ROM
module jtarbalest_sub(
    input               rst, clk,
    input               cen,          // 2 MHz enable

    // Cabinet inputs (read here, shared to main via shram)
    input        [ 5:0] joystick1, joystick2,
    input        [ 1:0] cab_1p,       // start buttons
    input        [ 1:0] coin,
    input               service, tilt,

    // main->sub command latches (sub_ctrl_w 0xa00004/0xa00006), read at 0x0800/0x0801
    input        [ 7:0] slatch0, slatch1,

    // Program ROM (snd SDRAM bank)
    output       [17:0] rom_addr,
    output reg          rom_cs,
    input        [ 7:0] rom_data,
    input               rom_ok,

    // Shared RAM (subsh side of the shram dual-port BRAM)
    output       [10:0] subsh_addr,
    output       [ 7:0] subsh_din,
    input        [ 7:0] subsh_dout,
    output               subsh_we,

    // Screen timing — the metafox sub_interrupt is generated from it below.
    input               hs,
    input               lvbl,
    output       [ 7:0] st_dout
);
`ifndef NOSUB
wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout;
reg  [ 7:0] cpu_din, cab_dout;
wire        cpu_wr;
reg         ram_cs, sh_cs, in_cs, lat_cs;

assign st_dout    = 0;
// metafox sub ROM is an 8 KB EPROM that MAME ROM_RELOADs across 0x6000-0xffff.
// mame2mra packs it once at region offset 0 and drops the reloads, so mirror it
// here: index the 8 KB image by A[12:0]. (Reset vector 0xfffc -> ROM[0x1ffc].)
assign rom_addr   = {5'd0, A[12:0]};
assign subsh_addr = A[10:0];
assign subsh_din  = cpu_dout;
assign subsh_we   = sh_cs & cpu_wr;        // byte writes from the sub

always @* begin
    ram_cs  = A[15:9]==0;                 // 0x0000-0x01ff
    in_cs   = A[15:12]==4'h1;             // 0x1000 region (inputs / bank)
    sh_cs   = A[15:12]==4'h5;             // 0x5000-0x57ff shared RAM
    rom_cs  = A[15]   | (A[15:13]==3'b011); // 0x6000-0xffff (8KB ROM, mirrored)
    lat_cs  = A[15:11]==5'h01;            // 0x0800 soundlatch (stub)
end

always @* begin
    case(A[2:1])
        2'd0: cab_dout = {coin[0],coin[1],service,tilt,4'hf}; // 0x1000 COINS
        2'd1: cab_dout = {cab_1p[0],1'b1,joystick1};          // 0x1002 P1
        2'd2: cab_dout = 8'h00;                               // 0x1004 status port: reads 0
                                                              //   (arbalest sub boot checks 0x1004==0; MAME nopr=0)
        2'd3: cab_dout = {cab_1p[1],1'b1,joystick2};          // 0x1006 P2
        default: cab_dout = 8'hff;
    endcase
end

always @* begin
    cpu_din = ram_cs  ? ram_dout   :
              sh_cs   ? subsh_dout :
              in_cs   ? cab_dout   :
              lat_cs  ? (A[0] ? slatch1 : slatch0) : // soundlatch 0x0800/0x0801 (main->sub)
              rom_cs  ? rom_data   : 8'hff;
end

// The 0x1000 write is the ROM-bank + coin-lockout register. Banking is not
// implemented (the 8 KB sub ROM is mirrored across 0x6000-0xffff, see rom_addr)
// and coin-lockout is a no-op here, so the latch is omitted. The write's only
// live effect is acking the sub IRQ below (in_cs & cpu_wr -> u_irq.clr).

jtframe_ram #(.AW(9)) u_ram(   // 0x0000-0x01ff internal RAM
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .addr   ( A[8:0]        ),
    .data   ( cpu_dout      ),
    .we     ( ram_cs & cpu_wr ),
    .q      ( ram_dout      )
);

// metafox sub_interrupt from the screen scanline (MAME line 0 = LVBL rising):
// IRQ (level) asserted entering line 112, NMI (edge) high during vblank (line>=240).
reg  [ 8:0] vline;
reg         hs_q, lvbl_q, irq_set, nmi;
always @(posedge clk) begin
    hs_q    <= hs;
    lvbl_q  <= lvbl;
    irq_set <= 0;
    if( lvbl & ~lvbl_q )       vline <= 0;
    else if( hs & ~hs_q ) begin
        vline <= vline + 9'd1;
        if( vline==9'd111 ) irq_set <= 1;
    end
    nmi <= vline >= 9'd240;
end

// IRQ latch: set at scanline 112, cleared by the 0x1000 bank/lockout write.
wire irq;
jtframe_edge u_irq(
    .rst    ( rst             ),
    .clk    ( clk             ),
    .edgeof ( irq_set         ),
    .clr    ( in_cs & cpu_wr  ),   // sub_bankswitch_lockout_w acks the IRQ
    .q      ( irq             )
);

jt65c02 u_cpu(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .irq    ( irq       ),
    .nmi    ( nmi       ),
    .rd     (           ),
    .wr     ( cpu_wr    ),
    .addr   ( A         ),
    .din    ( cpu_din   ),
    .dout   ( cpu_dout  )
);
`else
    initial rom_cs = 0;
    assign rom_addr=0, subsh_addr=0, subsh_din=0, subsh_we=0, st_dout=0;
`endif
endmodule
