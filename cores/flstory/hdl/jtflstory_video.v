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
    Date: 27-10-2024 */

module jtflstory_video(
    input             rst,
    input             clk,
    input             pxl_cen,

    input             hflip,
    input             vflip,
    output            lhbl,
    output            lvbl,
    output            vs,
    output            hs,

    output     [13:2] gfx_addr,
    input      [31:0] gfx_data,
    output            gfx_cs,
    input             gfx_ok,
);

wire [ 8:0] vdump, vrender, hdump;

jtframe_vtimer #(
    .V_START    ( 9'h0f0    ),
    .VCNT_END   ( 9'h1ff    ),
    .VB_START   ( 9'h1ef    ),
    .VB_END     ( 9'h10f    ),
    .VS_START   ( 9'h0f8    ),

    .HCNT_START ( 9'h080    ),
    .HCNT_END   ( 9'h1ff    ),
    .HS_START   ( 9'h0ad    ),
    .HB_START   ( 9'h089    ),
    .HB_END     ( 9'h109    )
)   u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ),
    .VS         ( vs        )
);

endmodule