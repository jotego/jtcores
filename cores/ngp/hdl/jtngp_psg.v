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
    Date: 23-5-2023 */

module jtngp_psg(
    input                    rst,
    input                    clk,
    input                    cen,

    input                    r_wn,
    input                    cs,
    input                    a0,
    input             [ 7:0] din,
    output                   ready,
    output reg signed [11:0] snd
);

wire signed [10:0] tone, noise;
wire        [ 1:0] cs_n, rdy;

assign ready = &rdy;
assign cs_n = ~({2{cs}} & {a0, ~a0});

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd <= 0;
    end else begin
        snd <= {tone[10], tone } + {noise[10], noise };
    end
end

jt89 #(.MODE(2) `ifdef JTFRAME_RELEASE ,.INTERPOL16(1) `endif  )u_jt89_0(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .clk_en ( cen       ),
    .wr_n   ( r_wn      ),
    .cs_n   ( cs_n[0]   ),
    .din    ( din       ),
    .sound  ( noise     ),
    .ready  ( rdy[0]    )
);

jt89 #(.MODE(1) `ifdef JTFRAME_RELEASE ,.INTERPOL16(1) `endif)u_jt89_1(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .clk_en ( cen       ),
    .wr_n   ( r_wn      ),
    .cs_n   ( cs_n[1]   ),
    .din    ( din       ),
    .sound  ( tone      ),
    .ready  ( rdy[1]    )
);

endmodule