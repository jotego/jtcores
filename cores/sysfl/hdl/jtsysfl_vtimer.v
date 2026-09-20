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

    Author: Andrea Bogazzi. email: andreabogazzi79@gmail.com
    Version: 1.0
    Date: 18-9-2026
*/

// 288x224 visible in 384x264 total, 6.048 MHz pixel clock (48.384/8)
module jtsysfl_vtimer(
    input             clk,
    input             pxl_cen,
    output     [ 8:0] vdump, vrender, vrender1, hdump,
    output            lhbl, lvbl, hs, vs
);

`include "vtimer.vh"

jtframe_vtimer #(
    .HCNT_START ( 9'h000    ),
    .HCNT_END   ( 9'h17F    ),
    .HB_START   ( HB_START  ),
    .HB_END     ( HB_END    ),
    .HS_START   ( HS_START  ),
    .HS_END     ( HS_END    ),

    .V_START    ( V_START   ),
    .VB_START   ( VB_START  ),
    .VB_END     ( VB_END    ),
    .VS_START   ( VS_START  ),
    .VS_END     ( VS_END    ),
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
    .HS         ( hs        ),
    .VS         ( vs        )
);

endmodule
