/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-12-2022 */

// wrapper for jtframe_objdraw_gate that hides the
// buffer data ports (buf_pred and buf_din that let
// the core modify the data before storing it)

module jtframe_objdraw #( parameter
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