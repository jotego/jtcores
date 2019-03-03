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
    Date: 14-1-2019 */

module jtgng_vgapxl(
    input         clk,
    input         double,
    input         en_mix,
    input  [11:0] rgb_in,
    output  [14:0] rgb_out
);

function [4:0] ext; // extends by duplicating MSB
    input [3:0] a;
    ext = { a, a[3] };
endfunction

reg [3:0] last_r, last_g, last_b;
reg [4:0] pxl_r, pxl_g, pxl_b;

assign rgb_out = { pxl_r, pxl_g, pxl_b };

wire [5:0] mix_r = ext(last_r) + ext(rgb_in[11:8]);
wire [5:0] mix_g = ext(last_g) + ext(rgb_in[ 7:4]);
wire [5:0] mix_b = ext(last_b) + ext(rgb_in[ 3:0]);


always @(posedge clk) begin
    {last_r, last_g, last_b} <= rgb_in;
    // pixel mixing
    if( !double || !en_mix ) begin
        pxl_r <= ext(rgb_in[11:8]);
        pxl_g <= ext(rgb_in[ 7:4]);
        pxl_b <= ext(rgb_in[ 3:0]);
    end
    else begin
        pxl_r <= mix_r[5:1];
        pxl_g <= mix_g[5:1];
        pxl_b <= mix_b[5:1];
    end
end

endmodule // jtgng_vgapxl