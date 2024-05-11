/* This file is part of JTFRAME.


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
    Date: 8-5-2024

*/

// Limiting multiplier of signed input by an unsigned gain
// the gain is taken as fixed point
// if the result does not fit in W bits
// peak is set and the output is clipped
module jtframe_limmul #(parameter
    WI = 16,
    WO = WI,
    WD = 7  // decimal part of the gain input (1.7=8 bits)
)(
    input                      rst,
    input                      clk,
    input                      cen,
    input  signed     [WI-1:0] sin,
    input             [   7:0] gain,
    input                      peaked,

    output reg signed [WO-1:0] mul,
    output        reg          peak
);

localparam FW=WI+9, MSB=FW-1-(10-WD);

wire signed [FW-1:0] full;
wire signed [   8:0] sgain;
wire      [FW-1:MSB] signs = full[FW-1:MSB];
wire v = |signs & ~&signs; // overflow

assign sgain = {1'b0,gain};
assign full  = sin * sgain;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mul <= 0;
        peak <= 0;
    end else if(cen) begin
        peak <= v | peaked;
        mul  <= v ? {full[FW-1],{WO-1{~full[FW-1]}}} : full[MSB-:WO];
    end
end

endmodule