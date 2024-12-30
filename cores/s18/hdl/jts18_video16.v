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

// 315-5361/2 video subsystem
// equivalent to System 16B 
// same palette and DAC logic as Super Hang-On

module jts18_video16(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    input              video_en,
    input              gray_n,

    // CPU interface
    input              dip_pause,
    input              char_cs,
    input              objram_cs,
    input      [12:1]  addr,
    input      [15:0]  din,
    input      [ 1:0]  dsn,

    output     [15:0]  char_dout,
    output     [15:0]  obj_dout,
    output             vint,

    // Other configuration
    input              flip,

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
    output     [20:1]  obj_addr,
    input      [15:0]  obj_data,

    // Video signal
    output             HS,
    output             VS,
    output             LHBL,
    output             LVBL,
    output     [ 8:0]  hdump,
    output     [ 8:0]  vdump,
    output     [ 8:0]  vrender,
    output     [ 5:0]  red,
    output     [ 5:0]  green,
    output     [ 5:0]  blue,

    // priority bits
    output     [ 1:0]  obj_prio,
    output             fix, sa, sb, tprio, s1_pri, s2_pri,
    // palette RAM
    output     [11:1]  pal_addr,
    input      [15:0]  pal_dout,
    // Debug
    input      [ 3:0]  gfx_en,
    input      [ 7:0]  debug_bus,
    // status dump
    input      [ 7:0]  st_addr,
    output     [ 7:0]  st_dout,
    output             scr_bad
);

localparam MODEL=1;
localparam [9:0] ROWSCR_DLY=10'd17;

// video layers
wire [11:0] obj_pxl;
wire [ 4:0] rpal, gpal, bpal;
wire        shadow, hstart, flipx;

assign rpal  = { pal_dout[ 3:0], pal_dout[12] };
assign gpal  = { pal_dout[ 7:4], pal_dout[13] };
assign bpal  = { pal_dout[11:8], pal_dout[14] };
assign obj_prio = obj_pxl[11:10];

jts16_tilemap #(.MODEL(MODEL),.HS_END(9'hA0),
    .SCR2_DLY(10'd9),.SCR1_DLY(10'd9),
    .ROWSCR1_DLY(ROWSCR_DLY),.ROWSCR2_DLY(ROWSCR_DLY)
    ) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .dip_pause  ( dip_pause ),
    .char_cs    ( char_cs   ),
    .cpu_addr   ( addr      ),
    .cpu_dout   ( din       ),
    .dswn       ( dsn       ),
    .char_dout  ( char_dout ),
    .vint       ( vint      ),

    // Other configuration
    .flip       ( flip      ),
    .ext_flip   (           ),
    .colscr_en  ( 1'b0      ),
    .rowscr_en  ( 1'b0      ),
    .alt_en     ( 1'b0      ),

    // SDRAM interface
    .char_ok    ( char_ok   ),
    .char_addr  ( char_addr ),
    .char_data  ( char_data ),
    .map1_ok    ( map1_ok   ),
    .map1_addr  ( map1_addr ),
    .map1_data  ( map1_data ),
    .scr1_ok    ( scr1_ok   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),
    .map2_ok    ( map2_ok   ),
    .map2_addr  ( map2_addr ),
    .map2_data  ( map2_data ),
    .scr2_ok    ( scr2_ok   ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data ),

    // Video signal
    .HS         ( HS        ),
    .VS         ( VS        ),
    .preLHBL    ( LHBL      ),
    .preLVBL    ( LVBL      ),
    .hstart     ( hstart    ),
    .flipx      ( flipx     ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .hdump      ( hdump     ),
    // Video layers
    .obj_pxl    ( obj_pxl   ),
    .pal_addr   ( pal_addr  ),
    .shadow     ( shadow    ),
    .set_fix    ( 1'b0      ),
    // Debug
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_addr    ( st_addr   ),
    .st_dout    ( st_dout   ),
    .scr_bad    ( scr_bad   ),
    // Active layer
    .fix        ( fix       ),
    .sa         (  sa       ),
    .sb         (  sb       ),
    .tprio      ( tprio     ),
    .s1_pri     ( s1_pri    ),
    .s2_pri     ( s2_pri    )
);

jts16_obj #(.MODEL(MODEL)) u_obj(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .pxl_cen   ( pxl_cen        ),
    .alt_bank  ( 1'b0           ),

    // CPU interface
    .cpu_obj_cs( objram_cs      ),
    .cpu_addr  ( addr[10:1]     ),
    .cpu_dout  ( din            ),
    .dswn      ( dsn            ),
    .cpu_din   ( obj_dout       ),

    // SDRAM interface
    .obj_ok    ( obj_ok         ),
    .obj_cs    ( obj_cs         ),
    .obj_addr  ( obj_addr       ), // 9 addr + 3 vertical = 12 bits
    .obj_data  ( obj_data       ),

    // Video signal
    .hstart    ( hstart         ),
    .hsn       ( ~HS            ),
    .flip      ( flipx          ),
    .vrender   ( MODEL==1 ? vrender : vdump ), // using vdump here breaks WB3 title screen
    .hdump     ( hdump          ),
    .pxl       ( obj_pxl        ),
    .debug_bus ( debug_bus      )
);

// Model of 315-5242 DAC
jtshanon_coldac u_dac(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .rin        ( rpal      ),
    .gin        ( gpal      ),
    .bin        ( bpal      ),
    .sh         ( shadow    ),
    .en         ( video_en  ),
    .gray_n     ( gray_n    ),
    .hilo       (pal_dout[15]),
    .rout       ( red       ),
    .gout       ( green     ),
    .bout       ( blue      )
);

endmodule