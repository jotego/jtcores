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
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 02-7-2024 */

// This module is used for sending an analogic video signal through the cartdrige pins for use with CRT
module jtframe_pocket_av_snac (
    input             clk,
    input             pxl_cen, pxl2_cen,
    input             rst,
    input      [ 1:0] anv_en,       // enable analogic video output
    input             snac_en,
    input             yc_en,
    // Base video
    input      [23:0] yc_vid,
    input      [ 7:0] bus_av3, bus_av2,
    input      [ 4:0] bus_av1,
    input             bus_av1_dir, bus_av2_dir, bus_av3_dir,
    input      [ 7:6] snac1_bus,
    input      [ 7:4] snac0_bus,
    input             snac31_bus, snac30_bus,
    input             snac1_dir, snac0_dir, snac31_dir, snac30_dir,
    // Final video
    output  reg [7:0] cart1_out, cart2_out, cart3_out,
    output  reg [7:4] cart0_out,
    output  reg [3:0] out_en,
    output  reg       cart30_out, cart31_out,
    output  reg       cart0_dir, cart1_dir, cart2_dir, cart3_dir,
    output  reg       cart30_dir,cart31_dir,cartp30_pwrst, vid_en
);

reg       clk_pxln, clk_av;
reg       scan2x;
reg [4:0] av1_out;
reg [7:0] av2_out, av3_out;
reg [7:6] snac1_out;
reg [5:0] yc2, yc3;

always @(posedge clk ) begin
    if( pxl2_cen ) clk_pxln <= ~pxl_cen;
    clk_av <= clk_pxln;
    if( scan2x   ) clk_av   <= pxl2_cen;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vid_en        <= 0;
        out_en        <= 4'b0;
        cartp30_pwrst <= 1'b0;
        av1_out       <= 5'h00;
        av2_out       <= 8'h00;
        av3_out       <= 8'h00;
        yc2           <= 6'b0;
        yc3           <= 6'b0;
        snac1_out     <= 2'b0;
        cart0_out     <= 4'b0;
        {cart1_dir, cart2_dir,  cart3_dir } <= 3'b0;
        {cart0_dir, cart30_dir, cart31_dir} <= 3'b100;
        {cart30_out, cart31_out} <= 2'b0;
    end else begin
        {vid_en, scan2x} <= anv_en;
         out_en[0]       <= snac_en | vid_en;
         out_en[3:1]     <= {snac0_dir, snac30_dir, snac31_dir};
         av1_out         <= bus_av1;
         av2_out         <= bus_av2;
         av3_out         <= bus_av3;
         yc2             <= yc_vid[15:10]; // Y
         yc3             <= yc_vid[23:18]; // C
         snac1_out       <= snac1_bus;
         cartp30_pwrst   <= 1'b1;
         cart0_out       <= snac0_bus;
         cart0_dir       <= snac0_dir;
         cart1_dir       <= bus_av1_dir | snac1_dir;
        {cart2_dir, cart3_dir  } <= { bus_av2_dir, bus_av3_dir };
        {cart30_dir,cart31_dir } <= { snac30_dir , snac31_dir  };
        {cart30_out, cart31_out} <= { snac30_bus , snac31_bus  };
    end
end

always @(*) begin
    cart1_out = {snac1_out, clk_av, av1_out};
    cart2_out = av2_out;
    cart3_out = av3_out;
    if ( yc_en) begin
        cart1_out = {snac1_out, ~clk, 5'b0 };
        cart2_out = {2'b01, yc2};
        cart3_out = {yc3  , av3_out[1:0]};
    end
end

endmodule
