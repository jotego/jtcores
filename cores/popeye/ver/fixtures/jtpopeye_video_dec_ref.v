`include "fixtures.vh"
/*  This file is part of JTPOPEYE.
    JTPOPEYE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTPOPEYE program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR AD PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTPOPEYE.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-3-2019 */

`timescale 1ns/1ps

module jtpopeye_video_dec(
    input      [12:0]   AD,
    output reg [12:0]   AD_dec
);

reg [12:0] pre;
// AD is obfuscated
always @(*) begin
    pre[  5:0] =~AD[  5:0];
    pre[ 12:6] = AD[ 12:6];
    AD_dec[9:0] = { pre[5], pre[9], pre[8:7], pre[4:3], pre[6], pre[2:0] };
    AD_dec[12:10] = pre[12:10];
end

// assign AD_dec[  2:0] =~AD[  2:0];
// assign AD_dec[    3] = AD[    6];
// assign AD_dec[    4] =~AD[    3];
// assign AD_dec[    5] =~AD[    4];
// assign AD_dec[    6] = AD[    7];
// assign AD_dec[    7] = AD[    8];
// assign AD_dec[    8] = AD[    9];
// assign AD_dec[    9] =~AD[    5];
// assign AD_dec[12:10] = AD[12:10];


endmodule // jtpopeye_video_ad
