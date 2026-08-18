/*  This file is part of JT89.

    JT89 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT89 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT89.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: Dec, 22nd, 2018
    
    JT89 with x16 interpolation filter. For use with SEGA MASTER SYSTEM cores.
    
    */

module jt89_sms(
    input          clk,
    input          rst,
    input          wr_n,
    input    [7:0] din,
    output  signed [10:0] sound,
    output         ready
);

jt89 #(.INTERPOL16(1)) u_jt89(
    .clk    ( clk       ),
    .clk_en ( 1'b1      ),
    .rst    ( rst       ),
    .wr_n   ( wr_n      ),
    .cs_n   ( 1'b0      ),
    .din    ( din       ),
    .sound  ( sound     ), // output interpolated at clk data rate
    .ready  ( ready     )
);

endmodule // jt89_sms
