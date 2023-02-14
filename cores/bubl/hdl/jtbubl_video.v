/*  This file is part of JTBUBL.
    JTBUBL program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTBUBL program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTBUBL.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 29-05-2020 */

module jtbubl_video(
    input               rst,
    input               clk,
    input               clk_cpu,
    input               pxl2_cen,
    input               pxl_cen,
    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,
    input               flip,
    input               dip_pause,
    input               start_button,
    // PROMs
    input      [ 7:0]   prog_addr,
    input      [ 3:0]   prog_data,
    input               prom_we,
    // CPU      interface
    input               pal_cs,
    output     [ 7:0]   pal_dout,
    input               black_n,
    input               cpu_rnw,
    input               cpu_cen,
    input      [12:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    input               vram_cs,
    output     [ 7:0]   vram_dout,
    //output              cpu_irqn,
    // SDRAM interface
    output     [17:0]   rom_addr,
    input      [31:0]   rom_data,
    input               rom_ok,
    output              rom_cs,
    // Colours
    output     [ 3:0]   red,
    output     [ 3:0]   green,
    output     [ 3:0]   blue,
    // Test
    input      [ 3:0]   gfx_en
);

wire [ 8:0] vrender, vrender1, vdump, hdump;
wire [ 7:0] col_addr;
wire        preLHBL, preLVBL;

jtframe_vtimer #(
    .HB_START( 9'd255 ),
    .HS_START( 9'd297 ),
    .HB_END  ( 9'd383 ),
    .V_START ( 9'd016 ),
    .VS_START( 9'd254 ),
    .VB_START( 9'd240 ),
    .VB_END  ( 9'd279 )
)
u_timer(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .H          ( hdump         ),
    .Hinit      (               ),
    .Vinit      (               ),
    .LHBL       ( preLHBL       ),
    .LVBL       ( preLVBL       ),
    .HS         ( HS            ),
    .VS         ( VS            )
);

jtbubl_gfx u_gfx(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .clk_cpu    ( clk_cpu        ),
    .pxl_cen    ( pxl_cen        ),
    .pxl2_cen   ( pxl2_cen       ),
    // PROMs
    .prog_addr  ( prog_addr      ),
    .prog_data  ( prog_data      ),
    .prom_we    ( prom_we        ),
    // Screen
    .flip       ( flip           ),
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    .vdump      ( vdump[7:0]     ),
    .hdump      ( hdump          ),
    // CPU interface
    .vram_cs    ( vram_cs        ),
    .vram_dout  ( vram_dout      ),
    .cpu_addr   ( cpu_addr       ),
    .cpu_rnw    ( cpu_rnw        ),
    .cpu_dout   ( cpu_dout       ),
    // SDRAM
    .rom_addr   ( rom_addr       ),
    .rom_data   ( rom_data       ),
    .rom_ok     ( rom_ok         ),
    .rom_cs     ( rom_cs         ),
    // Color address to palette
    .col_addr   ( col_addr       )
);


jtbubl_colmix u_colmix(
    .clk        ( clk            ),
    .clk_cpu    ( clk_cpu        ),
    .pxl_cen    ( pxl_cen        ),
    // Screen
    .preLHBL    ( preLHBL        ),
    .preLVBL    ( preLVBL        ),
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    // Colour address to palette
    .col_addr   ( col_addr       ),
    // CPU interface
    .cpu_addr   ( cpu_addr[8:0]  ),
    .cpu_rnw    ( cpu_rnw        ),
    .cpu_dout   ( cpu_dout       ),
    .pal_cs     ( pal_cs         ),
    .pal_dout   ( pal_dout       ),
    .black_n    ( black_n        ),
    // Colour output
    .red        ( red            ),
    .green      ( green          ),
    .blue       ( blue           )    
);

endmodule
