/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 9-11-2026 */

module jtblswhstl_cab(
    input                clk,
    input          [2:1] addr,
    input                eep_rdy,
    input                eep_do,
    input                dma,
    input         [ 6:0] joystick1,
    input         [ 6:0] joystick2,
    input         [ 1:0] cab_1p,
    input         [ 1:0] coin,
    input                service,
    input                dip_test,
    output reg    [ 7:0] dout
);

always @(posedge clk) begin
    case(addr)
        0: dout <= {1'b1, joystick1 };
        1: dout <= {1'b1, joystick2 };
        2: dout <= {1'b1, dma, cab_1p, dip_test, service, coin };
        3: dout <= {6'h3f, eep_rdy, eep_do };
    endcase
end

endmodule
