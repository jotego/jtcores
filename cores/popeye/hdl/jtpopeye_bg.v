/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_bg(
    input             rst,
    input             clk,
    input             cen5,
    input             cen10,
    input             nibd7,
    input             tnx1,

    input      [12:0] ad,
    input      [ 3:0] dd,
    input             dd7,
    input             csbw_n,
    input             dwrbk_n,
    input             memwr0,

    input             rohvck,
    input      [ 7:0] obj_do,
    input             do16,
    input      [ 8:1] rovi,

    output     [11:0] bg_addr,
    output            bglo_we,
    output            bghi_we,
    input      [ 7:0] bglo_dout,
    input      [ 7:0] bghi_dout,

    output reg [ 3:0] bakc
);

wire [12:0] adv;
wire [11:0] at_cpu, at_vid;
wire [ 8:0] roh_ld;

wire [ 5:0] rowv;
wire [ 3:0] bkmux;
wire        g7s, s8t, cp8u, wen, wsel, vsel, dotck;
reg  [ 8:0] roh;
reg  [ 8:1] rov, rovi_l;
reg         m8qn, rohvck_l, cp8u_l;

assign adv        = { ad[12:6], ~ad[5:0] };
assign at_cpu     = { adv[11], adv[10], adv[5], adv[9], adv[8], adv[7],
                      adv[4], adv[3], adv[6], adv[2:0] };
assign rowv       = nibd7 ? rov[7:2] : rov[6:1];
assign at_vid     = { rowv, roh[7:2] };
assign g7s        = csbw_n & rov[8];
assign bg_addr    = g7s ? 12'd0 : csbw_n ? at_vid : at_cpu;
assign vsel       = tnx1 ? roh[8] : nibd7 ? rov[1] : rov[7];
assign wsel       = nibd7 ? dd7 : adv[12];
assign s8t        = csbw_n ? vsel : ~wsel;
assign bkmux      = s8t ? bghi_dout[3:0] : bglo_dout[3:0];
assign cp8u       = csbw_n ? m8qn : memwr0;
assign wen        = ~dwrbk_n & ~( nibd7 & adv[12] );
assign bglo_we      = wen & ~wsel;
assign bghi_we      = wen &  wsel;
assign roh_ld     = { tnx1 & do16, obj_do };
assign dotck      = cen10 & ~cen5;

always @(posedge clk) begin
    if( rst ) begin
        roh      <= 0;
        m8qn     <= 0;
        rov      <= 0;
        rovi_l   <= 0;
        rohvck_l <= 1;
        cp8u_l   <= 0;
        bakc     <= 0;
    end else begin
        rovi_l   <= rovi;
        rohvck_l <= rohvck;
        cp8u_l   <= cp8u;
        if( dotck ) roh <= !rohvck ? roh_ld : roh + 9'd1;
        if( cen5 ) m8qn <= &roh[1:0];
        if( !csbw_n )
            rov <= 0;
        else if( rohvck && !rohvck_l )
            rov <= { ~rovi_l[8], rovi_l[7:1] };
        if( cp8u && !cp8u_l ) bakc <= bkmux;
    end
end

endmodule
