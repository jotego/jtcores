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
    Date: 18-09-2022 */

module jtkiwi_video(
    input               rst,
    input               clk,
    input               clk_cpu,
    input               pxl2_cen,
    input               pxl_cen,
    input               hb_dly,

    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,
    output              flip,
    output     [ 8:0]   hdump,
    // PROMs
    input      [ 9:0]   prog_addr,
    input      [ 7:0]   prog_data,
    input               prom_we,
    input               colprom_en,
    // CPU      interface
    input               pal_cs,
    output     [ 7:0]   pal_dout,
    input               cpu_rnw,
    input      [12:0]   cpu_addr,
    input      [ 7:0]   cpu_dout,
    input               vram_cs,
    input               vctrl_cs,
    input               vflag_cs,
    output     [ 7:0]   vram_dout,
    // Sub-CPU interface
    input               pal2_cs,
    input      [ 7:0]   cpu2_dout,
    input               cpu2_rnw,
    input      [ 9:0]   cpu2_addr,
    // SDRAM interface
    output     [20:2]   scr_addr,
    input      [31:0]   scr_data,
    input               scr_ok,
    output              scr_cs,

    output     [20:2]   obj_addr,
    input      [31:0]   obj_data,
    input               obj_ok,
    output              obj_cs,
    // Colours
    output     [ 4:0]   red,
    output     [ 4:0]   green,
    output     [ 4:0]   blue,
    // Test
    input      [ 3:0]   gfx_en,
    input      [ 7:0]   debug_bus,
    output     [ 7:0]   st_dout
);

wire [ 8:0] vrender, vrender1, vdump;
wire [ 8:0] scr_pxl, obj_pxl;
reg  [ 7:0] LHBL_l;
wire        preLHBL;

assign LHBL = hb_dly ? LHBL_l[4] : preLHBL; // used by JTKIWI

always @(posedge clk) begin
    LHBL_l <= LHBL_l<<1;
    LHBL_l[0] <= preLHBL;
end

jtframe_vtimer #(
    .HB_START( 9'd256 ),
    .HS_START( 9'd297 ),
    .HCNT_END( 9'd383 ),
    .HB_END  ( 9'd0   ),
    .V_START ( 9'd008 ),
    .VS_START( 9'd254 ),
    .VB_START( 9'd239 ),
    .VCNT_END( 9'd271 ),
    .VB_END  ( 9'd015 )
) u_timer(
    .clk        ( clk        ),
    .pxl_cen    ( pxl_cen    ),
    .vdump      ( vdump      ),
    .vrender    ( vrender    ),
    .vrender1   ( vrender1   ),
    .H          ( hdump      ),
    .Hinit      (            ),
    .Vinit      (            ),
    .LHBL       ( preLHBL    ),
    .LVBL       ( LVBL       ),
    .HS         ( HS         ),
    .VS         ( VS         )
);

jtkiwi_gfx u_gfx(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .clk_cpu    ( clk_cpu        ),
    .pxl_cen    ( pxl_cen        ),
    .pxl2_cen   ( pxl2_cen       ),
    // PROMs
    // .prog_addr  ( prog_addr      ),
    // .prog_data  ( prog_data      ),
    // .prom_we    ( prom_we        ),
    // Screen
    .flip       ( flip           ),
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    .vs         ( VS             ),
    .hs         ( HS             ),
    .vdump      ( vdump          ),
    .vrender    ( vrender        ),
    .hdump      ( hdump          ),
    // CPU interface
    .vram_cs    ( vram_cs        ),
    .vctrl_cs   ( vctrl_cs       ),
    .vflag_cs   ( vflag_cs       ),
    .cpu_din    ( vram_dout      ),
    .cpu_addr   ( cpu_addr       ),
    .cpu_rnw    ( cpu_rnw        ),
    .cpu_dout   ( cpu_dout       ),
    // SDRAM
    .scr_addr   ( scr_addr       ),
    .scr_data   ( scr_data       ),
    .scr_ok     ( scr_ok         ),
    .scr_cs     ( scr_cs         ),

    .obj_addr   ( obj_addr       ),
    .obj_data   ( obj_data       ),
    .obj_ok     ( obj_ok         ),
    .obj_cs     ( obj_cs         ),
    // Color address to palette
    .scr_pxl    ( scr_pxl        ),
    .obj_pxl    ( obj_pxl        ),
    .debug_bus  ( debug_bus      ),
    .st_dout    ( st_dout        )
);

jtkiwi_colmix u_colmix(
    .clk        ( clk            ),
    .clk_cpu    ( clk_cpu        ),
    .pxl_cen    ( pxl_cen        ),
    // Screen
    .LHBL       ( LHBL           ),
    .LVBL       ( LVBL           ),
    // CPU interface
    .cpu_addr   ( cpu_addr[9:0]  ),
    .cpu_rnw    ( cpu_rnw        ),
    .cpu_dout   ( cpu_dout       ),
    .cpu_din    ( pal_dout       ),
    .pal_cs     ( pal_cs         ),
    // Sub-CPU interface
    .pal2_cs    ( pal2_cs        ),
    .cpu2_addr  ( cpu2_addr[9:0] ),
    .cpu2_rnw   ( cpu2_rnw       ),
    .cpu2_dout  ( cpu2_dout      ),
    // PROMs
    .prog_addr  ( prog_addr      ),
    .prog_data  ( prog_data      ),
    .prom_we    ( prom_we        ),
    .colprom_en ( colprom_en     ),
    // Colour output
    .scr_pxl    ( scr_pxl        ),
    .obj_pxl    ( obj_pxl        ),
    .red        ( red            ),
    .green      ( green          ),
    .blue       ( blue           ),
    .gfx_en     ( gfx_en         ),
    .debug_bus  ( debug_bus      )
);

endmodule
