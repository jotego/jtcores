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
    Date: 17-7-2025 */

module jtajax_pcmvol(
    input                rst,
    input                clk,
    input                cs,
    input                wr_n,
    input         [ 3:0] addr,
    input                haddr,
    input         [ 7:0] din,
    input  signed [ 6:0] pcm_a,
    input  signed [ 6:0] pcm_b,
    output signed [10:0] l, r
);

wire we;
reg [3:0] again;
reg [7:0] bgain;
wire signed [10:0] snda, sndb_l, sndb_r;

assign we = cs && !wr_n && addr==12;

always @(posedge clk) if(we) begin
    if(haddr) begin
        again <= din[3:0];
    end else begin
        bgain <= din;
    end
end

jt007232_gain u_again(
    .clk        ( clk       ),
    .swap_gains ( 1'b0      ),
    .reg12      ( {2{again}}),
    .rawa       ( pcm_a     ),
    .rawb       ( 7'd0      ),
    .snda       ( snda      ),
    .sndb       (           )
);

jt007232_gain u_bgain(
    .clk        ( clk       ),
    .swap_gains ( 1'b0      ),
    .reg12      ( bgain     ),
    .rawa       ( pcm_b     ),
    .rawb       ( pcm_b     ),
    .snda       ( sndb_r    ),
    .sndb       ( sndb_l    )
);

jtframe_limsum #(.WI(11),.K(2))u_suml(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( 1'b1      ),
    .en         ( 2'b11     ),
    .parts      ({snda,sndb_l}),
    .sum        ( l         ),
    .peak       (           )
);

jtframe_limsum #(.WI(11),.K(2))u_sumr(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( 1'b1      ),
    .en         ( 2'b11     ),
    .parts      ({snda,sndb_r}),
    .sum        ( r         ),
    .peak       (           )
);

endmodule