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

    input      [ 3:0]   gfxbank0, gfxbank1,
    input      [ 2:0]   charbank,
    input      [ 1:0]   objbank,
    input               flip,
    input      [ 8:0]   scry,

    // tilemap VRAM
    output     [11:1]   scr_addr,
    input      [15:0]   scr_vram,
    // raster RAM
    output     [11:1]   ras_addr,
    input      [15:0]   ras_dout,
    // sprite RAM
    output     [ 9:1]   objr_addr,
    input      [15:0]   objr_dout,
    // sprite tile lookup RAM
    output     [13:1]   objl_addr,
    input      [15:0]   objl_dout,
    // palette
    output     [11:1]   mix_addr,
    input      [15:0]   mix_pal,

    output     [19:2]   scr0_addr,
    output              scr0_cs,
    input      [31:0]   scr0_data,
    input               scr0_ok,

    output     [21:2]   obj0_addr,
    output              obj0_cs,
    input      [31:0]   obj0_data,
    input               obj0_ok,

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
localparam [8:0] V_START  = 9'd0,
                 VB_START = 9'd239,
                 VB_END   = 9'd255,
                 VS_START = 9'd244,
                 VS_END   = 9'd248,
                 HB_START = 9'd351,
                 HB_END   = 9'd455,
                 HS_START = 9'd400,
                 HS_END   = 9'd424,
                 HCNT_END = 9'd455;

// MAME's visible window starts at pixel 4 of the 456 count, and
// jtframe_tilemap outputs eight pixels behind its fetch. Both layers are fed
// an hdump running this much ahead so the picture lands at x=0 with no left
// hand black bar. Wrapped on the 456 grid so the count stays continuous
// through the end of the line and the pipeline primes correctly
// Tiles and sprites do not share the same pipeline depth, so each layer gets
// its own lead. Sprites sit 9 pixels right of the tilemap
localparam [8:0] HOFF_SCR = 9'd14,
                 HOFF_OBJ = HOFF_SCR - 9'd9;

wire [ 8:0] vdump, vrender, H, hoff_scr, hoff_obj;
wire [ 9:0] scr_pxl, obj_pxl;
wire [10:0] pxl;

assign hoff_scr = H >= (HCNT_END-HOFF_SCR+9'd1) ? H+HOFF_SCR-(HCNT_END+9'd1) : H+HOFF_SCR;
assign hoff_obj = H >= (HCNT_END-HOFF_OBJ+9'd1) ? H+HOFF_OBJ-(HCNT_END+9'd1) : H+HOFF_OBJ;

// tiles land on palette 0-1023, sprites on 1024-2047.
// Sprites are transparent on pen 15, and the line buffer reads back 15 where
// nothing was drawn
assign pxl = &obj_pxl[3:0] ? { 1'b0, scr_pxl } : { 1'b1, obj_pxl };

jtframe_vtimer #(
    .V_START    ( V_START   ),
    .VB_START   ( VB_START  ),
    .VB_END     ( VB_END    ),
    .VS_START   ( VS_START  ),
    .VS_END     ( VS_END    ),
    .HB_START   ( HB_START  ),
    .HB_END     ( HB_END    ),
    .HS_START   ( HS_START  ),
    .HS_END     ( HS_END    ),
    .HCNT_END   ( HCNT_END  )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
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
    .hdump      ( hoff_scr  ),
    .vdump      ( vdump     ),
    .blankn     ( gfx_en[0] ),
    .gfxbank0   ( gfxbank0  ),
    .gfxbank1   ( gfxbank1  ),
    .charbank   ( charbank  ),
    .scry       ( scry      ),
    .scr_addr   ( scr_addr  ),
    .scr_vram   ( scr_vram  ),
    .ras_addr   ( ras_addr  ),
    .ras_dout   ( ras_dout  ),
    .rom_addr   ( scr0_addr ),
    .rom_cs     ( scr0_cs   ),
    .rom_data   ( scr0_data ),
    .rom_ok     ( scr0_ok   ),
    .pxl        ( scr_pxl   )
);

jtpspike_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .flip       ( flip      ),
    .hdump      ( hoff_obj  ),
    .vrender    ( vrender   ),
    .objbank    ( objbank   ),
    .objr_addr  ( objr_addr ),
    .objr_dout  ( objr_dout ),
    .objl_addr  ( objl_addr ),
    .objl_dout  ( objl_dout ),
    .rom_addr   ( obj0_addr ),
    .rom_cs     ( obj0_cs   ),
    .rom_data   ( obj0_data ),
    .rom_ok     ( obj0_ok   ),
    .pxl        ( obj_pxl   )
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
