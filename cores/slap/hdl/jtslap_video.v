/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtslap_video(
    input             rst,
    input             clk,
    input             pxl_cen,
    output            HS, VS, LHBL, LVBL,
    output      [8:0] hdump,
    input       [8:0] scrx,
    input       [7:0] scry,
    input             flip,
    output     [11:1] fixv_addr, scrv_addr,
    input      [15:0] fixv_data, scrv_data,
    output     [10:0] objv_addr,
    input       [7:0] objv_data,
    output     [13:1] fix_addr,
    output            fix_cs,
    input      [15:0] fix_data,
    input             fix_ok,
    output     [16:2] scr_addr, obj_addr,
    output            scr_cs, obj_cs,
    input      [31:0] scr_data, obj_data,
    input             scr_ok, obj_ok,
    output      [7:0] pal_addr,
    input       [3:0] palr_data, palg_data, palb_data,
    output      [3:0] red, green, blue,
    input       [3:0] gfx_en
);

wire [8:0] vdump, vrender;
wire [8:0] tile_h;
wire [8:0] tile_hf;
wire [8:0] scr_h, scr_v;
wire [7:0] fix_pxl, scr_pxl, obj_pxl;
// Prime the tile pipelines with the pixels immediately before X=0.
// The timing counter wraps at 388; tile coordinates wrap at 512.
assign tile_h = hdump >= 9'd296 ? hdump + 9'd124 : hdump;
assign tile_hf = tile_h + (flip ? 9'd216 : 9'd0);
assign scr_h = tile_hf + 9'd9;
assign scr_v = flip ? vdump - 9'd1 : vdump + 9'd1;

jtframe_vtimer #(
    .VB_START( 9'd255 ), .VB_END( 9'd15 ), .VCNT_END( 9'd269 ),
    .VS_START( 9'd264 ), .VS_END( 9'd2 ),
    .HB_START( 9'd296 ), .HB_END( 9'd0 ), .HCNT_END( 9'd387 ),
    .HS_START( 9'd320 ), .HS_END( 9'd352 )
) u_vtimer(
    .clk     ( clk      ),
    .pxl_cen ( pxl_cen  ),
    .vdump   ( vdump    ),
    .vrender ( vrender  ),
    .vrender1(          ),
    .H       ( hdump    ),
    .Hinit   (          ),
    .Vinit   (          ),
    .HS      ( HS       ),
    .VS      ( VS       ),
    .LHBL    ( LHBL     ),
    .LVBL    ( LVBL     )
);

jtframe_tilemap #(
    .VA          ( 11 ),
    .CW          ( 10 ),
    .BPP         (  2 ),
    .MAP_HW      (  9 ),
    .FLIP_MSB    (  0 ),
    .HDUMP_OFFSET( -9 )
) u_tilemap(
    .rst      ( rst               ),
    .clk      ( clk               ),
    .pxl_cen  ( pxl_cen           ),
    .hdump    ( tile_hf           ),
    .vdump    ( vdump             ),
    .blankn   ( 1'b1              ),
    .flip     ( flip              ),
    .vram_addr( fixv_addr         ),
    .code     ( fixv_data[9:0]    ),
    .pal      ( fixv_data[15:10]  ),
    .hflip    ( flip              ),
    .vflip    ( 1'b0              ),
    .rom_addr ( fix_addr          ),
    .rom_cs   ( fix_cs            ),
    .rom_data ( fix_data          ),
    .rom_ok   ( fix_ok            ),
    .pxl      ( fix_pxl           )
);

jtframe_scroll #(
    .VA      ( 11 ),
    .MAP_VW  (  8 ),
    .FLIP_HW (  9 )
) u_scroll(
    .rst      ( rst               ),
    .clk      ( clk               ),
    .pxl_cen  ( pxl_cen           ),
    .hs       ( HS                ),
    .hdump    ( scr_h             ),
    .vdump    ( scr_v             ),
    .blankn   ( 1'b1              ),
    .flip     ( flip              ),
    .scrx     ( scrx              ),
    .scry     ( scry              ),
    .vram_addr( scrv_addr         ),
    .code     ( scrv_data[11:0]   ),
    .pal      ( scrv_data[15:12]  ),
    .hflip    ( flip              ),
    .vflip    ( 1'b0              ),
    .rom_addr ( scr_addr          ),
    .rom_cs   ( scr_cs            ),
    .rom_data ( scr_data          ),
    .rom_ok   ( scr_ok            ),
    .pxl      ( scr_pxl           )
);

jtslap_obj u_obj(
    .rst      ( rst       ),
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .HS       ( HS        ),
    .LVBL     ( LVBL      ),
    .hdump    ( hdump     ),
    .vrender  ( vrender   ),
    .flip     ( flip      ),
    .vram_addr( objv_addr ),
    .vram_data( objv_data ),
    .rom_addr ( obj_addr  ),
    .rom_cs   ( obj_cs    ),
    .rom_data ( obj_data  ),
    .rom_ok   ( obj_ok    ),
    .pxl      ( obj_pxl   )
);

jtslap_colmix u_colmix(
    .clk      ( clk       ),
    .pxl_cen  ( pxl_cen   ),
    .LHBL     ( LHBL      ),
    .LVBL     ( LVBL      ),
    .fix_pxl  ( fix_pxl   ),
    .scr_pxl  ( scr_pxl   ),
    .obj_pxl  ( obj_pxl   ),
    .pal_addr ( pal_addr  ),
    .palr_data( palr_data ),
    .palg_data( palg_data ),
    .palb_data( palb_data ),
    .red      ( red       ),
    .green    ( green     ),
    .blue     ( blue      ),
    .gfx_en   ( gfx_en    )
);

endmodule
