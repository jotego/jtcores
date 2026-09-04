/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-4-2022 */

module jtrastan_video(
    input           rst,
    input           clk,
    input           opwolf,
    input           rbisland,
    output          pxl_cen,
    output          pxl2_cen,

    output          HS,
    output          VS,
    output          LHBL,
    output          LVBL,
    output          flip,

    input    [18:1] main_addr,
    input    [15:0] main_dout,
    input    [ 1:0] main_dsn,
    input           main_rnw,
    input           scr_cs,
    input           obj_cs,
    input    [ 2:0] obj_pal,
    output          sdakn,
    output          odakn,

    input    [ 4:0] ioctl_addr,
    output   [ 7:0] ioctl_din,

    output   [12:1] objram_addr,
    input    [15:0] objram_dout,
    output   [11:1] palram_addr,
    input    [15:0] palram_video_data,

`ifdef RASTAN_SCRRAM_SDRAM
    output   [15:2] ram0_addr,
    input    [31:0] ram0_data,
    input           ram0_ok,
    output          ram0_cs,
    output   [15:2] ram1_addr,
    input    [31:0] ram1_data,
    input           ram1_ok,
    output          ram1_cs,
`else
    output   [15:2] ram_addr,
    input    [31:0] ram_data,
`endif

    output   [19:2] rom0_addr,
    input    [31:0] rom0_data,
    input           rom0_ok,
    output          rom0_cs,

    output   [19:2] rom1_addr,
    input    [31:0] rom1_data,
    input           rom1_ok,
    output          rom1_cs,

    output   [19:2] orom_addr,
    input    [31:0] orom_data,
    input           orom_ok,
    output          orom_cs,

    output    [4:0] red,
    output    [4:0] green,
    output    [4:0] blue,

    input     [3:0] gfx_en,
    input     [7:0] debug_bus,
    output   [ 7:0] debug_view
);

wire        preLHBL, preLVBL;
wire [10:0] scr1_pxl, scr0_pxl;
wire [ 7:0] obj_pxl;
wire [ 8:0] hdump, vrender;
wire [31:0] scr0rom_data, scr1rom_data, objrom_data;

// Operation Wolf graphics ROMs use ROM_LOAD16_WORD_SWAP, whereas Rastan's
// paired byte ROMs already arrive in the native renderer order.
assign scr0rom_data = opwolf ? {rom0_data[23:16],rom0_data[31:24],
                                rom0_data[ 7: 0],rom0_data[15: 8]} : rom0_data;
assign scr1rom_data = opwolf ? {rom1_data[23:16],rom1_data[31:24],
                                rom1_data[ 7: 0],rom1_data[15: 8]} : rom1_data;
assign objrom_data  = opwolf ? {orom_data[23:16],orom_data[31:24],
                                orom_data[ 7: 0],orom_data[15: 8]} : orom_data;

jtrastan_scr u_scr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),

    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( preLHBL   ),
    .LVBL       ( preLVBL   ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .vrender    ( vrender   ),

    .main_addr  ( main_addr ),
    .main_dout  ( main_dout ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .scr_cs     ( scr_cs    ),        // selection from address decoder
    .dtackn     ( sdakn     ),

    .ioctl_addr ( ioctl_addr ),
    .ioctl_din  ( ioctl_din  ),

`ifdef RASTAN_SCRRAM_SDRAM
    .ram0_addr  ( ram0_addr ),
    .ram0_data  ( ram0_data ),
    .ram0_ok    ( ram0_ok   ),
    .ram0_cs    ( ram0_cs   ),
    .ram1_addr  ( ram1_addr ),
    .ram1_data  ( ram1_data ),
    .ram1_ok    ( ram1_ok   ),
    .ram1_cs    ( ram1_cs   ),
`else
    .ram_addr   ( ram_addr  ),
    .ram_data   ( ram_data  ),
`endif

    .rom0_addr  ( rom0_addr ),
    .rom0_data  ( scr0rom_data ),
    .rom0_ok    ( rom0_ok   ),
    .rom0_cs    ( rom0_cs   ),

    .rom1_addr  ( rom1_addr ),
    .rom1_data  ( scr1rom_data ),
    .rom1_ok    ( rom1_ok   ),
    .rom1_cs    ( rom1_cs   ),

    .scr1_pxl   ( scr1_pxl  ),
    .scr0_pxl   ( scr0_pxl  ),
    .debug_bus  ( debug_bus ),
    .debug_view ( debug_view)
);

jtrastan_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .HS         ( HS        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),
    .vrender    ( vrender   ),

    .ram_addr   ( objram_addr ),
    .ram_data   ( objram_dout ),
    .dtackn     ( odakn     ),

    .rom_addr   ( orom_addr ),
    .rom_data   ( objrom_data ),
    .rom_cs     ( orom_cs   ),
    .rom_ok     ( orom_ok   ),
    .pxl        ( obj_pxl   ),
    .debug_bus  ( debug_bus )
);

jtrastan_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .opwolf     ( opwolf    ),
    .rbisland   ( rbisland  ),

    .palram_addr( palram_addr ),
    .palram_video_data( palram_video_data ),

    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),

    .scr0_pxl   ( scr0_pxl  ),
    .scr1_pxl   ( scr1_pxl  ),
    .obj_pxl    ( obj_pxl   ),
    .obj_pal    ( obj_pal   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),

    .gfx_en     ( gfx_en    )
);

endmodule
