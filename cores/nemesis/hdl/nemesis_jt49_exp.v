/*  This file is part of JT49.

    JT49 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT49 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT49.  If not, see <http://www.gnu.org/licenses/>.
    
    Author: Jose Tejada Gomez. Twitter: @topapate
    Author: Olivier Scherler.  Mastodon: @oscherler@tooting.ch
    Version: 1.0
    Date: 10-Nov-2018
    
    Based on sqmusic, by the same author
    LUT modified by Olivier Scherler, Sept-2023
    
*/

// Custom LUT for the Nemesis AY-3-8910s, calculated to match the response
// recorded on an actual Nemesis PCB. The actual response has a slope similar
// to comp = 1 of jt49_exp at low and medium volumes, and a slope closer
// to comp = 2 of jt49_exp at high volumes.

// Compression vs dynamic range
// 0-7 -> hard knee between 20 and 21

`default_nettype none

module jt49_exp(
    input            clk,
    input      [2:0] comp,  // compression, ignored
    input      [4:0] din,
    output reg [7:0] dout 
);

reg [7:0] lut[0:31];

always @(posedge clk)
    dout <= lut[ din ];

initial begin
    lut[0]   = 8'd0;
    lut[1]   = 8'd9;
    lut[2]   = 8'd10;
    lut[3]   = 8'd12;
    lut[4]   = 8'd14;
    lut[5]   = 8'd16;
    lut[6]   = 8'd18;
    lut[7]   = 8'd21;
    lut[8]   = 8'd24;
    lut[9]   = 8'd28;
    lut[10]  = 8'd32;
    lut[11]  = 8'd36;
    lut[12]  = 8'd42;
    lut[13]  = 8'd48;
    lut[14]  = 8'd56;
    lut[15]  = 8'd64;
    lut[16]  = 8'd74;
    lut[17]  = 8'd85;
    lut[18]  = 8'd97;
    lut[19]  = 8'd112;
    lut[20]  = 8'd129;
    lut[21]  = 8'd144;
    lut[22]  = 8'd153;
    lut[23]  = 8'd162;
    lut[24]  = 8'd171;
    lut[25]  = 8'd181;
    lut[26]  = 8'd192;
    lut[27]  = 8'd203;
    lut[28]  = 8'd215;
    lut[29]  = 8'd228;
    lut[30]  = 8'd241;
    lut[31]  = 8'd255;

end
endmodule
