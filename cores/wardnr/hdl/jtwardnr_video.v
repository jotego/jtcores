/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Wardner video: three tile maps, sprites and the priority mixer. The raster
 * is 446x286 with 320x240 visible. Screen flip mirrors the tile maps only.
 */
module jtwardnr_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    input      [ 2:0] scr_cs,
    input      [ 2:0] scr_addr,
    input      [ 7:0] scr_din,
    output     [15:0] txoffs,
    output     [15:0] bgoffs,
    output     [15:0] fgoffs,
    input             flip,
    input             bg_bank,
    input             fg_bank,
    input             video_on,
    input      [ 3:0] gfx_en,

    output     [11:1] tx_vaddr,
    input      [15:0] tx_dout,
    output     [13:1] bg_vaddr,
    input      [15:0] bg_dout,
    output     [12:1] fg_vaddr,
    input      [15:0] fg_dout,
    output     [11:1] pal_vaddr,
    input      [15:0] pal_dout,
    output     [11:1] obj_vaddr,
    input      [15:0] obj_dout,
    output     [11:1] objcpy_addr,
    output     [ 1:0] objcpy_we,
    output     [11:1] objscan_addr,
    input      [15:0] objscan_dout,

    // graphics ROMs: one 8-pixel row per 32-bit word, a byte per plane
    output     [15:2] char_addr,
    input      [31:0] char_data,
    output            char_cs,
    input             char_ok,
    output     [17:2] fg_addr,
    input      [31:0] fg_data,
    output            fg_cs,
    input             fg_ok,
    output     [16:2] bg_addr,
    input      [31:0] bg_data,
    output            bg_cs,
    input             bg_ok,
    output     [17:2] obj_addr,
    input      [31:0] obj_data,
    output            obj_cs,
    input             obj_ok,

    output            LVBL,
    output            LHBL,
    output            HS,
    output            VS,
    output     [ 4:0] red,
    output     [ 4:0] green,
    output     [ 4:0] blue
);

wire [ 8:0] vrender, vrender1, heff, tx_pxl, hdump, vdump;
wire [ 7:0] bg_pxl, fg_pxl;
wire [11:0] bg_vaddr_lo, obj_pxl;
wire [14:0] fg_rom_addr;

// the tile engines start 16 counts before the visible line
assign heff = hdump >= 9'd430 ? hdump - 9'd446 : hdump;

assign bg_vaddr = { bg_bank, bg_vaddr_lo };
assign fg_addr  = {    1'b0, fg_rom_addr };

jtframe_vtimer #(
    .HB_START   ( 9'd319            ),
    .HB_END     ( 9'd445            ),
    .HCNT_END   ( 9'd445            ),
    .HS_START   ( 9'd352            ),
    .HS_END     ( 9'd382            ),
    .VB_START   ( 9'd239            ),
    .VB_END     ( 9'd285            ),
    .VCNT_END   ( 9'd285            ),
    .VS_START   ( 9'd248            ),
    .VS_END     ( 9'd256            )
) u_vtimer(
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .vdump      ( vdump             ),
    .vrender    ( vrender           ),
    .vrender1   ( vrender1          ),
    .H          ( hdump             ),
    .Hinit      (                   ),
    .Vinit      (                   ),
    .LHBL       ( LHBL              ),
    .LVBL       ( LVBL              ),
    .HS         ( HS                ),
    .VS         ( VS                )
);

jtwardnr_scroll u_bg(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .hs         ( HS                ),
    .hdump      ( heff              ),
    .vdump      ( vdump             ),
    .flip       ( flip              ),
    .cs         ( scr_cs[1]         ),
    .addr       ( scr_addr          ),
    .din        ( scr_din           ),
    .offs       ( bgoffs            ),
    .vram_addr  ( bg_vaddr_lo       ),
    .vram_data  ( bg_dout           ),
    .rom_addr   ( bg_addr           ),
    .rom_data   ( bg_data           ),
    .rom_cs     ( bg_cs             ),
    .rom_ok     ( bg_ok             ),
    .pxl        ( bg_pxl            )
);

jtwardnr_scroll u_fg(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .hs         ( HS                ),
    .hdump      ( heff              ),
    .vdump      ( vdump             ),
    .flip       ( flip              ),
    .cs         ( scr_cs[2]         ),
    .addr       ( scr_addr          ),
    .din        ( scr_din           ),
    .offs       ( fgoffs            ),
    .vram_addr  ( fg_vaddr          ),
    .vram_data  ( fg_dout           ),
    .rom_addr   ( fg_rom_addr       ),
    .rom_data   ( fg_data           ),
    .rom_cs     ( fg_cs             ),
    .rom_ok     ( fg_ok             ),
    .pxl        ( fg_pxl            )
);

jtwardnr_scroll #(.TEXT(1)) u_tx(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .hs         ( HS                ),
    .hdump      ( heff              ),
    .vdump      ( vdump             ),
    .flip       ( flip              ),
    .cs         ( scr_cs[0]         ),
    .addr       ( scr_addr          ),
    .din        ( scr_din           ),
    .offs       ( txoffs            ),
    .vram_addr  ( tx_vaddr          ),
    .vram_data  ( tx_dout           ),
    .rom_addr   ( char_addr         ),
    .rom_data   ( char_data         ),
    .rom_cs     ( char_cs           ),
    .rom_ok     ( char_ok           ),
    .pxl        ( tx_pxl            )
);

jtwardnr_obj u_obj(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .hs         ( HS                ),
    .LVBL       ( LVBL              ),
    .hdump      ( hdump             ),
    .vrender    ( vrender           ),
    .ram_addr   ( obj_vaddr         ),
    .ram_dout   ( obj_dout          ),
    .cpy_addr   ( objcpy_addr       ),
    .cpy_we     ( objcpy_we         ),
    .scan_addr  ( objscan_addr      ),
    .scan_dout  ( objscan_dout      ),
    .rom_addr   ( obj_addr          ),
    .rom_data   ( obj_data          ),
    .rom_cs     ( obj_cs            ),
    .rom_ok     ( obj_ok            ),
    .pxl        ( obj_pxl           )
);

jtwardnr_colmix u_colmix(
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .LVBL       ( LVBL              ),
    .LHBL       ( LHBL              ),
    .video_on   ( video_on          ),
    .gfx_en     ( gfx_en            ),
    .bg_pxl     ( bg_pxl            ),
    .fg_pxl     ( fg_pxl            ),
    .tx_pxl     ( tx_pxl            ),
    .obj_pxl    ( obj_pxl           ),
    .pal_vaddr  ( pal_vaddr         ),
    .pal_dout   ( pal_dout          ),
    .red        ( red               ),
    .green      ( green             ),
    .blue       ( blue              )
);

endmodule
