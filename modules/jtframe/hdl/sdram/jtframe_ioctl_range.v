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
    Date: 16-3-2025 */

module jtframe_ioctl_range #( parameter
    SDRAMW = 22,
    DW     =  8,
    AW     =  8,
    OFFSET =  22'h10_0000
)(
    input              clk,
    input [SDRAMW-1:0] addr,
    output reg[AW-1:0] addr_rel=0,
    input              en,
    output reg         inrange=0,
    input     [DW-1:0] din,
    output reg[DW-1:0] dout=0
);

localparam END=OFFSET+(1<<AW);

wire is_inrange = addr>=OFFSET[SDRAMW-1:0] && addr<END[SDRAMW-1:0];
wire [SDRAMW-1:0] rel = addr-OFFSET[SDRAMW-1:0];

always @(posedge clk) begin
    inrange <= is_inrange && en;
    if(is_inrange) begin
        dout    <= din;
        addr_rel<= rel[AW-1:0];
    end
end

endmodule