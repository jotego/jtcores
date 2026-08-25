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

    Author: Andrea Bogazzi
    Date: 2026 */

// Sound board for Konami GX604 (Black Panther): Z80 @3.579545MHz driving a
// YM2151 and a K007232. Unlike Salamander there is no VLM5030.
// From MAME nemesis.cpp salamand_state::blkpnthr_sound_map:
//     0000-7fff ROM      8000-87ff RAM
//     a000      sound latch (r)
//     b000-b00d K007232  c000-c001 YM2151
// The YM2151 IRQ is NOT wired on this board (MAME leaves it commented out);
// the Z80's only interrupt is the 7474 clocked by outlatch bit 3, auto-acked
// by /IORQ.

`default_nettype none

module jtblkpan_snd(
    input             rst,
    input             clk,
    input             cen_z80,    // 3.579545 MHz
    input             cen_fm,     // 3.579545 MHz
    input             cen_fm2,    // half of cen_fm
    input             cen_pcm,    // 3.579545 MHz

    input      [ 7:0] i_latch,
    input             i_irq,      // level from outlatch bit 3

    // ROM
    output            rom_cs,
    output     [14:0] rom_addr,
    input      [ 7:0] rom_data,
    input             rom_ok,

    // K007232 samples
    output     [16:0] pcma_addr, pcmb_addr,
    input      [ 7:0] pcma_dout, pcmb_dout,
    output            pcma_cs,   pcmb_cs,
    input             pcma_ok,   pcmb_ok,

    // Audio
    output signed [15:0] fm_l, fm_r,
    output signed [10:0] pcm,

    input      [ 7:0] debug_bus
);

wire [15:0] A;
wire [ 7:0] cpu_dout, ram_dout, fm_dout;
reg  [ 7:0] cpu_din;
wire        m1_n, mreq_n, iorq_n, rd_n, wr_n, rfsh_n, int_n;
wire        mem_cs = ~mreq_n & rfsh_n;
wire        ram_cs, latch_cs, pcm_cs, fm_cs;
reg         irq_ff, irq_l;

assign rom_cs   = mem_cs && !A[15];                       // 0000-7fff
assign ram_cs   = mem_cs &&  A[15:11]==5'b1_0000;         // 8000-87ff
assign latch_cs = mem_cs &&  A[15:12]==4'ha;              // a000
assign pcm_cs   = mem_cs &&  A[15:12]==4'hb;              // b000-b00d
assign fm_cs    = mem_cs &&  A[15:12]==4'hc;              // c000-c001
assign rom_addr = A[14:0];
assign int_n    = ~irq_ff;

// 7474: set on the rising edge of the outlatch bit, cleared by /IORQ
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        irq_ff <= 0;
        irq_l  <= 0;
    end else begin
        irq_l <= i_irq;
        if( i_irq && !irq_l ) irq_ff <= 1;
        if( !iorq_n         ) irq_ff <= 0;
    end
end

always @(*) begin
    cpu_din = 8'hff;
    case( 1'b1 )
        rom_cs:   cpu_din = rom_data;
        ram_cs:   cpu_din = ram_dout;
        latch_cs: cpu_din = i_latch;
        fm_cs:    cpu_din = fm_dout;
        default:;
    endcase
end

jtframe_ram #(.AW(11),.DW(8)) u_ram(
    .clk ( clk ), .cen( 1'b1 ),
    .addr( A[10:0] ), .data( cpu_dout ),
    .we  ( ram_cs & ~wr_n ), .q( ram_dout )
);

jtframe_z80_romwait u_cpu(
    .rst_n    ( ~rst      ),
    .clk      ( clk       ),
    .cen      ( cen_z80   ),
    .cpu_cen  (           ),
    .int_n    ( int_n     ),
    .nmi_n    ( 1'b1      ),
    .busrq_n  ( 1'b1      ),
    .m1_n     ( m1_n      ),
    .mreq_n   ( mreq_n    ),
    .iorq_n   ( iorq_n    ),
    .rd_n     ( rd_n      ),
    .wr_n     ( wr_n      ),
    .rfsh_n   ( rfsh_n    ),
    .halt_n   (           ),
    .busak_n  (           ),
    .A        ( A         ),
    .din      ( cpu_din   ),
    .dout     ( cpu_dout  ),
    .rom_cs   ( rom_cs    ),
    .rom_ok   ( rom_ok    )
);

jt51 u_jt51(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen_fm    ),
    .cen_p1 ( cen_fm2   ),
    .cs_n   ( ~fm_cs    ),
    .wr_n   ( wr_n      ),
    .a0     ( A[0]      ),
    .din    ( cpu_dout  ),
    .dout   ( fm_dout   ),
    .ct1    (           ),
    .ct2    (           ),
    .irq_n  (           ),   // not wired on this board
    .sample (           ),
    .left   (           ),
    .right  (           ),
    .xleft  ( fm_l      ),
    .xright ( fm_r      )
);

// MAME's volume_callback pans channel A hard left and channel B hard right.
// jt007232's mixed `snd` output is taken here; per-channel panning is a TODO.
jt007232 u_pcm(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen        ( cen_pcm    ),
    .addr       ( A[3:0]     ),
    .dacs       ( pcm_cs     ),
    .wr_n       ( wr_n       ),
    .din        ( cpu_dout   ),
    .cen_q      (            ),
    .cen_e      (            ),
    .swap_gains ( 1'b0       ),

    .roma_addr  ( pcma_addr  ),
    .roma_dout  ( pcma_dout  ),
    .roma_cs    ( pcma_cs    ),
    .roma_ok    ( pcma_ok    ),

    .romb_addr  ( pcmb_addr  ),
    .romb_dout  ( pcmb_dout  ),
    .romb_cs    ( pcmb_cs    ),
    .romb_ok    ( pcmb_ok    ),

    .snda       (            ),
    .sndb       (            ),
    .snd        ( pcm        ),

    .debug_bus  ( debug_bus  ),
    .st_dout    (            )
);

endmodule
