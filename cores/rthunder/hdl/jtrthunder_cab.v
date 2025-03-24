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
    Date: 23-3-2025 */

module jtrthunder_cab(
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

always @(posedge clk) begin
    cab_dout <= 0;
    if(portb) cab_dout <= a0 ? dipsw[15:8] : dipsw[7:0];
    if(porta) cab_dout <= a0 ?
        {1'b1   ,cab_1p[1],coin[1],service1,joystick2[UP],joystick1[UP],joystick2[B1], joystick1[B2]} :
        {service,cab_1p[1],coin[1],joystick2[RIGHT],joystick2[DOWN],joystick1[DOWN], joystick1[B1], joystick2[B2]};
end

endmodule
