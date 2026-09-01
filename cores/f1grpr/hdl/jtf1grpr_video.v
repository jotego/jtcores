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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 27-8-2026 */

// Video timing and mixer.
//
// Layers, back to front, and their palette bases (xRGB-555, 2048 entries):
//   ROZ    0x300  Konami 053936 over rozvram/rozgfx, 16 palettes of 16
//   fg     0x000  8bpp characters, transparent pen 0xff
//   SPR-1  0x100  16 palettes of 16
//   SPR-2  0x200
// The sprite-vs-layer order follows gfxctrl: MAME calls its handling a
// kludge, so it is reproduced rather than trusted.
//
// TODO the layers themselves - the mixer currently shows the palette only.

module jtf1grpr_video(
    input               rst,
    input               clk,
    input               pxl_cen,

    // GGA
    input               gga_cs, gga_we, gga_addr,
    input      [ 7:0]   gga_din,

    input      [ 7:0]   gfxctrl,
    input               flip,
    input      [ 8:0]   fg_scrx, fg_scry,
    input               roz_we,
    input      [ 4:1]   roz_addr,
    input      [15:0]   roz_din,

    // BRAM read ports
    output     [11:1]   fgv_addr,
    input      [15:0]   fgv_dout,
    output     [12:1]   rozv_addr,
    input      [15:0]   rozv_dout,
    output     [17:1]   rozg_addr,
    input      [15:0]   rozg_dout,
    output     [ 9:1]   objr0_addr,
    input      [15:0]   objr0_dout,
    output     [ 9:1]   objr1_addr,
    input      [15:0]   objr1_dout,
    output     [13:1]   objl0_addr,
    input      [15:0]   objl0_dout,
    output     [13:1]   objl1_addr,
    input      [15:0]   objl1_dout,
    output     [11:1]   mix_addr,
    input      [15:0]   mix_pal,

    // SDRAM gfx
    output     [20:2]   fg_addr,
    output              fg_cs,
    input      [31:0]   fg_data,
    input               fg_ok,
    output     [19:2]   obj0_addr,
    output              obj0_cs,
    input      [31:0]   obj0_data,
    input               obj0_ok,
    output     [18:2]   obj1_addr,
    output              obj1_cs,
    input      [31:0]   obj1_data,
    input               obj1_ok,

    input      [ 3:0]   gfx_en,

    output              LHBL, LVBL, HS, VS,
    output     [ 4:0]   red, green, blue
);

wire [ 8:0] hdump, vdump, vrender, vrender1, h_last, H, hsize, vsize;
wire        Hinit, Vinit;
wire [10:0] pxl;
wire [ 7:0] fg_pxl;
wire [10:0] o0_pxl, o1_pxl;
wire [15:1] o0l_addr, o1l_addr;
wire [21:2] o0r_addr, o1r_addr;
wire        fg_op, o0_op, o1_op;
wire [ 7:0] roz_pxl;
wire        roz_on;

assign hdump = H;

// C7-01 GGA, shared with pspike. 320x240 out of a 456x256 grid; the CPU
// reprograms it right after boot, these only have to be a legal grid
jtpspike_gga u_gga(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .cs         ( gga_cs    ),
    .we         ( gga_we    ),
    .addr       ( gga_addr  ),
    .din        ( gga_din   ),

    .h_last     ( h_last    ),
    .hsize      ( hsize     ),
    .vsize      ( vsize     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .H          ( H         ),
    .Hinit      ( Hinit     ),
    .Vinit      ( Vinit     ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

// jtpspike_obj emits a wider lookup and ROM address than this board wires:
// the CG RAM is 16kB (13 bits) and the sprite ROMs 1MB / 512kB
assign objl0_addr = o0l_addr[13:1];
assign objl1_addr = o1l_addr[13:1];
assign obj0_addr  = o0r_addr[19:2];
assign obj1_addr  = o1r_addr[18:2];

// Palette bases: fg 0x000 (8bpp), SPR-1 0x100, SPR-2 0x200, ROZ 0x300.
// fg clears on pen 0xff, sprites on pen 15.
assign fg_op = fg_pxl != 8'hff;
assign o0_op = o0_pxl[3:0] != 4'hf;
assign o1_op = o1_pxl[3:0] != 4'hf;
// MAME's draw order and the priority bitmap:
//   zoom_draw(..., tmap, flags=0, priority=0, hack=1)  ROZ writes 0
//   fg_tilemap->draw(..., flags=0, priority=1)          fg  writes 1
// prio_zoom_transpen skips a sprite pixel where (1<<bitmap) & pmask, so
// pmask 0x02 blocks only where the FG painted - sprites stay in front of
// the ROZ and behind the fg.
//   gfxctrl==0 : both chips 0x02, both behind the fg
//   otherwise  : SPR-1 gets 0x00 and covers even the fg; SPR-2 stays 0x02
// SPR-1 (pilots) sits ON TOP of SPR-2 (cars) - verified on the picture.
// Note this is the opposite of MAME's draw order, which paints spr_old[0]
// then spr_old[1] and so puts the cars above the pilots.
// MAME calls its own handling a kludge for the continue screen, so this
// reproduces MAME rather than claiming to match the PCB.
wire o0_front = gfxctrl != 8'h00;

// Layer isolation for bring-up: -d F1GP_LAYER=1 fg, 2 SPR-1, 4 SPR-2,
// 8 ROZ. Any combination; unset means the normal mix.
`ifdef F1GP_LAYER
localparam [3:0] LYR = `F1GP_LAYER;
assign pxl = (LYR[1] & o0_op) ? 11'h100 + { 3'd0, o0_pxl[7:0] } :
             (LYR[2] & o1_op) ? 11'h200 + { 3'd0, o1_pxl[7:0] } :
             (LYR[0] & fg_op) ? { 3'd0, fg_pxl } :
             (LYR[3] & roz_on)? 11'h300 + { 3'd0, roz_pxl } : 11'd0;
`else
assign pxl = ( o0_front & o0_op) ? 11'h100 + { 3'd0, o0_pxl[7:0] } :
              fg_op              ? { 3'd0, fg_pxl }                :
              o0_op              ? 11'h100 + { 3'd0, o0_pxl[7:0] } :
              o1_op              ? 11'h200 + { 3'd0, o1_pxl[7:0] } :
              roz_on             ? 11'h300 + { 3'd0, roz_pxl }     :
                                   11'd0;
`endif

jtf1grpr_fg u_fg(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .hsize      ( hsize     ),
    .vsize      ( vsize     ),
    .vdump      ( vdump     ),
    .scrx       ( fg_scrx   ),
    .scry       ( fg_scry   ),

    .fgv_addr   ( fgv_addr  ),
    .fgv_dout   ( fgv_dout  ),

    .rom_addr   ( fg_addr   ),
    .rom_cs     ( fg_cs     ),
    .rom_data   ( fg_data   ),
    .rom_ok     ( fg_ok     ),

    .pxl        ( fg_pxl    )
);


// SPR-1 and SPR-2, both vsystem_spr2 pritype 2: one pass, no priority filter.
// The map word is the tile code directly (no set_tile_indirect_cb on f1gp is
// wrong - there IS one, into the CG RAM), so the lookup RAM is used.
// cmask: sprites1 1MB/128 = 8192 -> 13 bits, sprites2 512kB/128 = 4096 -> 12
jtpspike_obj #(.PASSES(1)) u_obj0(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .en         ( 1'b1      ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .vrender    ( vrender   ),
    .hsize      ( hsize     ),
    .vsize      ( vsize     ),
    .xorg       ( 9'd1      ),   // -xoffs: the 1 px sits before the mirror
    .xoffs      ( 9'h1ff    ),   // 1 px left
    .yoffs      ( 9'h1f8    ),   // 8 lines up
    .objbank    ( 2'd0      ),

    .objr_addr  ( objr0_addr),
    .objr_dout  ( objr0_dout),
    .wide_lut   ( 1'b0      ),
    .cmask      ( 15'h1fff  ),
    .objl_addr  ( o0l_addr  ),
    .objl_dout  ( objl0_dout),

    .rom_addr   ( o0r_addr  ),
    .rom_cs     ( obj0_cs   ),
    .rom_data   ( obj0_data ),
    .rom_ok     ( obj0_ok   ),

    .pxl        ( o0_pxl    )
);

jtpspike_obj #(.PASSES(1)) u_obj1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .en         ( 1'b1      ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .vrender    ( vrender   ),
    .hsize      ( hsize     ),
    .vsize      ( vsize     ),
    .xorg       ( 9'd1      ),   // -xoffs: the 1 px sits before the mirror
    .xoffs      ( 9'h1ff    ),   // 1 px left
    .yoffs      ( 9'h1f8    ),   // 8 lines up
    .objbank    ( 2'd0      ),

    .objr_addr  ( objr1_addr),
    .objr_dout  ( objr1_dout),
    .wide_lut   ( 1'b0      ),
    .cmask      ( 15'h0fff  ),
    .objl_addr  ( o1l_addr  ),
    .objl_dout  ( objl1_dout),

    .rom_addr   ( o1r_addr  ),
    .rom_cs     ( obj1_cs   ),
    .rom_data   ( obj1_data ),
    .rom_ok     ( obj1_ok   ),

    .pxl        ( o1_pxl    )
);

jtf1grpr_roz u_roz(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .vs         ( VS        ),

    .cs         ( roz_we    ),
    .addr       ( roz_addr  ),
    .din        ( roz_din   ),
    .dsn        ( 2'b00     ),

    .rozv_addr  ( rozv_addr ),
    .rozv_dout  ( rozv_dout ),
    .rozg_addr  ( rozg_addr ),
    .rozg_dout  ( rozg_dout ),

    .pxl        ( roz_pxl   ),
    .on         ( roz_on    )
);

// The colmix latches RGB and samples LHBL on the same pxl_cen edge, but the
// GGA raises LHBL on that very edge (non-blocking), so the first pixel of the
// line - latched while H is still h_last - sees the OLD LHBL=0 and is zeroed:
// a permanently black x=0 column. Open the gate combinationally for that edge.
wire lhbl_gate = LHBL | (H==h_last);

jtf1grpr_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( lhbl_gate ),
    .LVBL       ( LVBL      ),

    .pxl        ( pxl       ),

    .mix_addr   ( mix_addr  ),
    .mix_pal    ( mix_pal   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule
