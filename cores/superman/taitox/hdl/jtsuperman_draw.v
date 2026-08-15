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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 7-11-2022 */

// This is tile map section of the SETA chip
// This one uses an independent line buffer
// from that of the sprites

module jtsuperman_draw(
    input               rst,
    input               clk,

    input               draw,
    output reg          busy,
    input      [13:0]   code,
    input      [ 8:0]   xpos,
    input      [ 3:0]   ysub,
    input               flip,

    input               hflip,
    input               vflip,
    input      [ 4:0]   pal,

    output     [20:2]   rom_addr,
    output reg          rom_cs,
    input               rom_ok,
    input      [31:0]   rom_data,

    output reg [ 8:0]   buf_addr,
    output              buf_we,
    output     [ 8:0]   buf_din,

    input      [ 7:0]   debug_bus
);

// Each tile is 16x16 and comes from the same ROM
// but it looks like the sprites have the two 8x16 halves swapped
parameter SWAP_HALVES = 1'b0;

reg  [31:0] pxl_data;
reg         rom_lsb;
reg  [ 3:0] cnt;
wire [ 3:0] ysubf, pxl_in;

assign ysubf    = ysub^{4{vflip}};
assign buf_din  = { pal, pxl_in };

// ============================================================================
// Byte → pixel-plane mapping (the X1-001/X1-002 bit scramble)
// ============================================================================
// pxl_data is one 32-bit word fetched from the gfx ROM.  Per MAME's
// gfx_layout for Taito X (taito_x.cpp ~line 967, `tilelayout`):
//
//   4 bpp, plane_offsets = { STEP4(0,8) } = { 0, 8, 16, 24 }
//
// In MAME's canonical ordering, each 32-bit fetch holds 8 horizontal
// pixels with one PLANE per BYTE:
//
//     pxl_data[ 7: 0]  = byte 0  =  plane 0  (LSB of palette index)
//     pxl_data[15: 8]  = byte 1  =  plane 1
//     pxl_data[23:16]  = byte 2  =  plane 2
//     pxl_data[31:24]  = byte 3  =  plane 3  (MSB of palette index)
//
// Inside each byte, bit 0 = leftmost pixel, bit 7 = rightmost (for
// no-hflip case — the always-block below shifts pxl_data right by 1
// each pxl_cen cycle so bit 0 is always the "current" pixel's bit).
//
// HOWEVER: the X1-001/X1-002 die assembles the 4-bit palette index
// from those plane bits with a SCRAMBLED bit order — not the
// MAME-tilelayout-natural { plane3, plane2, plane1, plane0 } order
// for { pxl_in[3], pxl_in[2], pxl_in[1], pxl_in[0] }.  The scramble
// is internal to the X1-002 die (see schematic W5100307A sheet 3,
// block 39 — the chip owns the CA/CGA/CGD buses going to the tile
// ROMs at sheet 5 blocks 43/45/37/38, but the internal logic that
// assembles palette-index bits from the 4 plane lanes isn't drawn
// at gate level on the PCB scan).  Our scramble was matched
// empirically against MAME pixel-perfect burst captures of Superman
// gameplay.  Touching this extraction WILL break Superman/Gigandes
// rendering, even though the scramble looks ugly.  The 68k-written
// palette entries land at indices that align with THIS specific
// scramble — the chip and the game ROM agree on the bit-mapping,
// and our HDL just has to match the chip.
//
//     pxl_in[3]  ←  pxl_data[16]  ←  byte 2 LSB  =  plane 2
//     pxl_in[2]  ←  pxl_data[ 0]  ←  byte 0 LSB  =  plane 0
//     pxl_in[1]  ←  pxl_data[24]  ←  byte 3 LSB  =  plane 3
//     pxl_in[0]  ←  pxl_data[ 8]  ←  byte 1 LSB  =  plane 1
//
// Equivalent MAME-plane → palette-index-bit mapping:
//     MAME plane 0 → palette bit 2     (pxl_in[2])
//     MAME plane 1 → palette bit 0     (pxl_in[0])
//     MAME plane 2 → palette bit 3     (pxl_in[3])
//     MAME plane 3 → palette bit 1     (pxl_in[1])
//
// This scramble is also why the Ballbros MRA needs the
// sequence=[1,3,0,2] ROM reorder in cfg/mame2mra.toml: Ballbros's 4
// single-plane ROMs (loaded via ROM_LOAD32_BYTE) land 1:1 in MAME's
// canonical byte → plane ordering, but Superman's ROMs already
// produce that same canonical layout via ROM_LOAD32_WORD_SWAP +
// 2-plane-per-byte packing in the original mask ROMs.  The HDL
// scramble below is "Superman-correct" — Ballbros needs the MRA
// step to FIRST land planes at the same byte positions that
// Superman naturally produces.
//
// hflip variant: same scramble, but read the MSB of each byte
// (bit 7 of each byte instead of bit 0) because the H-flipped
// pixel sequence reads pxl_data right-to-left.
// ============================================================================
assign pxl_in   = hflip ?
    { pxl_data[23], pxl_data[ 7], pxl_data[31], pxl_data[15] } :
    { pxl_data[16], pxl_data[ 0], pxl_data[24], pxl_data[ 8] };

assign rom_addr = { code, ysubf[3], rom_lsb^SWAP_HALVES, ysubf[2:0] };
assign buf_we   = busy & ~cnt[3];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_cs   <= 0;
        buf_addr <= 0;
        pxl_data <= 0;
        busy     <= 0;
        cnt      <= 0;
    end else begin
        if( !busy ) begin
            if( draw ) begin
                rom_lsb  <= hflip; // 14+4 = 18 (+2=20)
                rom_cs   <= 1;
                buf_addr <= xpos;
                busy     <= 1;
                cnt      <= 8;
            end
        end else begin
            if( rom_ok && rom_cs && cnt[3]) begin
                pxl_data <= rom_data;
                cnt[3]   <= 0;
                if( rom_lsb^hflip ) begin
                    rom_cs <= 0;
                end else begin
                    rom_cs <= 1;
                end
            end
            if( !cnt[3] ) begin
                cnt      <= cnt+1'd1;
                buf_addr <= buf_addr+1'd1;
                pxl_data <= hflip ? pxl_data << 1 : pxl_data >> 1;
                rom_lsb  <= ~hflip;
                if( cnt[2:0]==7 && !rom_cs ) busy <= 0;
            end
        end
    end
end

endmodule