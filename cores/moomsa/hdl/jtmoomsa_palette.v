/* SPDX-License-Identifier: GPL-3.0-or-later */

module jtmoomsa_palette(
    input         clk,
    input         cen,
    input  [10:0] addr,
    input         we_rn,
    input         we_gn,
    input         we_bn,
    input  [ 7:0] red_in,
    input  [ 7:0] green_in,
    input  [ 7:0] blue_in,
    output [ 7:0] red_out,
    output [ 7:0] green_out,
    output [ 7:0] blue_out
);

(* ramstyle = "M10K, no_rw_check" *) reg [7:0] red_ram [0:2047];
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] green_ram [0:2047];
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] blue_ram [0:2047];

always @(posedge clk) begin
    if(cen) begin
        if(!we_rn) red_ram[addr] <= red_in;
        if(!we_gn) green_ram[addr] <= green_in;
        if(!we_bn) blue_ram[addr] <= blue_in;
    end
end

assign red_out   = red_ram[addr];
assign green_out = green_ram[addr];
assign blue_out  = blue_ram[addr];

endmodule
