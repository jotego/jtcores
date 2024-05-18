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
    Date: 29-4-2024 */

module jts18_video(
    input              rst,
    input              clk96,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    // video configuration
    input              flip,
    inout              ext_flip,
    input              vdp_en,
    input              vid16_en,
    input              gray_n,
    input      [ 7:0]  tile_bank,
    output     [ 8:0]  vrender,

    // CPU interface
    input              dip_pause,
    input              char_cs,
    input              objram_cs,
    input      [23:1]  addr,
    input      [15:0]  din,
    input      [ 1:0]  dsn,
    input              rnw,
    input              asn,
    output             vdp_dtackn,

    output     [15:0]  char_dout,
    output     [15:0]  obj_dout,
    output     [15:0]  vdp_dout,
    output             vint,

    // palette RAM
    output     [10:0]  pal_addr,
    input      [15:0]  pal_dout,

    // SDRAM interface
    input              char_ok,
    output     [13:2]  char_addr, // 9 addr + 3 vertical + 2 horizontal = 14 bits
    input      [31:0]  char_data,

    input              map1_ok,
    output     [15:1]  map1_addr, // 3 pages + 11 addr = 14 (32 kB)
    input      [15:0]  map1_data,

    input              scr1_ok,
    output     [21:2]  scr1_addr, // 1 bank + 12 addr + 3 vertical = 15 bits
    input      [31:0]  scr1_data,

    input              map2_ok,
    output     [15:1]  map2_addr, // 3 pages + 11 addr = 14 (32 kB)
    input      [15:0]  map2_data,

    input              scr2_ok,
    output     [21:2]  scr2_addr, // 1 bank + 12 addr + 3 vertical = 15 bits
    input      [31:0]  scr2_data,

    input              obj_ok,
    output             obj_cs,
    output     [20:1]  obj_addr,
    input      [15:0]  obj_data,

    // Video signal
    output             HS,
    output             VS,
    output             LHBL,
    output             LVBL,
    output     [ 7:0]  red,
    output     [ 7:0]  green,
    output     [ 7:0]  blue,

    // Debug
    input      [ 3:0]  gfx_en,
    input      [ 7:0]  debug_bus,
    // status dump
    input      [ 7:0]  st_addr,
    output     [ 7:0]  st_dout
);

wire [5:0] s16_r, s16_g, s16_b;
wire [7:0] vdp_r, vdp_g, vdp_b;
wire [7:0] st_s16, st_vdp;
wire       LHBL_dly, LVBL_dly, scr1_sel, scr2_sel;

assign st_dout = st_vdp;
assign scr1_addr[21]=0;
assign scr2_addr[21]=0;
assign scr1_addr[20-:4] = scr1_sel ? tile_bank[7:4] : tile_bank[3:0];
assign scr2_addr[20-:4] = scr2_sel ? tile_bank[7:4] : tile_bank[3:0];
/* verilator tracing_off */
jts18_video16 u_video16(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .video_en   ( vid16_en  ),
    .flip       ( flip      ),
    .gray_n     ( gray_n    ),

    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),
    // CPU interface
    .dip_pause  ( dip_pause ),
    .char_cs    ( char_cs   ),
    .objram_cs  ( objram_cs ),
    .addr       ( addr[12:1]),
    .din        ( din       ),
    .dsn        ( dsn | {2{rnw}}),

    .char_dout  ( char_dout ),
    .obj_dout   ( obj_dout  ),
    .vint       ( vint      ),

    // SDRAM interface
    .char_ok    ( char_ok   ),
    .char_addr  ( char_addr ), // 9 addr + 3 vertical + 2 horizontal = 14 bits
    .char_data  ( char_data ),

    .map1_ok    ( map1_ok   ),
    .map1_addr  ( map1_addr ), // 3 pages + 11 addr = 14 (32 kB)
    .map1_data  ( map1_data ),

    .scr1_ok    ( scr1_ok   ),
    .scr1_addr  ({scr1_sel,scr1_addr[16:2]}), // 1 bank + 12 addr + 3 vertical = 15 bits
    .scr1_data  ( scr1_data ),

    .map2_ok    ( map2_ok   ),
    .map2_addr  ( map2_addr ), // 3 pages + 11 addr = 14 (32 kB)
    .map2_data  ( map2_data ),

    .scr2_ok    ( scr2_ok   ),
    .scr2_addr  ({scr2_sel,scr2_addr[16:2]}), // 1 bank + 12 addr + 3 vertical = 15 bits
    .scr2_data  ( scr2_data ),

    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    // Video signal
    .HS         ( HS        ),
    .VS         ( VS        ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .vdump      (           ),
    .vrender    ( vrender   ),
    .red        ( s16_r     ),
    .green      ( s16_g     ),
    .blue       ( s16_b     ),

    // Debug
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    // status dump
    .st_addr    ( st_addr   ),
    .st_dout    ( st_s16    ),
    .scr_bad    (           )
);
/* verilator tracing_on */
// Megadrive VDP
jts18_vdp u_vdp(
    .rst        ( rst       ),
    .clk96      ( clk96     ),
    .clk48      ( clk       ),

    // Main CPU interface
    .addr       ( addr      ),
    .din        ( din       ),
    .dout       ( vdp_dout  ),
    .rnw        ( rnw       ),
    .asn        ( asn       ),
    .dsn        ( dsn       ),
    .dtackn     ( vdp_dtackn),
    // Video output
    .hs         (           ),
    .vs         (           ),
    .red        ( vdp_r     ),
    .green      ( vdp_g     ),
    .blue       ( vdp_b     ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_vdp    )
);
/* verilator tracing_off */
jts18_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .LHBL_dly   ( LHBL_dly  ),
    .LVBL_dly   ( LVBL_dly  ),
    .gfx_en     ( gfx_en    ),
    .s16_r      ( s16_r     ),
    .s16_g      ( s16_g     ),
    .s16_b      ( s16_b     ),
    .vdp_r      ( vdp_r     ),
    .vdp_g      ( vdp_g     ),
    .vdp_b      ( vdp_b     ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule