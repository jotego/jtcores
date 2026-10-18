/* SPDX-License-Identifier: GPL-3.0-or-later */
// Word-bus variant of the microcoded TMS34010. Addresses remain bit addresses.
// word_restart is the arbiter's one-clock HOLD pulse between the read and
// write of a partial-word RMW pair; the field adapter then rereads that word.
module jttms10_word #(
    parameter integer CLKS_PER_STATE=8
)(
    input             rst,
    input             clk,
    input             cen,
    input             irq_req,
    input      [31:0] irq_vector,
    input             nmi_req, nmi_nostack, halt_req, emu_run,
    input      [15:0] psize, convsp, convdp, control, pmask,
    input             pixel_srt,
    input             cache_flush,
    output            nmi_clear, emu_ack, wvp_set,
    output            word_req,
    output            word_pending,
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
    wire        field_req, field_we, field_iaq, field_program, field_pixel, field_ack;
    wire [31:0] field_addr, field_wdata, field_rdata;
    wire [5:0]  field_size;
    wire        cache_req, cache_we, cache_lock, cache_ack, cache_restart, cache_hit;
    wire [31:0] cache_addr;
    wire [15:0] cache_wdata, cache_rdata;
    wire field_word_req, field_word_we, field_word_lock, data_ack;
    wire [31:0] field_word_addr, data_rdata;
    wire [15:0] field_word_wdata;
    reg         iaq_q, program_q, pixel_q, srt_q, request_latched;
    // Instruction and extension fetches are already aligned physical words.
    // They need no field extraction or RESPONSE/ALIGN clocks. Data, vectors
    // and stacks still use the field adapter, including all RMW/HOLD handling.
    wire program_read=field_program && !field_we && field_size==6'd16 &&
                      field_addr[3:0]==0;
    // Keep one logical operation pending across the cache/field helper's
    // short deassertions between physical words. Unrelated CPU requests
    // release this flag before starting another operation.
    assign word_pending=field_req;
    assign cache_req=program_read ? field_req : field_word_req;
    assign cache_we=program_read ? 1'b0 : field_word_we;
    assign cache_lock=program_read ? 1'b0 : field_word_lock;
    assign cache_addr=program_read ? field_addr : field_word_addr;
    assign cache_wdata=program_read ? 16'd0 : field_word_wdata;
    assign field_ack=program_read ? cache_ack : data_ack;
    assign field_rdata=program_read ? {16'd0,cache_rdata} : data_rdata;
    // An SRT MTR cycle exchanges no pixel data on LAD. Return a defined
    // zero to architectural pixel loads; partial RMW still retains its
    // normal read-before-write physical cycle sequence.
    wire [15:0] field_word_rdata = pixel_q && srt_q && !cache_we ?
                                   16'd0 : cache_rdata;

    jttms10 #(.CLKS_PER_STATE(CLKS_PER_STATE)) u_core(
        .rst(rst), .clk(clk), .cen(cen),
        .irq_req(irq_req), .irq_vector(irq_vector),
        .nmi_req(nmi_req), .nmi_nostack(nmi_nostack),
        .halt_req(halt_req), .emu_run(emu_run),
        .psize(psize), .convsp(convsp), .convdp(convdp),
        .control(control), .pmask(pmask),
        .nmi_clear(nmi_clear), .emu_ack(emu_ack), .wvp_set(wvp_set),
        .mem_req(field_req), .mem_we(field_we), .mem_iaq(field_iaq),
        .mem_program(field_program),
        .mem_pixel(field_pixel),
        .mem_addr(field_addr), .mem_wdata(field_wdata),
        .mem_size(field_size), .mem_rdata(field_rdata), .mem_ack(field_ack),
        .mem_cached(program_read && cache_hit),
        .pc(pc), .st(st), .ir(ir), .retire(retire), .fault(fault)
    );

    jttms10_field u_field(
        .clk(clk), .rst(rst), .req(field_req && !program_read), .we(field_we),
        .addr(field_addr), .wdata(field_wdata), .size(field_size),
        .ack(data_ack), .rdata(data_rdata),
        .word_req(field_word_req), .word_we(field_word_we), .word_addr(field_word_addr),
        .word_wdata(field_word_wdata), .word_lock(field_word_lock),
        .word_rdata(field_word_rdata), .word_ack(cache_ack && !program_read),
        .word_restart(cache_restart)
    );

    jttms10_cache u_cache(
        .clk(clk), .rst(rst),
        .cache_disable(control[15]), .cache_flush(cache_flush),
        .c_req(cache_req), .c_we(cache_we), .c_iaq(program_read ? field_iaq : iaq_q),
        .c_program(program_read || program_q), .c_pixel(program_read ? 1'b0 : pixel_q),
        .c_lock(cache_lock),
        .c_addr(cache_addr), .c_wdata(cache_wdata),
        .c_rdata(cache_rdata), .c_ack(cache_ack), .c_hit(cache_hit),
        .c_restart(cache_restart),
        .m_req(word_req), .m_we(word_we), .m_iaq(word_iaq),
        .m_pixel(word_pixel), .m_lock(word_lock),
        .m_addr(word_addr), .m_wdata(word_wdata),
        .m_rdata(word_rdata), .m_ack(word_ack),
        .m_restart(word_restart)
    );

    // The field adapter captures the CPU request on the same edge. Its first
    // physical word can appear after alignment clocks, so IAQ is captured
    // with that request and held through every word of the transaction.
    always @(posedge clk) begin
        if (rst) begin
            iaq_q <= 1'b0;
            program_q <= 1'b0;
            pixel_q <= 1'b0;
            srt_q <= 1'b0;
            request_latched <= 1'b0;
        end else if (!field_req) begin
            request_latched <= 1'b0;
            pixel_q <= 1'b0;
            srt_q <= 1'b0;
        end else if (!request_latched) begin
            iaq_q <= field_iaq;
            program_q <= field_program;
            pixel_q <= field_pixel;
            srt_q <= pixel_srt;
            request_latched <= 1'b1;
        end
    end
endmodule
