/* SPDX-License-Identifier: GPL-3.0-or-later */
// TMS34010 I/O page and synchronous host boundary. Addresses are BIT addresses.
// Based on the TI User's Guide section 6 and the GPL tms34010_io_regs leaf.
// Physical asynchronous host pin timing belongs outside this module.
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
    input host_req, host_we,
    input [1:0] host_reg, host_be,
    input [15:0] host_wdata,
    output [15:0] host_rdata,
    output host_ack, host_busy,
    output host_mem_req, host_mem_we,
    output [31:0] host_mem_addr,
    output [15:0] host_mem_wdata,
    output host_mem_is_io,
    output reg [15:0] host_mem_io_rdata,
    input [15:0] host_mem_rdata,
    input host_mem_ack,
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
    wire cpu_commit=word_req && word_we && word_ack && is_io;
    wire [4:0] host_idx=host_mem_addr[8:4];
    assign host_mem_is_io=host_mem_addr[31:9]==23'h600000;
    wire host_commit=host_mem_req && host_mem_we && host_mem_ack &&
                     host_mem_is_io;
    wire commit=cpu_commit || host_commit;
    wire [4:0] write_idx=host_commit ? host_idx : idx;
    wire [15:0] write_data=host_commit ? host_mem_wdata : word_wdata;
    reg [15:0] regs [0:31];
    wire [31:0] hstadr;
    wire [15:0] hstdata;
    wire host_ctl_we;
    wire [1:0] host_ctl_be;
    wire [15:0] host_ctl_wdata;
    wire [15:0] host_ctl_rdata={regs[5'h10][15:8],regs[5'h0f][7:0]};
    wire [1:0] cpu_host_sel=idx==5'h0d ? 2'd0 : idx==5'h0e ? 2'd1 : 2'd2;
    wire [1:0] indirect_host_sel=host_idx==5'h0d ? 2'd0 :
                                  host_idx==5'h0e ? 2'd1 : 2'd2;
    wire cpu_host_we=cpu_commit &&
        (idx==5'h0c || idx==5'h0d || idx==5'h0e);
    wire indirect_host_we=host_commit &&
        (host_idx==5'h0c || host_idx==5'h0d || host_idx==5'h0e);
    jttms10_host u_host(
        .clk(clk),.rst(rst),.host_req(host_req),.host_we(host_we),
        .host_reg(host_reg),.host_be(host_be),.host_wdata(host_wdata),
        .host_rdata(host_rdata),.host_ack(host_ack),.host_busy(host_busy),
        .ctl_rdata(host_ctl_rdata),.hstctlh(regs[5'h10]),
        .ctl_we(host_ctl_we),.ctl_be(host_ctl_be),
        .ctl_wdata(host_ctl_wdata),
        .cpu_we(cpu_host_we),.cpu_reg(cpu_host_sel),
        .cpu_wdata(word_wdata),
        .indirect_we(indirect_host_we),.indirect_reg(indirect_host_sel),
        .indirect_wdata(host_mem_wdata),
        .hstadr(hstadr),.hstdata(hstdata),
        .local_req(host_mem_req),.local_we(host_mem_we),
        .local_addr(host_mem_addr),.local_wdata(host_mem_wdata),
        .local_rdata(host_mem_rdata),.local_ack(host_mem_ack)
    );
    reg [1:0] lint1_sync, lint2_sync;
    wire lint1_level, lint2_level;
    generate if (CLKS_PER_STATE>1) begin: g_lint_state
        localparam integer PW=$clog2(CLKS_PER_STATE);
        localparam integer LAST=CLKS_PER_STATE-1;
        localparam integer SAMPLE=(CLKS_PER_STATE/2+2)%CLKS_PER_STATE;
        localparam integer TRANSFER=(CLKS_PER_STATE/2+CLKS_PER_STATE-1)%CLKS_PER_STATE;
        reg [PW-1:0] phase;
        reg [1:0] l1, l2;
        always @(posedge clk) begin
            if (rst) begin phase<=0; l1<=2'b11; l2<=2'b11; end
            else begin
                if (phase==LAST[PW-1:0]) phase<=0;
                else phase<=phase+1'b1;
                if (phase==SAMPLE[PW-1:0]) begin
                    l1[0]<=lint1_sync[1]; l2[0]<=lint2_sync[1];
                end
                if (phase==TRANSFER[PW-1:0]) begin
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
    wire ref_load=commit && write_idx==5'h1f;
    wire h_load=commit && write_idx==5'h1c;
    wire v_load=commit && write_idx==5'h1d;
    wire d_load=commit && write_idx==5'h1e;
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
                5'h0c: io_rdata=hstdata;
                5'h0d: io_rdata=hstadr[15:0];
                5'h0e: io_rdata=hstadr[31:16];
                5'h17,5'h18,5'h19,5'h1a: io_rdata=0;
                default: io_rdata=regs[idx];
            endcase
        end
    end
    always @* begin
        host_mem_io_rdata=0;
        if (host_mem_is_io) begin
            case (host_idx)
                5'h12: host_mem_io_rdata=intpend;
                5'h1c: host_mem_io_rdata=hcount;
                5'h1d: host_mem_io_rdata=vcount;
                5'h1e: host_mem_io_rdata=dpyadr;
                5'h1f: host_mem_io_rdata=refcnt;
                5'h0c: host_mem_io_rdata=hstdata;
                5'h0d: host_mem_io_rdata=hstadr[15:0];
                5'h0e: host_mem_io_rdata=hstadr[31:16];
                5'h17,5'h18,5'h19,5'h1a: host_mem_io_rdata=0;
                default: host_mem_io_rdata=regs[host_idx];
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
                case (write_idx)
                    5'h08: regs[5'h08]<=write_data & 16'hfffd;
                    5'h0b: regs[5'h0b]<=write_data & 16'hfffc;
                    5'h0f: begin
                        if (host_commit) begin
                            regs[5'h0f][2:0]<=write_data[2:0];
                            if (write_data[3]) regs[5'h0f][3]<=1;
                            if (!write_data[7]) regs[5'h0f][7]<=0;
                        end else begin
                            // CPU owns MSGOUT, clears INTIN with zero, and
                            // sets INTOUT with one. Host owns complementary bits.
                            regs[5'h0f][3]<=regs[5'h0f][3] & write_data[3];
                            regs[5'h0f][6:4]<=write_data[6:4];
                            regs[5'h0f][7]<=regs[5'h0f][7] | write_data[7];
                        end
                    end
                    5'h10: regs[5'h10]<=write_data & 16'hfb00;
                    5'h11: regs[5'h11]<=write_data & 16'h0e06;
                    5'h12: begin
                        dip<=dip & write_data[10];
                        wvp<=wvp & write_data[11];
                    end
                    5'h1b: regs[5'h1b]<=write_data & 16'h3fff;
                    5'h0c,5'h0d,5'h0e: ; // jttms10_host owns these three
                    5'h17,5'h18,5'h19,5'h1a,
                    5'h1c,5'h1d,5'h1e,5'h1f: ;
                    default: regs[write_idx]<=write_data;
                endcase
            end
            if (host_ctl_we && host_ctl_be[0]) begin
                regs[5'h0f][2:0]<=host_ctl_wdata[2:0];
                if (host_ctl_wdata[3]) regs[5'h0f][3]<=1;
                if (!host_ctl_wdata[7]) regs[5'h0f][7]<=0;
            end
            if (host_ctl_we && host_ctl_be[1])
                regs[5'h10]<=host_ctl_wdata & 16'hfb00;
            // Producer sets win simultaneous consumer clears.
            if (cpu_commit && idx==5'h0f && word_wdata[7])
                regs[5'h0f][7]<=1;
            // Hardware events win a same-cycle write-zero clear.
            if (dip_set) dip<=1;
            if (wvp_set) wvp<=1;
            if (nmi_clear && !(commit && write_idx==5'h10) &&
                !(host_ctl_we && host_ctl_be[1])) regs[5'h10][8]<=0;
        end
    end
    jttms10_refresh #(.CLKS_PER_STATE(CLKS_PER_STATE)) u_refresh(
        .clk(clk),.rst(rst),.rr(regs[5'h0b][4:3]),
        .load(ref_load),.wdata(write_data),.refcnt(refcnt),
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
        .live_wdata(write_data),.hcount(hcount),.vcount(vcount),
        .dpyadr(dpyadr),.hs(hs),.vs(vs),.hblank(hblank),
        .vblank(vblank),.blank(blank),.dip_set(dip_set),
        .screen_req(screen_req),.screen_ack(screen_ack),
        .screen_srfaddr(screen_srfaddr),.screen_dpytap(screen_dpytap),
        .screen_org(screen_org)
    );
endmodule
