/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-6-2025 */

module jtglfgreat_cab(
    input                clk, cpu_cen, cs, dma,
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
        2: dout <= { dipsw[19:16], dma, dip_test, cab_1p[1:0], 3'b111, service, coin };
        3: dout <= dipsw[15:0];
    endcase
end

endmodule
