/* SPDX-License-Identifier: GPL-3.0-or-later */
// Single-clock adaptation of the old GPL tms34010_video and
// tms34010_display_addr leaves, following TI User's Guide sections 6 and 9.
// Counter transitions use vclk_cen; completed CPU writes and screen ack are
// consumed on ANY core clock so no one-cycle event can be lost between VCLKs.
module jttms10_video(
    input clk, rst, vclk_cen,
    input hsync_n, vsync_n,
    input [15:0] hesync, heblnk, hsblnk, htotal,
    input [15:0] vesync, veblnk, vsblnk, vtotal,
    input [15:0] dpyctl, dpystart, dpyint, dpytap,
    input hcount_load, vcount_load, dpyadr_load,
    input [15:0] live_wdata,
    output reg [15:0] hcount, vcount, dpyadr,
    output hs, vs, hblank, vblank, blank,
    output reg dip_set,
    output reg screen_req,
    input screen_ack,
    output reg [13:0] screen_srfaddr,
    output reg [15:0] screen_dpytap,
    output reg screen_org
);
    reg odd_field;
    reg hs_sync1, hs_sync2, hs_prev;
    reg vs_sync1, vs_sync2, vs_prev;
    reg sre_prev, first_after_enable;
    wire env=dpyctl[15], nil=dpyctl[14], dxv=dpyctl[13];
    wire sre=dpyctl[12], org=dpyctl[10], hsd=dpyctl[0];
    // SRT is consumed by the pixel bus client; bit 1 is reserved.
    wire unused_dpyctl = &{1'b0,dpyctl[11],dpyctl[1]};
    wire [13:0] step={6'b0,dpyctl[9:2]};
    wire [15:0] half_line={1'b0,htotal[15:1]};
    wire ext_hs=!dxv && !hsd && hs_prev && !hs_sync2;
    wire ext_vs=!dxv && vs_prev && !vs_sync2;
    wire hwrap=hcount==htotal;
    wire line_start=(!dxv && !hsd) ? (ext_hs || hwrap) : hwrap;
    wire even_to_odd=dxv && !nil && !odd_field && vcount==vtotal && hcount==half_line;
    wire odd_sync_end=dxv && !nil && odd_field && vcount==vesync && hcount==half_line;
    wire hblank_start=hcount==hsblnk;
    wire eligible=hblank_start && vcount>=veblnk && vcount<vsblnk;
    wire frame_blank_start=hblank_start && vcount==vsblnk;
    wire first_active_hblank=hblank_start && vcount==veblnk;
    wire start_request=eligible && sre && !screen_req &&
        (first_active_hblank || first_after_enable || !sre_prev || dpyadr[1:0]==0);
    // TI User's Guide section 9.10.1: ORG=0 software loads one's-complement
    // DPYSTRT. The *stored* DPYADR always decrements; only the pin address is
    // inverted for ORG=0, yielding an effective increasing screen address.
    wire [13:0] frame_addr=(!nil && odd_field) ?
        dpystart[15:2]-(step>>1) : dpystart[15:2];
    assign hs=hcount<=hesync;
    assign vs=vcount<=vesync;
    assign hblank=hcount<=heblnk || hcount>hsblnk;
    assign vblank=vcount<=veblnk || vcount>vsblnk;
    assign blank=!env || hblank || vblank;

    always @(posedge clk) begin
        if (rst) begin
            hcount<=0; vcount<=0; dpyadr<=0; odd_field<=0;
            hs_sync1<=1; hs_sync2<=1; hs_prev<=1;
            vs_sync1<=1; vs_sync2<=1; vs_prev<=1;
            screen_req<=0; screen_srfaddr<=0; screen_dpytap<=0;
            screen_org<=0; sre_prev<=0; first_after_enable<=0;
            dip_set<=0;
        end else begin
            dip_set<=0;
            // A completed CPU write has priority over a simultaneous count.
            if (hcount_load) hcount<=live_wdata;
            else if (vclk_cen) begin
                if (line_start) hcount<=0;
                else hcount<=hcount+16'd1;
            end
            if (vcount_load) vcount<=live_wdata;
            else if (vclk_cen) begin
                if (!dxv && ext_vs) begin
                    vcount<=0;
                    if (!nil) odd_field<=hcount>heblnk && hcount<=hsblnk;
                end else if (even_to_odd && !hcount_load) begin
                    vcount<=0; odd_field<=1;
                end else if (odd_sync_end && !hcount_load) vcount<=vcount+16'd1;
                else if (line_start && !hcount_load) begin
                    if (vcount==vtotal) begin vcount<=0; odd_field<=0; end
                    else vcount<=vcount+16'd1;
                end
            end
            if (vclk_cen) begin
                hs_sync1<=hsync_n; hs_sync2<=hs_sync1; hs_prev<=hs_sync2;
                vs_sync1<=vsync_n; vs_sync2<=vs_sync1; vs_prev<=vs_sync2;
                if (nil) odd_field<=0;
                if (env && hblank_start && vcount==dpyint && !odd_sync_end)
                    dip_set<=1;
                sre_prev<=sre;
                if (!sre || start_request) first_after_enable<=0;
                else if (!sre_prev) first_after_enable<=1;
                if (start_request) begin
                    screen_req<=1;
                    screen_srfaddr<=dpyadr[15:2];
                    screen_dpytap<=dpytap & 16'h3fff;
                    screen_org<=org;
                end
            end
            if (screen_ack && screen_req) screen_req<=0;
            // DPYADR writes and completed transfers are handled on every
            // core clock; only scanline events depend on VCLK.
            if (dpyadr_load) dpyadr<=live_wdata;
            else begin
                if (vclk_cen && frame_blank_start) dpyadr[15:2]<=frame_addr;
                else if (screen_ack && screen_req)
                    dpyadr[15:2]<=dpyadr[15:2]-step;
                if (vclk_cen && first_active_hblank) dpyadr[1:0]<=dpystart[1:0];
                else if (screen_ack && screen_req) dpyadr[1:0]<=dpystart[1:0];
                else if (vclk_cen && eligible && sre && !screen_req && !start_request)
                    dpyadr[1:0]<=dpyadr[1:0]-2'd1;
            end
        end
    end
endmodule
