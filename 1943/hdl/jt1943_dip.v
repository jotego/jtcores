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
    Date: 20-10-2019 */

`timescale 1ns/1ps

module jt1943_dip(
    input           clk,
    input   [31:0]  status,
    input           game_pause,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    output  [ 7:0]  hdmi_arx,
    output  [ 7:0]  hdmi_ary,
    output          vertical_n,
    output  [ 1:0]  rotate,
    output          en_mixing,
    output  [ 1:0]  scanlines,

    output          enable_fm,
    output          enable_psg,
    output  [ 7:0]  dipsw_a,
    output  [ 7:0]  dipsw_b,
    // non standard:
    output          dip_pause,
    output          dip_flip,
    output  [ 1:0]  dip_fxlevel
);

assign     en_mixing     = ~status[9];

assign     dip_flip      = status[32'hb];
assign     enable_fm     = ~status[8], enable_psg = ~status[7];

`ifdef SIMULATION
    assign dip_pause = 1'b1; // avoid having the main CPU halted in simulation
    initial if(!dip_pause) $display("WARNING: DIP pause enabled");
`else
assign dip_pause = ~status[1] & ~game_pause;
`endif

`ifdef SIMULATION
    `ifdef DIP_TEST
    wire dip_test  = 1'b0;
    `else
    wire dip_test  = 1'b1;
    `endif
    initial if(!dip_test) $display("INFO: DIP test mode enabled");
`else
wire dip_test  = ~status[4];
`endif

wire       dip_upright   = 1'b1;
wire       dip_credits2p = 1'b1;
wire       dip_demosnd   = 1'b0;
wire       dip_continue  = 1'b1;
wire [2:0] dip_price2    = 3'b100;
wire [2:0] dip_price1    = ~3'b0;
assign     dip_fxlevel   = 2'b10 ^ status[13:12];
reg  [3:0] dip_level;

// play level
always @(posedge clk)
    case( status[3:2] )
        2'b00: dip_level <= 4'b0111; // normal
        2'b01: dip_level <= 4'b1111; // easy
        2'b10: dip_level <= 4'b0011; // hard
        2'b11: dip_level <= 4'b0000; // very hard
    endcase // status[3:2]


assign dipsw_a = {dip_test, dip_pause, dip_upright, dip_credits2p, dip_level };
assign dipsw_b = {dip_demosnd, dip_continue, dip_price2, dip_price1};


assign     vertical_n  = status[20];
wire       widescreen  = status[21];
assign     scanlines   = status[23:22];

assign rotate = { dip_flip, vertical_n };

// only for MiSTer
assign hdmi_arx = widescreen ? 8'd16 : vertical_n ? 8'd4 : 8'd3;
assign hdmi_ary = widescreen ? 8'd9  : vertical_n ? 8'd3 : 8'd4;

endmodule