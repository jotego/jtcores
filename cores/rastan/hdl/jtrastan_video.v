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
    Date: 2-4-2022 */

module jtrastan_video(
    input           rst,
    input           clk,
    output          pxl_cen,
    output          pxl2_cen,

    output          HS,
    output          VS,
    output          LHBL,
    output          LVBL,
    output          flip,

    input    [18:1] main_addr,
    input    [15:0] main_dout,
    output   [15:0] oram_dout,
    output   [15:0] pal_dout,
    input    [ 1:0] main_dsn,
    input           main_rnw,
    input           scr_cs,
    input           pal_cs,
    input           obj_cs,
    input    [ 2:0] obj_pal,
    output          sdakn,
    output          odakn,

    output   [15:2] ram0_addr,
    input    [31:0] ram0_data,
    input           ram0_ok,
    output          ram0_cs,

    output   [19:2] rom0_addr,
    input    [31:0] rom0_data,
    input           rom0_ok,
    output          rom0_cs,

    output   [15:2] ram1_addr,
    input    [31:0] ram1_data,
    input           ram1_ok,
    output          ram1_cs,

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
    output   [ 7:0] debug_view,
    // NVRAM (debug) dump
    input    [10:0] ioctl_addr,
    output   [ 7:0] ioctl_din,
    input           ioctl_ram
);

wire        preLHBL, preLVBL;
wire [10:0] scr1_pxl, scr0_pxl;
wire [ 7:0] obj_pxl;
wire [ 8:0] hdump, vrender;

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

    .ram0_addr  ( ram0_addr ),
    .ram0_data  ( ram0_data ),
    .ram0_ok    ( ram0_ok   ),
    .ram0_cs    ( ram0_cs   ),

    .rom0_addr  ( rom0_addr ),
    .rom0_data  ( rom0_data ),
    .rom0_ok    ( rom0_ok   ),
    .rom0_cs    ( rom0_cs   ),

    .ram1_addr  ( ram1_addr ),
    .ram1_data  ( ram1_data ),
    .ram1_ok    ( ram1_ok   ),
    .ram1_cs    ( ram1_cs   ),

    .rom1_addr  ( rom1_addr ),
    .rom1_data  ( rom1_data ),
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

    .main_addr  ( main_addr[10:1] ),
    .main_dout  ( main_dout ),
    .main_din   ( oram_dout ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .obj_cs     ( obj_cs    ),        // selection from address decoder
    .dtackn     ( odakn     ),

    .rom_addr   ( orom_addr ),
    .rom_data   ( orom_data ),
    .rom_cs     ( orom_cs   ),
    .rom_ok     ( orom_ok   ),
    .pxl        ( obj_pxl   ),
    // Debug
    .debug_bus  ( debug_bus ),
    .ioctl_ram  ( ioctl_ram ),
    .ioctl_addr ( ioctl_addr),
    .ioctl_din  ( ioctl_din )
);

jtrastan_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .main_addr  ( main_addr[11:1] ),
    .main_dout  ( main_dout ),
    .main_dsn   ( main_dsn  ),
    .main_din   ( pal_dout  ),
    .main_rnw   ( main_rnw  ),
    .pal_cs     ( pal_cs    ),        // selection from address decoder

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