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
    Date: 15-4-2021 */

// Divides a clock enable signal frequency by an integer

module jtframe_cendiv #( parameter
    MDIV    = 2
)(
    input      clk,
    input      cen_in,
    output reg cen_div, // Divided but not alligned with the original
    output     cen_da   // Divided and alligned
);

localparam CW = $clog2(MDIV);

reg [CW-1:0] cnt=0;
reg z;

assign cen_da = cen_in & z;

always @(posedge clk) begin
    if( cen_in ) cnt <= cnt==(MDIV[CW-1:0]-1) ? {CW{1'b0}} : cnt+1'd1;
    z <= cnt==0;
    cen_div <= cen_da;
end

endmodule