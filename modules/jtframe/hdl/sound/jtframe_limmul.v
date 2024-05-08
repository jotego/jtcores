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
    W  = 16,
    WD = 7  // decimal part of the gain input (1.7=8 bits)
)(
    input                     rst,
    input                     clk,
    input                     cen,
    input  signed     [W-1:0] sin,
    input             [  7:0] gain,
    input                     peaked,

    output reg signed [W-1:0] mul,
    output        reg         peak
);

localparam FW=W+9, MSB=FW-1-(8-WD);

wire signed [FW-1:0] full;
wire signed [   8:0] sgain;
wire          v;

assign sgain = {1'b0,gain};
assign full  = sin * sgain;
assign v     = {FW-1-MSB{full[FW-1]}}!=full[FW-2:MSB];

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mul <= 0;
        peak <= 0;
    end else if(cen) begin
        peak <= v | peaked;
        mul  <= peaked ? sin :
                     v ? {full[FW-1],{W-1{~full[FW-1]}}} : full[MSB-:W];
    end
end

endmodule