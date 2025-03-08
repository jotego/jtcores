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
    Date: 1-1-2025 */

module jtgaiden_video(
    input               rst,
    input               clk,

    input               pxl2_cen,
    input               pxl_cen,
    input               objdly, vsize_en,
    input        [ 1:0] frmbuf_en,

    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS,

    input               flip,

    // scroll registers
    input        [15:0] txt_x, txt_y, scra_x, scrb_x, scra_y, scrb_y,
    input        [ 7:0] obj_y,

    // video RAM
    output       [11:1] tram_addr,
    input        [15:0] tram_dout,

    output       [12:1] scra_addr,
    input        [15:0] scra_dout,

    output       [12:1] scrb_addr,
    input        [15:0] scrb_dout,

    output       [12:1] oram_addr,
    input        [15:0] oram_dout,

    output       [12:1] pal_addr,
    input        [15:0] pal_dout,

    // ROM
    output              txt_cs,
    output       [15:2] txt_addr,
    input        [31:0] txt_data,
    input               txt_ok,

    output              scr1_cs,
    output       [18:2] scr1_addr,
    input        [31:0] scr1_data,
    input               scr1_ok,

    output              scr2_cs,
    output       [18:2] scr2_addr,
    input        [31:0] scr2_data,
    input               scr2_ok,

    output              obj_cs,
    output       [19:2] obj_addr,
    input        [31:0] obj_data,
    input               obj_ok,

    // Colours
    output       [ 3:0] red,
    output       [ 3:0] green,
    output       [ 3:0] blue,
    // Test
    input        [ 3:0] gfx_en,
    input        [ 7:0] debug_bus
);

wire [ 8:0] vdump, hdump, vrender;
wire [ 7:0] txt_pxl;
wire [ 8:0] scr1_pxl, scr2_pxl;
wire [10:0] obj_pxl;
// shorter blankings used to cut access to SDRAM
reg         vblankn, hblankn, cblankn;

always @(posedge clk) begin
    vblankn <= !(vdump>9'o400 || vdump<9'o32);
    hblankn <= !(hdump>9'o411);
    cblankn <= vblankn & hblankn;
end

jtframe_vtimer #(
    .HS_START( 9'o452 ),
    .HB_START( 9'o410 ),
    .HB_END  ( 9'o010 ),
    .HCNT_END( 9'o577 ),

    .V_START ( 9'o020 ),
    .VS_START( 9'o030 ),
    .VS_END  ( 9'o033 ),
    .VB_START( 9'o377 ),
    .VB_END  ( 9'o037 ),
    .VCNT_END( 9'o427 )
)u_timer(
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .vrender1   (               ),
    .H          ( hdump         ),
    .Hinit      (               ),
    .Vinit      (               ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            )
);

jtgaiden_text u_text(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .blankn     ( cblankn   ),
    .flip       ( flip      ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .scr_x      ( txt_x[7:0]),
    .scr_y      ( txt_y[7:0]),
    .ram_addr   ( tram_addr ),
    .ram_dout   ( tram_dout ),
    .rom_cs     ( txt_cs    ),
    .rom_addr   ( txt_addr  ),
    .rom_data   ( txt_data  ),
    .rom_ok     ( txt_ok    ),
    .pxl        ( txt_pxl   )
);

jtgaiden_scroll u_scr1(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .blankn     ( cblankn   ),
    .flip       ( flip      ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .scr_x      ( scra_x    ),
    .scr_y      ( scra_y    ),
    .ram_addr   ( scra_addr ),
    .ram_dout   ( scra_dout ),
    .rom_cs     ( scr1_cs   ),
    .rom_addr   ( scr1_addr ),
    .rom_data   ( scr1_data ),
    .rom_ok     ( scr1_ok   ),
    .pxl        ( scr1_pxl  )
);

jtgaiden_scroll u_scr2(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( HS        ),
    .blankn     ( cblankn   ),
    .flip       ( flip      ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .scr_x      ( scrb_x    ),
    .scr_y      ( scrb_y    ),
    .ram_addr   ( scrb_addr ),
    .ram_dout   ( scrb_dout ),
    .rom_cs     ( scr2_cs   ),
    .rom_addr   ( scr2_addr ),
    .rom_data   ( scr2_data ),
    .rom_ok     ( scr2_ok   ),
    .pxl        ( scr2_pxl  )
);

jtgaiden_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .flip       ( flip      ),
    .blankn     ( vblankn   ),
    .frmbuf_en  ( frmbuf_en ),
    .objdly     ( objdly    ),
    .vsize_en   ( vsize_en  ),

    .lvbl       ( LVBL      ),
    .hs         ( HS        ),
    .hdump      ( hdump     ),
    .vrender    ( vdump     ),
    .scry       ( obj_y     ),

    .ram_addr   ( oram_addr ),
    .ram_dout   ( oram_dout ),

    .rom_cs     ( obj_cs    ),
    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),
    .rom_ok     ( obj_ok    ),

    .pxl        ( obj_pxl   ),
    .debug_bus  ( debug_bus )
);

jtgaiden_colmix u_colmix(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .pal_addr   ( pal_addr  ),
    .pal_dout   ( pal_dout  ),

    .txt_pxl    ( txt_pxl   ),
    .scr1_pxl   ( scr1_pxl  ),
    .scr2_pxl   ( scr2_pxl[7:0] ), // no blending bit
    .obj_pxl    ( obj_pxl   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
);

endmodule