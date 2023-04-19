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
    Date: 13-12-2022 */

module jtkarnov_video(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              pxl2_cen,
    input              flip,    // Screen flip
    input              wndrplnt,

    output             LHBL,
    output             LVBL,
    output             HS,
    output             VS,
    output      [ 8:0] hdump,

    // fixed layer
    output      [10:1] vram_addr,
    input       [15:0] vram_data,
    output      [14:2] fix_addr,
    input       [31:0] fix_data,
    output             fix_cs,
    input              fix_ok,      // ignored. It assumes that data is always right

    // scroll layer
    output      [10:1] scrram_addr,
    input       [15:0] scrram_data,
    output      [17:2] scr_addr,
    input       [31:0] scr_data,
    output             scr_cs,
    input              scr_ok,      // ignored. It assumes that data is always right

    input      [ 8:0]  scrx,
    input      [ 8:0]  scry,

    // object layer
    output      [11:1] objram_addr,
    input       [15:0] objram_data,
    output      [18:2] obj_addr,
    input       [31:0] obj_data,
    output             obj_cs,
    input              obj_ok,

    // Object buffer DMA (does not halt the CPU)
    output      [11:1] dma_addr,
    input              dma_start,
    output             dma_we,

    input       [10:0] prog_addr,
    input       [ 7:0] prog_data,
    input              prom_we,

    output      [3:0]  red,
    output      [3:0]  green,
    output      [3:0]  blue,

    input       [7:0]  debug_bus,
    input       [3:0]  gfx_en
);

wire [ 8:0] vdump, vrender, vrender1;
wire        blankn, hinit, nc;
wire [ 4:0] fix_pxl, fixg;
wire [ 7:0] scr_pxl, obj_pxl, scrg, objg;
wire [ 1:0] lyr_sel;
wire [17:2] scr_raw;

localparam [1:0] FIX=2'b00, OBJ=2'b01, SCR=2'b10;

assign fixg    = fix_pxl & {5{gfx_en[0]}};
assign objg    = obj_pxl & {8{gfx_en[3]}};
assign scrg    = scr_pxl & {8{gfx_en[1]}};
assign blankn  = ~(VS|HS);
assign lyr_sel = fixg[2:0]!=0 ? FIX : objg[3:0]!=0 ? OBJ : SCR;
assign scr_addr = scr_raw ^ (16'h1<<4); // 16x16 tiles are swapped horizontally

// Using the same as Robocop for now
jtframe_vtimer #(
    .VB_START   ( 9'hf7     ),
    .VB_END     ( 9'd7      ),
    .VCNT_END   ( 9'd271    ),
    .VS_START   ( 9'h106    ),
    .HS_START   ( 9'h1b0    ),
    .HB_START   ( 9'h189    ),
    .HJUMP      ( 1         ),
    .HB_END     ( 9'd9      ),
    .HINIT      ( 9'd255    )
)   u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .H          ( hdump     ),
    .Hinit      ( hinit     ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

wire [10:1] vram_raw;

assign vram_addr = wndrplnt ? {vram_raw[5:1], vram_raw[10:6]} : vram_raw;

jtframe_tilemap #(.PW(6),.CW(10),.XOR_HFLIP(1)) u_fix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),

    .vram_addr  ( vram_raw  ),

    .code       ( vram_data[9:0]   ),
    .pal        ( vram_data[15:14]  ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( fix_addr  ),
    .rom_data   ( fix_data  ),
    .rom_cs     ( fix_cs    ),
    .rom_ok     ( fix_ok    ),

    .pxl        ( { fix_pxl[4:3], fix_pxl[2:0], nc } ) // the fix layer is only 3 bpp
);

jtframe_scroll #(.SIZE(16),.PW(8),.VA(10),.CW(11),.XOR_HFLIP(1)) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( blankn    ),
    .flip       ( flip      ),
    .scrx       ( scrx      ),
    .scry       ( scry      ),
    .hs         ( HS        ),

    .vram_addr  ( scrram_addr ),

    .code       ( scrram_data[10:0]  ),
    .pal        ( scrram_data[15:12] ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),

    .rom_addr   ( scr_raw   ),
    .rom_data   ( scr_data  ),
    .rom_cs     ( scr_cs    ),
    .rom_ok     ( scr_ok    ),

    .pxl        ( scr_pxl   )
);

jtkarnov_obj u_obj(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .vrender    ( vrender   ),
    .hdump      ( hdump     ),
    .flip       ( flip      ),
    .hs         ( HS        ),

    .ram_addr   (objram_addr),
    .ram_data   (objram_data),

    .dma_start  ( dma_start ),
    .dma_addr   ( dma_addr  ),
    .dma_we     ( dma_we    ),

    .rom_addr   ( obj_addr  ),
    .rom_data   ( obj_data  ),
    .rom_cs     ( obj_cs    ),
    .rom_ok     ( obj_ok    ),

    .debug_bus  ( debug_bus ),

    .pxl        ( obj_pxl   )
);

jtframe_prom_colmix #(
    .CODING("BGR"),
    .SIMFILE0("../../../../rom/chelnov/ee-17.k8"),
    .SIMFILE1("../../../../rom/chelnov/ee-16.l6")
)u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),

    .lyr0_addr  ( {lyr_sel,3'd0, fixg } ),
    .lyr1_addr  ( {lyr_sel,objg } ),
    .lyr2_addr  ( {lyr_sel,scrg } ),
    .lyr3_addr  ( 10'd0     ),
    .lyr_sel    ( lyr_sel   ),

    .prog_addr  ( prog_addr ),
    .prog_data  ( prog_data ),
    .prom_we    ( prom_we   ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )

);

endmodule