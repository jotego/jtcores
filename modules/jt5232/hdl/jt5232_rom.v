/* This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 6-12-2024 */

// Matches documentation table 1

module jt5232_rom(
    input        clk,
    input  [6:0] addr,
    output [8:0] pgcnt, // programmable counter
    output [2:0] bsel,  // binary counter shift data
    output reg   noise
);

reg [11:0] rom;

assign {pgcnt,bsel}=rom;

always @(posedge clk) begin
    noise <= 0;
    case(addr)
        7'h00: rom <= { 9'd506, 3'd7};
        7'h01: rom <= { 9'd478, 3'd7};
        7'h02: rom <= { 9'd451, 3'd7};
        7'h03: rom <= { 9'd426, 3'd7};
        7'h04: rom <= { 9'd402, 3'd7};
        7'h05: rom <= { 9'd379, 3'd7};
        7'h06: rom <= { 9'd358, 3'd7};
        7'h07: rom <= { 9'd338, 3'd7};
        7'h08: rom <= { 9'd319, 3'd7};
        7'h09: rom <= { 9'd301, 3'd7};
        7'h0A: rom <= { 9'd284, 3'd7};
        7'h0B: rom <= { 9'd268, 3'd7};
        7'h0C: rom <= { 9'd253, 3'd7};
        7'h0D: rom <= { 9'd478, 3'd6};
        7'h0E: rom <= { 9'd451, 3'd6};
        7'h0F: rom <= { 9'd426, 3'd6};
        7'h10: rom <= { 9'd402, 3'd6};
        7'h11: rom <= { 9'd379, 3'd6};
        7'h12: rom <= { 9'd358, 3'd6};
        7'h13: rom <= { 9'd338, 3'd6};
        7'h14: rom <= { 9'd319, 3'd6};
        7'h15: rom <= { 9'd301, 3'd6};
        7'h16: rom <= { 9'd284, 3'd6};
        7'h17: rom <= { 9'd268, 3'd6};
        7'h18: rom <= { 9'd253, 3'd6};
        7'h19: rom <= { 9'd478, 3'd5};
        7'h1A: rom <= { 9'd451, 3'd5};
        7'h1B: rom <= { 9'd426, 3'd5};
        7'h1C: rom <= { 9'd402, 3'd5};
        7'h1D: rom <= { 9'd379, 3'd5};
        7'h1E: rom <= { 9'd358, 3'd5};
        7'h1F: rom <= { 9'd338, 3'd5};
        7'h20: rom <= { 9'd319, 3'd5};
        7'h21: rom <= { 9'd301, 3'd5};
        7'h22: rom <= { 9'd284, 3'd5};
        7'h23: rom <= { 9'd268, 3'd5};
        7'h24: rom <= { 9'd253, 3'd5};
        7'h25: rom <= { 9'd478, 3'd4};
        7'h26: rom <= { 9'd451, 3'd4};
        7'h27: rom <= { 9'd426, 3'd4};
        7'h28: rom <= { 9'd402, 3'd4};
        7'h29: rom <= { 9'd379, 3'd4};
        7'h2A: rom <= { 9'd358, 3'd4};
        7'h2B: rom <= { 9'd338, 3'd4};
        7'h2C: rom <= { 9'd319, 3'd4};
        7'h2D: rom <= { 9'd301, 3'd4};
        7'h2E: rom <= { 9'd284, 3'd4};
        7'h2F: rom <= { 9'd268, 3'd4};
        7'h30: rom <= { 9'd253, 3'd4};
        7'h31: rom <= { 9'd478, 3'd3};
        7'h32: rom <= { 9'd451, 3'd3};
        7'h33: rom <= { 9'd426, 3'd3};
        7'h34: rom <= { 9'd402, 3'd3};
        7'h35: rom <= { 9'd379, 3'd3};
        7'h36: rom <= { 9'd358, 3'd3};
        7'h37: rom <= { 9'd338, 3'd3};
        7'h38: rom <= { 9'd319, 3'd3};
        7'h39: rom <= { 9'd301, 3'd3};
        7'h3A: rom <= { 9'd284, 3'd3};
        7'h3B: rom <= { 9'd268, 3'd3};
        7'h3C: rom <= { 9'd253, 3'd3};
        7'h3D: rom <= { 9'd478, 3'd2};
        7'h3E: rom <= { 9'd451, 3'd2};
        7'h3F: rom <= { 9'd426, 3'd2};
        7'h40: rom <= { 9'd402, 3'd2};
        7'h41: rom <= { 9'd379, 3'd2};
        7'h42: rom <= { 9'd358, 3'd2};
        7'h43: rom <= { 9'd338, 3'd2};
        7'h44: rom <= { 9'd319, 3'd2};
        7'h45: rom <= { 9'd301, 3'd2};
        7'h46: rom <= { 9'd284, 3'd2};
        7'h47: rom <= { 9'd268, 3'd2};
        7'h48: rom <= { 9'd253, 3'd2};
        7'h49: rom <= { 9'd478, 3'd1};
        7'h4A: rom <= { 9'd451, 3'd1};
        7'h4B: rom <= { 9'd426, 3'd1};
        7'h4C: rom <= { 9'd402, 3'd1};
        7'h4D: rom <= { 9'd379, 3'd1};
        7'h4E: rom <= { 9'd358, 3'd1};
        7'h4F: rom <= { 9'd338, 3'd1};
        7'h50: rom <= { 9'd319, 3'd1};
        7'h51: rom <= { 9'd301, 3'd1};
        7'h52: rom <= { 9'd284, 3'd1};
        7'h53: rom <= { 9'd268, 3'd1};
        7'h54: rom <= { 9'd253, 3'd1};
        7'h55: rom <= { 9'd253, 3'd1};
        7'h56: rom <= { 9'd253, 3'd1};
        7'h57: rom <= { 9'd013, 3'd7};
        // noise generator according to data sheet is pitch data $7F
        // but MAME uses any value above $58
        default: begin noise <= 1; rom <= { 9'd000, 3'd3}; end
        // default: rom <= 0;
    endcase
end

endmodule