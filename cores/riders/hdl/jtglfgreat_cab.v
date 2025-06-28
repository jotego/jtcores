/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR addr PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-6-2025 */

module jtglfgreat_cab(
    input                clk, cpu_cen, cs, LVBL,
    input         [19:0] dipsw,
    input          [8:1] addr,
    input          [6:0] joystick1, joystick2, joystick3, joystick4,
    input          [3:0] cab_1p, coin,
    input                service, dip_test, adc,
    output reg     [15:0] dout
);

always @(posedge clk) begin
    case( addr[2:1] )
        0: dout <= { 1'b1, joystick2[6:0],  adc, joystick1[6:0] };
        1: dout <= { 1'b1, joystick4[6:0], 1'b1, joystick3[6:0] };
        2: dout <= { dipsw[19:16], LVBL, dip_test, cab_1p[1:0], 3'b111, service, coin };
        3: dout <= dipsw[15:0];
    endcase
end

endmodule
