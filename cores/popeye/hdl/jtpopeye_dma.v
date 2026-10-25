/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 12-10-2026 */

module jtpopeye_dma(
    input             rst,
    input             clk,
    input             reset_n,

    input             ai_n,
    input             bi_n,
    input             hbd_n,
    input             vb,
    input             busak_n,

    output reg        busrq_n,
    output            dma_cs,
    output     [10:0] dma_addr,
    output     [ 7:0] dm,
    output reg [ 3:0] dmcs_n,
    output reg        rohvs,
    output reg        rohvck
);

reg  [10:0] cnt;
reg         ai_l, bi_l, vb_l, busak_l, mr_l;
reg         h1l, busak_d, l1c, r1c;
wire        ai, bi, dm10;
wire        ai_rise, ai_fall, bi_fall, vb_rise, h1l_rise;
wire        d1c, cl1c_n, mr_n, cnt_en;

assign ai       = ~ai_n;
assign bi       = ~bi_n;
assign dm10     = cnt[10];
assign dm       = cnt[7:0];
assign dma_cs   = busak_d & ~dm10;
assign dma_addr = { 1'b1, cnt[6:4], cnt[1], ~cnt[7], ~cnt[3:2], ~cnt[0], ~cnt[9:8] };

assign ai_rise  =  ai & ~ai_l;
assign ai_fall  = ~ai &  ai_l;
assign bi_fall  = ~bi &  bi_l;
assign vb_rise  =  vb & ~vb_l;
assign h1l_rise =  ai_rise & bi & ~h1l;

assign d1c      = ~(~busak_d & hbd_n);
assign cl1c_n   = ~(~busrq_n & ~busak_d);
assign mr_n     = ~(~l1c & d1c);
assign cnt_en   = ~(h1l & busak_d);

always @(posedge clk) begin
    if( rst ) begin
        ai_l    <= 0;
        bi_l    <= 0;
        vb_l    <= 0;
        busak_l <= 1;
        mr_l    <= 0;
        h1l     <= 0;
        busak_d <= 0;
        busrq_n <= 1;
        l1c     <= 0;
        r1c     <= 0;
        cnt     <= 0;
        dmcs_n  <= 4'hf;
        rohvs   <= 1;
        rohvck  <= 1;
    end else begin
        ai_l <= ai;
        bi_l <= bi;
        vb_l <= vb;
        busak_l <= busak_n;
        mr_l    <= mr_n;
        if( ai_rise ) h1l     <= bi;
        if( bi_fall ) busak_d <= ~busak_l;
        if( dm10 || !reset_n )
            busrq_n <= 1;
        else if( vb_rise )
            busrq_n <= 0;
        if( !cl1c_n )
            l1c <= 0;
        else if( h1l_rise )
            l1c <= d1c;
        if( ai_rise ) r1c <= mr_l;
        if( !mr_n )
            cnt <= 0;
        else if( ai_fall && cnt_en && mr_l )
            cnt <= cnt + 11'd1;
        dmcs_n <= ( bi_n && busak_d && !dm10 ) ? ~(4'b1 << cnt[9:8]) : 4'hf;
        rohvs  <= ~(  r1c & mr_n );
        rohvck <= ~( ~r1c & bi   );
    end
end

endmodule
