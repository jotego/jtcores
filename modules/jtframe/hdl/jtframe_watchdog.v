/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-3-2025 */

module jtframe_watchdog #(
    parameter
        W=3,
        INVERT=0    // wdog=!INVERT when a watchdog event occurs
)(
    input  rst, clk, lvbl, clr,
    output reg wdog
);

reg [W-1:0] cnt=0;
reg lvbl_l=0;
wire frame = ~lvbl &lvbl_l;

localparam [0:0] RESET=~INVERT[0], ACTIVE=INVERT[0];

always @(posedge clk) begin
    lvbl_l  <= lvbl;
end

always @(posedge clk) begin
    wdog <= &cnt ? RESET : ACTIVE;
    if( rst ) begin
        cnt  <= 0;
        wdog <= RESET;
    end else if( clr) begin
        cnt  <= 0;
    end else if(frame) begin
        cnt  <= cnt+1'd1;
    end
end

endmodule