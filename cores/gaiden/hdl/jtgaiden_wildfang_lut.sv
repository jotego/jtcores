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
    Date: 1-1-2025 */

module jtgaiden_wildfang_lut(
    input                rst,
    input                clk,
    input                we,
    input          [7:0] din,
    output reg     [7:0] dout
);

localparam [3:0] INIT=0, 
                 CODEMSB=1,
                 CODELSB=2,
                 SELNIB3=3, // nibble selection
                 SELNIB2=4,
                 SELNIB1=5,
                 SELNIB0=6;

reg [ 4:0] jumpcode;
reg [15:0] jump_lut[0:16];
reg [15:0] jump;

initial begin
    jump_lut = '{
    16'h0c0c,16'h0cac,16'h0d42,16'h0da2,16'h0eea,16'h112e,16'h1300,16'h13fa,
    16'h159a,16'h1630,16'h109a,16'h1700,16'h1750,16'h1806,16'h18d6,16'h1a44,
    16'h1b52 };
end

always @(posedge clk) begin
    jump <= jump_lut[jumpcode];
end

always @(posedge clk) begin
    if(rst) begin
        dout <= 0;
    end else if(we) case(din[7:4])
        INIT:    dout <= 0;
        CODEMSB: begin jumpcode[4]   <= din[0];   dout<=8'h10; end
        CODELSB: begin jumpcode[3:0] <= din[3:0]; dout<=8'h20; end
        SELNIB3: dout <= {4'h4,jump[12+:4]};
        SELNIB2: dout <= {4'h5,jump[ 8+:4]};
        SELNIB1: dout <= {4'h6,jump[ 4+:4]};
        SELNIB0: dout <= {4'h7,jump[ 0+:4]};
        default:;
    endcase
end

endmodule    