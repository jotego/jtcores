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
    Date: 30-4-2022 */

module jtvigil_video(
    input         rst,
    input         clk,
    input         clk_cpu,

    input         flip,
    input         pxl_cen,
    input         pxl2_cen,

    output        LHBL,
    output        LVBL,
    output        HS,
    output        VS,
    output        v1,

    input  [ 7:0] main_addr,
    input  [ 7:0] main_dout,
    input         main_rnw,

    input  [ 8:0] scr1pos,
    output        scr1_cs,
    output [17:2] scr1_addr,
    input  [31:0] scr1_data,
    input         scr1_ok,

    input  [10:0] scr2pos,
    input  [ 2:0] scr2col,
    output [18:2] scr2_addr,
    input  [31:0] scr2_data,
    output        scr2_cs,
    input         scr2_ok,
    input         scr2enb,

    input         oram_cs,
    output [18:2] obj_addr,
    input  [31:0] obj_data,
    output        obj_cs,
    input         obj_ok,

    // Scroll VRAM
    output [11:0] vram_addr,
    input  [ 7:0] vram_dout,
    // Palette RAM
    output [10:0] pal_addr,
    input  [ 7:0] pal_dout,

    output [ 4:0] red,
    output [ 4:0] green,
    output [ 4:0] blue,

    input  [ 3:0] gfx_en,
    input  [ 7:0] debug_bus
);

wire [8:0] h;
wire [8:0] v, vrender;
wire [3:0] scr2_pxl;
wire [7:0] scr1_pxl, obj_pxl;

assign v1 = v[0];

// Measured on the original PCB
// Pixel clock is 6.144MHz
// H: 256 active pixels, 128 blank pixels
// HSync lasts for 32 pixels, from pixel 40 to 72.
// V blank lasts for 28 lines
// V sync starts 8 lines after Vblank and lasts for 6 lines
// H freq 16.00 kHz
// V freq 56.34  Hz
localparam [8:0] HDLY = 8;

jtframe_vtimer #(
    .HB_END   ( HDLY                    ),
    .HB_START ( 9'd255+HDLY+9'd1        ),
    .HS_START ( 9'd255+HDLY+9'd40       ),
    .HS_END   ( 9'd255+HDLY+9'd40+9'd32 ),
    .HCNT_END ( 9'd383             ),

    .V_START  ( 9'd0               ),
    .VB_START ( 9'd255             ),
    .VS_START ( 9'd255+9'd8        ),
    .VS_END   ( 9'd255+9'd8+9'd6   ),
    .VB_END   ( 9'd283             )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( v         ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( h         ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

jtvigil_scr1 u_scr1 (
    .rst      ( rst         ),
    .clk      ( clk         ),
    .clk_cpu  ( clk_cpu     ),
    .pxl_cen  ( pxl_cen     ),
    // VRAM
    .scan_addr( vram_addr   ),
    .scan_dout( vram_dout   ),
    // video
    .flip     ( flip        ),
    .hs       ( HS          ),
    .h        ( h           ),
    .v        ( v           ),
    .scrpos   ( scr1pos     ),
    .rom_addr ( scr1_addr   ),
    .rom_data ( scr1_data   ),
    .rom_cs   ( scr1_cs     ),
    .rom_ok   ( scr1_ok     ),
    .pxl      ( scr1_pxl    ),
    .debug_bus( debug_bus   )
);

jtvigil_scr2 u_scr2 (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .pxl_cen    ( pxl_cen     ),
    .flip       ( flip        ),
    .LHBL       ( LHBL        ),
    .LVBL       ( LVBL        ),
    .HS         ( HS          ),
    .h          ( h           ),
    .v          ( vrender     ),
    .scrpos     ( scr2pos     ),
    .rom_addr   ( scr2_addr   ),
    .rom_data   ( scr2_data   ),
    .rom_cs     ( scr2_cs     ),
    .rom_ok     ( scr2_ok     ),
    .pxl        ( scr2_pxl    ),
    .debug_bus  ( debug_bus   )
);

`ifndef NOOBJ
jtvigil_obj u_obj (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .clk_cpu    ( clk_cpu     ),
    .pxl_cen    ( pxl_cen     ),
    .flip       ( flip        ),
    .LHBL       ( LHBL        ),
    .main_addr  ( main_addr   ),
    .main_dout  ( main_dout   ),
    .oram_cs    ( oram_cs     ),
    .h          ( h           ),
    .v          ( vrender     ),
    .rom_addr   ( obj_addr    ),
    .rom_data   ( obj_data    ),
    .rom_cs     ( obj_cs      ),
    .rom_ok     ( obj_ok      ),
    .pxl        ( obj_pxl     ),
    .debug_bus  ( debug_bus   )
);
`else
    assign obj_cs   = 0;
    assign obj_addr = 0;
    assign obj_pxl  = 0;
`endif

jtvigil_colmix u_colmix (
    .rst      ( rst            ),
    .clk      ( clk            ),
    .pxl_cen  ( pxl_cen        ),
    .LHBL     ( LHBL           ),
    .LVBL     ( LVBL           ),
    .v        ( v              ),
    .scr1_pxl ( scr1_pxl       ),
    .scr2col  ( scr2col        ),
    .scr2_pxl ( scr2_pxl       ),
    .scr2enb  ( scr2enb        ),
    .obj_pxl  ( obj_pxl        ),
    // Palette RAM
    .pal_addr ( pal_addr       ),
    .pal_dout ( pal_dout       ),

    .red      ( red            ),
    .green    ( green          ),
    .blue     ( blue           ),
    // Debig
    .gfx_en   ( gfx_en         ),
    .debug_bus( debug_bus      )
);


endmodule