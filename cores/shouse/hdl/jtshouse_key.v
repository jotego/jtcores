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
    Date: 21-9-2023 */

// The implementation of the KEY chips follows MAME's documentation
// These chips won't impact any timing accuracy

module jtshouse_key(
    input               rst,
    input               clk,

    input               cs,
    input               rnw,
    input         [7:0] addr,
    input         [7:0] din,
    output reg    [7:0] dout,

    input               prog_en,
    input               prog_wr,
    input         [2:0] prog_addr,
    input         [7:0] prog_data

);

reg  [7:0] cfg[0:7];
reg  [7:0] mmr[0:7];
wire [7:0] mmr_mux, rng;
reg        cen_rng;

assign mmr_mux = mmr[cfg[4][2:0]];

always @(posedge clk or posedge rst) begin
    if( prog_en & prog_wr ) cfg[prog_addr] <= prog_data;
end

// Random number generator. Should research the real one: https://github.com/jotego/jtcores/issues/363
// For now, I use JT51's LFSR
reg [16:0] bb;
assign rng = bb[16-:8];

always @(posedge clk, posedge rst) begin : base_counter
    if( rst ) begin
        bb <= 14220;
    end else if(cen_rng) begin
        bb[16:1] <= bb[15:0];
        bb[0]    <= ~(bb[16]^bb[13]);
    end
end

always @(posedge clk or posedge rst) begin
    if(rst) begin
        cen_rng <= 0;
        dout    <= 0;
    end else begin
        cen_rng <= 0;
        if( cs & ~rnw ) mmr[addr[6:4]] <= din;
        case( addr[6:4] )
            cfg[2][2:0]: dout <= cfg[1]; // key ID
            cfg[3][2:0]: begin
                cen_rng <= 1;
                dout <= rng; // Random Number Generator
            end
            cfg[5][2:0]: dout <= { mmr_mux[3:0], mmr_mux[7:4] }; // swap nibbles
            cfg[6][2:0]: dout <= { mmr_mux[3:0], addr[7:4] }; // lower nibble
            cfg[7][2:0]: dout <= { mmr_mux[7:4], addr[7:4] }; // upper nibble
        endcase
    end
end


endmodule