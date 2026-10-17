/* SPDX-License-Identifier: GPL-3.0-or-later */
// Word-bus variant of the microcoded TMS34010. Addresses remain bit addresses.
// word_restart is the arbiter's one-clock HOLD pulse between the read and
// write of a partial-word RMW pair; the field adapter then rereads that word.
module jttms10_word(
    input             rst,
    input             clk,
    input             cen,
    input             irq_req,
    input      [31:0] irq_vector,
    input             nmi_req, nmi_nostack, halt_req, emu_run,
    input      [15:0] psize, convsp, convdp, control, pmask,
    input             pixel_srt,
    output            nmi_clear, emu_ack, wvp_set,
    output            word_req,
    output            word_we,
    output     [31:0] word_addr,
    output     [15:0] word_wdata,
    output            word_iaq,
    output            word_pixel,
    output            word_lock,
    input      [15:0] word_rdata,
    input             word_ack,
    input             word_restart,
    output     [31:0] pc,
    output     [31:0] st,
    output     [15:0] ir,
    output            retire,
    output            fault
);
    wire        field_req, field_we, field_iaq, field_pixel, field_ack;
    wire [31:0] field_addr, field_wdata, field_rdata;
    wire [5:0]  field_size;
    reg         iaq_q, pixel_q, srt_q, request_latched;
    // An SRT MTR cycle exchanges no pixel data on LAD. Return a defined
    // zero to architectural pixel loads; partial RMW still retains its
    // normal read-before-write physical cycle sequence.
    wire [15:0] field_word_rdata = pixel_q && srt_q && !word_we ?
                                   16'd0 : word_rdata;

    jttms10 u_core(
        .rst(rst), .clk(clk), .cen(cen),
        .irq_req(irq_req), .irq_vector(irq_vector),
        .nmi_req(nmi_req), .nmi_nostack(nmi_nostack),
        .halt_req(halt_req), .emu_run(emu_run),
        .psize(psize), .convsp(convsp), .convdp(convdp),
        .control(control), .pmask(pmask),
        .nmi_clear(nmi_clear), .emu_ack(emu_ack), .wvp_set(wvp_set),
        .mem_req(field_req), .mem_we(field_we), .mem_iaq(field_iaq),
        .mem_pixel(field_pixel),
        .mem_addr(field_addr), .mem_wdata(field_wdata),
        .mem_size(field_size), .mem_rdata(field_rdata), .mem_ack(field_ack),
        .pc(pc), .st(st), .ir(ir), .retire(retire), .fault(fault)
    );

    jttms10_field u_field(
        .clk(clk), .rst(rst), .req(field_req), .we(field_we),
        .addr(field_addr), .wdata(field_wdata), .size(field_size),
        .ack(field_ack), .rdata(field_rdata),
        .word_req(word_req), .word_we(word_we), .word_addr(word_addr),
        .word_wdata(word_wdata), .word_lock(word_lock),
        .word_rdata(field_word_rdata), .word_ack(word_ack),
        .word_restart(word_restart)
    );

    // The field adapter captures the CPU request on the same edge. Its first
    // physical word can appear after alignment clocks, so IAQ is captured
    // with that request and held through every word of the transaction.
    always @(posedge clk) begin
        if (rst) begin
            iaq_q <= 1'b0;
            pixel_q <= 1'b0;
            srt_q <= 1'b0;
            request_latched <= 1'b0;
        end else if (!field_req) begin
            request_latched <= 1'b0;
            pixel_q <= 1'b0;
            srt_q <= 1'b0;
        end else if (!request_latched) begin
            iaq_q <= field_iaq;
            pixel_q <= field_pixel;
            srt_q <= pixel_srt;
            request_latched <= 1'b1;
        end
    end
    assign word_iaq = iaq_q;
    assign word_pixel = pixel_q;
endmodule
