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
    Date: 7-3-2021 */

module jts16_video(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    input              video_en,
    input [7:0]        game_id,

    // CPU interface
    input              dip_pause,
    input              char_cs,
    input              pal_cs,
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
    input              colscr_en,
    input              rowscr_en,

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

localparam MODEL = `ifdef S16B 1; `else 0; `endif
localparam [8:0] OBJ_DLY = MODEL ? 9'd19 : 9'd15;

wire [ 8:0] hdump;
wire        preLHBL, preLVBL;
reg         alt_en, alt_objbank; // 171-5358 boards have a different GFX layout
wire        flipx;

// video layers
wire [11:0] obj_pxl;
wire [10:0] pal_addr;
wire        shadow;

always @(posedge clk) begin
    // Dunkshot, Sukeban and Time Scanner use a different
    // encoding for in tile map bytes.
    alt_en      <= MODEL && (game_id==8'h1b || game_id==8'h1c || game_id==8'h14);
    alt_objbank <= MODEL && game_id[4];
end

jts16_tilemap #(.MODEL(MODEL)) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .dip_pause  ( dip_pause ),
    .char_cs    ( char_cs   ),
    .pal_cs     ( pal_cs    ),
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .dswn       ( dsn       ),
    .char_dout  ( char_dout ),
    .vint       ( vint      ),

    // Other configuration
    .flip       ( flip      ),
    .ext_flip   ( ext_flip  ),
    .colscr_en  ( colscr_en ),
    .rowscr_en  ( rowscr_en ),
    .alt_en     ( alt_en    ),

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
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),
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
    .fix        (           ),
    .sa         (           ),
    .sb         (           )
);

jts16_obj #(.PXL_DLY(OBJ_DLY),.MODEL(MODEL)) u_obj(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .pxl_cen   ( pxl_cen        ),
    .alt_bank  ( alt_objbank    ),

    // CPU interface
    .cpu_obj_cs( objram_cs      ),
    .cpu_addr  ( cpu_addr[10:1] ),
    .cpu_dout  ( cpu_dout       ),
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
    .vrender   ( vrender        ), // using vdump here breaks WB3 title screen
    .hdump     ( hdump          ),
    .pxl       ( obj_pxl        ),
    .debug_bus ( debug_bus      )
);

jts16_colmix u_colmix(
    .rst       ( rst            ),
    .clk       ( clk            ),
    .pxl2_cen  ( pxl2_cen       ),
    .pxl_cen   ( pxl_cen        ),

    .video_en  ( video_en       ),

    .pal_addr  ( pal_addr       ),
    .shadow    ( shadow         ),
    // CPU interface
    .pal_cs    ( pal_cs         ),
    .cpu_addr  ( cpu_addr[11:1] ),
    .cpu_dout  ( cpu_dout       ),
    .dswn      ( dsn            ),
    .cpu_din   ( pal_dout       ),

    .preLVBL   ( preLVBL        ),
    .preLHBL   ( preLHBL        ),

    .LHBL      ( LHBL           ),
    .LVBL      ( LVBL           ),
    .red       ( red            ),
    .green     ( green          ),
    .blue      ( blue           )
);

endmodule