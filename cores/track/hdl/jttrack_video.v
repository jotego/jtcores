/*  This file is part of JTKICKER.
    JTKICKER program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKICKER program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKICKER.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-3-2022 */

module jttrack_video(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,
    input               pxl2_cen,

    // configuration
    input               flip,

    // CPU interface
    input        [11:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               cpu_rnw,

    input               vram_cs,
    output        [7:0] vram_dout,

    input               objram_cs,
    output        [7:0] obj_dout,

    // PROMs
    input         [7:0] prog_data,
    input        [10:0] prog_addr,
    input               prom_en,

    // Scroll
    output       [12:0] scr_addr,
    input        [31:0] scr_data,
    input               scr_ok,

    // Objects
    output       [13:0] obj_addr,
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

wire       preLHBL, preLVBL;
wire [8:0] vdump, vrender, hdump;
wire [8:0] hpos;
wire [3:0] obj_pxl, scr_pxl;
reg  [2:0] prom_we;
wire [9:0] prom_offset;

assign prom_offset = prog_addr[9:0]-10'h20;

always @* begin
    prom_we = 0;
    if( prom_en ) begin
        if( prog_addr[9:0] < 10'h20 )
            prom_we[0] = 1; // Final colour PROM
        else if( prog_addr[9:0]<10'h120 )
            prom_we[1] = 1; // OBJ
        else if( prog_addr[9:0]<10'h220 )
            prom_we[2] = 1; // SCR
    end
end

jtkicker_vtimer u_vtimer(
    .clk    ( clk       ),
    .pxl_cen( pxl_cen   ),
    .vdump  ( vdump     ),
    .vrender( vrender   ),
    .hdump  ( hdump     ),
    .hinit  (           ),
    .LHBL   ( preLHBL   ),
    .LVBL   ( preLVBL   ),
    .HS     ( HS        ),
    .VS     ( VS        )
);

jttrack_scroll u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    .vram_cs    ( vram_cs   ),
    .vram_dout  ( vram_dout ),

    // Row scroll
    .hpos       ( hpos      ),

    // video inputs
    .LHBL       ( preLHBL   ),
    .vdump      ( vdump[7:0]),
    .hdump      ( hdump     ),
    .flip       ( flip      ),

    // PROMs
    .prog_data  ( prog_data[3:0] ),
    .prog_addr  ( prom_offset[7:0] ),
    .prog_en    ( prom_we[2]),

    // SDRAM
    .rom_addr   ( scr_addr  ),
    .rom_data   ( scr_data  ),
    .rom_ok     ( scr_ok    ),

    .pxl        ( scr_pxl   ),
    .debug_bus  ( debug_bus )
);

jttrack_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),      // 48 MHz
    .clk24      ( clk24     ),      // 24 MHz

    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .cpu_addr   ( cpu_addr[10:0] ),
    .cpu_dout   ( cpu_dout  ),
    .obj_cs     ( objram_cs ),
    .cpu_rnw    ( cpu_rnw   ),
    .obj_dout   ( obj_dout  ),

    // video inputs
    .hinit      ( HS        ), // to ensure that vdump is right for the row scroll
    .LHBL       ( preLHBL   ),
    .LVBL       ( LVBL      ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .flip       ( flip      ),

    // row scroll
    .hpos       ( hpos      ),

    // PROMs
    .prog_data  ( prog_data[3:0] ),
    .prog_addr  ( prom_offset[7:0] ),
    .prog_en    ( prom_we[1]),

    // SDRAM
    .rom_cs     ( obj_cs    ),
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),
    .rom_ok     ( obj_ok    ),

    .pxl        ( obj_pxl   )
);

jtyiear_colmix #(.BLANK_DLY(9)) u_colmix(
    .clk        ( clk       ),

    .pxl_cen    ( pxl_cen   ),

    // video inputs
    .obj_pxl    ( obj_pxl   ),
    .scr_pxl    ( scr_pxl   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),

    // PROMs
    .prog_data  (prog_data  ),
    .prog_addr  (prog_addr[4:0]),
    .prog_en    (prom_we[0] ),

    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    )
);

endmodule