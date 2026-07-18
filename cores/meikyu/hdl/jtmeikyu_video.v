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

module jtmeikyu_video(
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
    output [ 7:0] obj_dout,
    input         main_rnw,

    output        scr1_cs,
    output [17:2] scr1_addr,
    input  [31:0] scr1_data,
    input         scr1_ok,

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
wire [7:0] scr1_pxl, obj_pxl;

assign v1 = v[0];

// MAME: set_raw(24MHz/3, 512, 64, 448, 284, 0, 256)
// Pixel clock 8 MHz (8.192 MHz here, clk/6)
// H: 384 active pixels, 512 total
// V blank lasts for 28 lines, 284 total
// V sync starts 8 lines after Vblank and lasts for 6 lines
// H freq 16.00 kHz
// V freq 56.34  Hz
localparam [8:0] HDLY = 8;

jtframe_vtimer #(
    .HB_END   ( HDLY                    ),
    .HB_START ( 9'd383+HDLY+9'd1        ),
    .HS_START ( 9'd383+HDLY+9'd40       ),
    .HS_END   ( 9'd383+HDLY+9'd40+9'd32 ),
    .HCNT_END ( 9'd511             ),

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

jtmeikyu_scr1 u_scr1 (
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
    .rom_addr ( scr1_addr   ),
    .rom_data ( scr1_data   ),
    .rom_cs   ( scr1_cs     ),
    .rom_ok   ( scr1_ok     ),
    .pxl      ( scr1_pxl    ),
    .debug_bus( debug_bus   )
);

`ifndef NOOBJ
jtvigil_obj #(.XBASE(9'h1bd),.VSCORE(9'd0),.CODE_SWAP(0)) u_obj (
    .rst        ( rst         ),
    .clk        ( clk         ),
    .clk_cpu    ( clk_cpu     ),
    .pxl_cen    ( pxl_cen     ),
    .flip       ( flip        ),
    .LHBL       ( LHBL        ),
    .main_addr  ( main_addr   ),
    .main_dout  ( main_dout   ),
    .main_din   ( obj_dout    ),
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

jtmeikyu_colmix u_colmix (
    .rst      ( rst            ),
    .clk      ( clk            ),
    .pxl_cen  ( pxl_cen        ),
    .LHBL     ( LHBL           ),
    .LVBL     ( LVBL           ),
    .scr1_pxl ( scr1_pxl       ),
    .obj_pxl  ( obj_pxl        ),
    .pal_addr ( pal_addr       ),
    .pal_dout ( pal_dout       ),

    .red      ( red            ),
    .green    ( green          ),
    .blue     ( blue           ),
    .gfx_en   ( gfx_en         ),
    .debug_bus( debug_bus      )
);


endmodule