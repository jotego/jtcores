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
    Date: 21-12-2021 */

/* verilator tracing_off */

module jtkicker_vtimer(
    input               clk,        
    input               pxl_cen,
    output        [8:0] vdump,
    output        [8:0] vrender,
    output        [8:0] hdump,
    output              hinit,
    output              LHBL,
    output              LVBL,
    output              HS,
    output              VS
);

parameter LAYOUT = 0;

localparam [8:0] VB_START = LAYOUT==3 ? 9'd238 : 9'd239,
                 VB_END   = LAYOUT==3 ? 9'd014 : 9'd015;

`ifdef VERILATOR
    /* verilator tracing_on */
    integer frame_cnt=0;
    reg VSl;
    always @(posedge clk) begin
        VSl <= VS;
        if( VS && !VSl ) frame_cnt<=frame_cnt+1;
    end
    wire [8:0] H = hdump^9'h100; // original count
    wire [4:0] pinpon_obj = { &H[8:7],~H[8],H[6:4]};
    /* verilator tracing_off */
`endif

// The original counter keeps hdump[7] high
// while hdump[8] is high (i.e. during HBLANK)
// The rest of the count should match quite well
// the original, particularly VBLANK, H period
// and V period
jtframe_vtimer #(
    .VB_START   (  VB_START ),
    .VB_END     (  VB_END   ),
    .VCNT_END   (  9'd263   ),
    .VS_START   (  9'd260   ),
    .HB_END     (  9'd383   ),
    .HB_START   (  9'd255   ),
    .HCNT_END   (  9'd383   ),
    .HS_START   (  9'h12F   ),
    .HS_END     (  9'h14F   )
) u_vtimer(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .vdump      ( vdump     ),
    .vrender    ( vrender   ),
    .vrender1   (           ),
    .H          ( hdump     ),
    .Hinit      ( hinit     ),
    .Vinit      (           ),
    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        )
);

endmodule