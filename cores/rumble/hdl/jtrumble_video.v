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
    output              HS,
    output              VS,
    // Priority PROMs
    input       [7:0]   prog_addr,
    input               prom_prio,
    input       [3:0]   prom_din,
    // Palette RAM
    input               pal_cs,
    input       [3:0]   gfx_en,
    input       [7:0]   debug_bus,
    // Pixel output
    output      [3:0]   red,
    output      [3:0]   green,
    output      [3:0]   blue
);

localparam LAYOUT = 10;

localparam PXL_CHRW=7;

wire [PXL_CHRW-1:0] char_pxl;
wire [7:0] obj_pxl;
wire [7:0] scr_pxl;
wire [3:0] cc;

wire       HINIT, preLVBL, preLHBL;
wire       LVBL_obj, LHBL_obj;
reg  [8:0] LHBL_sh;
wire [8:0] H;

always @(posedge clk) begin
    vmid <= V==9'h60;
    if(pxl_cen) begin
        LHBL_sh    <= LHBL_sh << 1;
        LHBL_sh[0] <= !(H[8] ? H[7:0] > 8'hA7 : H[7:0] < 8'h47);
    end
end

assign LVBL_obj = ~V[8];
assign LHBL_obj = flip ? LHBL_sh[8] : LHBL_sh[6];

// Frame rate and blanking as the original
// Sync pulses slightly adjusted
jtframe_vtimer #(
    .HB_START ( 9'h1B0 ),
    .HB_END   ( 9'h050 ),
    .HCNT_END ( 9'h1FF ),
    .VB_START ( 9'hF8  ),
    .VB_END   ( 9'h08  ),
    .VCNT_END ( 9'h10F ),
    .VS_START ( 9'h107 ),
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
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          ),
    // unused
    .vrender   (          ),
    .vrender1  (          )
);

jtgng_char #(
    .HOFFSET (       7    ),
    .HFLIP_EN(       0    ),
    .VFLIP_EN(       0    ),
    .ROM_AW  (   CHARW    ),
    .PALW    ( PXL_CHRW-2 ),
    .LAYOUT  ( LAYOUT     )
) u_char (
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
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

`ifndef NOSCR
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

`ifndef NOOBJ
reg  okout, last_match;
wire match = V==9'h10c;


always @(posedge clk) begin
    last_match <= match;
    okout <= match && !last_match;
end

// reg [8:0] Vadj;

// always @* begin
//     Vadj = V + {debug_bus[7], debug_bus};
//     if( Vadj>9'h10F) Vadj = Vadj-9'h10f;
// end

jtgng_obj #(
    .OBJMAX       ( 10'h200     ),
    .ROM_AW       ( OBJW        ),
    .PALW         (  4          ),
    .PXL_DLY      (  0          ),
    .LAYOUT       ( LAYOUT      ))
u_obj (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .draw_cen   ( pxl2_cen    ),
    .dma_cen    ( pxl_cen     ),
    .pxl_cen    ( pxl_cen     ),
    .AB         ( dma_addr    ),
    .DB         ( dma_data    ),
    .OKOUT      ( okout       ),
    .bus_req    ( bus_req     ),
    .bus_ack    ( bus_ack     ),
    .blen       ( blcnten     ),
    .LHBL       ( LHBL_obj    ),
    .LVBL       ( LVBL_obj    ),
    .LVBL_obj   ( LVBL_obj    ),
    .HINIT      ( HINIT       ),
    .flip       ( flip        ),
    .V          ( V[7:0]      ),
    .H          ( H           ),
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
    .preLHBL      ( preLHBL       ),
    .preLVBL      ( preLVBL       ),
    .LVBL         ( LVBL          ),
    .LHBL         ( LHBL          ),

    // Priority PROM
    .prog_addr    ( prog_addr     ),
    .prom_prio_we ( prom_prio     ),
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