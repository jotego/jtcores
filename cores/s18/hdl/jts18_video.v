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
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    input              video_en,


    // CPU interface
    input              dip_pause,
    input              char_cs,
    input              objram_cs,
    input      [12:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dsn,

    output     [15:0]  char_dout,
    output     [15:0]  pal_dout,
    output     [15:0]  obj_dout,
    output             vint,

    // Other configuration
    input              flip,
    inout              ext_flip,

    // SDRAM interface
    input              char_ok,
    output     [13:2]  char_addr, // 9 addr + 3 vertical + 2 horizontal = 14 bits
    input      [31:0]  char_data,

    input              map1_ok,
    output     [15:1]  map1_addr, // 3 pages + 11 addr = 14 (32 kB)
    input      [15:0]  map1_data,

    input              scr1_ok,
    output     [17:2]  scr1_addr, // 1 bank + 12 addr + 3 vertical = 15 bits
    input      [31:0]  scr1_data,

    input              map2_ok,
    output     [15:1]  map2_addr, // 3 pages + 11 addr = 14 (32 kB)
    input      [15:0]  map2_data,

    input              scr2_ok,
    output     [17:2]  scr2_addr, // 1 bank + 12 addr + 3 vertical = 15 bits
    input      [31:0]  scr2_data,

    input              obj_ok,
    output             obj_cs,
    output     [19:0]  obj_addr,
    input      [15:0]  obj_data,

    // Video signal
    output             HS,
    output             VS,
    output             LHBL,
    output             LVBL,
    output             hstart,
    output     [ 8:0]  vdump,
    output     [ 8:0]  vrender,
    output     [ 4:0]  red,
    output     [ 4:0]  green,
    output     [ 4:0]  blue,

    // Debug
    input      [ 3:0]  gfx_en,
    input      [ 7:0]  debug_bus,
    // status dump
    input      [ 7:0]  st_addr,
    output     [ 7:0]  st_dout,
    output             scr_bad
);

wire [5:0] r16, g16, b16;

jts18_video16 u_video16(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .video_en   ( video_en  ),

    // CPU interface
    .dip_pause  ( dip_pause ),
    .char_cs    ( char_cs   ),
    .objram_cs  ( objram_cs ),
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .dsn        ( dsn       ),

    output     [15:0]  char_dout,
    output     [15:0]  pal_dout,
    output     [15:0]  obj_dout,
    output             vint,

    // Other configuration
    input              flip,
    inout              ext_flip,

    // SDRAM interface
    input              char_ok,
    output     [13:2]  char_addr, // 9 addr + 3 vertical + 2 horizontal = 14 bits
    input      [31:0]  char_data,

    .map1_ok        ( map1_ok       ),
    .map1_addr      ( map1_addr     ), // 3 pages + 11 addr = 14 (32 kB)
    .map1_data      ( map1_data     ),

    .scr1_ok        ( scr1_ok       ),
    .scr1_addr      ( scr1_addr     ), // 1 bank + 12 addr + 3 vertical = 15 bits
    .scr1_data      ( scr1_data     ),

    .map2_ok        ( map2_ok       ),
    .map2_addr      ( map2_addr     ), // 3 pages + 11 addr = 14 (32 kB)
    .map2_data      ( map2_data     ),

    .scr2_ok        ( scr2_ok       ),
    .scr2_addr      ( scr2_addr     ), // 1 bank + 12 addr + 3 vertical = 15 bits
    .scr2_data      ( scr2_data     ),

    input              obj_ok,
    output             obj_cs,
    output     [19:0]  obj_addr,
    input      [15:0]  obj_data,

    // Video signal
    output             HS,
    output             VS,
    output             LHBL,
    output             LVBL,
    output             hstart,
    output     [ 8:0]  vdump,
    output     [ 8:0]  vrender,
    .red            ( r16           ),
    .green          ( g16           ),
    .blue           ( b16           ),

    // Debug
    .gfx_en         ( gfx_en        ),
    .debug_bus      ( debug_bus     ),
    // status dump
    .st_addr        ( st_addr       ),
    .st_dout        (               ),
    .scr_bad        (               )
);

endmodule