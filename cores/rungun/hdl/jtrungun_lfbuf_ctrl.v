/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 13-8-2025 */

module jtrungun_lfbuf_ctrl(
    input             clk,
    input             obj_done,

    output     [ 8:0] ln_addr,
    output reg        ln_done=0,
    input             ln_hs, ln_vs, ln_lvbl,
    input      [ 7:0] ln_v,
    output            ln_we,

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

wire [9:0] nx_hdump;
reg  [8:0] start_lhbl=0, end_lhbl=0;
reg        lnhs_l=0, rest_done=0;
reg  [1:0] cencnt=0;
wire       hs_edge, data_ok, blank_v, is_hblanking;

assign vdump    = ln_v;
assign nx_hdump = {1'b0,hdump}+10'd1;
assign ln_we    = ~ln_done & ~is_hblanking & cen;
assign ln_addr  = hdump;
assign hs_edge  = ln_hs & ~lnhs_l;
assign hdumpf   = {9{hflip}}^hdump,
       vdumpf   = {8{vflip}}^vdump;
assign data_ok  = ~ln_lvbl | is_hblanking | &{fix_ok|~fix_cs,scr_ok|~scr_cs,obj_ok|~obj_cs};
assign blank_v  = ln_v=='h17;
assign is_hblanking = !lhbl;

always @(posedge clk) begin
    end_lhbl <= {3'd0,hsy_len} + {3'd0,hsa_len};
    start_lhbl <= 9'd0 - {3'd0,hbs_len};
end

always @(posedge clk) begin
    ln_done <= rest_done && (blank_v || obj_done);
    cencnt  <= (cencnt==2 && data_ok) ? 2'd0 : cencnt!=2 ? cencnt+1'd1 : cencnt;
    cen     <= &{data_ok,cencnt==2, ~rest_done};
    obj_cen <= &{data_ok,cencnt==2, ~rest_done|~obj_done};
    if(blank_v) begin
        cen     <= ~ln_done;
        obj_cen <= ~ln_done;
    end
    lnhs_l <= ln_hs;
    if(cen && !rest_done ) begin
        {rest_done,hdump} <= nx_hdump;
    end
    if( hs_edge ) begin
        hdump     <= 9'd0;
        hs        <= 1;
        lhbl      <= 0;
        ln_done   <= 0;
        rest_done <= 0;
    end
    if( hdump=={3'd0,hsy_len} ) hs   <= 0;
    if( hdump==end_lhbl       ) lhbl <= 1;
    if( hdump==start_lhbl     ) lhbl <= 0;
end

endmodule
