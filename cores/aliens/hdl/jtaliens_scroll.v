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
    Date: 15-4-2023 */

module jtaliens_scroll(
    input             rst,
    input             clk,
    input             pxl_cen,

    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    // CPU interface
    input             cpu_we,
    input      [ 7:0] cpu_dout
    input      [15:0] cpu_addr,
    output     [ 7:0] tilemap_dout,
    output     [ 7:0] tilerom_dout,
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode
    output     [ 8:0] hdump,

    output            irq_n,
    output            firq_n,
    output            nmi_n,
    output            flip,


    // Tile ROMs
    output     [12:0] fix_addr,
    output     [12:0] lyra_addr,
    output     [12:0] lyrb_addr,

    output            fix_cs,
    output            lyra_cs,
    output            lyrb_cs,

    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,

    // Final pixels
    output            lyrf_blnk_n,
    output            lyra_blnk_n,
    output            lyrb_blnk_n,
    output     [ 7:0] lyrf_pxl,
    output     [11:0] lyra_pxl,
    output     [11:0] lyrb_pxl,

    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [ 7:0] lyrf_col,
            lyra_col,  lyrb_col;
wire [ 2:0] lyra_hsub, lyrb_hsub;
wire        hflip_en;
wire [ 8:0] hdump;

assign fix_cs  = gfx_en[0];
assign lyra_cs = gfx_en[1];
assign lyra_cs = gfx_en[2];

jt052109 u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_din    (tilemap_dout),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( cpu_we    ),
    .rst8       ( rst8      ),

    // control
    .rmrd       ( rmrd      ),
    .hdump      ( hdump     ),
    .vdump      ( vdump     ),

    .irq_n      ( irq_n     ),
    .firq_n     ( firq_n    ),
    .nmi_n      ( nmi_n     ),
    .flip       ( flip      ),
    .hflip_en   ( hflip_en  ),

    // tile ROM addressing
    // original pins: { CAB2,CAB1,VC[10:0] }
    // [2:0] tile row (8 lines)
    .fix_addr   ( fix_addr  ),
    .lyra_addr  ( lyra_addr ),
    .lyrb_addr  ( lyrb_addr ),

    .lyrf_col   ( lyrf_col  ),
    .lyra_col   ( lyra_col  ),
    .lyrb_col   ( lyrb_col  ),

    // Debug
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   )
);

jt051962 u_draw(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .flip       ( flip      ),
    .hflip_en   ( hflip_en  ),

    .cpu_addr   ( cpu_addr  ),
    .cpu_din    (tilerom_dout),

    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),

    .lyrf_col   ( lyrf_col  ),
    .lyra_col   ( lyra_col  ),
    .lyrb_col   ( lyrb_col  ),

    .hdump      ( hdump     ),
    .vdump      ( vdump     ),
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),

    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),

    // Debug
    .gfx_en     ( gfx_en    )
);

endmodule