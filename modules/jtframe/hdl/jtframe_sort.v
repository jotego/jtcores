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
    Date: 14-1-2022 */

module jtframe_sort(
    input      [7:0] debug_bus,
    input      [3:0] busin,
    output reg [3:0] busout
);
    always @* begin
        case( debug_bus[4:0] )
            5'h00: busout = { busin[3], busin[2], busin[1], busin[0] };
            5'h01: busout = { busin[3], busin[2], busin[0], busin[1] };
            5'h02: busout = { busin[3], busin[1], busin[2], busin[0] };
            5'h03: busout = { busin[3], busin[1], busin[0], busin[2] };
            5'h04: busout = { busin[3], busin[0], busin[1], busin[2] };
            5'h05: busout = { busin[3], busin[0], busin[2], busin[1] };

            5'h06: busout = { busin[2], busin[3], busin[1], busin[0] };
            5'h07: busout = { busin[2], busin[3], busin[0], busin[1] };
            5'h08: busout = { busin[2], busin[1], busin[3], busin[0] };
            5'h09: busout = { busin[2], busin[1], busin[0], busin[3] };
            5'h0a: busout = { busin[2], busin[0], busin[1], busin[3] };
            5'h0b: busout = { busin[2], busin[0], busin[3], busin[1] };

            5'h0c: busout = { busin[1], busin[2], busin[3], busin[0] };
            5'h0d: busout = { busin[1], busin[2], busin[0], busin[3] };
            5'h0e: busout = { busin[1], busin[3], busin[2], busin[0] };
            5'h0f: busout = { busin[1], busin[3], busin[0], busin[2] };
            5'h10: busout = { busin[1], busin[0], busin[3], busin[2] };
            5'h11: busout = { busin[1], busin[0], busin[2], busin[3] };

            5'h12: busout = { busin[0], busin[2], busin[1], busin[3] };
            5'h13: busout = { busin[0], busin[2], busin[3], busin[1] };
            5'h14: busout = { busin[0], busin[1], busin[2], busin[3] };
            5'h15: busout = { busin[0], busin[1], busin[3], busin[2] };
            5'h16: busout = { busin[0], busin[3], busin[1], busin[2] };
            5'h17: busout = { busin[0], busin[3], busin[2], busin[1] };
            default: busout = busin;
        endcase
    end
endmodule

///////////////////////////////////////////////////////////////
module jtframe_sort3(
    input      [7:0] debug_bus,
    input      [2:0] busin,
    output reg [2:0] busout
);
    always @* begin
        case( debug_bus[2:0] )
            3'h0: busout = { busin[2], busin[1], busin[0] };
            3'h1: busout = { busin[2], busin[0], busin[1] };
            3'h2: busout = { busin[1], busin[2], busin[0] };
            3'h3: busout = { busin[1], busin[0], busin[2] };
            3'h4: busout = { busin[0], busin[1], busin[2] };
            3'h5: busout = { busin[0], busin[2], busin[1] };
            default: busout = busin;
        endcase
    end
endmodule

///////////////////////////////////////////////////////////////
module jtframe_sort5(
    input      [7:0] debug_bus,
    input      [4:0] busin,
    output reg [4:0] busout
);
    always @* begin
        case( debug_bus[6:0] )
            7'h00: busout = { busin[4], busin[3], busin[2], busin[1], busin[0] };
            7'h01: busout = { busin[4], busin[3], busin[2], busin[0], busin[1] };
            7'h02: busout = { busin[4], busin[3], busin[1], busin[2], busin[0] };
            7'h03: busout = { busin[4], busin[3], busin[1], busin[0], busin[2] };
            7'h04: busout = { busin[4], busin[3], busin[0], busin[2], busin[1] };
            7'h05: busout = { busin[4], busin[3], busin[0], busin[1], busin[2] };
            7'h06: busout = { busin[4], busin[2], busin[3], busin[1], busin[0] };
            7'h07: busout = { busin[4], busin[2], busin[3], busin[0], busin[1] };
            7'h08: busout = { busin[4], busin[2], busin[1], busin[3], busin[0] };
            7'h09: busout = { busin[4], busin[2], busin[1], busin[0], busin[3] };
            7'h0A: busout = { busin[4], busin[2], busin[0], busin[3], busin[1] };
            7'h0B: busout = { busin[4], busin[2], busin[0], busin[1], busin[3] };
            7'h0C: busout = { busin[4], busin[1], busin[3], busin[2], busin[0] };
            7'h0D: busout = { busin[4], busin[1], busin[3], busin[0], busin[2] };
            7'h0E: busout = { busin[4], busin[1], busin[2], busin[3], busin[0] };
            7'h0F: busout = { busin[4], busin[1], busin[2], busin[0], busin[3] };
            7'h10: busout = { busin[4], busin[1], busin[0], busin[3], busin[2] };
            7'h11: busout = { busin[4], busin[1], busin[0], busin[2], busin[3] };
            7'h12: busout = { busin[4], busin[0], busin[3], busin[2], busin[1] };
            7'h13: busout = { busin[4], busin[0], busin[3], busin[1], busin[2] };
            7'h14: busout = { busin[4], busin[0], busin[2], busin[3], busin[1] };
            7'h15: busout = { busin[4], busin[0], busin[2], busin[1], busin[3] };
            7'h16: busout = { busin[4], busin[0], busin[1], busin[3], busin[2] };
            7'h17: busout = { busin[4], busin[0], busin[1], busin[2], busin[3] };
            7'h18: busout = { busin[3], busin[4], busin[2], busin[1], busin[0] };
            7'h19: busout = { busin[3], busin[4], busin[2], busin[0], busin[1] };
            7'h1A: busout = { busin[3], busin[4], busin[1], busin[2], busin[0] };
            7'h1B: busout = { busin[3], busin[4], busin[1], busin[0], busin[2] };
            7'h1C: busout = { busin[3], busin[4], busin[0], busin[2], busin[1] };
            7'h1D: busout = { busin[3], busin[4], busin[0], busin[1], busin[2] };
            7'h1E: busout = { busin[3], busin[2], busin[4], busin[1], busin[0] };
            7'h1F: busout = { busin[3], busin[2], busin[4], busin[0], busin[1] };
            7'h20: busout = { busin[3], busin[2], busin[1], busin[4], busin[0] };
            7'h21: busout = { busin[3], busin[2], busin[1], busin[0], busin[4] };
            7'h22: busout = { busin[3], busin[2], busin[0], busin[4], busin[1] };
            7'h23: busout = { busin[3], busin[2], busin[0], busin[1], busin[4] };
            7'h24: busout = { busin[3], busin[1], busin[4], busin[2], busin[0] };
            7'h25: busout = { busin[3], busin[1], busin[4], busin[0], busin[2] };
            7'h26: busout = { busin[3], busin[1], busin[2], busin[4], busin[0] };
            7'h27: busout = { busin[3], busin[1], busin[2], busin[0], busin[4] };
            7'h28: busout = { busin[3], busin[1], busin[0], busin[4], busin[2] };
            7'h29: busout = { busin[3], busin[1], busin[0], busin[2], busin[4] };
            7'h2A: busout = { busin[3], busin[0], busin[4], busin[2], busin[1] };
            7'h2B: busout = { busin[3], busin[0], busin[4], busin[1], busin[2] };
            7'h2C: busout = { busin[3], busin[0], busin[2], busin[4], busin[1] };
            7'h2D: busout = { busin[3], busin[0], busin[2], busin[1], busin[4] };
            7'h2E: busout = { busin[3], busin[0], busin[1], busin[4], busin[2] };
            7'h2F: busout = { busin[3], busin[0], busin[1], busin[2], busin[4] };
            7'h30: busout = { busin[2], busin[4], busin[3], busin[1], busin[0] };
            7'h31: busout = { busin[2], busin[4], busin[3], busin[0], busin[1] };
            7'h32: busout = { busin[2], busin[4], busin[1], busin[3], busin[0] };
            7'h33: busout = { busin[2], busin[4], busin[1], busin[0], busin[3] };
            7'h34: busout = { busin[2], busin[4], busin[0], busin[3], busin[1] };
            7'h35: busout = { busin[2], busin[4], busin[0], busin[1], busin[3] };
            7'h36: busout = { busin[2], busin[3], busin[4], busin[1], busin[0] };
            7'h37: busout = { busin[2], busin[3], busin[4], busin[0], busin[1] };
            7'h38: busout = { busin[2], busin[3], busin[1], busin[4], busin[0] };
            7'h39: busout = { busin[2], busin[3], busin[1], busin[0], busin[4] };
            7'h3A: busout = { busin[2], busin[3], busin[0], busin[4], busin[1] };
            7'h3B: busout = { busin[2], busin[3], busin[0], busin[1], busin[4] };
            7'h3C: busout = { busin[2], busin[1], busin[4], busin[3], busin[0] };
            7'h3D: busout = { busin[2], busin[1], busin[4], busin[0], busin[3] };
            7'h3E: busout = { busin[2], busin[1], busin[3], busin[4], busin[0] };
            7'h3F: busout = { busin[2], busin[1], busin[3], busin[0], busin[4] };
            7'h40: busout = { busin[2], busin[1], busin[0], busin[4], busin[3] };
            7'h41: busout = { busin[2], busin[1], busin[0], busin[3], busin[4] };
            7'h42: busout = { busin[2], busin[0], busin[4], busin[3], busin[1] };
            7'h43: busout = { busin[2], busin[0], busin[4], busin[1], busin[3] };
            7'h44: busout = { busin[2], busin[0], busin[3], busin[4], busin[1] };
            7'h45: busout = { busin[2], busin[0], busin[3], busin[1], busin[4] };
            7'h46: busout = { busin[2], busin[0], busin[1], busin[4], busin[3] };
            7'h47: busout = { busin[2], busin[0], busin[1], busin[3], busin[4] };
            7'h48: busout = { busin[1], busin[4], busin[3], busin[2], busin[0] };
            7'h49: busout = { busin[1], busin[4], busin[3], busin[0], busin[2] };
            7'h4A: busout = { busin[1], busin[4], busin[2], busin[3], busin[0] };
            7'h4B: busout = { busin[1], busin[4], busin[2], busin[0], busin[3] };
            7'h4C: busout = { busin[1], busin[4], busin[0], busin[3], busin[2] };
            7'h4D: busout = { busin[1], busin[4], busin[0], busin[2], busin[3] };
            7'h4E: busout = { busin[1], busin[3], busin[4], busin[2], busin[0] };
            7'h4F: busout = { busin[1], busin[3], busin[4], busin[0], busin[2] };
            7'h50: busout = { busin[1], busin[3], busin[2], busin[4], busin[0] };
            7'h51: busout = { busin[1], busin[3], busin[2], busin[0], busin[4] };
            7'h52: busout = { busin[1], busin[3], busin[0], busin[4], busin[2] };
            7'h53: busout = { busin[1], busin[3], busin[0], busin[2], busin[4] };
            7'h54: busout = { busin[1], busin[2], busin[4], busin[3], busin[0] };
            7'h55: busout = { busin[1], busin[2], busin[4], busin[0], busin[3] };
            7'h56: busout = { busin[1], busin[2], busin[3], busin[4], busin[0] };
            7'h57: busout = { busin[1], busin[2], busin[3], busin[0], busin[4] };
            7'h58: busout = { busin[1], busin[2], busin[0], busin[4], busin[3] };
            7'h59: busout = { busin[1], busin[2], busin[0], busin[3], busin[4] };
            7'h5A: busout = { busin[1], busin[0], busin[4], busin[3], busin[2] };
            7'h5B: busout = { busin[1], busin[0], busin[4], busin[2], busin[3] };
            7'h5C: busout = { busin[1], busin[0], busin[3], busin[4], busin[2] };
            7'h5D: busout = { busin[1], busin[0], busin[3], busin[2], busin[4] };
            7'h5E: busout = { busin[1], busin[0], busin[2], busin[4], busin[3] };
            7'h5F: busout = { busin[1], busin[0], busin[2], busin[3], busin[4] };
            7'h60: busout = { busin[0], busin[4], busin[3], busin[2], busin[1] };
            7'h61: busout = { busin[0], busin[4], busin[3], busin[1], busin[2] };
            7'h62: busout = { busin[0], busin[4], busin[2], busin[3], busin[1] };
            7'h63: busout = { busin[0], busin[4], busin[2], busin[1], busin[3] };
            7'h64: busout = { busin[0], busin[4], busin[1], busin[3], busin[2] };
            7'h65: busout = { busin[0], busin[4], busin[1], busin[2], busin[3] };
            7'h66: busout = { busin[0], busin[3], busin[4], busin[2], busin[1] };
            7'h67: busout = { busin[0], busin[3], busin[4], busin[1], busin[2] };
            7'h68: busout = { busin[0], busin[3], busin[2], busin[4], busin[1] };
            7'h69: busout = { busin[0], busin[3], busin[2], busin[1], busin[4] };
            7'h6A: busout = { busin[0], busin[3], busin[1], busin[4], busin[2] };
            7'h6B: busout = { busin[0], busin[3], busin[1], busin[2], busin[4] };
            7'h6C: busout = { busin[0], busin[2], busin[4], busin[3], busin[1] };
            7'h6D: busout = { busin[0], busin[2], busin[4], busin[1], busin[3] };
            7'h6E: busout = { busin[0], busin[2], busin[3], busin[4], busin[1] };
            7'h6F: busout = { busin[0], busin[2], busin[3], busin[1], busin[4] };
            7'h70: busout = { busin[0], busin[2], busin[1], busin[4], busin[3] };
            7'h71: busout = { busin[0], busin[2], busin[1], busin[3], busin[4] };
            7'h72: busout = { busin[0], busin[1], busin[4], busin[3], busin[2] };
            7'h73: busout = { busin[0], busin[1], busin[4], busin[2], busin[3] };
            7'h74: busout = { busin[0], busin[1], busin[3], busin[4], busin[2] };
            7'h75: busout = { busin[0], busin[1], busin[3], busin[2], busin[4] };
            7'h76: busout = { busin[0], busin[1], busin[2], busin[4], busin[3] };
            7'h77: busout = { busin[0], busin[1], busin[2], busin[3], busin[4] };
            default: busout = busin;
        endcase
    end
endmodule