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

    input      [15:0] tx_scrx,
    input      [15:0] tx_scry,
    input      [15:0] bg_scrx,
    input      [15:0] bg_scry,
    input      [15:0] fg_scrx,
    input      [15:0] fg_scry,
    input             flip,
    input             bg_bank,
    input             fg_bank,
    input             video_on,
    input      [ 3:0] gfx_en,

    output     [11:1] tx_vaddr,
    input      [15:0] tx_vq,
    output     [13:1] bg_vaddr,
    input      [15:0] bg_vq,
    output     [12:1] fg_vaddr,
    input      [15:0] fg_vq,
    output     [11:1] pal_vaddr,
    input      [15:0] pal_vq,
    output     [11:1] obj_vaddr,
    input      [15:0] obj_vq,
    output     [11:1] objcpy_addr,
    output     [ 1:0] objcpy_we,
    output     [11:1] objscan_addr,
    input      [15:0] objscan_q,

    input             ioctl_ram,
    input      [11:0] ioctl_addr,
    output     [ 7:0] ioctl_din,

    // graphics ROMs: one 8-pixel row per 32-bit word, a byte per plane
    output     [13:0] char_addr,
    input      [31:0] char_data,
    output            char_cs,
    input             char_ok,
    output     [15:0] fg_addr,
    input      [31:0] fg_data,
    output            fg_cs,
    input             fg_ok,
    output     [14:0] bg_addr,
    input      [31:0] bg_data,
    output            bg_cs,
    input             bg_ok,
    output     [15:0] obj_addr,
    input      [31:0] obj_data,
    output            obj_cs,
    input             obj_ok,

    output            LVBL,
    output            LHBL,
    output            HS,
    output            VS,
    output     [ 8:0] hdump,
    output     [ 8:0] vdump,
    output     [ 4:0] red,
    output     [ 4:0] green,
    output     [ 4:0] blue
);

wire [ 8:0] vrender, vrender1, heff, tx_pxl;
wire [ 8:0] bg_scrx_eff, bg_scry_eff, fg_scrx_eff, fg_scry_eff, tx_scrx_eff;
wire [ 7:0] tx_scry_eff, bg_pxl, fg_pxl;
wire [11:0] bg_vaddr_lo, obj_pxl;
wire [14:0] fg_rom_addr;
wire [31:0] bg_data_rev, fg_data_rev, tx_data_3p;
wire        Hinit, Vinit;

// the tile engines start 16 counts before the visible line
assign heff = hdump >= 9'd430 ? hdump - 9'd446 : hdump;

// MAME's tile map offsets (55,30, or 453,482 flipped) fold into the scroll
// values, plus 9 horizontally for the tile engine's latency
assign bg_scrx_eff = flip ? bg_scrx[8:0] - 9'd67 : bg_scrx[8:0] + 9'd64;
assign bg_scry_eff = flip ? bg_scry[8:0] - 9'd29 : bg_scry[8:0] + 9'd30;
assign fg_scrx_eff = flip ? fg_scrx[8:0] - 9'd67 : fg_scrx[8:0] + 9'd64;
assign fg_scry_eff = flip ? fg_scry[8:0] - 9'd29 : fg_scry[8:0] + 9'd30;
assign tx_scrx_eff = flip ? tx_scrx[8:0] - 9'd67 : tx_scrx[8:0] + 9'd64;
assign tx_scry_eff = flip ? tx_scry[7:0] - 8'd29 : tx_scry[7:0] + 8'd30;

// the ROMs hold plane 0 in the top byte; the text layer has three planes
assign bg_data_rev = { bg_data[7:0], bg_data[15:8], bg_data[23:16], bg_data[31:24] };
assign fg_data_rev = { fg_data[7:0], fg_data[15:8], fg_data[23:16], fg_data[31:24] };
assign tx_data_3p  = { 8'd0, char_data[7:0], char_data[15:8], char_data[23:16] };

assign bg_vaddr = { bg_bank, bg_vaddr_lo };
// Wardner's foreground ROM has no second bank
assign fg_addr  = { 1'b0, fg_rom_addr };

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
    .Hinit      ( Hinit             ),
    .Vinit      ( Vinit             ),
    .LHBL       ( LHBL              ),
    .LVBL       ( LVBL              ),
    .HS         ( HS                ),
    .VS         ( VS                )
);

jtframe_scroll #(
    .SIZE       ( 8                 ),
    .CW         ( 12                ),
    .VA         ( 12                ),
    .PW         ( 8                 ),
    .MAP_HW     ( 9                 ),
    .MAP_VW     ( 9                 ),
    .FLIP_HW    ( 9                 ),
    .FLIP_VW    ( 9                 ),
    .HJUMP      ( 1                 ),
    .XOR_HFLIP  ( 1                 )
) u_bg(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .hs         ( HS                ),
    .hdump      ( heff              ),
    .vdump      ( vdump             ),
    .flip       ( flip              ),
    .blankn     ( 1'b1              ),
    .scrx       ( bg_scrx_eff       ),
    .scry       ( bg_scry_eff       ),
    .vram_addr  ( bg_vaddr_lo       ),
    .code       ( bg_vq[11:0]       ),
    .pal        ( bg_vq[15:12]      ),
    .hflip      ( 1'b0              ),
    .vflip      ( 1'b0              ),
    .rom_addr   ( bg_addr           ),
    .rom_data   ( bg_data_rev       ),
    .rom_cs     ( bg_cs             ),
    .rom_ok     ( bg_ok             ),
    .pxl        ( bg_pxl            )
);

jtframe_scroll #(
    .SIZE       ( 8                 ),
    .CW         ( 12                ),
    .VA         ( 12                ),
    .PW         ( 8                 ),
    .MAP_HW     ( 9                 ),
    .MAP_VW     ( 9                 ),
    .FLIP_HW    ( 9                 ),
    .FLIP_VW    ( 9                 ),
    .HJUMP      ( 1                 ),
    .XOR_HFLIP  ( 1                 )
) u_fg(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .hs         ( HS                ),
    .hdump      ( heff              ),
    .vdump      ( vdump             ),
    .flip       ( flip              ),
    .blankn     ( 1'b1              ),
    .scrx       ( fg_scrx_eff       ),
    .scry       ( fg_scry_eff       ),
    .vram_addr  ( fg_vaddr          ),
    .code       ( fg_vq[11:0]       ),
    .pal        ( fg_vq[15:12]      ),
    .hflip      ( 1'b0              ),
    .vflip      ( 1'b0              ),
    .rom_addr   ( fg_rom_addr       ),
    .rom_data   ( fg_data_rev       ),
    .rom_cs     ( fg_cs             ),
    .rom_ok     ( fg_ok             ),
    .pxl        ( fg_pxl            )
);

jtframe_scroll #(
    .SIZE       ( 8                 ),
    .CW         ( 11                ),
    .VA         ( 11                ),
    .PW         ( 9                 ),
    .MAP_HW     ( 9                 ),
    .MAP_VW     ( 8                 ),
    .FLIP_HW    ( 9                 ),
    .FLIP_VW    ( 9                 ),
    .HJUMP      ( 1                 ),
    .XOR_HFLIP  ( 1                 )
) u_tx(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .hs         ( HS                ),
    .hdump      ( heff              ),
    .vdump      ( vdump             ),
    .flip       ( flip              ),
    .blankn     ( 1'b1              ),
    .scrx       ( tx_scrx_eff       ),
    .scry       ( tx_scry_eff       ),
    .vram_addr  ( tx_vaddr          ),
    .code       ( tx_vq[10:0]       ),
    .pal        ( tx_vq[15:11]      ),
    .hflip      ( 1'b0              ),
    .vflip      ( 1'b0              ),
    .rom_addr   ( char_addr         ),
    .rom_data   ( tx_data_3p        ),
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
    .ram_dout   ( obj_vq            ),
    .cpy_addr   ( objcpy_addr       ),
    .cpy_we     ( objcpy_we         ),
    .scan_addr  ( objscan_addr      ),
    .scan_dout  ( objscan_q         ),
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
    .pal_vq     ( pal_vq            ),
    .ioctl_ram  ( ioctl_ram         ),
    .ioctl_addr ( ioctl_addr        ),
    .ioctl_din  ( ioctl_din         ),
    .red        ( red               ),
    .green      ( green             ),
    .blue       ( blue              )
);

endmodule
