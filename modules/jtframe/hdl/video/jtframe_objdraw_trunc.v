/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-3-2024 */

// wrapper for jtframe_objdraw_gate that hides the
// buffer data ports (buf_pred and buf_din that let
// the core modify the data before storing it)
// object width is 16, 8 or 4 pixels

module jtframe_objdraw_trunc #( parameter
    CW    = 12,
    PW    =  8,
    ZW    =  6,
    ZI    = ZW-1,
    ZENLARGE= 0,
    SWAPH =  0,
    HJUMP =  0,
    LATCH =  0,
    FLIP_OFFSET=0,
    KEEP_OLD  = 0,
    SHADOW    = 0,
    ALPHA     = 0,
    PACKED    = 0
)(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               hs,
    input               flip,
    input        [ 8:0] hdump,
    input        [ 1:0] trunc,

    input               draw,
    output              busy,
    input    [CW-1:0]   code,
    input      [ 8:0]   xpos,
    input      [ 3:0]   ysub,
    // optional zoom, keep at zero for no zoom
    input    [ZW-1:0]   hzoom,
    input               hz_keep, // set at 1 for the first tile

    input               hflip,
    input               vflip,
    input      [PW-5:0] pal,

    output     [CW+6:2] rom_addr, // {code,H,Y}
    output              rom_cs,
    input               rom_ok,
    input      [31:0]   rom_data,

    output     [PW-1:0] pxl
);

    wire [PW-1:0] buf_d;

    jtframe_objdraw_gate #(
        .CW             ( CW            ),
        .PW             ( PW            ),
        .ZW             ( ZW            ),
        .ZI             ( ZI            ),
        .ZENLARGE       ( ZENLARGE      ),
        .SWAPH          ( SWAPH         ),
        .HJUMP          ( HJUMP         ),
        .LATCH          ( LATCH         ),
        .FLIP_OFFSET    ( FLIP_OFFSET   ),
        .SHADOW         ( SHADOW        ),
        .KEEP_OLD       ( KEEP_OLD      ),
        .ALPHA          ( ALPHA         ),
        .PACKED         ( PACKED        )
    )u_gate(
        .rst            ( rst           ),
        .clk            ( clk           ),
        .pxl_cen        ( pxl_cen       ),
        .hs             ( hs            ),
        .flip           ( flip          ),
        .hdump          ( hdump         ),
        .draw           ( draw          ),
        .busy           ( busy          ),
        .code           ( code          ),
        .xpos           ( xpos          ),
        .ysub           ( ysub          ),
        .trunc          ( trunc         ),
        .hzoom          ( hzoom         ),
        .hz_keep        ( hz_keep       ),
        .hflip          ( hflip         ),
        .vflip          ( vflip         ),
        .pal            ( pal           ),
        .rom_addr       ( rom_addr      ),
        .rom_cs         ( rom_cs        ),
        .rom_ok         ( rom_ok        ),
        .rom_data       ( rom_data      ),

        .buf_pred       ( buf_d         ),
        .buf_din        ( buf_d         ),

        .pxl            ( pxl           )
    );

endmodule