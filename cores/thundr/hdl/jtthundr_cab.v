/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-3-2025 */

module jtthundr_cab(
    input               clk,

    input               a0,
    input               porta, portb,   // names from schematic

    input        [15:0] dipsw,
    input        [ 6:0] joystick1, joystick2,
    input        [ 1:0] cab_1p,
    input        [ 1:0] coin,
    input               service,

    output reg   [ 7:0] cab_dout=0,
    output       [ 7:0] other
);

localparam UP=3,DOWN=2,LEFT=1,RIGHT=0,B0=4,B1=5,B2=6;
localparam [2:0] UNUSED=3'b111;

wire service1=1'b1;

assign other={joystick2[LEFT],joystick2[B0],joystick1[RIGHT],joystick1[LEFT],joystick1[B0],UNUSED};

wire [7:0] dsw0 = {dipsw[6], dipsw[4], dipsw[2], dipsw[0], dipsw[8+6], dipsw[8+4], dipsw[8+2], dipsw[8+0]};
wire [7:0] dsw1 = {dipsw[7], dipsw[5], dipsw[3], dipsw[1], dipsw[8+7], dipsw[8+5], dipsw[8+3], dipsw[8+1]};

always @(posedge clk) begin
    cab_dout <= 0;
    if(portb) cab_dout <= a0 ? dsw1 : dsw0;
    if(porta) cab_dout <= a0 ?
        {1'b1   ,cab_1p[1],coin[1],service1,joystick2[UP],joystick1[UP],joystick2[B1], joystick1[B2]} :
        {service,cab_1p[0],coin[0],joystick2[RIGHT],joystick2[DOWN],joystick1[DOWN], joystick1[B1], joystick2[B2]};
end

endmodule
