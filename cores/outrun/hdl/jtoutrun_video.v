/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 10-7-2022 */

module jtoutrun_video(
    input              rst,
    input              clk,
    input              pxl2_cen,  // pixel clock enable (2x)
    input              pxl_cen,   // pixel clock enable

    input              video_en,
    input              obj_swap,
    // input [1:0]        game_id,

    // CPU interface
    input              dip_pause,
    input              char_cs,
    input              pal_cs,
    input              objram_cs,
    input              road_cs,
    input              sub_io_cs,
    input      [13:1]  cpu_addr,
    input      [11:1]  sub_addr,
    input      [15:0]  cpu_dout,
    input      [15:0]  sub_dout,
    input      [ 1:0]  main_dswn,
    input      [ 1:0]  sub_dsn,
    input              sub_rnw,

    output     [15:0]  char_dout,
    output     [15:0]  pal_dout,
    output     [15:0]  obj_dout,
    output     [15:0]  road_dout,
    output             vint,
    output reg         line_intn,

    // Other configuration
    input              flip,
    inout              ext_flip,

    // SDRAM interface
    input              char_ok,
    output     [13:2]  char_addr,
    input      [31:0]  char_data,

    input              map1_ok,
    output     [15:1]  map1_addr,
    input      [15:0]  map1_data,

    input              scr1_ok,
    output     [17:2]  scr1_addr,
    input      [31:0]  scr1_data,

    input              map2_ok,
    output     [15:1]  map2_addr,
    input      [15:0]  map2_data,

    input              scr2_ok,
    output     [17:2]  scr2_addr,
    input      [31:0]  scr2_data,

    input              obj_ok,
    output             obj_cs,
`ifdef SHANON
    output     [19:1]  obj_addr,
    input      [15:0]  obj_data,
`else
    output     [19:2]  obj_addr,
    input      [31:0]  obj_data,
`endif

    output      [14:1] rd0_addr,
    input       [15:0] rd0_data,
    output             rd0_cs,
    input              rd0_ok,

    output      [14:1] rd1_addr,
    input       [15:0] rd1_data,
    output             rd1_cs,
    input              rd1_ok,

    // Video signal
    output             HS,
    output             VS,
    output             LHBL,
    output             LVBL,
    output             hstart,
    output     [ 8:0]  hdump,
    output     [ 8:0]  vdump,
    output     [ 8:0]  vrender,
    output     [ 4:0]  red,
    output     [ 4:0]  green,
    output     [ 4:0]  blue,

`ifdef JTFRAME_LF_BUFFER
    output     [ 8:0]  ln_addr,
    output     [15:0]  ln_data,
    output             ln_done,
    input              ln_hs,
    input      [15:0]  ln_pxl,
    input      [ 7:0]  ln_v,
    output             ln_we,
`endif
    // Debug
    input      [ 3:0]  gfx_en,
    input      [ 7:0]  debug_bus,
    // status dump
    input      [ 7:0]  st_addr,
    output reg [ 7:0]  st_dout,
    output             scr_bad,
    // SD card dumps
    input      [21:0]  ioctl_addr,
    input              ioctl_ram,
    output reg [ 7:0]  ioctl_din,
    // Get some random data during start-up for the palette
    input      [21:0]  prog_addr,
    input      [ 7:0]  prog_data,
    input              prog_we
);

wire        preLHBL, preLVBL;
wire        flipx;
wire        sa, sb, fix;

// SD card dump
wire [ 7:0] pal_dump, road_dump, obj_dump;

// video layers
wire [ 4:3] rc;
wire [ 7:0] rd_pxl;
wire [10:0] tmap_addr;
wire        shadow;
wire [ 7:0] st_tile, st_obj, st_road;
wire [11:0] obj2tile;   // object pixel going into the tile mapper
`ifdef SHANON
wire [11:0] obj_pxl;

assign obj2tile = obj_pxl;
`else
wire [13:0] obj_pxl;

assign obj2tile = { obj_pxl[5:4], {2{obj_pxl[6]}}, {2{obj_pxl[3:0]}}^8'h50 }; // schematics video 1/7
`endif

always @* begin
    case( ioctl_addr[15:12] )
        0,1: ioctl_din = pal_dump;  // first 8kB of pal RAM dumped
        1,2: ioctl_din = road_dump; // 8 kB
        3:   ioctl_din = obj_dump;
        default: ioctl_din = 0;
    endcase
end

always @(posedge clk) begin
    case(st_addr[5:4])
        0: st_dout <= st_tile;
        1: st_dout <= st_obj;
        2: st_dout <= st_road;
    endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        line_intn <= 1;
    end else begin
        line_intn <= !(vdump==64 || vdump==128 || vdump==192);
    end
end

jtoutrun_road u_road(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .v          ( vdump     ),
    .vint       ( vint      ),

    // CPU interface
    .cpu_addr   ( sub_addr  ),
    .cpu_dout   ( sub_dout  ),
    .cpu_din    ( road_dout ),
    .cpu_dsn    ( sub_dsn   ),
    .cpu_rnw    ( sub_rnw   ),
    .road_cs    ( road_cs   ),
    .io_cs      ( sub_io_cs ),

    // ROMs
    .rom0_cs    ( rd0_cs    ),
    .rom0_ok    ( rd0_ok    ),
    .rom0_addr  ( rd0_addr  ),
    .rom0_data  ( rd0_data  ),

    .rom1_addr  ( rd1_addr  ),
    .rom1_data  ( rd1_data  ),
    .rom1_cs    ( rd1_cs    ),
    .rom1_ok    ( rd1_ok    ),

    .pxl        ( rd_pxl    ),
    .rc         ( rc        ),
    .debug_bus  ( debug_bus ),

    .st_addr    ( st_addr   ),
    .st_dout    ( st_road   ),

    .ioctl_ram  ( ioctl_ram  ),
    .ioctl_din  ( road_dump  ),
    .ioctl_addr ( ioctl_addr )
);

jts16_tilemap #(.MODEL(1)) u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),

    .dip_pause  ( dip_pause ),
    .char_cs    ( char_cs   ),
    .pal_cs     ( pal_cs    ),
    .cpu_addr   ( cpu_addr[12:1] ),
    .cpu_dout   ( cpu_dout  ),
    .dswn       ( main_dswn ),
    .char_dout  ( char_dout ),
    .vint       ( vint      ),

    // Other configuration
    .flip       ( flip      ),
    .ext_flip   ( ext_flip  ),
    .colscr_en  ( 1'b0      ), // unused input on S16B tile maps
    .rowscr_en  ( 1'b0      ), // unused input on S16B tile maps
`ifdef SHANON
    .alt_en     ( 1'b1      ), // Super Hang On uses the alternative character layout
    .obj_pxl    ( obj_pxl   ),
`else
    .alt_en     ( 1'b0      ), // I used to have game_id==1 here when Out Run and SHANON where a single core
    .obj_pxl    ( obj2tile  ),
`endif

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
    .pal_addr   ( tmap_addr ),
    .shadow     ( shadow    ),
    .set_fix    ( 1'b1      ),  // fixed layer always on top
    // Selected layer
    .sa         ( sa        ),
    .sb         ( sb        ),
    .fix        ( fix       ),
    // Debug
    .gfx_en     ( gfx_en    ),
    //.debug_bus  ( debug_bus ),
    .debug_bus  ( 8'd0      ),
    .st_addr    ( st_addr   ),
    .st_dout    ( st_tile   ),
    .scr_bad    ( scr_bad   )
);

`ifdef SHANON
    wire nc;

    // Super Hang On uses the System 16 object chip
    jts16_obj #(.PXL_DLY(9'd22),.MODEL(1)) u_obj(
        .rst       ( rst            ),
        .clk       ( clk            ),
        .pxl_cen   ( pxl_cen        ),
        .alt_bank  ( 1'b0           ),

        // CPU interface
        .cpu_obj_cs( objram_cs      ),
        .cpu_addr  ( cpu_addr[10:1] ),
        .cpu_dout  ( cpu_dout       ),
        .dswn      ( main_dswn      ),
        .cpu_din   ( obj_dout       ),

        // SDRAM interface
        .obj_ok    ( obj_ok         ),
        .obj_cs    ( obj_cs         ),
        .obj_addr  ({nc, obj_addr } ), // 9 addr + 3 vertical = 12 bits
        .obj_data  ( obj_data       ),

        // Video signal
        .hstart    ( hstart         ),
        .hsn       ( ~HS            ),
        .flip      ( flipx          ),
        .vrender   ( vrender        ),
        .hdump     ( hdump          ),
        .pxl       ( obj_pxl        ),
        //.debug_bus ( debug_bus      )
        .debug_bus ( 8'd0      )
    );
    assign st_obj = 0;
`else
    jtoutrun_obj #(.PXL_DLY(9'd14)) u_obj(
        .rst       ( rst            ),
        .clk       ( clk            ),
        .pxl_cen   ( pxl_cen        ),
        .obj_swap  ( obj_swap       ),

        // CPU interface
        .cpu_obj_cs( objram_cs      ),
        .cpu_addr  ( cpu_addr[10:1] ),
        .cpu_dout  ( cpu_dout       ),
        .dswn      ( main_dswn      ),
        .cpu_din   ( obj_dout       ),

        // SDRAM interface
        .obj_ok    ( obj_ok         ),
        .obj_cs    ( obj_cs         ),
        .obj_addr  ( obj_addr       ), // 9 addr + 3 vertical = 12 bits
        .obj_data  ( obj_data       ),

        // Video signal
`ifdef JTFRAME_LF_BUFFER
        .hstart    ( ln_hs          ),
        .vrender   ( { 1'd0, ln_v } ),
        .buf_addr  ( ln_addr        ),
        .buf_data  ( ln_data[13:0]  ),
        .buf_we    ( ln_we          ),
        .ln_done   ( ln_done        ),
        .pxl       (                ),
`else
        .vrender   ( vrender        ),
        .hstart    ( hstart         ),
        .buf_addr  (                ),
        .buf_data  (                ),
        .buf_we    (                ),
        .ln_done   (                ),
        .pxl       ( obj_pxl        ),
`endif
        .LHBL      ( ~HS            ),
        .flip      ( flipx          ),
        .hdump     ( hdump          ),

        .st_addr   ( st_addr        ),
        .st_dout   ( st_obj         ),
        .debug_bus ( debug_bus      ),
        .ioctl_addr(ioctl_addr[11:0]),
        .ioctl_din ( obj_dump       )
    );
`ifdef JTFRAME_LF_BUFFER
    assign obj_pxl        = ln_pxl[13:0];
    assign ln_data[15:14] = 0;
`endif
`endif

`ifdef SHANON
jtshanon_colmix u_colmix(
`else
jtoutrun_colmix u_colmix(
`endif
    .rst       ( rst            ),
    .clk       ( clk            ),
    .pxl_cen   ( pxl_cen        ),
    .pxl2_cen  ( pxl2_cen       ),

    //.video_en  ( video_en       ),
    .video_en  ( 1'b1           ),
    .tmap_addr ( tmap_addr      ),
    .shadow    ( shadow         ),
    // CPU interface
    .pal_cs    ( pal_cs         ),
    .cpu_addr  ( cpu_addr[13:1] ),
    .cpu_dout  ( cpu_dout       ),
    .dswn      ( main_dswn      ),
    .cpu_din   ( pal_dout       ),

    .preLVBL   ( preLVBL        ),
    .preLHBL   ( preLHBL        ),

    .rd_pxl    ( rd_pxl         ),
    .rc        ( rc             ),
    .obj_pxl   ( obj_pxl        ),
    .sa        ( sa             ),
    .sb        ( sb             ),
    .fix       ( fix            ),

    .LHBL      ( LHBL           ),
    .LVBL      ( LVBL           ),
    .red       ( red            ),
    .green     ( green          ),
    .blue      ( blue           ),
    .debug_bus ( debug_bus      ),
`ifndef SHANON
    .prog_addr ( prog_addr      ),
    .prog_data ( prog_data      ),
    .prog_we   ( prog_we        ),
`endif

    .ioctl_ram ( ioctl_ram      ),
    .ioctl_din ( pal_dump       ),
    .ioctl_addr( ioctl_addr     )
);

endmodule