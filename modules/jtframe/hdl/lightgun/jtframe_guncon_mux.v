/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version. */

module jtframe_guncon_mux #(
    parameter BUTTONS = 2
)(
    input         rst,
    input         clk,
    input         enable,

    input  [15:0] joystick1,
    input  [15:0] joystick2,
    input  [ 8:0] board_gun_1p_x,
    input  [ 8:0] board_gun_1p_y,
    input  [ 8:0] board_gun_2p_x,
    input  [ 8:0] board_gun_2p_y,

    input         p1_aim_valid,
    input  [ 9:0] p1_x,
    input  [ 7:0] p1_y,
    input         p1_trigger,
    input         p1_start,
    input         p1_button,
    input         p1_select,

    input         p2_aim_valid,
    input  [ 9:0] p2_x,
    input  [ 7:0] p2_y,
    input         p2_trigger,
    input         p2_start,
    input         p2_button,
    input         p2_select,

    output reg [15:0] joystick1_out,
    output reg [15:0] joystick2_out,
    output reg [ 8:0] gun_1p_x,
    output reg [ 8:0] gun_1p_y,
    output reg [ 8:0] gun_2p_x,
    output reg [ 8:0] gun_2p_y
);

localparam START_BIT = BUTTONS+4;
localparam COIN_BIT  = BUTTONS+5;

wire [15:0] guncon_joy1, guncon_joy2;
wire [ 8:0] guncon_1p_x, guncon_1p_y, guncon_2p_x, guncon_2p_y;

// GunCon X is reported at ten-bit precision. JTFRAME's established lightgun
// interface is nine bits, so it receives the upper nine bits directly.
assign guncon_1p_x = p1_aim_valid ? p1_x[9:1] : 9'h1ff;
assign guncon_1p_y = p1_aim_valid ? { 1'b0, p1_y } : 9'h1ff;
assign guncon_2p_x = p2_aim_valid ? p2_x[9:1] : 9'h1ff;
assign guncon_2p_y = p2_aim_valid ? { 1'b0, p2_y } : 9'h1ff;
assign guncon_joy1 = !enable ? 16'd0 :
                     (p1_trigger ? 16'h0010 : 16'd0) |
                     (p1_button  ? 16'h0020 : 16'd0) |
                     (p1_start   ? 16'h0001 << START_BIT : 16'd0) |
                     (p1_select  ? 16'h0001 << COIN_BIT  : 16'd0);
assign guncon_joy2 = !enable ? 16'd0 :
                     (p2_trigger ? 16'h0010 : 16'd0) |
                     (p2_button  ? 16'h0020 : 16'd0) |
                     (p2_start   ? 16'h0001 << START_BIT : 16'd0) |
                     (p2_select  ? 16'h0001 << COIN_BIT  : 16'd0);

always @(posedge clk) begin
    if (rst) begin
        joystick1_out <= 16'd0;
        joystick2_out <= 16'd0;
        gun_1p_x      <= 9'd0;
        gun_1p_y      <= 9'd0;
        gun_2p_x      <= 9'd0;
        gun_2p_y      <= 9'd0;
    end else begin
        joystick1_out <= joystick1 | guncon_joy1;
        joystick2_out <= joystick2 | guncon_joy2;
        gun_1p_x      <= enable ? guncon_1p_x : board_gun_1p_x;
        gun_1p_y      <= enable ? guncon_1p_y : board_gun_1p_y;
        gun_2p_x      <= enable ? guncon_2p_x : board_gun_2p_x;
        gun_2p_y      <= enable ? guncon_2p_y : board_gun_2p_y;
    end
end

endmodule
