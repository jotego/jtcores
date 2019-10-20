/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 19-10-2019 */

module jtgng_objcnt #(parameter
    OBJMAX_LINE = 6'd24
) (
    input               clk,
    input               cen /*direct_enable*/,
    input               pxl_cen,
    input               HINIT,
    output              HINIT_short,
    output reg [4:0]    objcnt,
    output reg [3:0]    pxlcnt
);

// HINIT is generated in the pxl_cen domain (6MHz)
// If cen is 8MHz, The HINIT pulse will last for two 8MHz cen pulses
// and that can create problems.
// The signal is resampled here to obtain a shortened version.

reg HINIT_clr, HINIT_latch;
reg last_HINIT;

always @(posedge clk) begin 
    last_HINIT <= HINIT;
    if( HINIT && !last_HINIT) HINIT_latch <= 1'b1;
    if( HINIT_clr ) HINIT_latch <= 1'b0;
end

assign HINIT_short = cen & pxl_cen & (HINIT_latch | HINIT);

reg over;

always @(posedge clk) if(cen) begin
    HINIT_clr <= 1'b0;
    if( HINIT_short ) begin
        { over, objcnt, pxlcnt } <= { 6'd32-OBJMAX_LINE,4'd0};
        HINIT_clr <= HINIT_short;
    end else
        if( !over )  { over, objcnt, pxlcnt } <=  { over, objcnt, pxlcnt } + 1'd1;
end

endmodule