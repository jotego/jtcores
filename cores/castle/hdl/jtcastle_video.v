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
    Date: 31-01-2023 */

module jtcastle_video(
    input               rst,
    input               clk,
    output              pxl2_cen,
    output              pxl_cen,
    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,
    output              flip,
    // PROMs
    input      [10:0]   prog_addr,
    input      [ 3:0]   prog_data,
    input               prom_we,
    // CPU      interface
    inout               gfx1_cs,
    inout               gfx2_cs,
    input               pal_cs,
    input               cpu_rnw,
    input               cpu_cen,
    input      [15:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    output     [ 7:0]   gfx1_dout,
    output     [ 7:0]   gfx2_dout,
    output     [ 7:0]   pal_dout,
    output              cpu_firqn,
    output              cpu_irqn,
    output              cpu_nmin,
    // Haunted Castle:
    input      [ 1:0]   video_bank,
    input               prio,
    // SDRAM interface
    output     [18:0]   gfx1_addr,
    input      [15:0]   gfx1_data,
    input               gfx1_ok,
    output              gfx1_romcs,
    output     [18:0]   gfx2_addr,
    input      [15:0]   gfx2_data,
    input               gfx2_ok,
    output              gfx2_romcs,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue,
    // Test
    input      [ 7:0]   debug_bus,
    output reg [ 7:0]   st_dout,
    input      [ 3:0]   gfx_en
);

wire [ 8:0] vrender, vrender1, vdump, hdump;
wire [ 6:0] gfx1_pxl, gfx2_pxl;
wire [13:0] gfx1_addr_in, gfx2_addr_in;
wire        gfx1_sel, gfx2_sel;
wire        preLHBL, preLVBL;
wire        prio_we;
wire [ 9:0] pal_addr;
wire [ 7:0] prio_mux, st_dout1, st_dout2;
wire        gfx1_prom_we, gfx2_prom_we;

assign gfx1_prom_we = (prog_addr[10:9]==0) && prom_we;
assign gfx2_prom_we = (prog_addr[10:9]==1) && prom_we;
assign prio_we      = (prog_addr[10:9]==2) && prom_we;

assign pal_addr  = { 2'd0, cpu_addr[7:0]^8'd1 };

assign gfx1_addr_in  = cpu_addr[13:0];
assign gfx2_addr_in  = { ^cpu_addr[14:13], cpu_addr[12:10], (~cpu_addr[14])^cpu_addr[9], cpu_addr[8:0] };
assign gfx1_addr[18] = video_bank[0] &  gfx1_sel;
assign gfx2_addr[18] = video_bank[1] & ~gfx2_sel;

always @(posedge clk) st_dout <= debug_bus[3] ? st_dout2 : st_dout1;

jtframe_cen48 u_cen(
    .clk        ( clk       ),    // 48 MHz
    .cen12      ( pxl2_cen  ),
    .cen16      (           ),
    .cen16b     (           ),
    .cen8       (           ),
    .cen6       ( pxl_cen   ),
    .cen4       (           ),
    .cen4_12    (           ), // cen4 based on cen12
    .cen3       (           ),
    .cen3q      (           ), // 1/4 advanced with respect to cen3
    .cen1p5     (           ),
    .cen12b     (           ),
    .cen6b      (           ),
    .cen3b      (           ),
    .cen3qb     (           ),
    .cen1p5b    (           )
);

jtcontra_gfx #(
    .CFGFILE("gfx1_cfg.hex" ),
    .SIMATTR("gfx1_attr.bin"),
    .SIMCODE("gfx1_code.bin"),
    .SIMOBJ ("gfx1_obj.bin" )
) u_gfx1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk24      ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( preLHBL       ),
    .LVBL       ( preLVBL       ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    // PROMs
    .prom_we    ( gfx1_prom_we  ),
    .prog_addr  ( prog_addr[8:0]),
    .prog_data  ( prog_data[3:0]),
    // Screen position
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .flip       ( flip          ),
    // CPU      interface
    .cs         ( gfx1_cs       ),
    .cpu_rnw    ( cpu_rnw       ),
    .addr       ( gfx1_addr_in  ),
    .cpu_dout   ( cpu_dout      ),
    .dout       ( gfx1_dout     ),
    .cpu_irqn   ( cpu_irqn      ),
    .cpu_firqn  ( cpu_firqn     ),
    .cpu_nmin   ( cpu_nmin      ),
    // SDRAM interface
    .rom_obj_sel( gfx1_sel      ),
    .rom_addr   (gfx1_addr[17:0]),
    .rom_data   ( gfx1_data     ),
    .rom_cs     ( gfx1_romcs    ),
    .rom_ok     ( gfx1_ok       ),
    .pxl_out    ( gfx1_pxl      ),
    // Unused
    .col_cs     (               ),
    .pxl_pal    (               ),
    // Test
    .gfx_en     ( gfx_en[1:0]   ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_dout1      )
);

jtcontra_gfx #(
    .CFGFILE("gfx2_cfg.hex" ),
    .SIMATTR("gfx2_attr.bin"),
    .SIMCODE("gfx2_code.bin"),
    .SIMOBJ ("gfx2_obj.bin" ),
    .VTIMER ( 0             )
) u_gfx2(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk24      ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .LHBL       ( preLHBL       ),
    .LVBL       ( preLVBL       ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    // PROMs
    .prom_we    ( gfx2_prom_we  ),
    .prog_addr  ( prog_addr[8:0]),
    .prog_data  ( prog_data[3:0]),
    // Screen position
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .flip       (               ),
    // CPU      interface
    .cs         ( gfx2_cs       ),
    .cpu_rnw    ( cpu_rnw       ),
    .addr       ( gfx2_addr_in  ),
    .cpu_dout   ( cpu_dout      ),
    .dout       ( gfx2_dout     ),
    .cpu_irqn   (               ),
    .cpu_firqn  (               ),
    .cpu_nmin   (               ),
    // SDRAM interface
    .rom_obj_sel( gfx2_sel      ),
    .rom_addr   (gfx2_addr[17:0]),
    .rom_data   ( gfx2_data     ),
    .rom_cs     ( gfx2_romcs    ),
    .rom_ok     ( gfx2_ok       ),
    .pxl_out    ( gfx2_pxl      ),
    // Unused
    .col_cs     (               ),
    .pxl_pal    (               ),
    // Test
    .gfx_en     ( gfx_en[3:2]   ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_dout2      )
);

// Chip ID 007327
jtcastle_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk24      ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // CPU      interface
    .prio_cfg   ( prio          ),
    .pal_cs     ( pal_cs        ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_addr   ( pal_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .pal_dout   ( pal_dout      ),
    // PROMs
    .prog_addr  ( prog_addr     ),
    .prog_data  ( prog_data     ),
    .prom_we    ( prio_we       ),
    // Colours
    .gfx1_pxl   ( gfx1_pxl      ),
    .gfx2_pxl   ( gfx2_pxl      ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule