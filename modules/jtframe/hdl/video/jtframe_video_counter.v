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
    Date: 25-1-2025 */

module jtframe_video_counter(
    input        rst,
    input        clk,
    input        pxl_cen,

    input        lhbl,
    input        lvbl,
    input        flip,

    output [8:0] v, h
);

reg  [8:0] vcnt, hcnt;
reg        lhbl_l;

assign v = vcnt ^ { 1'b0, {8{flip}}};
assign h = hcnt ^ { 1'b0, {8{flip}}};

always @(posedge clk) begin
    if( rst ) begin
        lhbl_l      <= 0;
        vcnt        <= 0;
        hcnt        <= 0;
    end else if(pxl_cen) begin
        lhbl_l <= lhbl & lvbl;
        if (!lvbl) begin
            vcnt <= 0;
        end else if( !lhbl && lhbl_l ) begin
            vcnt <= vcnt + 9'd1;
        end
        if (!lhbl) begin
            hcnt <= 0;
        end else begin 
            hcnt <= hcnt + 9'd1;
        end
    end
end

endmodule
