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
    Date: 3-10-2020 */

module jtlabrun_video(
    input               rst,
    input               clk,
    input               clk24,
    output              pxl2_cen,
    output              pxl_cen,
    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,
    output              flip,
    input               dip_pause,
    input               cab_1p,
    // PROMs
    input      [ 8:0]   prog_addr,
    input      [ 3:0]   prog_data,
    input               prom_we,
    // CPU      interface
    input               gfx_cs,
    inout               pal_cs,
    input               cpu_rnw,
    input               cpu_cen,
    input      [13:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    output     [ 7:0]   gfx_dout,
    output     [ 7:0]   pal_dout,
    output              cpu_irqn,
    output              cpu_nmin,
    // SDRAM interface
    output     [17:0]   gfx_addr,
    input      [15:0]   gfx_data,
    input               gfx_ok,
    output              gfx_romcs,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue,
    // Test
    input      [ 3:0]   gfx_en,
    input      [ 7:0]   debug_bus,
    output     [ 7:0]   st_dout
);

localparam LABRUN=0, FLANE=1;

parameter GAME=0; // 0=Labyrinth Runner, 1=Fast Lane

wire [ 6:0] gfx_pxl;
wire        gfx_palcs;
wire [17:0] pre_gfx_addr;
wire        preLHBL, preLVBL;

generate
    if( GAME==1 ) begin
        assign pal_cs   = gfx_palcs;
        assign gfx_addr = pre_gfx_addr;
    end else begin
        assign gfx_addr = {1'b0, pre_gfx_addr[16:0]};
    end
endgenerate

jtframe_cen48 u_cen(
    .clk        ( clk       ),    // 48 MHz
    .cen12      ( pxl2_cen  ),
    .cen16      (           ),
    .cen8       (           ),
    .cen6       ( pxl_cen   ),
    .cen4       (           ),
    .cen4_12    (           ), // cen4 based on cen12
    .cen3       (           ),
    .cen3q      (           ), // 1/4 advanced with respect to cen3
    .cen1p5     (           ),
    .cen12b     (           ),
    .cen16b     (           ),
    .cen6b      (           ),
    .cen3b      (           ),
    .cen3qb     (           ),
    .cen1p5b    (           )
);

jtcontra_gfx #(
    .BYPASS_VPROM({1'b0,GAME==LABRUN}),
    .BYPASS_OPROM( {1'b0,GAME==FLANE})
    ) u_gfx(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk24      ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( preLHBL       ),
    .LVBL       ( preLVBL       ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    // PROMs
    .prom_we    ( prom_we       ),
    .prog_addr  ({GAME==FLANE?1'b1:1'b0,prog_addr[7:0]} ), // ? explicit to indicate bit width
    .prog_data  ( prog_data[3:0]),
    // Screen position
    .hdump      (               ),
    .vdump      (               ),
    .vrender    (               ),
    .vrender1   (               ),
    .flip       ( flip          ),
    // CPU      interface
    .cs         ( gfx_cs        ),
    .cpu_rnw    ( cpu_rnw       ),
    .addr       ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .dout       ( gfx_dout      ),
    .cpu_irqn   ( cpu_irqn      ),
    .cpu_firqn  (               ),
    .cpu_nmin   ( cpu_nmin      ),
    .col_cs     ( gfx_palcs     ),
    // SDRAM interface
    .rom_obj_sel(               ),
    .rom_addr   ( pre_gfx_addr  ),
    .rom_data   ( gfx_data      ),
    .rom_cs     ( gfx_romcs     ),
    .rom_ok     ( gfx_ok        ),
    .pxl_out    ( gfx_pxl       ),
    .pxl_pal    (               ),
    // Test
    .gfx_en     ( gfx_en[1:0]   ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_dout       )
);


jtlabrun_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk24      ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    // CPU      interface
    .pal_cs     ( pal_cs        ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr[7:0] ),
    .cpu_dout   ( cpu_dout      ),
    .pal_dout   ( pal_dout      ),
    // Colours
    .gfx_pxl    ( gfx_pxl       ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule