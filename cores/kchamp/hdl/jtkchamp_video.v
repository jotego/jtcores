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
    Date: 3-9-2022 */

module jtkchamp_video(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,
    input               pxl2_cen,

    // configuration
    input               flip,
    input               enc,
    output              v6,

    // CPU interface
    input        [10:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               cpu_rnw,

    input               vram_cs,
    output        [7:0] vram_dout,
    output reg          vram_bsy,

    input               oram_cs,
    output        [7:0] obj_dout,

    // PROMs
    input         [3:0] prog_data,
    input         [9:0] prog_addr,
    input               prom_we,

    // Scroll
    output       [14:1] char_addr,
    input        [15:0] char_data,
    input               char_ok,
    output              char_cs,

    // Objects
    output       [16:2] obj_addr,
    input        [31:0] obj_data,
    output              obj_cs,
    input               obj_ok,

    output              HS,
    output              VS,
    output              LHBL,
    output              LVBL,
    output        [3:0] red,
    output        [3:0] green,
    output        [3:0] blue,
    input         [3:0] gfx_en,
    input         [7:0] debug_bus
);

wire [8:0] vdump, vrender, hdump, vf, hf;
wire [6:0] char_pxl;
wire [5:0] obj_pxl;

assign vf = vdump ^ { 1'b0, {8{flip}}};
assign hf = hdump ^ { 1'b0, {8{flip}}};
assign v6 = vdump[6];

always @(posedge clk) begin
    if( hdump[8] )
        vram_bsy <= 1; // it's odd that it's busy during blanking
    else if( !hdump[1] && pxl_cen )
        vram_bsy <= &hdump[6:3];
end

jtframe_vtimer #(
    .HB_END  ( 9'd9         ),
    .HB_START( 9'd255+9'd10 ),
    .HCNT_END( 9'd383       ),
    .HS_START( 9'd256+9'd64 ),
    .HS_END  ( 9'd256+9'd96 ),
    .VB_START( 9'd239       ),
    .VB_END  ( 9'd15        ),
    .VS_START( 9'd255       ),
    .VS_END  ( 9'd255+9'd8  )
)u_vtimer(
    .clk     ( clk       ),
    .pxl_cen ( pxl_cen   ),
    .vdump   ( vdump     ),
    .vrender ( vrender   ),
    .vrender1(           ),
    .H       ( hdump     ),
    .Hinit   (           ),
    .Vinit   (           ),
    .LHBL    ( LHBL      ),
    .LVBL    ( LVBL      ),
    .HS      ( HS        ),
    .VS      ( VS        )
);

jtkchamp_char u_char(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vf        ),
    .hdump      ( hf        ),
    .flip       ( flip      ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    .vram_cs    ( vram_cs   ),
    .cpu_din    ( vram_dout ),

    // SDRAM
    .rom_addr   ( char_addr ),
    .rom_data   ( char_data ),
    .rom_ok     ( char_ok   ),
    .rom_cs     ( char_cs   ),

    .pxl        ( char_pxl  ),
    .debug_bus  ( debug_bus )
);

jtkchamp_obj u_obj(
    .clk        ( clk       ),      // 48 MHz
    .clk24      ( clk24     ),      // 24 MHz

    .pxl_cen    ( pxl_cen   ),
    .enc        ( enc       ),

    // CPU interface
    .cpu_addr   ( cpu_addr[7:0] ),
    .cpu_dout   ( cpu_dout  ),
    .oram_cs    ( oram_cs   ),
    .cpu_rnw    ( cpu_rnw   ),
    .cpu_din    ( obj_dout  ),

    // video inputs
    .vdump      ( vf        ),
    .hdump      ( hdump     ),
    .hs         ( HS        ),
    .flip       ( flip      ),

    // SDRAM
    .rom_cs     ( obj_cs    ),
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),
    .rom_ok     ( obj_ok    ),
    .debug_bus  ( debug_bus ),

    .pxl        ( obj_pxl   )
);

jtkchamp_colmix u_colmix(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // video inputs
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .obj_pxl    ( obj_pxl   ),
    .char_pxl   ( char_pxl  ),

    // PROMs
    .prog_data  ( prog_data ),
    .prog_addr  ( prog_addr ),
    .prog_en    ( prom_we   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

endmodule