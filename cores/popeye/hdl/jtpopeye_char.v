/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_char(
    input             rst,
    input             clk,
    input             cen10,
    input             cen5,

    input      [11:0] ad,
    input      [ 7:0] dd,
    input             csv,
    input             memwr0,

    input      [ 7:0] h,
    input             hb,
    input      [ 7:0] v,
    input             vb,
    input             rv,

    output     [11:0] char_addr,
    input      [ 7:0] char_data,

    output reg        txtv,
    output reg [ 3:0] txtc
);

wire [ 5:0] adv;
wire [ 9:0] cpu_a, scan;
wire [ 7:0] ddt, tq;
wire [ 3:0] ddtc, cq;
wire        txtshift_n, ddtwr, dotck;
reg  [ 9:0] ta;
reg  [ 7:0] din, sh;
reg         we5pr, we5s, wrt;

assign adv        = ~ad[5:0];
assign cpu_a      = { adv[5], ad[9:7], adv[4:3], ad[6], adv[2:0] };
assign scan       = { v[7:3], h[7:3] };
assign ddtwr      = csv & memwr0;
assign dotck      = cen10 & ~cen5;
assign txtshift_n = ~(&h[2:0] & ~hb);
assign ddt        = wrt ? din      : tq;
assign ddtc       = wrt ? din[3:0] : cq;
assign char_addr  = { 1'b1, ddt, v[2:0] };

always @(posedge clk) begin
    if( rst ) begin
        ta    <= 0;
        din   <= 0;
        wrt   <= 0;
        we5pr <= 0;
        we5s  <= 0;
    end else begin
        ta    <= csv ? cpu_a : scan;
        din   <= dd;
        wrt   <= ddtwr;
        we5pr <= ddtwr && ad[11:10]==2'd0;
        we5s  <= ddtwr && ad[11:10]==2'd1;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        sh   <= 0;
        txtc <= 0;
        txtv <= 1;
    end else begin
        if( dotck ) begin
            if( !txtshift_n ) begin
                sh   <= char_data;
                txtc <= ddtc;
            end else begin
                sh   <= rv ? { sh[6:0], 1'b0 } : { 1'b0, sh[7:1] };
            end
        end
        if( vb ) sh <= 0;
        txtv <= ~(rv ? sh[7] : sh[0]);
    end
end

jtframe_ram #(.AW(10),.DW(8)) u_5pr(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( ddt       ),
    .addr   ( ta        ),
    .we     ( we5pr     ),
    .q      ( tq        )
);

jtframe_ram #(.AW(10),.DW(4)) u_5s(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( ddtc      ),
    .addr   ( ta        ),
    .we     ( we5s      ),
    .q      ( cq        )
);

endmodule
