/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-1-2025 */

module jtframe_multiway(
    input         clk,
    input         vs,
    input  [15:0] ana1, ana2,
    input  [15:0] raw1, raw2,
    output [15:0] joy1, joy2
);
    wire [1:0] frame_cnt;

    assign joy1[15:4]=raw1[15:4];
    assign joy2[15:4]=raw2[15:4];

    function [7:0]horizontal(input [15:0]ana); begin
        horizontal=ana[7:0];
    end endfunction

    function [7:0]vertical(input [15:0]ana); begin
        vertical=ana[15:8];
    end endfunction

    jtframe_multiway_framecnt u_counter(clk,vs,frame_cnt);
    jtframe_multiway_emu_analog u_joy1_hori(clk,frame_cnt,raw1[1:0],horizontal(ana1),joy1[1:0]);
    jtframe_multiway_emu_analog u_joy2_hori(clk,frame_cnt,raw2[1:0],horizontal(ana2),joy2[1:0]);
    jtframe_multiway_emu_analog u_joy1_vert(clk,frame_cnt,raw1[3:2],vertical  (ana1),joy1[3:2]);
    jtframe_multiway_emu_analog u_joy2_vert(clk,frame_cnt,raw2[3:2],vertical  (ana2),joy2[3:2]);
endmodule

module jtframe_multiway_framecnt(
    input            clk, vs,
    output reg [1:0] frame_cnt=0
);
    reg vs_l;

    always @(posedge clk) begin
        vs_l <= vs;
        if( vs && !vs_l ) frame_cnt <= frame_cnt+2'd1;
    end
endmodule

module jtframe_multiway_emu_analog(
    input            clk,
    input      [1:0] frame_cnt,
    input      [1:0] raw,
    input      [7:0] ana,
    output reg [1:0] joy
);
    localparam NONINVERT=1'b0, INVERT=1'b1, CONFLICT=2'b11;

    reg [1:0] multi;

    function pwm( input invert, rawin, input [7:0] range); begin : _pwm
        reg disabled;
        reg [7:0] abs;
        abs = {8{invert}}^range;
        disabled = abs[7];
        case(abs[6:4])
         default: pwm=1;
               3: pwm=frame_cnt[1:0]!=0; // 75%
               2: pwm=frame_cnt[0];      // 50%
               1: pwm=frame_cnt[1:0]==0; // 25%
               0: pwm=rawin;
        endcase
        if(disabled) pwm=rawin;
    end endfunction

    always @(posedge clk) begin
        multi[0] <= pwm(NONINVERT, raw[0], ana);
        multi[1] <= pwm(   INVERT, raw[1], ana);
        case(multi)
            CONFLICT:joy <= 0;
            default: joy <= multi;
        endcase
    end
endmodule
