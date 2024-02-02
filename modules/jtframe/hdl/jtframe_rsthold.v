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
    Date: 1-2-2024 */

module jtframe_rsthold(
    input      rst,
    input      clk,
    input      hold,
    output reg rst_h
`ifdef JTFRAME_CLK24 ,
    input      rst24,
    input      clk24,
    output reg rst24_h
`endif
`ifdef JTFRAME_CLK48 ,
    input      rst48,
    input      clk48,
    output reg rst48_h
`endif    
);

reg hold24, hold48;

always @(negedge clk)   rst_h   <= rst   || hold;
`ifdef JTFRAME_CLK24
always @(posedge clk24) hold24  <= hold;
always @(negedge clk24) rst24_h <= rst24 || hold24; `endif
`ifdef JTFRAME_CLK48
always @(posedge clk48) hold48  <= hold;
always @(negedge clk48) rst48_h <= rst48 || hold; `endif

endmodule