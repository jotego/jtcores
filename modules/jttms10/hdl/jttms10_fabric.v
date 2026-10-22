/* SPDX-License-Identifier: GPL-3.0-or-later */
// Physical-word fabric and peripherals, independent of the microcoded CPU.
module jttms10_fabric #(
    parameter integer CLKS_PER_STATE=8,
    parameter integer RESET_REFRESH=0
)(
    input clk, rst, vclk_cen,
`ifdef JTTMS10_REGRESSION
    output            obs_bus_start, obs_bus_complete,
    output     [15:0] obs_bus_rdata,
`endif
    input hcs_n, hsync_n, vsync_n, lint1_n, lint2_n,
    input hold_req,
    output hold_ack,
    input host_req, host_we,
    input [1:0] host_reg, host_be,
    input [15:0] host_wdata,
    output [15:0] host_rdata,
    output host_ack, host_busy,
    input word_req, word_we, word_iaq, word_lock, word_pixel,
    input [31:0] word_addr,
    input [15:0] word_wdata,
    output [15:0] word_rdata,
    output word_ack, word_restart,
    input nmi_clear, wvp_set,
    output [15:0] psize, convsp, convdp, control, pmask,
    output pixel_srt,
    output [15:0] intenb, intpend, hstctlh,
    output irq_pending,
    output [31:0] irq_vector,
    output nmi_pending, nmi_nmim, halt, hint_n,
    output [15:0] hcount, vcount, dpyadr, refcnt,
    output hs, vs, hblank, vblank, blank,
    output cyc_req,
    output [3:0] cyc_kind,
    output [31:0] cyc_addr,
    output [15:0] cyc_wdata, cyc_io_rdata,
    output cyc_iaq,
    output [13:0] cyc_srfaddr,
    output [15:0] cyc_dpytap,
    output cyc_org,
    output [7:0] cyc_dram_row,
    input [15:0] cyc_rdata,
    input cyc_ack
);
    wire is_io, screen_req, screen_ack, screen_org;
    wire [15:0] io_rdata, screen_dpytap;
    wire [13:0] screen_srfaddr;
    wire refresh_req, refresh_cbr;
    wire [7:0] refresh_row;
    wire host_mem_req, host_mem_we, host_mem_is_io, host_mem_ack;
    wire [31:0] host_mem_addr;
    wire [15:0] host_mem_wdata, host_mem_io_rdata, host_mem_rdata;
    jttms10_io #(.CLKS_PER_STATE(CLKS_PER_STATE)) u_io(
        .clk(clk),.rst(rst),.vclk_cen(vclk_cen),
        .hcs_n(hcs_n),.hsync_n(hsync_n),.vsync_n(vsync_n),
        .lint1_n(lint1_n),.lint2_n(lint2_n),
        .word_req(word_req),.word_we(word_we),.word_ack(word_ack),
        .word_addr(word_addr),.word_wdata(word_wdata),
        .is_io(is_io),.io_rdata(io_rdata),
        .host_req(host_req),.host_we(host_we),.host_reg(host_reg),
        .host_be(host_be),.host_wdata(host_wdata),
        .host_rdata(host_rdata),.host_ack(host_ack),
        .host_busy(host_busy),
        .host_mem_req(host_mem_req),.host_mem_we(host_mem_we),
        .host_mem_addr(host_mem_addr),.host_mem_wdata(host_mem_wdata),
        .host_mem_is_io(host_mem_is_io),
        .host_mem_io_rdata(host_mem_io_rdata),
        .host_mem_rdata(host_mem_rdata),.host_mem_ack(host_mem_ack),
        .nmi_clear(nmi_clear),.wvp_set(wvp_set),
        .psize(psize),.convsp(convsp),.convdp(convdp),
        .control(control),.pmask(pmask),.pixel_srt(pixel_srt),
        .intenb(intenb),.intpend(intpend),.hstctlh(hstctlh),
        .irq_pending(irq_pending),.irq_vector(irq_vector),
        .nmi_pending(nmi_pending),.nmi_nmim(nmi_nmim),
        .halt(halt),.hint_n(hint_n),
        .hcount(hcount),.vcount(vcount),.dpyadr(dpyadr),.refcnt(refcnt),
        .hs(hs),.vs(vs),.hblank(hblank),.vblank(vblank),.blank(blank),
        .screen_req(screen_req),.screen_ack(screen_ack),
        .screen_srfaddr(screen_srfaddr),.screen_dpytap(screen_dpytap),
        .screen_org(screen_org),
        .refresh_req(refresh_req),.refresh_row(refresh_row),
        .refresh_cbr(refresh_cbr)
    );
    jttms10_bus #(.RESET_REFRESH(RESET_REFRESH)) u_bus(
`ifdef JTTMS10_REGRESSION
        .obs_bus_start ( obs_bus_start ),
        .obs_bus_complete ( obs_bus_complete ),
        .obs_bus_rdata ( obs_bus_rdata ),
`endif
        .clk(clk),.rst(rst),.hold_req(hold_req),.hold_ack(hold_ack),
        .screen_req(screen_req),.screen_ack(screen_ack),
        .screen_srfaddr(screen_srfaddr),.screen_dpytap(screen_dpytap),
        .screen_org(screen_org),
        .refresh_req(refresh_req),.refresh_row(refresh_row),
        .refresh_cbr(refresh_cbr),
        .host_mem_req(host_mem_req),.host_mem_we(host_mem_we),
        .host_mem_addr(host_mem_addr),.host_mem_wdata(host_mem_wdata),
        .host_mem_is_io(host_mem_is_io),
        .host_mem_io_rdata(host_mem_io_rdata),
        .host_mem_rdata(host_mem_rdata),.host_mem_ack(host_mem_ack),
        .word_req(word_req),.word_we(word_we),.word_iaq(word_iaq),
        .word_lock(word_lock),.word_pixel(word_pixel),
        .word_addr(word_addr),.word_wdata(word_wdata),
        .is_io(is_io),.pixel_srt(pixel_srt),.io_rdata(io_rdata),
        .word_rdata(word_rdata),.word_ack(word_ack),
        .word_restart(word_restart),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),
        .cyc_iaq(cyc_iaq),.cyc_srfaddr(cyc_srfaddr),
        .cyc_dpytap(cyc_dpytap),.cyc_org(cyc_org),
        .cyc_dram_row(cyc_dram_row),
        .cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack)
    );
endmodule
