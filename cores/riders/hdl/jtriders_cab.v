/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-6-2025 */

module jtriders_cab(
    input                clk, cpu_cen, cs, LVBL, eep_rdy, eep_do,
    input          [2:0] IPLn,
    input          [8:1] addr,
    input          [6:0] joystick1, joystick2, joystick3, joystick4,
    input          [3:0] cab_1p, coin, service,
    input                dip_test,
    output reg     [7:0] dout
);

reg fake_dma=0, cs_l;

always @(posedge clk) begin
    if( cpu_cen ) begin
        cs_l <= cs;
        if( !cs && !cs_l ) fake_dma <= ~fake_dma;
    end
    dout[7:0] <= addr[1] ? { dip_test, 2'b11, IPLn[0], LVBL, fake_dma, eep_rdy, eep_do }:
                       { service, coin };
    case( {addr[8],addr[2:1]} )
        0: dout <= { cab_1p[0], joystick1[6:0] };
        1: dout <= { cab_1p[1], joystick2[6:0] };
        2: dout <= { cab_1p[2], joystick3[6:0] };
        3: dout <= { cab_1p[3], joystick4[6:0] };
        default:;
    endcase
end

endmodule
