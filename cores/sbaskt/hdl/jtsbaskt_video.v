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
    Date: 29-12-2021 */

module jtsbaskt_video(
    input               rst,
    input               clk,        // 48 MHz
    input               clk24,      // 24 MHz

    input               pxl_cen,
    input               pxl2_cen,

    // configuration
    input         [3:0] pal_sel,
    input               flip,

    // CPU interface
    input        [10:0] cpu_addr,
    input         [7:0] cpu_dout,
    input               cpu_rnw,

    input               vram_cs,
    input               vscr_cs,
    output        [7:0] vram_dout,
    output        [7:0] vscr_dout,

    input               objram_cs,
    input               obj_frame,
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
    output              V16,
    output              LHBL,
    output              LVBL,
    output        [3:0] red,
    output        [3:0] green,
    output        [3:0] blue,
    input         [3:0] gfx_en,
    input         [7:0] debug_bus
);

wire       preLHBL, preLVBL, hinit;
wire [8:0] vdump, vrender, hdump;
wire [3:0] obj_pxl, scr_pxl;
wire       scr_prio;
reg  [2:0] prog_rgb;
reg        prog_scr, prog_obj;

assign V16 = vdump[4];

always @(*) begin
    prog_obj = 0;
    prog_scr = 0;
    prog_rgb = 0;
    if( prom_en )
        case( prog_addr[10:8] )
            0: prog_rgb = 1;
            1: prog_rgb = 2;
            2: prog_rgb = 4;
            3: prog_scr = 1;
            4: prog_obj = 1;
            default:;
        endcase
end

jtkicker_vtimer u_vtimer(
    .clk    ( clk       ),
    .pxl_cen( pxl_cen   ),
    .vdump  ( vdump     ),
    .vrender( vrender   ),
    .hdump  ( hdump     ),
    .hinit  ( hinit     ),
    .LHBL   ( preLHBL   ),
    .LVBL   ( preLVBL   ),
    .HS     ( HS        ),
    .VS     ( VS        )
);

jtkicker_scroll #(.LAYOUT(2)) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk24      ( clk24     ),

    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_rnw    ( cpu_rnw   ),
    .vram_cs    ( vram_cs   ),
    .vscr_cs    ( vscr_cs   ),
    .vram_dout  ( vram_dout ),
    .vscr_dout  ( vscr_dout ),

    // video inputs
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .vdump      ( vdump[7:0]),
    .hdump      ( hdump     ),
    .flip       ( flip      ),

    // PROMs
    .prog_data  ( prog_data[3:0] ),
    .prog_addr  ( prog_addr[7:0] ),
    .prog_en    ( prog_scr       ),

    // SDRAM
    .rom_addr   ( scr_addr  ),
    .rom_data   ( scr_data  ),
    .rom_ok     ( scr_ok    ),

    .pxl        ( scr_pxl   ),
    .prio       ( scr_prio  ),
    .debug_bus  (           )
);

jtsbaskt_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),      // 48 MHz
    .clk24      ( clk24     ),      // 24 MHz

    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .cpu_addr   ( cpu_addr[9:0] ),
    .cpu_dout   ( cpu_dout  ),
    .obj_cs     ( objram_cs ),
    .cpu_rnw    ( cpu_rnw   ),
    .obj_dout   ( obj_dout  ),
    .obj_frame  ( obj_frame ),

    // video inputs
    .hinit      ( hinit     ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .vrender    (vrender[7:0]),
    .hdump      ( hdump     ),
    .flip       ( flip      ),

    // PROMs - Unused
    .prog_data  ( prog_data[3:0] ),
    .prog_addr  ( prog_addr[7:0] ),
    .prog_en    ( prog_obj       ),

    // SDRAM
    .rom_cs     ( obj_cs    ),
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),
    .rom_ok     ( obj_ok    ),

    .pxl        ( obj_pxl   ),
    .debug_bus  ( debug_bus )
);

jtsbaskt_colmix u_colmix(
    .clk        ( clk       ),

    .pxl_cen    ( pxl_cen   ),
    .pal_sel    ( pal_sel   ),
    .scr_prio   ( scr_prio  ),
    // video inputs
    .obj_pxl    ( obj_pxl   ),
    .scr_pxl    ( scr_pxl   ),
    .preLHBL    ( preLHBL   ),
    .preLVBL    ( preLVBL   ),

    // PROMs
    .prog_data  ( prog_data[3:0] ),
    .prog_addr  ( prog_addr[7:0] ),
    .prog_en    ( prog_rgb       ),

    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    )
);

endmodule