/* SPDX-License-Identifier: GPL-3.0-or-later */
// Word-bus variant of the microcoded TMS34010. Addresses remain bit addresses.
module jttms10_word(
    input             rst,
    input             clk,
    input             cen,
    output            word_req,
    output            word_we,
    output     [31:0] word_addr,
    output     [15:0] word_wdata,
    output            word_iaq,
    output            word_lock,
    input      [15:0] word_rdata,
    input             word_ack,
    output     [31:0] pc,
    output     [31:0] st,
    output     [15:0] ir,
    output            retire,
    output            fault
);
    wire        field_req, field_we, field_iaq, field_ack;
    wire [31:0] field_addr, field_wdata, field_rdata;
    wire [5:0]  field_size;
    reg         iaq_q, request_latched;

    jttms10 u_core(
        .rst(rst), .clk(clk), .cen(cen),
        .mem_req(field_req), .mem_we(field_we), .mem_iaq(field_iaq),
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
        .word_rdata(word_rdata), .word_ack(word_ack)
    );

    // The field adapter captures the CPU request on the same edge. Its first
    // physical word can appear after alignment clocks, so IAQ is captured
    // with that request and held through every word of the transaction.
    always @(posedge clk) begin
        if (rst) begin
            iaq_q <= 1'b0;
            request_latched <= 1'b0;
        end else if (!field_req) begin
            request_latched <= 1'b0;
        end else if (!request_latched) begin
            iaq_q <= field_iaq;
            request_latched <= 1'b1;
        end
    end
    assign word_iaq = iaq_q;
endmodule
