/* SPDX-License-Identifier: GPL-3.0-or-later */
// Word-bus variant of the microcoded TMS34010. Addresses remain bit addresses.
// word_restart is the arbiter's one-clock HOLD pulse between the read and
// write of a partial-word RMW pair; the field adapter then rereads that word.
module jttms10_word #(
    parameter integer CLKS_PER_STATE=8,
    parameter integer TIMED_PROGRAM=0
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
    output            word_pending, word_early,
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
    wire        field_req, field_we, field_iaq, field_program, field_pixel, field_ack, field_post, field_fast;
    wire [31:0] field_addr, field_wdata, field_rdata;
    wire [5:0]  field_size;
    wire cache_ack, cache_hit, field_busy;
    wire unused_cache_restart,unused_cache_we,unused_cache_pixel,unused_cache_lock;
    wire [15:0] unused_cache_wdata;
    wire cache_word_req, cache_word_ack, cache_word_iaq;
    wire [31:0] cache_word_addr;
    wire [15:0] cache_rdata;
    wire field_word_req, field_word_we, field_word_lock, data_ack;
    wire [31:0] field_word_addr, data_rdata;
    wire [15:0] field_word_wdata;
    reg iaq_q, pixel_q, srt_q, request_latched, data_owner, post_busy, post_ack, early_data_q;
    reg data_word_ack;
    reg [15:0] data_word_rdata;
    // Instruction and extension fetches are already aligned physical words.
    // They need no field extraction or RESPONSE/ALIGN clocks. Data, vectors
    // and stacks still use the field adapter, including all RMW/HOLD handling.
    wire program_read=field_program && !field_we && field_size==6'd16 &&
                      field_addr[3:0]==0;
    wire packet_copy=ir[15:10]==6'b101110 || ir[15:9]==7'b1011110 ||
                     (ir & 16'hfdff)==16'h05c0 || ir==16'h0340;
    wire fast_program=program_read && field_fast && !packet_copy;
    wire cache_bus_ready=!packet_copy || !program_read || field_iaq || field_fast;
    wire data_request=field_req && !program_read;
    wire data_accept=data_request && !field_busy && !post_ack && !post_busy;
    // Keep one logical operation pending across the cache/field helper's
    // short deassertions between physical words. Unrelated CPU requests
    // release this flag before starting another operation.
    assign word_pending=field_req || data_owner;
    // Timed loads/stores allocate data in their assigned intrinsic state.
    // Registered field/cache/bus handoffs may use that state's row phase.
    // A CEN-delayed launch qualifies only at/after its next state boundary.
    localparam integer SLOT_PW=$clog2(CLKS_PER_STATE);
    localparam [SLOT_PW-1:0] SLOT_LAST=CLKS_PER_STATE[SLOT_PW-1:0]-1'b1;
    reg [SLOT_PW-1:0] slot_phase;
    reg slot_eligible;
    reg copy_source_accepted;
    wire indirect_copy=ir[15:10]==6'b100010 || ir[15:9]==7'b1001110 ||
                       ir[15:10]==6'b100110 || ir[15:10]==6'b101010 ||
                       ir[15:10]==6'b110100 || (ir & 16'hfde0)==16'hd400 || packet_copy;
    wire indirect_load=indirect_copy || ir==16'h01c0 ||
        ir[15:10]==6'b100001 || ir[15:9]==7'b1000111 ||
        ir[15:10]==6'b100101 || ir[15:10]==6'b101001 || ir[15:10]==6'b101101 ||
        ir[15:9]==7'b1010111 || (ir & 16'hfde0)==16'h05a0 || (ir & 16'hffe0)==16'h07e0;
    reg fast_slot;
    assign word_early=(early_data_q && data_owner && (slot_eligible || slot_phase==0)) ||
                      (fast_program && !data_owner && (fast_slot || slot_phase==0));
    always @(posedge clk) begin
        if(rst) begin slot_phase<=0; slot_eligible<=0; fast_slot<=0; copy_source_accepted<=0; end
        else begin
            slot_phase<=slot_phase==SLOT_LAST ? {SLOT_PW{1'b0}} : slot_phase+1'b1;
            // Only an accepted source read can carry its slot across the
            // copy handoff. Address preparation after a pause owns no slot.
            if(field_req && program_read && field_iaq && field_ack) copy_source_accepted<=0;
            if(data_accept && indirect_copy && !field_we) copy_source_accepted<=1;
            if(slot_phase==0) fast_slot<=cen;
            else if(!cen) fast_slot<=0;
            if(!field_req && !data_owner && (!indirect_copy || !copy_source_accepted || !cen)) slot_eligible<=0;
            else if(slot_phase==0 || (!request_latched && slot_phase==1)) slot_eligible<=1;
        end
    end

    // Program lookup can hit the existing RAM while a data operation owns
    // the external bus. A miss waits for that operation, preserving ordering.
    assign word_req=data_owner ? field_word_req && !data_word_ack : fast_program ? field_req : cache_word_req && cache_bus_ready;
    assign word_we=data_owner && field_word_we;
    assign word_addr=data_owner ? field_word_addr : fast_program ? field_addr : cache_word_addr;
    assign word_wdata=data_owner ? field_word_wdata : 16'd0;
    assign word_iaq=data_owner ? iaq_q : fast_program ? field_iaq : cache_word_iaq;
    assign word_pixel=data_owner && pixel_q;
    assign word_lock=data_owner && field_word_lock;
    assign cache_word_ack=word_ack && !data_owner && !fast_program;
    // A posted operation may finish its CPU microinstruction on the edge
    // which captures the field, with the response register retaining ACK
    // if CEN is low. Copy read/write requests retain a separating low clock.
    assign field_ack=fast_program ? word_ack && !data_owner : program_read ? cache_ack :
                     (data_accept && field_post) || post_ack || (!post_busy && data_ack);
    assign field_rdata=program_read ? {16'd0,fast_program ? word_rdata : cache_rdata} : data_rdata;
    wire [15:0] field_word_rdata=pixel_q && srt_q && !field_word_we ?
                                  16'd0 : data_word_rdata;
    // Match the existing registered bypass response. CPU CEN cannot discard
    // a physical response or change its captured payload.
    always @(posedge clk) begin
        if(rst) begin data_word_ack<=0;data_word_rdata<=0;end
        else begin
            data_word_ack<=word_ack && data_owner;
            if(word_ack && data_owner) data_word_rdata<=word_rdata;
        end
    end

    jttms10 #(.CLKS_PER_STATE(CLKS_PER_STATE),.TIMED_PROGRAM(TIMED_PROGRAM)) u_core(
        .rst(rst), .clk(clk), .cen(cen),
        .irq_req(irq_req), .irq_vector(irq_vector),
        .nmi_req(nmi_req), .nmi_nostack(nmi_nostack),
        .halt_req(halt_req), .emu_run(emu_run),
        .psize(psize), .convsp(convsp), .convdp(convdp),
        .control(control), .pmask(pmask),
        .nmi_clear(nmi_clear), .emu_ack(emu_ack), .wvp_set(wvp_set),
        .mem_req(field_req), .mem_we(field_we), .mem_iaq(field_iaq),
        .mem_program(field_program),
        .mem_pixel(field_pixel), .mem_post(field_post), .mem_fast(field_fast),
        .mem_addr(field_addr), .mem_wdata(field_wdata),
        .mem_size(field_size), .mem_rdata(field_rdata), .mem_ack(field_ack),
        .mem_cached(program_read && cache_hit),
        .pc(pc), .st(st), .ir(ir), .retire(retire), .fault(fault)
    );

    jttms10_field u_field(
        .clk(clk), .rst(rst), .req(data_request && !post_busy && !post_ack), .we(field_we),
        .addr(field_addr), .wdata(field_wdata), .size(field_size),
        .ack(data_ack), .busy(field_busy), .rdata(data_rdata),
        .word_req(field_word_req), .word_we(field_word_we), .word_addr(field_word_addr),
        .word_wdata(field_word_wdata), .word_lock(field_word_lock),
        .word_rdata(field_word_rdata), .word_ack(data_word_ack),
        .word_restart(word_restart && data_owner)
    );

    jttms10_cache u_cache(
        .clk(clk), .rst(rst),
        .cache_disable(control[15]), .cache_flush(cache_flush),
        .c_req(field_req && program_read && !fast_program), .c_we(1'b0), .c_iaq(field_iaq),
        .c_program(1'b1), .c_pixel(1'b0), .c_lock(1'b0),
        .c_addr(field_addr), .c_wdata(16'd0),
        .c_rdata(cache_rdata), .c_ack(cache_ack), .c_hit(cache_hit), .c_restart(unused_cache_restart),
        .m_req(cache_word_req), .m_we(unused_cache_we), .m_iaq(cache_word_iaq), .m_pixel(unused_cache_pixel), .m_lock(unused_cache_lock),
        .m_addr(cache_word_addr), .m_wdata(unused_cache_wdata),
        .m_rdata(word_rdata), .m_ack(cache_word_ack), .m_restart(word_restart && !data_owner)
    );

    // The timed fabric samples readiness/data at Q1 and retains the data
    // through Q4. Direct dispatch needs one settled ROM-read clock before
    // ACK; raw word interfaces do not opt into this capability.
    // synthesis translate_off
    reg [15:0] fast_data_q;
    always @(posedge clk) begin
        fast_data_q<=word_rdata;
        if(!rst && fast_program && field_iaq && word_ack && !data_owner &&
           word_rdata!==fast_data_q)
            $fatal(1,"fast program data did not settle before ACK");
    end
    // synthesis translate_on

    // Data metadata belongs to the accepted field until every physical word
    // completes; the CPU may independently address the program cache.
    always @(posedge clk) begin
        if(rst) begin
            iaq_q<=0;pixel_q<=0;srt_q<=0;request_latched<=0;data_owner<=0;post_busy<=0;post_ack<=0;early_data_q<=0;
        end else begin
            if(!data_request) post_ack<=0;
            if(!field_req) request_latched<=0;
            else request_latched<=1;
            if(data_accept) begin
                iaq_q<=field_iaq;pixel_q<=field_pixel;srt_q<=pixel_srt;data_owner<=1;
                early_data_q<=(indirect_load || field_post) && !field_pixel;
                if(field_post) begin post_busy<=1;post_ack<=1;end
            end
            if(data_ack) begin data_owner<=0;post_busy<=0;end
        end
    end
endmodule
