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
    Date: 5-4-2021 */

module jtrumble_video#(
    parameter CHARW = 13,
    parameter SCRW  = 17,
    parameter OBJW  = 17
)(
    input               rst,
    input               clk,
    input               pxl2_cen,
    input               pxl_cen,
    input               cpu_cen,
    input       [12:0]  cpu_AB,
    output      [ 8:0]  V,
    input               RnW,
    input               flip,
    input       [ 7:0]  cpu_dout,
    // CHAR
    input               char_cs,
    output      [ 7:0]  char_dout,
    input               char_ok,
    output              char_busy,
    output [CHARW-1:0]  char_addr,
    input       [15:0]  char_data,
    // SCROLL - ROM
    input               scr_cs,
    output      [ 7:0]  scr_dout,
    output  [SCRW-1:0]  scr_addr,
    input       [15:0]  scr_data,
    input               scr_ok,
    output              scr_busy,
    input       [ 9:0]  scr_hpos,
    input       [ 9:0]  scr_vpos,
    // DMA
    output              dma_cs,
    input               dma_ok,
    output      [ 8:0]  dma_addr,
    input       [ 7:0]  dma_data,
    // OBJ
    output              bus_req, // Request bus
    input               bus_ack, // bus acknowledge
    output              blcnten, // bus line counter enable
    output  [OBJW-1:0]  obj_addr,
    input       [15:0]  obj_data,
    input               obj_ok,
    // Sync signals
    output reg          vmid,
    output              LVBL,
    output              LHBL,
    output              LHBL_dly,
    output              LVBL_dly,
    output              HS,
    output              VS,
    // Priority PROMs
    input       [7:0]   prog_addr,
    input               prom_prior_we,
    input       [3:0]   prom_din,
    // Palette RAM
    input               pal_cs,
    input       [3:0]   gfx_en,
    // Pixel output
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue
);

localparam LAYOUT = 10;

localparam PXL_CHRW=7;

wire [PXL_CHRW-1:0] char_pxl;
wire [6:0] obj_pxl;
wire [7:0] scr_pxl;
wire [3:0] cc;
wire [3:0] avatar_idx;

wire       HINIT;
wire       LVBL_obj, LHBL_obj;
wire [8:0] H;

always @(posedge clk) vmid<=V==9'h60;

assign LVBL_obj = LVBL;
assign LHBL_obj = LHBL;

// Frame rate and blanking as the original
// Sync pulses slightly adjusted
jtframe_vtimer #(
    .HB_START ( 9'h1AF ),
    .HB_END   ( 9'h04F ),
    .HCNT_END ( 9'h1FF ),
    .VB_START ( 9'hF0  ),
    .VB_END   ( 9'h00  ),
    .VCNT_END ( 9'h10F ),
    .VS_START ( 9'h0FF ),
    .HS_START ( 9'h1f0 ),
    .HS_END   ( 9'h027 ),
    .H_VB     ( 9'h7   ),
    .H_VS     ( 9'h1FF ),
    .H_VNEXT  ( 9'h1FF ),
    .HINIT    ( 9'h0   )
) u_timer(
    .clk       ( clk      ),
    .pxl_cen   ( pxl_cen  ),
    .vdump     ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LVBL      ( LVBL     ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          ),
    // unused
    .vrender   (          ),
    .vrender1  (          )
);

`ifndef NOCHAR

wire [9:0] char_scan;

jtgng_char #(
    .HOFFSET (       7    ),
    .ROM_AW  (   CHARW    ),
    .PALW    ( PXL_CHRW-2 ),
    .LAYOUT  ( LAYOUT     )
) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .cpu_cen    ( cpu_cen       ),
    .AB         ( { ~cpu_AB[0], cpu_AB[11:1] } ),
    .V          ( V[7:0]        ),
    .H          ( H[8:0]        ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( char_dout     ),
    // Bus arbitrion
    .char_cs    ( char_cs       ),
    .wr_n       ( RnW           ),
    .busy       ( char_busy     ),
    // Pause screen
    .pause      ( 1'b0          ),
    .scan       (               ),
    .msg_low    (               ),
    .msg_high   (               ),
    // ROM
    .char_addr  ( char_addr     ),
    .rom_data   ( char_data     ),
    .rom_ok     ( char_ok       ),
    // Pixel output
    .char_on    ( 1'b1          ),
    .char_pxl   ( char_pxl      ),
    // unused
    .dseln      (               ),
    .prog_addr  (               ),
    .prog_din   (               ),
    .prom_we    (               )
);

`else
assign char_pxl  = ~7'd0;
assign char_mrdy = 1'b1;
`endif

`ifndef NOSCR
// wire [7:0] scr_pre;
//
// jtframe_sh #(.width(8),.stages(5)) u_hb_dly(
//     .clk    ( clk      ),
//     .clk_en ( pxl_cen     ),
//     .din    ( scr_pre  ),
//     .drop   ( scr_pxl  )
// );

jtgng_scroll #(
    .HOFFSET( 1    ),
    .ROM_AW ( SCRW  ),
    .TILE4  ( 1     ),
    .LAYOUT (LAYOUT ),
    .PALW   ( 4     ),
    .SCANW  ( 12    ),
    .POSW   ( 10    )
) u_scroll (
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .cpu_cen    ( cpu_cen       ),
    // screen position
    .H          ( H             ),
    .V          ( V[7:0]        ),
    .hpos       ( scr_hpos      ),
    .vpos       ( scr_vpos      ),
    .flip       ( flip          ),
    // bus arbitrion
    .Asel       ( ~cpu_AB[0]    ),
    .AB         ( { cpu_AB[6:1], cpu_AB[12:7] }  ),
    .scr_cs     ( scr_cs        ),
    .din        ( cpu_dout      ),
    .dout       ( scr_dout      ),
    .wr_n       ( RnW           ),
    .busy       ( scr_busy      ),
    // ROM
    .scr_addr   ( scr_addr      ),
    .rom_data   ( scr_data      ),
    .rom_ok     ( scr_ok        ),
    // pixel output
    .scr_pal    ( scr_pxl[7:4]  ),
    .scr_col    ( scr_pxl[3:0]  )
);
`else
assign scr_busy   = 1'b0;
assign scr_pxl    = 8'hff;
assign scr_addr   = 17'd0;
assign scr_dout   = 8'd0;
`endif

assign dma_cs = bus_ack;


`ifndef NOOBJ
reg  okout, last_match;
reg  miss;
wire dma_cen;
wire match = V==9'h10c;

// no tick recovery yet:
assign dma_cen = pxl_cen & (~bus_ack | dma_ok | ~miss);

always @(posedge clk) if(pxl_cen) begin
    miss <= bus_req & (bus_ack&~dma_ok);
end

always @(posedge clk) begin
    last_match <= match;
    okout <= match && !last_match;
end

jtgng_obj #(
    .OBJMAX       ( 10'h200     ),
    .ROM_AW       ( OBJW        ),
    .PALW         (  3          ),
    .PXL_DLY      (  0          ),
    .LAYOUT       ( LAYOUT      ),
    // Avatar parameters
    .AVATAR_MAX   ( 0           ),
    .VERTICAL     ( 0           ))
u_obj (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .draw_cen   ( pxl2_cen    ),
    .dma_cen    ( dma_cen     ),
    .pxl_cen    ( pxl_cen     ),
    .AB         ( dma_addr    ),
    .DB         ( dma_data    ),
    .OKOUT      ( okout       ),
    .bus_req    ( bus_req     ),
    .bus_ack    ( bus_ack     ),
    .blen       ( blcnten     ),
    .LHBL       ( LHBL_obj    ),
    .LVBL       ( LVBL        ),
    .LVBL_obj   ( LVBL_obj    ),
    .HINIT      ( HINIT       ),
    .flip       ( flip        ),
    .V          ( V[7:0]      ),
    .H          ( H           ),
    // avatar display
    .pause      ( 1'b0        ),
    .avatar_idx (             ),
    // SDRAM interface
    .obj_addr   ( obj_addr    ),
    .obj_data   ( obj_data    ),
    .rom_ok     ( obj_ok      ),
    // pixel data
    .obj_pxl    ( obj_pxl     ),
    // unused
    .prog_addr  (             ),
    .prog_din   (             ),
    .prom_hi_we ( 1'b0        ),
    .prom_lo_we ( 1'b0        ),
    .OBJON      ( 1'b1        )
);
`else
assign blcnten = 1'b0;
assign bus_req = 1'b0;
assign obj_pxl = ~6'd0;
`endif

`ifndef NOCOLMIX
jtrumble_colmix u_colmix(
    .rst          ( rst           ),
    .clk          ( clk           ),
    .pxl_cen      ( pxl_cen       ),
    .pxl2_cen     ( pxl2_cen      ),

    .char_pxl     ( char_pxl      ),
    .scr_pxl      ( scr_pxl       ),
    .obj_pxl      ( obj_pxl       ),
    .LVBL         ( LVBL          ),
    .LHBL         ( LHBL          ),
    .LHBL_dly     ( LHBL_dly      ),
    .LVBL_dly     ( LVBL_dly      ),

    // Priority PROM
    .prog_addr    ( prog_addr     ),
    .prom_prio_we ( prom_prior_we ),
    .prom_din     ( prom_din      ),

    // DEBUG
    .gfx_en       ( gfx_en        ),

    // CPU interface
    .pal_cs       ( pal_cs        ),
    .cpu_addr     ( cpu_AB[9:0]   ),
    .cpu_dout     ( cpu_dout      ),

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