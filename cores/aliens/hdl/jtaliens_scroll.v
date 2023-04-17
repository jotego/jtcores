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
    input             we,
    input      [ 7:0] din,      // data can be written to any RAM chip attached
    input      [15:0] addr,
    output            dout,     // only half data bus available upon settings
    output            rst8,     // reset signal at 8th frame

    // control
    input             rmrd,     // Tile ROM read mode
    output     [ 8:0] hdump,
    output     [ 8:0] vdump,

    output            irq_n,
    output            firq_n,
    output            nmi_n,
    output            flip,


    // Tile ROMs
    output     [12:0] fix_addr,
    output     [12:0] lyra_addr,
    output     [12:0] lyrb_addr,
);

wire [ 7:0] fix_col,
            lyra_col,  lyrb_col;
wire [ 2:0] lyra_hsub, lyrb_hsub;
wire        hflip_en;

jt052109 u_tilemap(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    // CPU interface
    .we         ( we        ),
    .din        ( din       ),
    .addr       ( addr      ),
    .dout       ( dout      ),
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
    .fix_col    ( fix_col   ),
    .lyra_col   ( lyra_col  ),
    .lyrb_col   ( lyrb_col  ),

    // subtile addressing
    .lyra_hsub  ( lyra_hsub ),   // original pins: { ZA4H, ZA2H, ZA1H }
    .lyrb_hsub  ( lyrb_hsub )    // original pins: { ZB4H, ZB2H, ZB1H }
);

endmodule