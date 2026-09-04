/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-8-2025 */

module jtrungun_lfbuf_ctrl(
    input             rst, clk,
    input             obj_done,

    output reg [ 8:0] ln_addr=0,
    output reg [15:0] ln_data=0,
    output reg        ln_done=0,
    input             ln_hs, ln_vs, ln_lvbl,
    input      [ 7:0] ln_v,
    output reg        ln_we=0,

    // Renderer pipeline
    input      [ 8:0] obj_pxl_raw,
    input      [ 7:0] fix_pxl_raw, psc_pxl_raw,
    input      [ 1:0] shadow_raw,
    input             lrsw, pri,
    input      [15:0] ln_data_raw,
    output reg [ 8:0] obj_pxl=0,
    output reg [ 7:0] fix_pxl=0, psc_pxl=0,
    output reg [ 1:0] shadow=0,
    output reg        lrsw_l=0, pri_l=0,

    input             scr_cs, obj_cs, fix_cs,
                      scr_ok, obj_ok, fix_ok,
                      hflip, vflip,
    // virtual screen
    input      [ 5:0] hbs_len,  // H blank start to HS start
                      hsy_len,  // HS length
                      hsa_len,  // HS end to active video start

    output reg        cen=0,
    output reg        obj_cen=0,
    output reg        hs=0, lhbl=0,
    output reg [ 8:0] hdump=0,
    output     [ 8:0] hdumpf,
    output     [ 7:0] vdump, vdumpf
);

wire [ 9:0] nx_hdump;
wire [ 8:0] ln_addr_raw;
wire        hs_edge, data_ok, rom_wait, step, blank_v, is_hblanking, ln_we_raw;
reg  [ 8:0] start_lhbl=0, end_lhbl=0, ln_addr_m=0;
reg  [ 2:0] cen_state=3'b001;
reg         lnhs_l=0, rest_done=0, ln_done_raw=0, ln_done_m=0, ln_we_m=0;

assign vdump         = ln_v;
assign nx_hdump      = {1'b0,hdump}+10'd1;
assign ln_we_raw     = ~ln_done_raw & ~is_hblanking & cen;
assign ln_addr_raw   = hdump;
assign hs_edge       = ln_hs & ~lnhs_l;
assign hdumpf        = {9{hflip}}^hdump;
assign vdumpf        = {8{vflip}}^vdump;
assign rom_wait      = (fix_cs & ~fix_ok) | (scr_cs & ~scr_ok) | (obj_cs & ~obj_ok);
assign data_ok       = ~ln_lvbl | is_hblanking | ~rom_wait;
assign step          = data_ok & cen_state[2];
assign blank_v       = ln_v==8'h17;
assign is_hblanking = !lhbl;

always @(posedge clk) begin
    end_lhbl <= {3'd0,hsy_len} + {3'd0,hsa_len};
    start_lhbl <= 9'd0 - {3'd0,hbs_len};
end

always @(posedge clk) begin
    if( rst ) begin
        obj_pxl  <= 0;
        fix_pxl  <= 0;
        psc_pxl  <= 0;
        shadow   <= 0;
        lrsw_l   <= 0;
        pri_l    <= 0;
        ln_data  <= 0;
        ln_addr_m <= 0;
        ln_addr  <= 0;
        ln_done_m <= 0;
        ln_done  <= 0;
        ln_we_m   <= 0;
        ln_we    <= 0;
    end else begin
        obj_pxl  <= obj_pxl_raw;
        fix_pxl  <= fix_pxl_raw;
        psc_pxl  <= psc_pxl_raw;
        shadow   <= shadow_raw;
        lrsw_l   <= lrsw;
        pri_l    <= pri;
        ln_data  <= ln_data_raw;
        ln_addr_m <= ln_addr_raw;
        ln_addr  <= ln_addr_m;
        ln_done_m <= ln_done_raw;
        ln_done  <= ln_done_m;
        ln_we_m   <= ln_we_raw;
        ln_we    <= ln_we_m;
    end
end

always @(posedge clk) begin
    ln_done_raw <= rest_done && (blank_v || obj_done);
    cen_state[0] <= step;
    cen_state[1] <= cen_state[0];
    cen_state[2] <= cen_state[1] | (cen_state[2] & ~data_ok);
    cen      <= blank_v ? ~ln_done_raw : step & ~rest_done;
    obj_cen  <= blank_v ? ~ln_done_raw : step & (~rest_done | ~obj_done);
    lnhs_l   <= ln_hs;
    if(cen && !rest_done ) begin
        {rest_done,hdump} <= nx_hdump;
    end
    if( hs_edge ) begin
        hdump       <= 9'd0;
        hs          <= 1;
        lhbl        <= 0;
        ln_done_raw <= 0;
        rest_done   <= 0;
    end
    if( hdump=={3'd0,hsy_len} ) hs   <= 0;
    if( hdump==end_lhbl       ) lhbl <= 1;
    if( hdump==start_lhbl     ) lhbl <= 0;
end

endmodule
