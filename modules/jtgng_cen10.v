/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 13-10-2019 */

module jtgng_cen10(
    input   clk,    // 48MHz only
    output  reg cen10,
    // 180 shifted signals
    output  reg cen10b
);

reg [2:0] cencnt=3'd0;
reg [2:0] muxcnt=3'd0;
reg [2:0] next=3'd4, nextb=3'd2;

always @(*) begin
    next = muxcnt[2] ? 3'd3 : 3'd4;
    nextb= muxcnt[2] ? 3'd1 : 3'd2;
end

always @(negedge clk) begin
    cencnt <= cencnt+3'd1;
    cen10  <= cencnt == next;
    cen10b <= cencnt == nextb;
    if( cencnt==next ) begin
        cencnt <= 3'd0;
        muxcnt <= muxcnt[2] ? 3'd1 : muxcnt + 3'b1;
    end
end

endmodule // jtgng_cen