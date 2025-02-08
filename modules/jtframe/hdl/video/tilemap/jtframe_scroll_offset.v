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
    Date: 7-2-2025 */

module jtframe_scroll_offset #(parameter
    MAP_HW     = 9,
    MAP_VW     = 9,
    VDUMPW     = 9,
    HDUMPW     = 9,
    COL_SCROLL = 0 // set to 1 to enable 8-pixel column scroll
)(
    input       clk, 
                flip, hs,
    input [8:0] hdump, vdump,
    input [MAP_HW-1:0] scrx,
    input [MAP_VW-1:0] scry,

    output reg [VDUMPW-1:0] veff,
    output reg [HDUMPW-1:0] heff
);

localparam VDW=9,
           HEW = HDUMPW>VDW ? HDUMPW : VDW,
           VEW = VDUMPW>VDW ? VDUMPW : VDW;

reg  [VDW-1:0] vdf, hdf;
reg  [HEW-1:0] hfull;
reg  [VEW-1:0] vfull;
wire h8;
reg  hsl, h8_l,
     line_changed, tile_changed, update_veff;

assign h8 = heff[3];

always @* begin
    hdf   = hdump ^ { 1'b0, {8{flip}} };
    hfull = hdf + scrx;
    heff  = hfull[HDUMPW-1:0];

    vdf   = vdump ^ { 1'b0, {8{flip}} };
    vfull = vdf + scry;
end

always @* begin
    line_changed = ~hs & hsl;
    tile_changed = h8 != h8_l;
    update_veff  = COL_SCROLL==1 ? tile_changed : line_changed;
end    

always @(posedge clk) begin
    hsl  <= hs;
    h8_l <= h8;
    if( update_veff ) veff <= vfull[VDUMPW-1:0];
end

endmodule