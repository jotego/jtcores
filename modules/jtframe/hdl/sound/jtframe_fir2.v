/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 22-11-2020 */

module jtframe_fir2(
    input             rst,
    input             clk,
    input             sample,
    input      signed [15:0] l_in,
    input      signed [15:0] r_in,
    output reg signed [15:0] l_out,
    output reg signed [15:0] r_out
);

parameter [7:0] KMAX = 8'd68;

reg signed [15:0] ram[0:511];   // dual port RAM
reg [6:0] pt_wr, pt_rd, cnt;
reg       st;
reg signed [35:0] acc_l, acc_r;
reg signed [15:0] coeff;
reg signed [31:0] p_l, p_r;

function signed [35:0] ext;
    input signed [31:0] p;
    ext = { {4{p[31]}}, p };
endfunction

function [6:0] loop_inc;
    input [6:0] s;
    loop_inc = s == KMAX ? 8'd0 : s+8'd1;
endfunction

function signed [15:0] sat;
    input [35:0] a;
    sat = a[35:30] == {6{a[29]}} ? a[29:14] : { a[35], {15{~a[35]}} };
endfunction

always@(posedge clk) begin
    if( rst ) begin
        l_out <= 16'd0;
        r_out <= 16'd0;
        pt_rd <= 8'd0;
        pt_wr <= 8'd0;
        cnt   <= 8'd0;
    end else begin
        if( sample ) begin
            pt_rd <= pt_wr;
            cnt   <= KMAX;
            ram[ { 2'd1, pt_wr } ] <= l_in;
            ram[ { 2'd2, pt_wr } ] <= r_in;
            pt_wr <= loop_inc( pt_wr );
            acc_l <= 36'd0;
            acc_r <= 36'd0;
            p_l   <= 32'd0;
            p_r   <= 32'd0;
            st    <= 0;
        end else begin
            if( cnt != 8'd0 ) begin
                st <= ~st;
                if( st == 0 ) begin
                    coeff <= ram[ {2'd0, cnt } ];
                end else begin
                    p_l <= ram[ {2'd1, pt_rd } ] * coeff;
                    p_r <= ram[ {2'd2, pt_rd } ] * coeff;
                    acc_l <= acc_l + ext(p_l);
                    acc_r <= acc_r + ext(p_r);
                    cnt <= cnt-8'd1;
                    pt_rd <= loop_inc( pt_rd );
                end
            end else begin
                l_out <= sat(acc_l);
                r_out <= sat(acc_r);
            end
        end
    end
end

initial begin
    $readmemh( "fir2_69.hex", ram );
end
endmodule
