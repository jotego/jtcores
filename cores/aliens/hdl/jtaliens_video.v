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

module jtaliens_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    // Base Video
    output            lhbl,
    output            lvbl,
    output            hs,
    output            vs,

    // CPU interface
    input      [15:0] cpu_addr,
    input      [ 7:0] cpu_dout
    output     [ 7:0] pal_dout,
    output     [ 7:0] tilemap_dout,
    output     [ 7:0] tilerom_dout,
    input             pal_we,
    input             tilemap_we,
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode
    input      [ 2:0] prio_cfg,

    output            cpu_irq_n,
    output            cpu_firq_n,
    output            cpu_nmi_n,
    output            flip,

    // PROMs
    input      [ 7:0] prog_addr,
    input      [ 1:0] prog_data,
    input             prom_we,

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

    // Color
    output     [ 4:0] red,
    output     [ 4:0] green,
    output     [ 4:0] blue,

    // Debug
    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus,
    output     [ 7:0] st_dout
);

wire [ 8:0] hdump;
wire [ 7:0] lyrf_pxl;
wire [11:0] lyra_pxl, lyrb_pxl;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n;
wire        prio_we;

assign prio_we = prom_we & ~prog_addr[7];

jtaliens_scroll u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),
    .hs         ( hs        ),
    .vs         ( vs        ),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_din    ( cpu_din   ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( tilemap_we),
    .rst8       ( rst8      ),

    // control
    .rmrd       ( rmrd      ),
    .hdump      ( hdump     ),

    .irq_n      ( cpu_irq_n ),
    .firq_n     ( cpu_firq_n),
    .nmi_n      ( cpu_nmi_n ),
    .flip       ( flip      ),


    // Tile ROMs
    .fix_addr   ( fix_addr  ),
    .lyra_addr  ( lyra_addr ),
    .lyrb_addr  ( lyrb_addr ),

    .fix_cs     ( fix_cs    ),
    .lyra_cs    ( lyra_cs   ),
    .lyrb_cs    ( lyrb_cs   ),

    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),

    // Final pixels
    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),

    // Debug
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus ),
    .st_dout    ( st_dout   ),
);

jtaliens_colmix u_colmix(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // Base Video
    .lhbl       ( lhbl      ),
    .lvbl       ( lvbl      ),

    input      [ 2:0] prio_cfg,
    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_din    ( pal_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_we     ( pal_we    ),

    // PROMs
    .prog_addr  (prog_addr[6:0]),
    .prog_data  ( prog_data ),
    .prom_we    ( prio_we   ),

    // Final pixels
    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyro_blnk_n( 1'b0      ),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  ),
    .lyro_pxl   ( 8'd0      ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule