/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-2-2025 */

module jtflstory_gun(
    input            clk,
                     gunx_cs, guny_cs, trcrt_cs,
    input      [8:0] gun_x, gun_y,

    output reg [7:0] gun_dout
);

    reg [7:0] gunadj_x, gunadj_y;

    always @(posedge clk) begin
        if(trcrt_cs) begin
            gunadj_x <= gun_x[7:0];
            gunadj_y <= gun_y[7:0];
        end
        gun_dout <= gunx_cs ? gunadj_x :
                    guny_cs ? gunadj_y : 8'h01;
    end
endmodule