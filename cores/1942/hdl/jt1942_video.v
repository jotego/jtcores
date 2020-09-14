/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-1-2019 */

module jt1942_video(
    input               rst,
    input               clk,
    input               cen6,
    input               cen3,
    input               cpu_cen,
    input       [10:0]  cpu_AB,
    input       [ 7:0]  V,
    input       [ 8:0]  H,
    input               rd_n,
    input               wr_n,
    input               flip,
    input       [ 7:0]  cpu_dout,
    input               pause,
    // CHAR
    input               char_cs,
    output      [ 7:0]  chram_dout,
    output      [11:0]  char_addr,
    input       [15:0]  char_data,
    output              char_busy,
    input               char_ok,
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
    input               HINIT,
    output      [14:0]  obj_addr,
    input       [15:0]  obj_data,
    input               obj_ok,
    // Color Mix
    input               LVBL,
    input               LHBL,
    output              LHBL_dly,
    output              LVBL_dly,
    input               LHBL_obj,
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue,
    // PROM access
    input       [7:0]   prog_addr,
    input       [3:0]   prog_din,
    input               prom_char_we,
    input               prom_d1_we,
    input               prom_d2_we,
    input               prom_d6_we,
    input               prom_e8_we,
    input               prom_e9_we,
    input               prom_e10_we,
    input               prom_obj_we,
    input               prom_m11_we,
    // Debug
    input       [3:0]   gfx_en
);

`ifdef VULGUS
localparam VULGUS = 1'b1;
`else
localparam VULGUS = 1'b0;
`endif

localparam COFFSET = 9'd5;
localparam SOFFSET = 9'd5;

wire [3:0] char_pxl, obj_pxl;

`ifndef NOCHAR
wire [7:0] char_msg_low;
wire [7:0] char_msg_high = 8'h2;
wire [9:0] char_scan;
wire [5:0] char_pal;
wire [1:0] char_col;

`ifndef NOCHAR
jtgng_char #(
    .HOFFSET ( COFFSET ),
    .ROM_AW  ( 12      ),
    .IDMSB1  (  7      ),
    .IDMSB0  (  7      ),
    .VFLIP   (  6      ),
    .PALW    (  6      ),
    .HFLIP_EN(  0      ),   // 1942 does not have character H flip
    .PALETTE (  1      ),
    .PALETTE_SIMFILE( "../../../rom/1942/sb-0.f1" )
) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    .cpu_cen    ( cpu_cen       ),
    .AB         ( cpu_AB        ),
    .V          ( V             ),
    .H          ( H[7:0]        ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( chram_dout    ),
    // Bus arbitrion
    .char_cs    ( char_cs       ),
    .wr_n       ( wr_n          ),
    .busy       ( char_busy     ),
    // Pause screen
    .pause      ( pause         ),
    .scan       ( char_scan     ),
    .msg_low    ( char_msg_low  ),
    .msg_high   ( char_msg_high ),
    // PROM access
    .prog_addr  ( prog_addr     ),
    .prog_din   ( prog_din      ),
    .prom_we    ( prom_char_we  ),
    // ROM
    .char_addr  ( char_addr     ),
    .rom_data   ( char_data     ),
    .rom_ok     ( char_ok       ),
    // Pixel output
    .char_on    ( 1'b1          ),
    .char_pxl   ( char_pxl      )
);
`else
assign char_addr = 12'd0;
assign char_pxl  = 4'hf;
`endif

jtframe_ram #(.aw(10),.synfile("msg.hex"),.simfile("msg.bin")) u_char_msg(
    .clk    ( clk          ),
    .cen    ( cen6         ),
    .data   ( 8'd0         ),
    .addr   ( char_scan    ),
    .we     ( 1'b0         ),
    .q      ( char_msg_low )
);
`else
assign char_wait_n = 1'b1;
assign char_pxl = 4'hf;
`endif

`ifndef NOSCR
wire [2:0] scr_col;
wire [4:0] scr_pal;
reg  [5:0] scr_pxl;

// As scr_AB width differs depending on VULGUS
// I think it is more clear to use `ifdef rather
// than generate here.
`ifdef VULGUS
wire [9:0] scr_AB = cpu_AB[9:0];
wire       scr_sel= cpu_AB[10];
`else // 1942
wire [8:0] scr_AB = { cpu_AB[9:5], cpu_AB[3:0] };
wire       scr_sel= cpu_AB[4];
`endif

jtgng_scroll #(
    .HOFFSET ( SOFFSET ),
    .ROM_AW  ( 14      ),
    .IDMSB1  ( 7       ),
    .IDMSB0  ( 7       ),
    .VFLIP   ( 6       ),
    .HFLIP   ( 5       ),
    .PALW    ( 5       ),
    .SCANW   ( VULGUS ? 10 : 9 )
) u_scroll (
    .clk          ( clk           ),
    .pxl_cen      ( cen6          ),
    .cpu_cen      ( cpu_cen       ),
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
jtframe_prom #(.aw(8),.dw(2),.simfile("../../../rom/1942/sb-2.d1")) u_prom_d1(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din[1:0]  ),
    .rd_addr( scr_pal_addr   ),
    .wr_addr( prog_addr      ),
    .we     ( prom_d1_we     ),
    .q      ( scr_pal2[5:4]   )
);

jtframe_prom #(.aw(8),.dw(4),.simfile("../../../rom/1942/sb-3.d2")) u_prom_d2(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din       ),
    .rd_addr( scr_pal_addr   ),
    .wr_addr( prog_addr      ),
    .we     ( prom_d2_we     ),
    .q      ( scr_pal2[3:0]   )
);

// Vulgus only uses this PROM
jtframe_prom #(.aw(8),.dw(4),.simfile("../../../rom/1942/sb-4.d6")) u_prom_d6(
    .clk    ( clk            ),
    .cen    ( cen6           ),
    .data   ( prog_din       ),
    .rd_addr( {scr_pal, scr_col} ),
    .wr_addr( prog_addr      ),
    .we     ( prom_d6_we     ),
    .q      ( scr_pal_addr[3:0]  )
);

reg [3:0] pre_scr_pxl;
always @(*) begin
    pre_scr_pxl = scr_pal_addr[3:0];
    scr_pxl     = VULGUS ? { scr_br[1:0], pre_scr_pxl } : scr_pal2;
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
    // screen
    .HINIT          ( HINIT     ),
    .LHBL           ( LHBL_obj  ),
    .LVBL           ( LVBL      ),
    .V              ( V         ),
    .H              ( H         ),
    .flip           ( flip      ),
    // CPU bus
    .AB             ( cpu_AB[6:0] ),
    .DB             ( cpu_dout    ),
    .obj_cs         ( obj_cs      ),
    .wr_n           ( wr_n        ),
    // SDRAM interface
    .obj_addr       ( obj_addr    ),
    .obj_data       ( obj_data    ),
    .obj_ok         ( obj_ok      ),
    // PROMs
    .prog_addr      ( prog_addr   ),
    .prom_m11_we    ( prom_m11_we ), // Object logic timing
    .prom_pal_we    ( prom_obj_we ),
    .prog_din       ( prog_din    ),
    // pixel output
    .obj_pxl        ( obj_pxl   )
);

`ifndef NOCOLMIX
jt1942_colmix #(.VULGUS(VULGUS)) u_colmix (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
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
`else
assign  red = 4'd0;
assign blue = 4'd0;
assign green= 4'd0;
`endif

endmodule