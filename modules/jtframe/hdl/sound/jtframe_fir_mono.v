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
    Date: 12-1-2021

*/

// Generic FIR filter for mono signals
// Max 255 coefficients

// Parameters
// KMAX = number of coefficients (8 bit value)
// COEFFS = hex file with filter coefficients

module jtframe_fir_mono(
    input             rst,
    input             clk,
    input             sample,
    input      signed [15:0] din,
    output reg signed [15:0] dout
);

parameter [7:0] KMAX = 8'd68;
parameter     COEFFS = "filter.hex";

reg         [ 7:0] pt_wr, pt_rd, cnt;
reg         [ 8:0] rd_addr;
reg                st, wt_ram;
reg  signed [35:0] acc;
reg  signed [15:0] coeff;
reg  signed [31:0] p;
wire signed [15:0] ram_dout;

function signed [35:0] ext;
    input signed [31:0] p;
    ext = { {4{p[31]}}, p };
endfunction

function [7:0] loop_inc;
    input [7:0] s;
    loop_inc = s == KMAX-8'd1 ? 8'd0 : s+8'd1;
endfunction

function signed [15:0] sat;
    input [35:0] a;
    sat = a[35:30] == {6{a[29]}} ? a[29:14] : { a[35], {15{~a[35]}} };
endfunction

always @(*) begin
    rd_addr = st==0 ? {1'd0, cnt} : {1'd1, pt_rd};
end

// dual port RAM
// the first half contains the coefficients
// the second half, contains the signal

jtframe_dual_ram #(.DW(16), .AW(9), .SYNFILE(COEFFS)) u_ram(
    .clk0   ( clk           ),
    .clk1   ( clk           ),
    // Port 0: write
    .data0  ( din           ),
    .addr0  ( {1'd1, pt_wr} ),
    .we0    ( sample        ),
    .q0     (               ),
    // Port 1: read
    .data1  ( 16'd0         ),
    .addr1  ( rd_addr       ),
    .we1    ( 1'd0          ),
    .q1     ( ram_dout      )
);

always@(posedge clk, posedge rst) begin
    if( rst ) begin
        dout  <= 16'd0;
        pt_rd <= 8'd0;
        pt_wr <= 8'd0;
        cnt   <= 8'd0;
        acc   <= 36'd0;
        p     <= 32'd0;
        coeff <= 16'd0;
    end else begin
        if( sample ) begin
            pt_rd <= pt_wr;
            cnt   <= 0;
            // ram[ { 1'd1, pt_wr } ] <= din;
            pt_wr <= loop_inc( pt_wr );
            acc   <= 36'd0;
            p     <= 32'd0;
            st    <= 0;
            wt_ram<= 1;
        end else begin
            wt_ram <= ~wt_ram;
            if( !wt_ram ) begin
                if( cnt < KMAX ) begin
                    st <= ~st;
                    if( st == 0 ) begin
                        coeff <= ram_dout;
                    end else begin
                        p     <= ram_dout * coeff;
                        acc   <= acc + ext(p);
                        cnt   <= cnt+7'd1;
                        pt_rd <= loop_inc( pt_rd );
                    end
                end else begin
                    dout <= sat(acc);
                end
            end
        end
    end
end

endmodule

