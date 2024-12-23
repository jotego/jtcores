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
    Date: 15-9-2019 */

module jtbiocom_video(
    input               rst,
    input               clk,
    input               cen12,
    input               cen8,
    input               cen6,
    input               cpu_cen,
    input       [13:1]  cpu_AB,
    input       [ 8:0]  V,
    input       [ 8:0]  H,
    input               RnW,
    input               flip,
    input       [15:0]  cpu_dout,
    // CHAR
    input               char_cs,
    output      [ 7:0]  char_dout,
    input               char_ok,
    output              char_busy,
    output      [12:0]  char_addr,
    input       [15:0]  char_data,
    // SCROLL 1
    input               scr1_cs,
    output      [ 7:0]  scr1_dout,
    output      [16:0]  scr1_addr,
    input       [15:0]  scr1_data,
    input               scr1_ok,
    output              scr1_busy,
    input       [ 9:0]  scr1_hpos,
    input       [ 9:0]  scr1_vpos,
    // SCROLL 2
    input               scr2_cs,
    output      [ 7:0]  scr2_dout,
    output      [14:0]  scr2_addr,
    input       [15:0]  scr2_data,
    input               scr2_ok,
    output              scr2_busy,
    input       [ 8:0]  scr2_hpos,
    input       [ 8:0]  scr2_vpos,
    // OBJ
    input               HINIT,
    output      [13:1]  obj_AB,
    input       [11:0]  oram_dout,   // only 12 bits are read
    input               OKOUT,
    output              bus_req, // Request bus
    input               bus_ack, // bus acknowledge
    output              blcnten,    // bus line counter enable
    output      [17:2]  obj_addr,
    input       [31:0]  obj_data,
    input               obj_ok,
    output              obj_cs,
    // Color Mix
    input               HS,
    input               preLHBL,
    input               preLVBL,
    input               LVBL_obj,
    input               LHBL_obj,
    output              LHBL,
    output              LVBL,
    input               col_uw,
    input               col_lw,
    input       [3:0]   gfx_en,
    // Priority PROM
    input       [7:0]   prog_addr,
    input               prom_prio_we,
    input       [3:0]   prom_din,
    // Pixel output: 5 bits per colour!
    output      [4:0]   red,
    output      [4:0]   green,
    output      [4:0]   blue
);

// parameters from jtgng_colmix:
parameter SCRWIN        = 1,
          PALETTE_PROM  = 0,
          PALETTE_RED   = "",
          PALETTE_GREEN = "",
          PALETTE_BLUE  = "";
parameter [1:0] OBJ_PAL = 2'b01; // 01 for GnG, 10 for Commando
    // These two bits mark the region of the palette RAM/PROM where
    // palettes for objects are stored

localparam CHAR_OFFSET = 9'd5;
localparam SCR1_OFFSET = 9'd1;
localparam SCR2_OFFSET = 9'd1;
localparam OBJ_DLY     = 3;

wire [5:0] char_pxl;
wire [7:0] obj_pxl;
wire [3:0] scr1_col, scr2_col;
wire [3:0] scr1_pal, scr2_pal;
wire [3:0] cc;

reg [7:0] scr1_pxl, scr2_pxl;

always @(posedge clk) if(cen6) begin
    scr1_pxl <= { scr1_pal, scr1_col };
    scr2_pxl <= { scr2_pal, scr2_col };
end

jtgng_char #(.HOFFSET(CHAR_OFFSET)) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    .AB         ( cpu_AB[11:1]  ),
    .V          ( V[7:0]        ),
    .H          ( H[7:0]        ),
    .flip       ( flip          ),
    .din        ( cpu_dout[7:0] ),
    .dout       ( char_dout     ),
    // Bus arbitrion
    .char_cs    ( char_cs       ),
    .wr_n       ( RnW           ),
    .busy       ( char_busy     ),
    // ROM
    .char_addr  ( char_addr     ),
    .rom_data   ( char_data     ),
    .rom_ok     ( char_ok       ),
    // Pixel output
    .char_on    ( 1'b1          ),
    .char_pxl   ( char_pxl      ),
    // unused
    .dseln      ( 2'b11         ),
    .prog_addr  (               ),
    .prog_din   (               ),
    .prom_we    (               )
);

`ifdef NOSCR
    `define NOSCR1
    `define NOSCR2
`endif

`ifndef NOSCR1
jtgng_scroll #(
    .ROM_AW     ( 17            ),
    .SCANW      ( 12            ),
    .POSW       ( 10            ),
    .HOFFSET    ( SCR1_OFFSET   ),
    .TILE4      (  1            ), // 4bpp
    .LAYOUT     (  1            ),
    .SIMID      (  1            ))
u_scroll1 (
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    // screen position
    .H          ( H             ),
    .V          ( V[7:0]        ),
    .hpos       ( scr1_hpos     ),
    .vpos       ( scr1_vpos     ),
    .flip       ( flip          ),
    // bus arbitrion
    .Asel       ( cpu_AB[1]     ),
    .AB         ( cpu_AB[13:2]  ),
    .scr_cs     ( scr1_cs       ),
    .din        ( cpu_dout[7:0] ),
    .dout       ( scr1_dout     ),
    .wr_n       ( RnW           ),
    .busy       ( scr1_busy     ),
    // ROM
    .scr_addr   ( scr1_addr     ),
    .rom_data   ( scr1_data     ),
    .rom_ok     ( scr1_ok       ),
    // pixel output
    .scr_col    ( scr1_col      ),
    .scr_pal    ( scr1_pal      )
);
`else
assign scr1_busy  = 0;
assign scr1_col   = ~4'd0;
assign scr1_pal   = ~4'd0;
assign scr1_addr  = 0;
assign scr1_dout  = 0;
`endif



`ifndef NOSCR2
jtgng_scroll #(
    .ROM_AW     ( 15            ),
    .SCANW      ( 12            ),
    .HOFFSET    ( SCR2_OFFSET   ),
    .TILE4      (  1            ), // 4bpp
    .LAYOUT     (  2            ),
    .SIMID      (  2            ))
u_scroll2 (
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    // screen position
    .H          ( H             ),
    .V          ( V[7:0]        ),
    .hpos       ( scr2_hpos     ),
    .vpos       ( scr2_vpos     ),
    .flip       ( flip          ),
    // bus arbitrion
    .Asel       ( cpu_AB[1]     ),
    .AB         ( cpu_AB[13:2]  ),
    .scr_cs     ( scr2_cs       ),
    .din        ( cpu_dout[7:0] ),
    .dout       ( scr2_dout     ),
    .wr_n       ( RnW           ),
    .busy       ( scr2_busy     ),
    // ROM
    .scr_addr   ( scr2_addr     ),
    .rom_data   ( scr2_data     ),
    .rom_ok     ( scr2_ok       ),
    // pixel output
    .scr_col    ( scr2_col      ),
    .scr_pal    ( scr2_pal      )
);
`else
assign scr2_busy  = 0;
assign scr2_col   = ~4'd0;
assign scr2_pal   = ~4'd0;
assign scr2_addr  = 0;
assign scr2_dout  = 0;
`endif

/* verilator tracing_off */
jttora_obj #( // 160 objects scanned. Max 31 objects drawn per line
    .VINV       (  0         ),
    .ROM_AW     ( 18         ),
    .DMA_AW     ( 10         ),
    .DMA_DW     ( 12         ))
u_obj (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .dma_cen    ( cen8        ),
    .pxl_cen    ( cen6        ),
    // screen
    .hs         ( HS          ),
    .LVBL       ( LVBL        ),
    .vdump      ( V           ),
    .hdump      ( H           ),
    .flip       ( flip        ),
    // CPU bus
    .AB         ( obj_AB[10:1]),
    .DB         ( oram_dout   ),
    // shared bus
    .OKOUT      ( OKOUT       ),
    .bus_req    ( bus_req     ),
    .bus_ack    ( bus_ack     ),
    .blen       ( blcnten     ),
    // SDRAM interface
    .rom_addr   ( obj_addr    ),
    .rom_data   ( obj_data    ),
    .rom_cs     ( obj_cs      ),
    .rom_ok     ( obj_ok      ),
    // pixel data
    .pxl        ( obj_pxl     ),
    .debug_bus  ( 8'd0        )
);

assign obj_AB[13:11] = 3'b111;
/* verilator tracing_on */
`ifndef NOCOLMIX
jtbiocom_colmix u_colmix (
    .rst          ( rst           ),
    .clk          ( clk           ),
    .cen6         ( cen6          ),
    .cpu_cen      ( cpu_cen       ),

    .char_pxl     ( char_pxl      ),
    .scr1_pxl     ( scr1_pxl      ),
    .scr2_pxl     ( scr2_pxl      ),
    .obj_pxl      ( obj_pxl       ),
    .LVBL         ( LVBL          ),
    .LHBL         ( LHBL          ),
    .preLHBL      ( preLHBL       ),
    .preLVBL      ( preLVBL       ),

    // PROMs
    .prog_addr    ( prog_addr     ),
    .prom_prio_we ( prom_prio_we  ),
    .prom_din     ( prom_din      ),

    // DEBUG
    .gfx_en       ( gfx_en        ),

    // CPU interface
    .AB           ( cpu_AB[10:1]  ),
    .col_uw       ( col_uw        ),
    .col_lw       ( col_lw        ),
    .DB           ( cpu_dout      ),

    // colour output
    .red          ( red           ),
    .green        ( green         ),
    .blue         ( blue          )
);
`else
assign  red = 4'd0;
assign blue = 4'd0;
assign green= 4'd0;
`endif

endmodule