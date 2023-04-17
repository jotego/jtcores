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
    output     [ 7:0] cpu_din,
    input             cpu_we,
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode

    output            irq_n,
    output            firq_n,
    output            nmi_n,
    output            flip,


    // Tile ROMs
    output     [12:0] fix_addr,
    output     [12:0] lyra_addr,
    output     [12:0] lyrb_addr,

    input      [31:0] lyrf_data,
    input      [31:0] lyra_data,
    input      [31:0] lyrb_data,

    input      [ 3:0] gfx_en,
    input      [ 7:0] debug_bus
);

wire [ 8:0] hdump;
wire [ 7:0] lyrf_pxl;
wire [11:0] lyra_pxl, lyrb_pxl;
wire        lyrf_blnk_n, lyra_blnk_n, lyrb_blnk_n;

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
    .cpu_we     ( cpu_we    ),
    .rst8       ( rst8      ),

    // control
    .rmrd       ( rmrd      ),
    .hdump      ( hdump     ),

    .irq_n      ( irq_n     ),
    .firq_n     ( firq_n    ),
    .nmi_n      ( nmi_n     ),
    .flip       ( flip      ),


    // Tile ROMs
    .fix_addr   ( fix_addr  ),
    .lyra_addr  ( lyra_addr ),
    .lyrb_addr  ( lyrb_addr ),

    .lyrf_data  ( lyrf_data ),
    .lyra_data  ( lyra_data ),
    .lyrb_data  ( lyrb_data ),

    // Final pixels
    .lyrf_blnk_n(lyrf_blnk_n),
    .lyra_blnk_n(lyra_blnk_n),
    .lyrb_blnk_n(lyrb_blnk_n),
    .lyrf_pxl   ( lyrf_pxl  ),
    .lyra_pxl   ( lyra_pxl  ),
    .lyrb_pxl   ( lyrb_pxl  )
);

endmodule