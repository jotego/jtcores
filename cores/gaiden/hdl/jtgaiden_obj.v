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
    Date: 2-1-2025 */

module jtgaiden_obj(
    input               rst,
    input               clk,
    input               pxl_cen,
    input               flip,
    input               blankn,
    input        [ 1:0] frmbuf_en,
    input               objdly, vsize_en,

    input               lvbl,
    input               hs,
    input        [ 8:0] hdump,
    input        [ 8:0] vrender,
    input        [ 7:0] scry,

    output       [12:1] ram_addr,
    input        [15:0] ram_dout,

    output              rom_cs,
    output       [19:2] rom_addr,
    input        [31:0] rom_data,
    input               rom_ok,

    output       [10:0] pxl,
    input        [ 7:0] debug_bus
);

localparam [8:0] HOFFSET=9;
localparam       PXLW=11,CW=13;

wire   [CW+6:2] raw_addr;
wire [PXLW-1:0] pre_pxl,dly_pxl,slow_pxl;

wire          hflip, vflip, blend, dr_draw, dr_busy;
wire   [ 8:0] hpos;
wire   [12:0] code;
wire   [31:0] sorted;
wire   [ 3:0] pal;
wire   [ 1:0] size, prio;
wire   [ 3:0] ysub;
wire   [ 6:0] attr;

assign attr     = {prio,blend,pal};

jtframe_8x8x4_packed_msb u_conv(
    .raw    ( rom_data  ),
    .sorted ( sorted    )
);

jtgaiden_objscan u_scan(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .flip       ( flip      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .blankn     ( blankn    ),
    .frmbuf_en  ( frmbuf_en ),
    .vsize_en   ( vsize_en  ),

    .scry       ( scry      ),
    .vrender    ( vrender   ),

    // Look-up table
    .ram_addr   ( ram_addr  ),
    .ram_dout   ( ram_dout  ),
    // rom address translation
    .raw_addr   ( raw_addr  ),
    .rom_addr   ( rom_addr  ),
    // draw attributes and control
    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .ysub       ( ysub      ),
    .code       ( code      ),
    .pal        ( pal       ),
    .blend      ( blend     ),
    .size       ( size      ),
    .hpos       ( hpos      ),
    .prio       ( prio      ),
    .dr_draw    ( dr_draw   ),
    .dr_busy    ( dr_busy   ),
    .debug_bus  ( debug_bus )
);

jtframe_objdraw #(.CW(CW),.PW(PXLW),.LATCH(1),.HFIX(0)) u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .flip       ( flip      ),
    .hdump      ( hdump     ),

    .draw       ( dr_draw   ),
    .busy       ( dr_busy   ),
    .code       ( code      ),
    .xpos       ( hpos      ),
    .ysub       ( ysub      ),
    // optional zoom, keep at zero for no zoom
    .hzoom      ( 6'd0      ),
    .hz_keep    ( 1'b0      ), // set at 1 for the first tile

    .hflip      ( hflip     ),
    .vflip      ( vflip     ),
    .pal        ( attr      ),

    .rom_addr   ( raw_addr  ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .rom_data   ( sorted    ),

    .pxl        ( pre_pxl   )
);

jtframe_sh #(.W(PXLW),.L(HOFFSET)) u_sh(
    .clk    ( clk       ),
    .clk_en ( pxl_cen   ),
    .din    ( pre_pxl   ),
    .drop   ( dly_pxl   )
);

jtframe_sh #(.W(PXLW),.L(1)) u_sh2(
    .clk    ( clk       ),
    .clk_en ( pxl_cen   ),
    .din    ( dly_pxl   ),
    .drop   ( slow_pxl  )
);

assign pxl = objdly ? slow_pxl : dly_pxl;

endmodule