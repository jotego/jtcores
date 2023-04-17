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

jtframe_vtimer #(
    .HCNT_START ( 9'h020    ),
    .HCNT_END   ( 9'h19F    ),
    .HB_START   ( 9'h19F    ),
    .HB_END     ( 9'h05F    ),  // 10.6 us
    .HS_START   ( 9'h033    ),
    .HS_END     ( 9'h04D    ),  //  4.33 us

    .V_START    ( 9'h0F8    ),
    .VB_START   ( 9'h1F0    ),
    .VB_END     ( 9'h110    ),  //  2.56 ms
    .VS_START   ( 9'h0FA    ),
    .VCNT_END   ( 9'h1FF    )   // 16.896 ms (59.18Hz)
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    (           ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ),
    .VS         ( vs        )
);

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


    // tile ROM addressing
    // original pins: { CAB2,CAB1,VC[10:0] }
    // [2:0] tile row (8 lines)
    output reg [12:0] fix_addr,
    output reg [12:0] lyra_addr,
    output reg [12:0] lyrb_addr,
    output reg [ 7:0] fix_col,
    output reg [ 7:0] lyra_col,
    output reg [ 7:0] lyrb_col,

    // subtile addressing
    output     [ 2:0] lyra_hsub,   // original pins: { ZA4H, ZA2H, ZA1H }
    output     [ 2:0] lyrb_hsub,   // original pins: { ZB4H, ZB2H, ZB1H }

    // config to drawing chip 051962
    output            flip_up,  // original pin: BEN
);

endmodule