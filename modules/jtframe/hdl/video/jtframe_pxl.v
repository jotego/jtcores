/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-IV-2019 */

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
