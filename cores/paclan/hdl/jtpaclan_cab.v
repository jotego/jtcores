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
    Date: 18-5-2025 */

module jtpaclan_cab(
    input               clk,

    input        [ 1:0] addr,

    input        [15:0] dipsw,
    input        [ 6:0] joystick1, joystick2,
    input        [ 1:0] cab_1p,
    input        [ 1:0] coin,
    input               service,

    output reg   [ 7:0] cab_dout=0,
    output       [ 7:0] other
);

localparam UP=3,DOWN=2,LEFT=1,RIGHT=0,B0=4,B1=5,B2=6,UPRIGHT=1'b1;
localparam [3:0] UNUSED=4'b1111;

assign other={joystick2[LEFT],joystick2[B0],joystick1[RIGHT],joystick1[LEFT],joystick1[B0],UNUSED[2:0]};

always @(posedge clk) begin
    cab_dout <= addr[0] ? {dipsw[0+:4],dipsw[8+:4]} : {dipsw[7-:4],dipsw[15-:4]};
    if(addr[1]) cab_dout <= addr[0] ?
        { coin,    service, joystick2[RIGHT], UNUSED} :
        { UPRIGHT, service, cab_1p, joystick2[UP], joystick2[DOWN], joystick1[UP], joystick1[DOWN]};
end

endmodule
