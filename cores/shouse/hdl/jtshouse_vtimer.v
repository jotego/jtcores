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
    Date: 15-3-2025 */

// See https://github.com/jotego/jtcores/issues/348
module jtshouse_vtimer(
    input             clk,
    input             pxl_cen,
    output     [ 8:0] vdump, vrender, vrender1, hdump,
    output            lhbl, lvbl, hs, vs
);

`include "vtimer.vh"

jtframe_vtimer #(
    .HCNT_START ( 9'h000    ),
    .HCNT_END   ( 9'h17F    ),
    .HB_START   ( 9'h160    ), // 288 visible, 384 total (96 pxl=HB)
    .HB_END     ( 9'h040    ), // Fixed layer is mapped for a counter that leaves blanking at $40
    .HS_START   ( HS_START  ), // HS starts 32 pixels after HB
    .HS_END     ( HS_END    ), // 32 pixel wide

    .V_START    ( V_START   ), // 224 visible, 40 blank, 264 total
    .VB_START   ( VB_START  ),
    .VB_END     ( VB_END    ),
    .VS_START   ( VS_START  ), // 8 lines wide, 8 lines after VB start
    .VS_END     ( VS_END    ), // 60.6 Hz according to MAME
    .VCNT_END   ( VCNT_END  )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   ( vrender1  ),
    .H          ( hdump     ),
    .Hinit      (           ),
    .Vinit      (           ),
    .LHBL       ( lhbl      ),
    .LVBL       ( lvbl      ),
    .HS         ( hs        ), // 16kHz
    .VS         ( vs        )
);

endmodule