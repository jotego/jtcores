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
    Date: 10-8-2026 */

// C7-01 GGA video timing. 7.159MHz pixel clock over a 456x256 grid,
// 352x240 visible

module jtpspike_video(
    input               rst,
    input               clk,
    input               pxl_cen,

    input               turbofrc, aerofgt, karatblz,
    // C7-01 GGA write port
    input               gga_cs, gga_we, gga_addr,
    input      [ 7:0]   gga_din,
    input      [31:0]   gfxbank,    // eight 4-bit banks
    input      [ 2:0]   charbank,
    input      [ 1:0]   objbank,
    input               flip,
    input      [ 8:0]   scry, scrx1, scry1, scrx0,

    // tilemap VRAM
    output     [12:1]   scr_addr,
    input      [15:0]   scr_vram,
    output     [12:1]   scr1v_addr,
    input      [15:0]   scr1_vram,
    // raster RAM
    output     [11:1]   ras_addr,
    input      [15:0]   ras_dout,
    // sprite RAM. The second chip reads the upper half of its own copy
    output     [10:1]   objr_addr,
    input      [15:0]   objr_dout,
    output     [10:1]   objr1_addr,
    input      [15:0]   objr1_dout,
    // sprite tile lookup RAM
    output     [15:1]   objl_addr,
    input      [15:0]   objl_dout,
    output     [15:1]   objl1_addr,
    input      [15:0]   objl1_dout,
    // palette
    output     [11:1]   mix_addr,
    input      [15:0]   mix_pal,

    output     [19:2]   scr0_addr,
    output              scr0_cs,
    input      [31:0]   scr0_data,
    input               scr0_ok,
    output     [20:2]   scr1_addr,
    output              scr1_cs,
    input      [31:0]   scr1_data,
    input               scr1_ok,

    output     [21:2]   obj0_addr,
    output              obj0_cs,
    input      [31:0]   obj0_data,
    input               obj0_ok,
    output     [20:2]   obj1_addr,
    output              obj1_cs,
    input      [31:0]   obj1_data,
    input               obj1_ok,

    input      [ 3:0]   gfx_en,

    output              LHBL, LVBL, HS, VS,
    output     [ 4:0]   red, green, blue
);

// Taken from the GGA register table the game writes at boot (ROM 0x1202e).
// H registers count in units of 4 pixels, V registers in units of 2 lines,
// both biased by one unit:
//   00=57 -> 352 HB start   01=63 -> 400 HS start
//   02=69 -> 424 HS end     03=71 -> 456 H total
//   08=77 -> 240 VB start   09=79 -> 244 VS start
//   0a=7b -> 248 VS end     0b=7f -> 256 V total
wire [8:0] h_last;

// MAME's visible window starts at pixel 4 of the 456 count, and
// jtframe_tilemap outputs eight pixels behind its fetch. Both layers are fed
// an hdump running this much ahead so the picture lands at x=0 with no left
// hand black bar. Wrapped on the 456 grid so the count stays continuous
// through the end of the line and the pipeline primes correctly
// Tiles and sprites do not share the same pipeline depth, so each layer gets
// its own lead. Sprites sit 9 pixels right of the tilemap.
//
// Part of the lead is the visible window offset, and it is NOT the same for
// both games: pspikes is set_visarea(0*8+4,...) so its picture starts at x=4,
// turbofrc is set_visarea(0*8,...) and starts at x=0. The remaining 10 is the
// tilemap pipeline. Carrying the pspikes 4 over to turbofrc stacks with the
// per layer scroll bias and shifts the whole picture along the scanline
// Visible window start differs per game: pspikes x=4, turbofrc x=0,
// aerofgtb x=12 (set_visarea(0*8+12,...)). The other 10 is the tilemap pipeline
wire       two      = turbofrc | aerofgt;   // turbofrc tile format and map
// karatblz also has two tile layers and two sprite chips - screen_update_karatblz
// draws tilemap 0 and 1 and both spr devices - but its tile format is its own,
// so the enables cannot reuse `two`
wire       dual     = two | karatblz;
// Sprite tile-code mask: declared ROM_REGION size / 128 - 1. See jtpspike_objscan
wire [14:0] cmask0 = karatblz ? 15'h7fff : turbofrc ? 15'h3fff : 15'h1fff;
wire [14:0] cmask1 = karatblz ? 15'h1fff : 15'h0fff;
// Each engine is fed an hdump running ahead of H by its own pipeline depth
// plus the game's visible-window origin, from MAME set_visarea:
//   pspikes 4 (0*8+4)  turbofrc 0 (0*8)  karatblz 8 (1*8)  aerofgtb 12 (0*8+12)
// MAME's per-layer scroll bias is applied separately in _scr.v as xb0/xb1.
// screen_update_turbofrc uses -11 / -7 and aerofgtb runs that same routine, but
// its VIDEO_START adds set_scrolldx(1,1). MAME folds that in as
// effective = m_dx - rowscroll, so the dx ADDS to the bias: 12 / 8, not 10 / 6. The sprite chip's own x offset comes from
// vsystem_spr2 set_offsets, which ONLY aerofgtb sets, to (3,-1).
`ifndef PSCR
 `define PSCR 10
`endif
localparam [8:0] P_SCR = `PSCR,   // tilemap fetch pipeline (sweepable)
                 P_OBJ = 9'd1;    // sprite line-buffer readout
wire [8:0] visx     = karatblz ? 9'd8 : aerofgt ? 9'd12 : turbofrc ? 9'd0 : 9'd4;
wire [8:0] xoffs    = aerofgt ? 9'd3 : 9'd0;          // MAME set_offsets x
wire [8:0] hoff_scr = visx + P_SCR;
wire [8:0] xb0      = karatblz ? 9'd8 : aerofgt ? 9'd12 : 9'd11;
wire [8:0] xb1      = karatblz ? 9'd4 : aerofgt ? 9'd8  : 9'd7;
wire [8:0] obj_yoffs= aerofgt ? 9'h1ff : 9'd0;        // MAME set_offsets y = -1
wire [8:0] hoff_obj = visx + P_OBJ - xoffs;

wire [ 8:0] vdump, vrender, H, hdump_scr, hdump_obj;
wire [ 9:0] scr_pxl, scr1_pxl;
wire [10:0] obj_pxl, obj1_pxl;
wire [10:0] pxl;
wire [20:2] scr1_raw, scr0_raw;
wire [21:2] obj1_raw;
wire        s0_op, s1_op, o0_op, o1_op;

assign scr1_addr = scr1_raw;
assign scr0_addr = scr0_raw[19:2];
assign obj1_addr = obj1_raw[20:2];
// the second chip walks the upper half of the sprite RAM
assign objr1_addr[10] = 1'b1;
assign objr_addr[10]  = 1'b0;
assign hdump_scr = H >= (h_last-hoff_scr+9'd1) ? H+hoff_scr-(h_last+9'd1) : H+hoff_scr;
assign hdump_obj = H >= (h_last-hoff_obj+9'd1) ? H+hoff_obj-(h_last+9'd1) : H+hoff_obj;

// Sprites are transparent on pen 15 and the line buffer reads back 15 where
// nothing was drawn. Tile layer 1 is transparent on pen 15 too
assign s0_op = 1'b1;                    // layer 0 is the opaque background
assign s1_op = ~&scr1_pxl[3:0];
assign o0_op = ~&obj_pxl[3:0];
assign o1_op = ~&obj1_pxl[3:0];

// pspikes  palette 2048: tiles 0-1023, sprites 1024-2047
// turbofrc palette 1024 in four fixed blocks of 256:
//          layer 0, layer 1, sprites 0, sprites 1
// Order back to front on turbofrc is layer 0, sprites with pri==0, layer 1,
// sprites with pri==1 - layer 1 masks the low priority sprites
// turbofrc sprite pixel: pal[6:0] is {pri, objbank, colour}, and only the
// four colour bits index its 256 entry block
// MAME GFXDECODE colorbase, 11-bit index: turbofrc/aerofgt/karatblz have a
// 1024-entry palette with tiles at 0 and 256, spr1 at 512 ({3'b010,..}) and
// spr2 at 768 ({3'b011,..}). pspikes is the odd one out: 2048 entries with
// sprites at 1024 ({1'b1,..}). These are correct - verified against
// GFXDECODE_ENTRY colorbases, do not "fix" them.
wire [10:0] o0_idx = { 3'b010, obj_pxl [7:4], obj_pxl [3:0] };
wire [10:0] o1_idx = { 3'b011, obj1_pxl[7:4], obj1_pxl[3:0] };

wire [10:0] kb_pxl = o1_op ? o1_idx :
                     o0_op ? o0_idx :
                     s1_op ? { 1'b0, 2'b01, scr1_pxl[7:0] } :
                             { 1'b0, 2'b00, scr_pxl[7:0] };
`ifdef SIM_ONLY_SCR0
assign pxl = { 1'b0, 2'b00, scr_pxl[7:0] };
`elsif SIM_ONLY_SCR1
assign pxl = s1_op ? { 1'b0, 2'b01, scr1_pxl[7:0] } : 11'd0;
`elsif SIM_ONLY_OBJ
assign pxl = o1_op ? o1_idx : o0_op ? o0_idx : 11'd0;
`else
assign pxl = karatblz ? kb_pxl :
             !two ? ( o0_op ? { 1'b1, obj_pxl[9:0] } : { 1'b0, scr_pxl } ) :
             ( o1_op & obj1_pxl[10] ) ? o1_idx :
             ( o0_op & obj_pxl [10] ) ? o0_idx :
               s1_op                  ? { 1'b0, 2'b01, scr1_pxl[7:0] } :
               o1_op                  ? o1_idx :
               o0_op                  ? o0_idx :
                                        { 1'b0, 2'b00, scr_pxl[7:0] };
`endif

jtpspike_gga u_gga(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .aerofgt    ( aerofgt   ),
    .cs         ( gga_cs    ),
    .we         ( gga_we    ),
    .addr       ( gga_addr  ),
    .din        ( gga_din   ),
    .h_last     ( h_last    ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( H         ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);


jtpspike_scr u_scr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .flip       ( flip      ),
    .hdump      ( hdump_scr ),
    .vdump      ( vdump     ),
    .blankn     ( gfx_en[0] ),
    .two        ( two       ),
    .kb         ( karatblz  ),
    .noraster   ( karatblz  ),
    .xbias      ( xb0       ),
    .layer      ( 1'b0      ),
    .gfxbank    ( gfxbank   ),
    .charbank   ( charbank  ),
    .scrx       ( scrx0     ),   // raster RAM elsewhere, register on karatblz
    .scry       ( scry      ),
    .scr_addr   ( scr_addr  ),
    .scr_vram   ( scr_vram  ),
    .ras_addr   ( ras_addr  ),
    .ras_dout   ( ras_dout  ),
    .rom_addr   ( scr0_raw  ),
    .rom_cs     ( scr0_cs   ),
    .rom_data   ( scr0_data ),
    .rom_ok     ( scr0_ok   ),
    .pxl        ( scr_pxl   )
);

// Second tile layer, turbofrc onwards. Idle on pspikes
jtpspike_scr u_scr1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .flip       ( flip      ),
    .hdump      ( hdump_scr ),
    .vdump      ( vdump     ),
    .blankn     ( gfx_en[1] & dual ),
    .two        ( two       ),
    .kb         ( karatblz  ),
    .noraster   ( karatblz  ),
    .xbias      ( xb1       ),
    .layer      ( 1'b1      ),
    .gfxbank    ( gfxbank   ),
    .charbank   ( 3'd0      ),
    .scrx       ( scrx1     ),
    .scry       ( scry1     ),
    .scr_addr   ( scr1v_addr),
    .scr_vram   ( scr1_vram ),
    .ras_addr   (           ),
    .ras_dout   ( 16'd0     ),
    .rom_addr   ( scr1_raw  ),
    .rom_cs     ( scr1_cs   ),
    .rom_data   ( scr1_data ),
    .rom_ok     ( scr1_ok   ),
    .pxl        ( scr1_pxl  )
);

jtpspike_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .flip       ( flip      ),
    .hdump      ( hdump_obj ),
    .vrender    ( vrender   ),
    .yoffs      ( obj_yoffs ),
    .en         ( gfx_en[2] ),
    .objbank    ( objbank   ),
    .objr_addr  ( objr_addr[9:1] ),
    .objr_dout  ( objr_dout ),
    .wide_lut   ( karatblz  ),
    .cmask      ( cmask0    ),
    .objl_addr  ( objl_addr ),
    .objl_dout  ( objl_dout ),
    .rom_addr   ( obj0_addr ),
    .rom_cs     ( obj0_cs   ),
    .rom_data   ( obj0_data ),
    .rom_ok     ( obj0_ok   ),
    .pxl        ( obj_pxl   )
);

// Second sprite chip. It walks the upper half of the sprite RAM, so its copy
// is addressed with the top bit forced high
jtpspike_obj u_obj1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .en         ( dual & gfx_en[3] ),
    .flip       ( flip      ),
    .hdump      ( hdump_obj ),
    .vrender    ( vrender   ),
    .yoffs      ( obj_yoffs ),
    .objbank    ( objbank   ),
    .objr_addr  ( objr1_addr[9:1] ),
    .objr_dout  ( objr1_dout),
    .wide_lut   ( karatblz  ),
    .cmask      ( cmask1    ),
    .objl_addr  ( objl1_addr),
    .objl_dout  ( objl1_dout),
    .rom_addr   ( obj1_raw  ),
    .rom_cs     ( obj1_cs   ),
    .rom_data   ( obj1_data ),
    .rom_ok     ( obj1_ok   ),
    .pxl        ( obj1_pxl  )
);

jtpspike_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .pxl        ( pxl       ),
    .mix_addr   ( mix_addr  ),
    .mix_pal    ( mix_pal   ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule
