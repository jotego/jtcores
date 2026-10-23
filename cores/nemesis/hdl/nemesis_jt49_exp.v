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
    Author: Olivier Scherler.  Twitter: @oscherler
    Version: 1.0
    Date: 10-Nov-2018
    
    Based on sqmusic, by the same author
    LUT modified by Olivier Scherler, Sept-2023
    
    */

// Custom LUT for the Nemesis AY-3-8910s, calculated to match the response
// recorded on an actual Nemesis PCB. The actual response has a slope similar
// to comp = 1 of jt49_exp at low and medium volumes, and a slope closer
// to comp = 2  of jt49_exp at high volumes.

// Compression vs dynamic range
// 0 -> hard knee between 20 and 21
// 1 -> [same]
// 2 -> [same]
// 3 -> [same]

module nemesis_jt49_exp(
    input            clk,
    input      [1:0] comp,  // compression
    input      [4:0] din,
    output reg [7:0] dout 
);

reg [7:0] lut[0:127];

always @(posedge clk)
    dout <= lut[ {comp,din} ];

initial begin
    lut[0] = 8'd0;
    lut[1] = 8'd9;
    lut[2] = 8'd10;
    lut[3] = 8'd12;
    lut[4] = 8'd14;
    lut[5] = 8'd16;
    lut[6] = 8'd18;
    lut[7] = 8'd21;
    lut[8] = 8'd24;
    lut[9] = 8'd28;
    lut[10] = 8'd32;
    lut[11] = 8'd36;
    lut[12] = 8'd42;
    lut[13] = 8'd48;
    lut[14] = 8'd56;
    lut[15] = 8'd64;
    lut[16] = 8'd74;
    lut[17] = 8'd85;
    lut[18] = 8'd97;
    lut[19] = 8'd112;
    lut[20] = 8'd129;
    lut[21] = 8'd144;
    lut[22] = 8'd153;
    lut[23] = 8'd162;
    lut[24] = 8'd171;
    lut[25] = 8'd181;
    lut[26] = 8'd192;
    lut[27] = 8'd203;
    lut[28] = 8'd215;
    lut[29] = 8'd228;
    lut[30] = 8'd241;
    lut[31] = 8'd255;
    lut[32] = 8'd0;
    lut[33] = 8'd9;
    lut[34] = 8'd10;
    lut[35] = 8'd12;
    lut[36] = 8'd14;
    lut[37] = 8'd16;
    lut[38] = 8'd18;
    lut[39] = 8'd21;
    lut[40] = 8'd24;
    lut[41] = 8'd28;
    lut[42] = 8'd32;
    lut[43] = 8'd36;
    lut[44] = 8'd42;
    lut[45] = 8'd48;
    lut[46] = 8'd56;
    lut[47] = 8'd64;
    lut[48] = 8'd74;
    lut[49] = 8'd85;
    lut[50] = 8'd97;
    lut[51] = 8'd112;
    lut[52] = 8'd129;
    lut[53] = 8'd144;
    lut[54] = 8'd153;
    lut[55] = 8'd162;
    lut[56] = 8'd171;
    lut[57] = 8'd181;
    lut[58] = 8'd192;
    lut[59] = 8'd203;
    lut[60] = 8'd215;
    lut[61] = 8'd228;
    lut[62] = 8'd241;
    lut[63] = 8'd255;
    lut[64] = 8'd0;
    lut[65] = 8'd9;
    lut[66] = 8'd10;
    lut[67] = 8'd12;
    lut[68] = 8'd14;
    lut[69] = 8'd16;
    lut[70] = 8'd18;
    lut[71] = 8'd21;
    lut[72] = 8'd24;
    lut[73] = 8'd28;
    lut[74] = 8'd32;
    lut[75] = 8'd36;
    lut[76] = 8'd42;
    lut[77] = 8'd48;
    lut[78] = 8'd56;
    lut[79] = 8'd64;
    lut[80] = 8'd74;
    lut[81] = 8'd85;
    lut[82] = 8'd97;
    lut[83] = 8'd112;
    lut[84] = 8'd129;
    lut[85] = 8'd144;
    lut[86] = 8'd153;
    lut[87] = 8'd162;
    lut[88] = 8'd171;
    lut[89] = 8'd181;
    lut[90] = 8'd192;
    lut[91] = 8'd203;
    lut[92] = 8'd215;
    lut[93] = 8'd228;
    lut[94] = 8'd241;
    lut[95] = 8'd255;
    lut[96] = 8'd0;
    lut[97] = 8'd9;
    lut[98] = 8'd10;
    lut[99] = 8'd12;
    lut[100] = 8'd14;
    lut[101] = 8'd16;
    lut[102] = 8'd18;
    lut[103] = 8'd21;
    lut[104] = 8'd24;
    lut[105] = 8'd28;
    lut[106] = 8'd32;
    lut[107] = 8'd36;
    lut[108] = 8'd42;
    lut[109] = 8'd48;
    lut[110] = 8'd56;
    lut[111] = 8'd64;
    lut[112] = 8'd74;
    lut[113] = 8'd85;
    lut[114] = 8'd97;
    lut[115] = 8'd112;
    lut[116] = 8'd129;
    lut[117] = 8'd144;
    lut[118] = 8'd153;
    lut[119] = 8'd162;
    lut[120] = 8'd171;
    lut[121] = 8'd181;
    lut[122] = 8'd192;
    lut[123] = 8'd203;
    lut[124] = 8'd215;
    lut[125] = 8'd228;
    lut[126] = 8'd241;
    lut[127] = 8'd255;

end
endmodule
