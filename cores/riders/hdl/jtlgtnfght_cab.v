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
    Date: 13-6-2025 */

module jtlgtnfght_cab(
    input                clk,
    input                cpu_n,       // low when CPU can access video RAM
    input          [4:1] addr,
    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [19:0] dipsw,
    input         [ 1:0] cab_1p,
    input         [ 1:0] coin,
    input                service,
    input                dip_test,
    output reg    [ 7:0] dout
);

always @(posedge clk) begin
    casez(addr)
        4'b00_00: dout <= {1'b1, service, dip_test, cab_1p, cpu_n, coin };
        4'b00_01: dout <= {1'b1, joystick1 };
        4'b00_10: dout <= {1'b1, joystick2 };
        4'b00_11: dout <= dipsw[0+:8];
        4'b01_??: dout <= dipsw[8+:8];
        4'b10_??: dout <= {4'hf, dipsw[16+:4]};
        default: dout <= 8'hff;
    endcase
end

endmodule
