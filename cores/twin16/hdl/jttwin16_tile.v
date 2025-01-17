/*  This file is part of JTCORES.
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
    Date: 23-12-2024 */

// makes consequitive requests and 
// converts 16 bit data to 32 bits
module jttwin16_tile(
    input             rst,
    input             clk,
    input             vramcvf,

    output reg [17:1] stram_addr,
    input      [15:0] stram_dout,

    input      [17:2] lyra_addr, lyrb_addr,
    output reg [31:0] lyra_data, lyrb_data
);

reg [ 2:0] st;
reg [15:0] low; // low half

always @(posedge clk) begin
    st <= st+3'd1;
    case(st)
        0: begin stram_addr<={lyra_addr,1'b0}; lyrb_data<={stram_dout,low}; end
        2: begin stram_addr<={lyra_addr,1'b1}; low      <= stram_dout;      end
        4: begin stram_addr<={lyrb_addr,1'b0}; lyra_data<={stram_dout,low}; end
        6: begin stram_addr<={lyrb_addr,1'b1}; low      <= stram_dout;      end
    endcase
end

endmodule    