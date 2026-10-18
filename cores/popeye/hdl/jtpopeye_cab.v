/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_cab(
    input            rst,
    input            clk,
    input            psg_cen,
    input      [1:0] addr,
    input            initeo,
    input            tnx1,

    input      [1:0] cab_1p,
    input            coin,
    input            service,
    input      [5:0] joystick1,
    input      [5:0] joystick2,

    output reg [7:0] cab
);
    localparam [17:0] COIN_LEN = 18'd188800;

    reg  [17:0] coin_cnt;
    reg         coin_l;
    wire        coin_trig, coin_os;

    assign coin_trig = coin_l & ~coin;
    assign coin_os   = coin_cnt!=0;

    function [7:0] arrange(input [5:0] joy, input b2); begin
        arrange = { b2 & ~joy[5], 2'd0, ~joy[4], ~joy[2], ~joy[3], ~joy[1], ~joy[0] };
    end endfunction

    always @(posedge clk) begin
        if( rst ) begin
            coin_l   <= 1;
            coin_cnt <= 0;
        end else if( psg_cen ) begin
            coin_l <= coin;
            if( coin_trig )
                coin_cnt <= COIN_LEN;
            else if( coin_os )
                coin_cnt <= coin_cnt - 18'd1;
        end
    end

    always @(posedge clk) begin
        if( rst ) begin
            cab <= 0;
        end else begin
            case( addr )
                2'd1: cab <= { coin_os, ~service, 1'b0, initeo, ~cab_1p[1], ~cab_1p[0], 2'b00 };
                2'd2: cab <= arrange(joystick2, tnx1);
                2'd3: cab <= arrange(joystick1, tnx1);
                default: cab <= 0;
            endcase
        end
    end
endmodule
