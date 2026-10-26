/*  SPDX-FileCopyrightText: © 2026 Andrea Bogazzi
    SPDX-License-Identifier: GPL-3.0-or-later
    Date: 25-10-2026 */

module jtf1gpr2_obj #(parameter ATTR_AW=11, LUT_AW=14, ROM_AW=21)(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
    input               flip,
    input      [ 8:0]   hdump, vrender,
    input      [ 8:0]   hsize, vsize,

    output     [ATTR_AW:1] objr_addr,
    input      [15:0]   objr_dout,
    output     [LUT_AW:1] objl_addr,
    input      [15:0]   objl_dout,

    output     [ROM_AW-1:2] rom_addr,
    output              rom_cs,
    input      [31:0]   rom_data,
    input               rom_ok,

    output     [10:0]   pxl
);

wire [21:2] draw_addr;
wire [14:0] code;
wire [ 8:0] xpos;
wire [ 7:0] hzoom;
wire [ 6:0] pal;
wire [ 3:0] ysub;
wire        draw, busy, hz_keep, hflip, vflip;

wire [ 8:0] hdump_eff = flip ? ~hdump   + hsize : hdump;
wire [ 8:0] vrend_eff = flip ? ~vrender + vsize  : vrender;

assign rom_addr = { draw_addr[ROM_AW-1:7], draw_addr[5:2], draw_addr[6] };

jtf1gpr2_objscan #(
    .ATTR_AW    ( ATTR_AW   ),
    .LUT_AW     ( LUT_AW    )
) u_scan(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .hs         ( hs        ),
    .vrender    ( vrend_eff ),
    .xoffs      ( 9'd0      ),
    .yoffs      ( 9'd0      ),
    .flip       ( flip      ),

    .objr_addr  ( objr_addr ),
    .objr_dout  ( objr_dout ),
    .objl_addr  ( objl_addr ),
    .objl_dout  ( objl_dout ),

    .draw       ( draw      ),
    .busy       ( busy      ),
    .code       ( code      ),
    .xpos       ( xpos      ),
    .ysub       ( ysub      ),
    .hzoom      ( hzoom     ),
    .hz_keep    ( hz_keep   ),
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       )
);

jtframe_objdraw #(
    .CW         ( 15        ),
    .PW         ( 11        ),
    .ZW         ( 8         ),
    .ZI         ( 6         ),
    .ZENLARGE   ( 1         ),
    .HJUMP      ( 0         ),
    .HFIX       ( 0         ),
    .LATCH      ( 1         ),
    .ALPHA      ( 15        ),
    .PACKED     ( 1         )
) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( 1'b0      ),
    .hdump      ( hdump_eff ),

    .draw       ( draw      ),
    .busy       ( busy      ),
    .code       ( code      ),
    .xpos       ( xpos      ),
    .ysub       ( ysub      ),
    .hzoom      ( hzoom     ),
    .hz_keep    ( hz_keep   ),

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( pal       ),

    .rom_addr   ( draw_addr ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( rom_data  ),

    .pxl        ( pxl       )
);

endmodule
