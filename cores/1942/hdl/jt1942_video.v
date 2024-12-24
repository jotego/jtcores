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
    Date: 20-1-2019 */

module jt1942_video(
    input               rst,
    input               clk,
    input               cen6,
    input               cen3,
    input               cpu_cen,

    input       [ 1:0]  game_id,

    input       [10:0]  cpu_AB,
    output      [ 8:0]  V,
    output      [ 8:0]  H,
    input               rd_n,
    input               wr_n,
    input               flip,
    input       [ 7:0]  cpu_dout,
    input               pause,
    // CHAR
    input               char_cs,
    output      [11:0]  char_addr,
    input       [15:0]  char_data,
    output              char_busy,
    input               char_ok,
    output      [10:1]  tmap_addr,
    input       [15:0]  tmap_dout,
    // SCROLL - ROM
    input               scr_cs,
    output              scr_busy,
    output      [ 7:0]  scram_dout,
    output      [13:0]  scr_addr,
    input       [23:0]  scrom_data,
    input       [ 2:0]  scr_br,
    input       [ 8:0]  scr_hpos,
    input       [ 8:0]  scr_vpos,
    input               scr_ok,
    // OBJ
    input               obj_cs,
    output      [14:0]  obj_addr,
    input       [15:0]  obj_data,
    input               obj_ok,
    // Color Mix
    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue,
    // PROM access
    input       [7:0]   prog_addr,
    input       [7:0]   prog_din,
    input               prom_char_we,
    input               prom_d1_we,
    input               prom_d2_we,
    input               prom_d6_we,
    input               prom_e8_we,
    input               prom_e9_we,
    input               prom_e10_we,
    input               prom_obj_we,
    // Debug
    input       [3:0]   gfx_en
);

`include "1942.vh"
localparam COFFSET = 9'd5;
localparam SOFFSET = 9'd5;

reg         vulgus, hige;
wire        preLHBL, preLVBL, LHBL_obj, HINIT;
wire [ 3:0] char_pxl, obj_pxl;
wire [ 7:0] char_prom;
wire [ 8:0] aux_AB = cpu_AB[8:0]-9'h80;
wire [ 6:0] obj_AB = hige ? aux_AB[8:2] :cpu_AB[6:0];
wire [15:0] char_sorted;

always @(posedge clk ) begin
    hige   <= game_id==HIGEMARU;
    vulgus <= game_id==VULGUS;
end

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .LHBL_obj  ( LHBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          ),
    .LVBL_obj  (          )
);

// Higemaru only uses 5 bits for char palette. The other games use 6 bits.
// in order to share the module, the same data is written in both halves of the
// palette PROM. Higemaru writes bit 6 during hi-score entry and does not
// clear it afterwards. See https://github.com/jotego/jtcores/issues/466

assign char_sorted = { char_data[8+:4],char_data[0+:4], char_data[12+:4],char_data[4+:4] };
assign char_busy   = H[2:1]!=3 && char_cs;

jtframe_tilemap #(.CW(9),.BPP(2),.XOR_HFLIP(1),.XOR_VFLIP(0))u_char(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),

    .vdump      ( V             ),
    .hdump      ( H+9'd2        ),
    .blankn     ( LVBL          ),
    .flip       ( flip          ),

    .vram_addr  ( tmap_addr     ),

    .code       ({tmap_dout[15],tmap_dout[7:0]}),
    .pal        ({tmap_dout[13]&~hige,tmap_dout[12:8]}),
    .hflip      ( tmap_dout[13]& hige ),
    .vflip      ( tmap_dout[14]       ),

    .rom_addr   ( char_addr     ),
    .rom_data   ( char_sorted   ),
    .rom_cs     (               ),
    .rom_ok     ( char_ok       ),      // ignored. It assumes that data is always right

    .pxl        ( char_prom     )
);

jtframe_prom #(.AW(8),.DW(4)) u_chprom(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din[3:0]  ),
    .rd_addr( char_prom      ),
    .wr_addr( prog_addr      ),
    .we     ( prom_char_we   ),
    .q      ( char_pxl       )
);
/* verilator tracing_off */
`ifndef NOSCR
wire [2:0] scr_col;
wire [4:0] scr_pal;
reg  [5:0] scr_pxl;

wire [9:0] scr_AB = vulgus ? cpu_AB[9:0] : {cpu_AB[9:5], 1'b0, cpu_AB[3:0]};
wire       scr_sel= vulgus ? cpu_AB[10] : cpu_AB[4];
// Higemaru does not use this layer
jtgng_scroll #(
    .HOFFSET ( SOFFSET ),
    .ROM_AW  ( 14      ),
    .IDMSB1  ( 7       ),
    .IDMSB0  ( 7       ),
    .VFLIP   ( 6       ),
    .HFLIP   ( 5       ),
    .PALW    ( 5       ),
    .SCANW   ( 10      ) // only 9 for 1942
) u_scroll (
    .clk          ( clk           ),
    .pxl_cen      ( cen6          ),
    // screen position
    .H            ( H             ),
    .V            ( V[7:0]        ),
    .hpos         ( scr_hpos      ),
    .vpos         ( scr_vpos      ),
    .flip         ( flip          ),
    // bus arbitrion
    .Asel         ( scr_sel       ),
    .AB           ( scr_AB        ),
    .scr_cs       ( scr_cs        ),
    .din          ( cpu_dout      ),
    .dout         ( scram_dout    ),
    .wr_n         ( wr_n          ),
    .busy         ( scr_busy      ),
    // ROM
    .scr_addr     ( scr_addr      ),
    .rom_data     ( scrom_data    ),
    .rom_ok       ( scr_ok        ),
    // pixel
    .scr_col      ( scr_col       ),
    .scr_pal      ( scr_pal       )
);

wire [7:0] scr_pal_addr;
assign scr_pal_addr[7] = 1'b0;
assign scr_pal_addr[6:4] = scr_br[2:0];

// Scroll palette PROMs
wire [5:0] scr_pal2;
jtframe_prom #(.AW(8),.DW(2),.SIMFILE("../../../rom/1942/sb-2.d1")) u_prom_d1(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din[1:0]  ),
    .rd_addr( scr_pal_addr   ),
    .wr_addr( prog_addr      ),
    .we     ( prom_d1_we     ),
    .q      ( scr_pal2[5:4]   )
);

jtframe_prom #(.AW(8),.DW(4),.SIMFILE("../../../rom/1942/sb-3.d2")) u_prom_d2(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din[3:0]  ),
    .rd_addr( scr_pal_addr   ),
    .wr_addr( prog_addr      ),
    .we     ( prom_d2_we     ),
    .q      ( scr_pal2[3:0]   )
);

// Vulgus only uses this PROM
jtframe_prom #(.AW(8),.DW(4),.SIMFILE("../../../rom/1942/sb-4.d6")) u_prom_d6(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din[3:0]  ),
    .rd_addr( {scr_pal, scr_col} ),
    .wr_addr( prog_addr      ),
    .we     ( prom_d6_we     ),
    .q      ( scr_pal_addr[3:0]  )
);

reg [3:0] pre_scr_pxl;
always @(*) begin
    pre_scr_pxl = scr_pal_addr[3:0];
    scr_pxl     = vulgus ? { scr_br[1:0], pre_scr_pxl } : scr_pal2;
end
`else
initial $display("INFO: scroll simulation omitted.");
wire  [5:0] scr_pxl;

assign scr_busy  = 1'b0;
assign scr_addr  = 14'd0;
assign scr_pxl   = ~6'h0;
`endif

jt1942_obj #(.PXL_DLY(4)) u_obj(
    .rst            ( rst       ),
    .clk            ( clk       ),
    .cen6           ( cen6      ),
    .cen3           ( cen3      ),
    .cpu_cen        ( cpu_cen   ),
    .game_id        ( game_id   ),
    // screen
    .HINIT          ( HINIT     ),
    .LHBL           ( LHBL_obj  ),
    .LVBL           ( LVBL      ),
    .V              ( V[7:0]    ),
    .H              ( H         ),
    .flip           ( flip      ),
    // CPU bus
    .AB             ( obj_AB    ),
    .DB             ( cpu_dout  ),
    .obj_cs         ( obj_cs    ),
    .wr_n           ( wr_n      ),
    // SDRAM interface
    .obj_addr       ( obj_addr    ),
    .obj_data       ( obj_data    ),
    .obj_ok         ( obj_ok      ),
    // PROMs
    .prog_addr      ( prog_addr   ),
    .prom_pal_we    ( prom_obj_we ),
    .prog_din       (prog_din[3:0]),
    // pixel output
    .obj_pxl        ( obj_pxl   )
);

jt1942_colmix u_colmix (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .game_id    ( game_id       ),
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    // pixel input from generator modules
    .char_pxl   ( char_pxl      ),        // character color code
    .scr_pxl    ( scr_pxl       ),
    .obj_pxl    ( obj_pxl       ),
    // Palette PROMs E8, E9, E10
    .prog_addr  ( prog_addr     ),
    .prom_e8_we ( prom_e8_we    ),
    .prom_e9_we ( prom_e9_we    ),
    .prom_e10_we( prom_e10_we   ),
    .prom_din   ( prog_din      ),

    // DEBUG
    .gfx_en     ( gfx_en        ),

    // output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule