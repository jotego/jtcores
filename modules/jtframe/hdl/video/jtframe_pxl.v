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
    Date: 3-IV-2019 */

module jtframe_pxl #(parameter wi=4, wo=6)(
    input              clk,
    input              cen,
    input              double,
    input              en_mix,
    input   [3*wi-1:0] rgb_in,
    output  [3*wo-1:0] rgb_out
);

`ifdef SIMULATION
initial begin
    if( wo<wi ) begin
        $display("%m: output bit width must be larger or equal to input width");
    end
end
`endif

function [wo:0] ext; // extends by duplicating MSB
    input [wi-1:0] a;
    ext = { 1'b0, a, a[wi-1:wi-1-(wo-wi)] };
endfunction

reg [wi-1:0] last_r, last_g, last_b;
reg [wo-1:0] pxl_r, pxl_g, pxl_b;

assign rgb_out = { pxl_r, pxl_g, pxl_b };

wire [wo:0] mix_r = ext(last_r) + ext(rgb_in[3*wi-1:2*wi]);
wire [wo:0] mix_g = ext(last_g) + ext(rgb_in[2*wi-1:wi  ]);
wire [wo:0] mix_b = ext(last_b) + ext(rgb_in[  wi-1:0   ]);


always @(posedge clk) if(cen) begin
    {last_r, last_g, last_b} <= rgb_in;
    // pixel mixing
    if( !double || !en_mix ) begin
        pxl_r <= ext(rgb_in[3*wi-1:3*wi]);
        pxl_g <= ext(rgb_in[2*wi-1:  wi]);
        pxl_b <= ext(rgb_in[  wi-1:   0]);
    end
    else begin
        pxl_r <= mix_r[wo:1];
        pxl_g <= mix_g[wo:1];
        pxl_b <= mix_b[wo:1];
    end
end

endmodule
