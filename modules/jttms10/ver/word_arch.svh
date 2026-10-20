// SPDX-License-Identifier: GPL-3.0-or-later
// Physical timed integration for the unchanged architectural vector checks.
// Included inside test.sv; the same held-request memory serves both benches.
    wire word_req, word_pending, word_early, word_we, word_iaq, word_lock;
    wire word_pixel, word_ack, word_restart, word_wait;
    wire [31:0] word_addr;
    wire [15:0] word_wdata, word_rdata, cycle_wdata;
    wire [3:0] cycle_kind;
    reg hold_req = 0, hold_sent = 0, hold_seen = 0;
    wire hold_ack;
    integer hold_enabled = 0, hold_left = 0;
    initial if ($value$plusargs("HOLD_AFTER_WRITE=%d",hold_enabled)) begin end
    assign mem_we = cycle_kind==4'd1;
    assign mem_wdata = {16'd0,cycle_wdata};
    assign mem_size = 6'd16;
    assign mem_pixel = word_pixel;

    jttms10_word #(.TIMED_PROGRAM(1)) u_cpu (
        .rst(rst),.clk(clk),.cen(cen),
        .psize(PIXEL_SIZE),.convdp(CONVDP),.convsp(CONVSP),
        .control(CONTROL),.pmask(PMASK),.wvp_set(wvp_set),
        .irq_req(1'b0),.irq_vector(32'd0),
        .nmi_req(1'b0),.nmi_nostack(1'b0),.halt_req(1'b0),
        .emu_run(1'b1),.nmi_clear(),.emu_ack(),
        .word_req(word_req),.word_pending(word_pending),.word_early(word_early),
        .word_we(word_we),.word_addr(word_addr),.word_wdata(word_wdata),
        .word_iaq(word_iaq),.word_lock(word_lock),.word_pixel(word_pixel),
        .word_rdata(word_rdata),.word_ack(word_ack),
        .word_restart(word_restart),.word_wait(word_wait),
        .pixel_srt(1'b0),.cache_flush(1'b0),
        .pc(pc),.st(st),.ir(ir),.retire(retire),.fault(fault),.halted()
    );

    jttms10_bus #(.TIMING(1)) u_bus (
        .clk(clk),.rst(rst),.hold_req(hold_req),.hold_ack(hold_ack),
        .screen_req(1'b0),.screen_srfaddr(14'd0),.screen_dpytap(16'd0),.screen_org(1'b0),.screen_ack(),
        .refresh_req(1'b0),.refresh_row(8'd0),.refresh_cbr(1'b0),
        .host_mem_req(1'b0),.host_mem_we(1'b0),.host_mem_addr(32'd0),.host_mem_wdata(16'd0),
        .host_mem_is_io(1'b0),.host_mem_io_rdata(16'd0),.host_mem_rdata(),.host_mem_ack(),
        .word_req(word_req),.word_pending(word_pending),.word_early(word_early),.word_we(word_we),
        .word_iaq(word_iaq),.word_lock(word_lock),.word_pixel(word_pixel),
        .word_addr(word_addr),.word_wdata(word_wdata),.word_rdata(word_rdata),
        .word_ack(word_ack),.word_restart(word_restart),.word_wait(word_wait),
        .is_io(1'b0),.pixel_srt(1'b0),.io_rdata(16'd0),
        .cyc_req(mem_req),.cyc_kind(cycle_kind),.cyc_addr(mem_addr),.cyc_wdata(cycle_wdata),
        .cyc_io_rdata(),.cyc_iaq(mem_iaq),.cyc_srfaddr(),.cyc_dpytap(),.cyc_org(),.cyc_dram_row(),
        .cyc_rdata(mem_rdata[15:0]),.cyc_ack(mem_ack)
    );

    // Bus arbitration owns HOLD. Inject once at a real pixel response and
    // require it to be granted; merely raising a signal is not coverage.
    always @(negedge clk) if (!rst && hold_enabled!=0) begin
        if (!hold_sent && mem_req && mem_ack && mem_we && word_pixel) begin
            hold_req = 1;
            hold_sent = 1;
        end
        if (hold_ack) begin
            if (mem_req) $fatal(1,"memory cycle issued during HOLD grant");
            hold_seen = 1;
            hold_left = hold_left+1;
            if (hold_left==20) hold_req = 0;
        end
    end
