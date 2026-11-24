/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 5-10-2026 */

module jtnarc_sound(
    input             rst,
    input             clk,
    input             cen8,
    input             cen_fm,
    input             cen_fm2,
    input             cen192,

    input             rst_rom,
    input             clk_rom,

    input      [15:0] snd_latch,
    output     [ 7:0] tb_data,
    output            tb_ack_n,

    output     [16:0] mrom_addr,
    output            mrom_rd,
    input      [ 7:0] mrom_data,
    input             mrom_ok,

    output     [17:0] srom_addr,
    output            srom_rd,
    input      [ 7:0] srom_data,
    input             srom_ok,

    output signed [15:0] fm_l,
    output signed [15:0] fm_r,
    output     [15:0] dac_m,
    output     [15:0] dac_s,
    output signed [15:0] cvsd
);

`ifndef NOSOUND
wire [16:0] mcpu_addr;
wire [17:0] scpu_addr;
wire [ 7:0] mcpu_data, scpu_data, comm;
wire        mcpu_cs, mrom_hit, scpu_cs, srom_hit, comm_st;
wire        board_rst, strobe, nmi_n, cvsd_clk, cvsd_din;
wire signed [ 9:0] cvsd_dac;
wire signed [15:0] fm_raw_l, fm_raw_r, dacm_s, dacs_s, dacm_h, dacs_h;
wire        [ 7:0] dacm_raw, dacs_raw;
wire [ 7:0] scd;
reg  [15:0] latch_s, latch_l;
reg         mcpu_ok, scpu_ok;

assign board_rst = ~latch_l[10];
assign strobe    =  latch_l[9];
assign nmi_n     =  latch_l[8];
assign scd       =  latch_l[7:0];

always @(posedge clk) begin
    if( rst ) begin
        latch_s <= 16'hfbff;
        latch_l <= 16'hfbff;
    end else begin
        latch_s <= snd_latch;
        latch_l <= latch_s;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        mcpu_ok <= 0;
        scpu_ok <= 0;
    end else begin
        mcpu_ok <= mrom_hit & mcpu_cs;
        scpu_ok <= srom_hit & scpu_cs;
    end
end

jtnarc_sndmain u_main(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .cen8      ( cen8      ),
    .cen_fm    ( cen_fm    ),
    .cen_fm2   ( cen_fm2   ),
    .cen192    ( cen192    ),
    .board_rst ( board_rst ),
    .scd       ( scd       ),
    .strobe    ( strobe    ),
    .nmi_n     ( nmi_n     ),
    .comm      ( comm      ),
    .comm_st   ( comm_st   ),
    .tb        ( tb_data   ),
    .ack_n     ( tb_ack_n  ),
    .rom_addr  ( mcpu_addr ),
    .rom_cs    ( mcpu_cs   ),
    .rom_data  ( mcpu_data ),
    .rom_ok    ( mcpu_ok   ),
    .dac       ( dacm_raw  ),
    .fm_l      ( fm_raw_l  ),
    .fm_r      ( fm_raw_r  )
);

jtnarc_sndsub u_sub(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .cen8      ( cen8      ),
    .board_rst ( board_rst ),
    .comm      ( comm      ),
    .comm_st   ( comm_st   ),
    .rom_addr  ( scpu_addr ),
    .rom_cs    ( scpu_cs   ),
    .rom_data  ( scpu_data ),
    .rom_ok    ( scpu_ok   ),
    .dac       ( dacs_raw  ),
    .cvsd_clk  ( cvsd_clk  ),
    .cvsd_din  ( cvsd_din  )
);

jtnarc_cvsd u_cvsd(
    .rst      ( rst      ),
    .clk      ( clk      ),
    .cvsd_clk ( cvsd_clk ),
    .cvsd_din ( cvsd_din ),
    .dac      ( cvsd_dac )
);

jtnarc_cvsdflt u_cvsdflt(
    .rst    ( rst      ),
    .clk    ( clk      ),
    .cen192 ( cen192   ),
    .dac    ( cvsd_dac ),
    .snd    ( cvsd     )
);

assign dacm_s = { ~dacm_raw[7], dacm_raw[6:0], 8'd0 };
assign dacs_s = { ~dacs_raw[7], dacs_raw[6:0], 8'd0 };
assign fm_l   = fm_raw_l >>> 1;
assign fm_r   = fm_raw_r >>> 1;
assign dacm_h = dacm_s >>> 1;
assign dacs_h = dacs_s >>> 1;
assign dac_m  = dacm_h ^ 16'h8000;
assign dac_s  = dacs_h ^ 16'h8000;

jtnarc_sndrom #(.AW(17)) u_mrom(
    .rst       ( rst_rom   ),
    .clk       ( clk_rom   ),
    .cs        ( mcpu_cs   ),
    .addr      ( mcpu_addr ),
    .dout      ( mcpu_data ),
    .ok        ( mrom_hit  ),
    .lane_addr ( mrom_addr ),
    .lane_rd   ( mrom_rd   ),
    .lane_data ( mrom_data ),
    .lane_ok   ( mrom_ok   )
);

jtnarc_sndrom #(.AW(18)) u_srom(
    .rst       ( rst_rom   ),
    .clk       ( clk_rom   ),
    .cs        ( scpu_cs   ),
    .addr      ( scpu_addr ),
    .dout      ( scpu_data ),
    .ok        ( srom_hit  ),
    .lane_addr ( srom_addr ),
    .lane_rd   ( srom_rd   ),
    .lane_data ( srom_data ),
    .lane_ok   ( srom_ok   )
);

`else
assign tb_data   = 0;
assign tb_ack_n  = 1;
assign mrom_addr = 0;
assign mrom_rd   = 0;
assign srom_addr = 0;
assign srom_rd   = 0;
assign fm_l      = 0;
assign fm_r      = 0;
assign dac_m     = 0;
assign dac_s     = 0;
assign cvsd      = 0;
`endif
endmodule
