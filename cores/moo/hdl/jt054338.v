/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jt054338 #(
    parameter ALPHA_INV = 0
)(
    input             rst,
    input             clk,

    input             cs,
    input             we,
    input      [ 3:0] addr,
    input      [15:0] din,
    input      [ 1:0] dsn,
    output     [15:0] dout,

    input      [ 1:0] pblend,
    input      [ 1:0] shadow,

    output     [23:0] bg_rgb,
    output     [ 7:0] alpha_level,
    output            alpha_add,
    output            video_en,
    output            mixpri,
    output            shdpri,
    output            brtpri,
    output            clipsl,
    output     [23:0] dump_mmr,

    output signed [9:0] shadow_r,
    output signed [9:0] shadow_g,
    output signed [9:0] shadow_b
);

localparam BGC_R   =  4'd0,
           BGC_GB  =  4'd1,
           SHAD1R  =  4'd2,
           BRI3    =  4'd11,
           PBLEND  =  4'd13,
           CONTROL =  4'd15;

reg [15:0] regs[0:15];

wire [ 3:0] shd_base = shadow == 2'd2 ? SHAD1R + 4'd3 :
                       shadow == 2'd3 ? SHAD1R + 4'd6 : SHAD1R;
wire [ 8:0] shd_r9   = shadow == 0 ? 9'd0  : regs[shd_base     ][8:0];
wire [ 8:0] shd_g9   = shadow == 0 ? 9'd0  : regs[shd_base+4'd1][8:0];
wire [ 8:0] shd_b9   = shadow == 0 ? 9'd0  : regs[shd_base+4'd2][8:0];
wire [ 7:0] mixset   = pblend == 0 ? 8'h1f :
                       pblend[0]   ? regs[PBLEND + {3'd0,pblend[1]}][ 7:0] :
                                     regs[PBLEND + {3'd0,pblend[1]}][15:8];
wire [ 4:0] mixlv    = ALPHA_INV ? ~mixset[4:0] : mixset[4:0];

assign dout        = regs[addr];
assign bg_rgb      = { regs[BGC_R][7:0], regs[BGC_GB][15:8], regs[BGC_GB][7:0] };
assign alpha_level = { mixlv, mixlv[4:2] };
assign alpha_add   = pblend != 0 && mixset[5];
assign video_en    = regs[CONTROL][0];
assign mixpri      = regs[CONTROL][1];
assign shdpri      = regs[CONTROL][2];
assign brtpri      = regs[CONTROL][3];
assign clipsl      = regs[CONTROL][5];
assign dump_mmr    = { regs[CONTROL][7:0], regs[BRI3][7:0], regs[PBLEND][7:0] };

assign shadow_r    = {shd_r9[8], shd_r9};
assign shadow_g    = {shd_g9[8], shd_g9};
assign shadow_b    = {shd_b9[8], shd_b9};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        regs[ 0] <= 0; regs[ 1] <= 0; regs[ 2] <= 0; regs[ 3] <= 0;
        regs[ 4] <= 0; regs[ 5] <= 0; regs[ 6] <= 0; regs[ 7] <= 0;
        regs[ 8] <= 0; regs[ 9] <= 0; regs[10] <= 0; regs[11] <= 0;
        regs[12] <= 0; regs[13] <= 0; regs[14] <= 0; regs[15] <= 0;
    end else if( cs && we ) begin
        if( !dsn[1] ) regs[addr][15:8] <= din[15:8];
        if( !dsn[0] ) regs[addr][ 7:0] <= din[ 7:0];
    end
end

endmodule
