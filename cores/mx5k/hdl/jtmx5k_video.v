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
    Date: 02-05-2020 */

module jtmx5k_video(
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
    // CPU      interface
    input               gfx1_cs,
    output              pal_cs,
    input               cpu_rnw,
    input               cpu_cen,
    input      [15:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    output     [ 7:0]   gfx1_dout,
    output     [ 7:0]   pal_dout,
    output              cpu_irqn,
    output              cpu_nmin,
    // SDRAM interface
    output reg [17:0]   gfx1_addr,
    input      [15:0]   gfx1_data,
    input               gfx1_ok,
    output              gfx1_romcs,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue,
    // Test
    input      [ 3:0]   gfx_en,
    input      [ 7:0]   debug_bus,
    output     [ 7:0]   st_dout
);

parameter GAME=0;

wire [ 8:0] vrender, vrender1, vdump, hdump;
wire [ 6:0] gfx1_pxl, gfx2_pxl;
reg  [13:0] gfx_addr_in;
wire [17:0] pre_gfx1_addr;
wire        gfx1_sel, gfx2_sel;
wire        post2_cs;
wire [ 3:0] gfx1_pal;
wire        preLHBL, preLVBL;

//assign post2_cs = gfx1_sel && !cpu_rnw; // only writes
assign post2_cs = 0;

always @(*) begin
    gfx_addr_in[11:0] = cpu_addr[11:0];
    casez( cpu_addr[15:10] )
        6'b0000_1?: gfx_addr_in[13:12]=1; // palette
        6'b0001_??: gfx_addr_in[13:12]=3; // objects
        6'b0010_??: gfx_addr_in[13:12]=2;
        default: gfx_addr_in[13:12]=0;
    endcase
    // Logic external to the K007121, chips 15D and 16D
    gfx1_addr = pre_gfx1_addr;
    if( pre_gfx1_addr[13:10]==0 && !gfx1_sel ) gfx1_addr[17:14]=0;
end

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
    .cen16b     (           ),
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
    .SIMOBJ ("gfx1_obj.bin" ),
    .BYPASS_VPROM( 1        ),
    .BYPASS_OPROM( 1        )
) u_gfx1(
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
    .prom_we    (               ),
    .prog_addr  (               ),
    .prog_data  (               ),
    // Screen position
    .hdump      ( hdump         ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   ( vrender1      ),
    .flip       ( flip          ),
    // CPU      interface
    .cs         ( gfx1_cs       ),
    .col_cs     ( pal_cs        ),
    .cpu_rnw    ( cpu_rnw       ),
    .addr       ( gfx_addr_in   ),
    .cpu_dout   ( cpu_dout      ),
    .dout       ( gfx1_dout     ),
    .cpu_irqn   ( cpu_irqn      ),
    .cpu_firqn  (               ),
    .cpu_nmin   ( cpu_nmin      ),
    // SDRAM interface
    .rom_obj_sel( gfx1_sel      ),
    .rom_addr   ( pre_gfx1_addr ),
    .rom_data   ( gfx1_data     ),
    .rom_cs     ( gfx1_romcs    ),
    .rom_ok     ( gfx1_ok       ),
    .pxl_out    ( gfx1_pxl      ),
    .pxl_pal    ( gfx1_pal      ),
    // Test
    .gfx_en     ( gfx_en[1:0]   ),
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_dout       )
);

// The second K007121 is only used to
// extract the palette bits using a
// funny connection:
// The VRAM is shared with the 1st one
// Pixel data from ROM is zero'ed but
// when reading through the palette PROM
// interface, the palette bits (4 MSBs of
// address) is recorded so that is the
// information that is dumped.
// Note that the logic gates 13F and 14F
// in the schematics use the object and
// tile blank information so the second
// K007121 selects between object and
// sprite correctly
// This second K007121 has been removed
// from the FPGA core and instead the
// palette bits are directly dumped by
// the first one without any
// accuracy loss

jtmx5k_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk24      ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // CPU      interface
    .pal_cs     ( pal_cs        ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_addr   ( cpu_addr[9:0] ),
    .cpu_dout   ( cpu_dout      ),
    .pal_dout   ( pal_dout      ),
    // Colours
    .gfx1_pxl   ( gfx1_pxl      ),
    .gfx1_pal   ( gfx1_pal      ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule