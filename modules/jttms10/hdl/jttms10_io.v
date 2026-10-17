/* SPDX-License-Identifier: GPL-3.0-or-later */
// Standalone, CPU-visible TMS34010 I/O page. Addresses are BIT addresses.
// Based on the TI User's Guide section 6 and the GPL tms34010_io_regs leaf.
// Host pin transactions/indirect host memory cycles are intentionally absent.
module jttms10_io #(
    parameter integer CLKS_PER_STATE=8
)(
    input clk, rst, vclk_cen,
    input hcs_n, hsync_n, vsync_n,
    input lint1_n, lint2_n,
    input word_req, word_we, word_ack,
    input [31:0] word_addr,
    input [15:0] word_wdata,
    output is_io,
    output reg [15:0] io_rdata,
    input nmi_clear, wvp_set,
    output [15:0] psize, convsp, convdp, control, pmask,
    output pixel_srt,
    output [15:0] intenb, intpend, hstctlh,
    output irq_pending,
    output reg [31:0] irq_vector,
    output nmi_pending, nmi_nmim, halt, hint_n,
    output [15:0] hcount, vcount, dpyadr, refcnt,
    output hs, vs, hblank, vblank, blank,
    output screen_req,
    input screen_ack,
    output [13:0] screen_srfaddr,
    output [15:0] screen_dpytap,
    output screen_org,
    output refresh_req,
    output [7:0] refresh_row,
    output refresh_cbr
);
    wire [4:0] idx=word_addr[8:4];
    // The field sequencer supplies aligned physical words on this boundary.
    wire unused_addr = &{1'b0,word_addr[3:0]};
    assign is_io=word_addr[31:9]==23'h600000;
    wire commit=word_req && word_we && word_ack && is_io;
    reg [15:0] regs [0:31];
    reg [1:0] lint1_sync, lint2_sync;
    wire lint1_level, lint2_level;
    generate if (CLKS_PER_STATE>1) begin: g_lint_state
        localparam integer PW=$clog2(CLKS_PER_STATE);
        localparam integer SAMPLE=(CLKS_PER_STATE/2+2)%CLKS_PER_STATE;
        localparam integer TRANSFER=(CLKS_PER_STATE/2+CLKS_PER_STATE-1)%CLKS_PER_STATE;
        reg [PW-1:0] phase;
        reg [1:0] l1, l2;
        always @(posedge clk) begin
            if (rst) begin phase<=0; l1<=2'b11; l2<=2'b11; end
            else begin
                if (phase==PW'(CLKS_PER_STATE-1)) phase<=0;
                else phase<=phase+1'b1;
                if (phase==PW'(SAMPLE)) begin
                    l1[0]<=lint1_sync[1]; l2[0]<=lint2_sync[1];
                end
                if (phase==PW'(TRANSFER)) begin
                    l1[1]<=l1[0]; l2[1]<=l2[0];
                end
            end
        end
        assign lint1_level=l1[1];
        assign lint2_level=l2[1];
    end else begin: g_lint_clock
        assign lint1_level=lint1_sync[1];
        assign lint2_level=lint2_sync[1];
    end endgenerate
    reg dip, wvp;
    wire dip_set;
    wire ref_load=commit && idx==5'h1f;
    wire h_load=commit && idx==5'h1c;
    wire v_load=commit && idx==5'h1d;
    wire d_load=commit && idx==5'h1e;
    assign psize=regs[5'h15];
    assign convsp=regs[5'h13];
    assign convdp=regs[5'h14];
    assign control=regs[5'h0b];
    assign pmask=regs[5'h16];
    assign pixel_srt=regs[5'h08][11];
    assign intenb=regs[5'h11];
    assign hstctlh=regs[5'h10];
    assign intpend={4'b0,wvp,dip,regs[5'h0f][3],6'b0,
                    !lint2_level,!lint1_level,1'b0};
    assign nmi_pending=regs[5'h10][8];
    assign nmi_nmim=regs[5'h10][9];
    assign halt=regs[5'h10][15];
    assign hint_n=!regs[5'h0f][7];
    assign refresh_cbr=regs[5'h0b][2];
    wire [15:0] active=regs[5'h11] & intpend;
    assign irq_pending=|(active & 16'h0e06);
    always @* begin
        if (active[9]) irq_vector=32'hffff_fec0;
        else if (active[10]) irq_vector=32'hffff_fea0;
        else if (active[11]) irq_vector=32'hffff_fe80;
        else if (active[1]) irq_vector=32'hffff_ffc0;
        else if (active[2]) irq_vector=32'hffff_ffa0;
        else irq_vector=32'h0000_0000;
    end
    always @* begin
        io_rdata=0;
        if (is_io) begin
            case (idx)
                5'h12: io_rdata=intpend;
                5'h1c: io_rdata=hcount;
                5'h1d: io_rdata=vcount;
                5'h1e: io_rdata=dpyadr;
                5'h1f: io_rdata=refcnt;
                5'h17,5'h18,5'h19,5'h1a: io_rdata=0;
                default: io_rdata=regs[idx];
            endcase
        end
    end
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i=0;i<32;i=i+1) regs[i]<=0;
            regs[5'h10][15]<=hcs_n;
            lint1_sync<=2'b11;
            lint2_sync<=2'b11;
            dip<=0; wvp<=0;
        end else begin
            lint1_sync<={lint1_sync[0],lint1_n};
            lint2_sync<={lint2_sync[0],lint2_n};
            if (commit) begin
                case (idx)
                    5'h08: regs[5'h08]<=word_wdata & 16'hfffd;
                    5'h0b: regs[5'h0b]<=word_wdata & 16'hfffc;
                    5'h0d: regs[5'h0d]<=word_wdata & 16'hfff0;
                    5'h0f: begin
                        // CPU owns MSGOUT and can clear INTIN with zero and
                        // set INTOUT with one; MSGIN is host owned.
                        regs[5'h0f][3]<=regs[5'h0f][3] & word_wdata[3];
                        regs[5'h0f][6:4]<=word_wdata[6:4];
                        regs[5'h0f][7]<=regs[5'h0f][7] | word_wdata[7];
                    end
                    5'h10: regs[5'h10]<=word_wdata & 16'hfb00;
                    5'h11: regs[5'h11]<=word_wdata & 16'h0e06;
                    5'h12: begin
                        dip<=dip & word_wdata[10];
                        wvp<=wvp & word_wdata[11];
                    end
                    5'h1b: regs[5'h1b]<=word_wdata & 16'h3fff;
                    5'h17,5'h18,5'h19,5'h1a,
                    5'h1c,5'h1d,5'h1e,5'h1f: ;
                    default: regs[idx]<=word_wdata;
                endcase
            end
            // Hardware events win a same-cycle write-zero clear.
            if (dip_set) dip<=1;
            if (wvp_set) wvp<=1;
            if (nmi_clear && !(commit && idx==5'h10)) regs[5'h10][8]<=0;
        end
    end
    jttms10_refresh #(.CLKS_PER_STATE(CLKS_PER_STATE)) u_refresh(
        .clk(clk),.rst(rst),.rr(regs[5'h0b][4:3]),
        .load(ref_load),.wdata(word_wdata),.refcnt(refcnt),
        .row(refresh_row),.req(refresh_req)
    );
    jttms10_video u_video(
        .clk(clk),.rst(rst),.vclk_cen(vclk_cen),
        .hsync_n(hsync_n),.vsync_n(vsync_n),
        .hesync(regs[5'h00]),.heblnk(regs[5'h01]),
        .hsblnk(regs[5'h02]),.htotal(regs[5'h03]),
        .vesync(regs[5'h04]),.veblnk(regs[5'h05]),
        .vsblnk(regs[5'h06]),.vtotal(regs[5'h07]),
        .dpyctl(regs[5'h08]),.dpystart(regs[5'h09]),
        .dpyint(regs[5'h0a]),.dpytap(regs[5'h1b]),
        .hcount_load(h_load),.vcount_load(v_load),.dpyadr_load(d_load),
        .live_wdata(word_wdata),.hcount(hcount),.vcount(vcount),
        .dpyadr(dpyadr),.hs(hs),.vs(vs),.hblank(hblank),
        .vblank(vblank),.blank(blank),.dip_set(dip_set),
        .screen_req(screen_req),.screen_ack(screen_ack),
        .screen_srfaddr(screen_srfaddr),.screen_dpytap(screen_dpytap),
        .screen_org(screen_org)
    );
endmodule
