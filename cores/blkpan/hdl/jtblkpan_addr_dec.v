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

// 68000 address decoder for Konami GX604 (Black Panther).
//
// No schematics available, so this is transcribed from MAME's
// salamand_state::blkpnthr_map (nemesis.cpp) as a partial decode on the bits
// the board actually looks at. Low bits are don't-cares, so peripherals mirror
// the way they would on the PCB.
//
//   000000-07ffff  ROM                 090000-097fff  work RAM
//   080000-081fff  palette (low lane)  0a0000/0a0001  out / int latch
//   0c0001         sound latch (w)     0c0002         DSW0 (r)
//   0c0004         watchdog (w)        0c2000-0c2007  IN0,IN1,IN2,DSW1 (r)
//   100000-101fff  colorram  -> VCS2   102000-103fff  videoram -> VCS1
//   120000-12ffff  charram   -> CHACS  180000-181fff  scroll   -> VZCS
//   190000-190fff  spriteram -> OBJRAM
//
// NOTE the colorram/videoram order is REVERSED with respect to both Nemesis
// and Salamander, which put videoram in the lower block.

`default_nettype none

module jtblkpan_addr_dec(
    input        i_as_n,
    input        i_lds_n,
    input        i_uds_n,
    input [23:1] i_cpu_addr,

    output       o_rom_cs,
    output       o_ram_cs,
    output       o_pal_cs,
    output       o_outlatch_cs,
    output       o_intlatch_cs,
    output       o_snd_cs,
    output       o_wdog_cs,
    output       o_dsw0_cs,
    output       o_in0_cs,
    output       o_in1_cs,
    output       o_in2_cs,
    output       o_dsw1_cs,
    // GX400A_VIDEO selects, all active low
    output       o_chacs_n,
    output       o_objram_n,
    output       o_vcs1,
    output       o_vcs2,
    output       o_vzcs
);

wire       vma = ~i_as_n;
wire [7:0] ab  = i_cpu_addr[23:16];   // region byte
wire       a13 = i_cpu_addr[13];

// 000000-07ffff: the ROM answers on the whole 512kB window
assign o_rom_cs      = vma && ab[7:3]==5'b00000;
assign o_pal_cs      = vma && ab==8'h08;
assign o_ram_cs      = vma && ab==8'h09;

// 0a0000 (upper lane) = outlatch, 0a0001 (lower lane) = intlatch
assign o_outlatch_cs = vma && ab==8'h0a && ~i_uds_n;
assign o_intlatch_cs = vma && ab==8'h0a && ~i_lds_n;

// 0c0000 block: a13 splits the write/DSW0 group from the input group
wire io_cs = vma && ab==8'h0c;
assign o_snd_cs      = io_cs && ~a13 && i_cpu_addr[2:1]==2'd0 && ~i_lds_n;
assign o_dsw0_cs     = io_cs && ~a13 && i_cpu_addr[2:1]==2'd1;
assign o_wdog_cs     = io_cs && ~a13 && i_cpu_addr[2:1]==2'd2;
assign o_in0_cs      = io_cs &&  a13 && i_cpu_addr[2:1]==2'd0;
assign o_in1_cs      = io_cs &&  a13 && i_cpu_addr[2:1]==2'd1;
assign o_in2_cs      = io_cs &&  a13 && i_cpu_addr[2:1]==2'd2;
assign o_dsw1_cs     = io_cs &&  a13 && i_cpu_addr[2:1]==2'd3;

// Video board. a13 picks colorram (low) vs videoram (high) inside 0x10xxxx;
// a14 is a don't-care, which reproduces MAME's mirror(0x4000) on colorram.
assign o_vcs2        = !( vma && ab==8'h10 && ~a13 );
assign o_vcs1        = !( vma && ab==8'h10 &&  a13 );
assign o_chacs_n     = !( vma && ab==8'h12 );
assign o_vzcs        = !( vma && ab==8'h18 );
assign o_objram_n    = !( vma && ab==8'h19 );

endmodule
