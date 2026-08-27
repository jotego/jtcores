/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-5-2023 */

module jtngp_psg(
    input                    rst,
    input                    clk,
    input                    cen,

    input                    r_wn,
    input                    cs,
    input                    a0,
    input             [ 7:0] din,
    output                   ready,
    output reg signed [11:0] snd
);

wire signed [10:0] tone, noise;
wire        [ 1:0] cs_n, rdy;

assign ready = &rdy;
assign cs_n = ~({2{cs}} & {a0, ~a0});

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        snd <= 0;
    end else begin
        snd <= {tone[10], tone } + {noise[10], noise };
    end
end

jt89 #(.MODE(2) `ifdef JTFRAME_RELEASE ,.INTERPOL16(1) `endif  )u_jt89_0(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .clk_en ( cen       ),
    .wr_n   ( r_wn      ),
    .cs_n   ( cs_n[0]   ),
    .din    ( din       ),
    .sound  ( noise     ),
    .ready  ( rdy[0]    )
);

jt89 #(.MODE(1) `ifdef JTFRAME_RELEASE ,.INTERPOL16(1) `endif)u_jt89_1(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .clk_en ( cen       ),
    .wr_n   ( r_wn      ),
    .cs_n   ( cs_n[1]   ),
    .din    ( din       ),
    .sound  ( tone      ),
    .ready  ( rdy[1]    )
);

endmodule