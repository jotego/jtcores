/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * New microcoded CPU plus physical-word field, I/O and NARC cycle fabric.
 * Addresses on word/cyc buses are bit addresses.
 */
module jttms10_system #(
    parameter integer CLKS_PER_STATE=8,
    parameter integer RESET_REFRESH=1
)(
    input clk, rst, cen, vclk_cen,
    input hcs_n, hsync_n, vsync_n, lint1_n, lint2_n,
    input hold_req, emu_run,
    output hold_ack, emu_ack,
    input host_req, host_we,
    input [1:0] host_reg, host_be,
    input [15:0] host_wdata,
    output [15:0] host_rdata,
    output host_ack, host_busy, hint_n,
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
    input cyc_ack,
    output [31:0] pc, st,
    output [15:0] ir,
    output retire, fault,
    output [15:0] intenb, intpend,
    output irq_pending, nmi_pending, halt
);
    wire word_req, word_we, word_iaq, word_lock, word_pixel;
    wire [31:0] word_addr;
    wire [15:0] word_wdata, word_rdata;
    wire word_ack, word_restart, nmi_clear, wvp_set;
    wire [31:0] irq_vector;
    wire nmi_nmim;
    wire [15:0] psize, convsp, convdp, control, pmask, hstctlh;
    wire pixel_srt;
    wire unused_hstctlh = &{hstctlh[15],hstctlh[13:0]};

    jttms10_word #(.CLKS_PER_STATE(CLKS_PER_STATE)) u_cpu(
        .rst(rst),.clk(clk),.cen(cen),
        .irq_req(irq_pending),.irq_vector(irq_vector),
        .nmi_req(nmi_pending),.nmi_nostack(nmi_nmim),
        .halt_req(halt),.emu_run(emu_run),
        .psize(psize),.convsp(convsp),.convdp(convdp),
        .control(control),.pmask(pmask),.pixel_srt(pixel_srt),
        .cache_flush(hstctlh[14]),
        .nmi_clear(nmi_clear),.emu_ack(emu_ack),.wvp_set(wvp_set),
        .word_req(word_req),.word_we(word_we),.word_addr(word_addr),
        .word_wdata(word_wdata),.word_iaq(word_iaq),
        .word_lock(word_lock),.word_pixel(word_pixel),
        .word_rdata(word_rdata),.word_ack(word_ack),.word_restart(word_restart),
        .pc(pc),.st(st),.ir(ir),.retire(retire),.fault(fault)
    );

    // CVXYL consumes the pixel size and destination conversion pitch.
    /* verilator lint_off PINCONNECTEMPTY */
    jttms10_fabric #(.CLKS_PER_STATE(CLKS_PER_STATE),
                     .RESET_REFRESH(RESET_REFRESH)) u_fabric(
        .clk(clk),.rst(rst),.vclk_cen(vclk_cen),
        .hcs_n(hcs_n),.hsync_n(hsync_n),.vsync_n(vsync_n),
        .lint1_n(lint1_n),.lint2_n(lint2_n),
        .hold_req(hold_req),.hold_ack(hold_ack),
        .host_req(host_req),.host_we(host_we),.host_reg(host_reg),
        .host_be(host_be),.host_wdata(host_wdata),
        .host_rdata(host_rdata),.host_ack(host_ack),.host_busy(host_busy),
        .word_req(word_req),.word_we(word_we),.word_iaq(word_iaq),
        .word_lock(word_lock),.word_pixel(word_pixel),
        .word_addr(word_addr),.word_wdata(word_wdata),
        .word_rdata(word_rdata),.word_ack(word_ack),
        .word_restart(word_restart),
        .nmi_clear(nmi_clear),.wvp_set(wvp_set),
        .psize(psize),.convsp(convsp),.convdp(convdp),
        .control(control),.pmask(pmask),
        .pixel_srt(pixel_srt),.intenb(intenb),.intpend(intpend),.hstctlh(hstctlh),
        .irq_pending(irq_pending),.irq_vector(irq_vector),
        .nmi_pending(nmi_pending),.nmi_nmim(nmi_nmim),
        .halt(halt),.hint_n(hint_n),
        .hcount(),.vcount(),.dpyadr(),.refcnt(),
        .hs(hs),.vs(vs),.hblank(hblank),.vblank(vblank),.blank(blank),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),
        .cyc_iaq(cyc_iaq),.cyc_srfaddr(cyc_srfaddr),
        .cyc_dpytap(cyc_dpytap),.cyc_org(cyc_org),
        .cyc_dram_row(cyc_dram_row),
        .cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack)
    );
    /* verilator lint_on PINCONNECTEMPTY */
endmodule
