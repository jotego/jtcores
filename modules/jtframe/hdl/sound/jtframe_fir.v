/* This file is part of JTFRAME.


    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-11-2020

*/

// Generic FIR filter for stereo signals
// Max 127 coefficients

// Parameters
// KMAX = number of coefficients (8 bit value)
// COEFFS = hex file with filter coefficients

module jtframe_fir(
    input             rst,
    input             clk,
    input             sample,
    input      signed [15:0] l_in,
    input      signed [15:0] r_in,
    output reg signed [15:0] l_out,
    output reg signed [15:0] r_out
);

parameter [7:0] KMAX = 8'd68;
parameter COEFFS = "filter.hex";

reg signed [15:0] ram[0:511];   // dual port RAM
reg [6:0] pt_wr, pt_rd;
reg [7:0] cnt;
reg       st;
reg signed [35:0] acc_l, acc_r;
reg signed [15:0] coeff;
reg signed [31:0] p_l, p_r;
wire       [ 8:0] ram_idx, ptr_l, ptr_r; // using a wire prevents a false warning from Quartus

assign ram_idx = {2'd0, cnt[6:0]};
assign ptr_l   = {2'd1, pt_rd };
assign ptr_r   = {2'd2, pt_rd };

function signed [35:0] ext;
    input signed [31:0] p;
    ext = { {4{p[31]}}, p };
endfunction

function [6:0] loop_inc;
    input [6:0] s;
    loop_inc = s == KMAX[6:0]-7'd1 ? 7'd0 : s+7'd1;
endfunction

function signed [15:0] sat;
    input [35:0] a;
    sat = a[35:32] == {4{a[31]}} ? a[31:16] : { a[35], {15{~a[35]}} };
endfunction

always@(posedge clk, posedge rst) begin
    if( rst ) begin
        l_out <= 0;
        r_out <= 0;
        pt_rd <= 0;
        pt_wr <= 0;
        cnt   <= 0;
        acc_l <= 0;
        acc_r <= 0;
        p_l   <= 0;
        p_r   <= 0;
    end else begin
        if( sample ) begin
            pt_rd <= pt_wr;
            cnt   <= 0;
            ram[ { 2'd1, pt_wr } ] <= l_in;
            ram[ { 2'd2, pt_wr } ] <= r_in;
            pt_wr <= loop_inc( pt_wr );
            acc_l <= 0;
            acc_r <= 0;
            p_l   <= 0;
            p_r   <= 0;
            st    <= 0;
        end else begin
            if( cnt < KMAX ) begin
                st <= ~st;
                if( st == 0 ) begin
                    coeff <= ram[ ram_idx ];
                end else begin
                    p_l <= ram[ ptr_l ] * coeff;
                    p_r <= ram[ ptr_r ] * coeff;
                    acc_l <= acc_l + ext(p_l);
                    acc_r <= acc_r + ext(p_r);
                    cnt <= cnt+8'd1;
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
    $readmemh( COEFFS, ram );
end
endmodule

