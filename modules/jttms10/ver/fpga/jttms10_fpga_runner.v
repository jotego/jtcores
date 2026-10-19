// SPDX-License-Identifier: GPL-3.0-or-later
// Autonomous bounded batch runner for the TMS34010 timing fixtures.
// The host stages descriptors/program words before START. No HPS signal is
// consulted while a case is in RUN.
module jttms10_fpga_runner(
    input  wire        clk,
    input  wire        reset_n,
    input  wire [3:0]  avs_address,
    input  wire        avs_read,
    output wire [31:0] avs_readdata,
    input  wire        avs_write,
    input  wire [31:0] avs_writedata,
    output wire        avs_waitrequest
);
    localparam integer MAX_CASES=32;
    localparam integer MAX_PROGRAM_WORDS=4096;
    localparam integer RESULT_WORDS=72;
    localparam integer EVENTS_PER_CASE=128;
    localparam [3:0] S_IDLE=0,S_CLEAR=1,S_COPY_READ=2,S_RESET=3,S_RUN=4,S_DONE=5,
                     S_SNAPSHOT_READ=6,S_DESC=7,S_VALIDATE=8,S_DESC_LATCH=9,
                     S_COPY_WRITE=10,S_SNAPSHOT_WRITE=11;

    reg [31:0] desc [0:MAX_CASES*8-1];
    reg [15:0] program_store [0:MAX_PROGRAM_WORDS-1];
    reg [15:0] memory [0:4095];
    reg [31:0] results [0:MAX_CASES*RESULT_WORDS-1];
    reg [31:0] timeout_limit=32'd4000000;
    reg [31:0] case_count=0, desc_ptr=0, program_ptr=0, result_index=0;
    reg [31:0] status=0;
    reg [31:0] case_index=0, word_index=0, case_clock=0, start_clock=0;
    reg [31:0] test_pc=0, next_pc=0, case_id=0, program_base=0, program_length=0;
    reg [31:0] measure_pass=1, measure_seen=0;
    reg [2:0] desc_index=0;
    reg measuring=0;
    reg found_test=0;
    reg [3:0] state=S_IDLE;
    reg cpu_reset=1;

    reg [31:0] rf_shadow [0:63];
    reg [63:0] rf_valid=0;
    reg [15:0] mem_read_q=0;
    reg [31:0] target_addr_q=0;
    reg [15:0] target_wdata_q=0;
    reg target_iaq_q=0;
    reg [15:0] target_io_data_q=0;
    reg [3:0] target_kind_q=0;
    reg [2:0] target_age=0;
    reg [1:0] target_state=0;
    localparam [1:0] T_IDLE=0,T_WAIT=1,T_ACK=2;
    reg [31:0] event_count=0;
    reg [127:0] events [0:MAX_CASES*EVENTS_PER_CASE-1];
    reg [7:0] case_event_count [0:MAX_CASES-1];
    reg event_overflow=0;
    reg [31:0] event_index=0;
    reg [31:0] cycle_counter=0;
    reg [6:0] snapshot_index=0;
    reg [31:0] desc_q=0;
    reg [15:0] program_q=0;
    reg [31:0] snapshot_q=0;
    reg [31:0] csr_read_q=0;
    reg [31:0] results_read_q;
    reg [127:0] events_read_q;
    reg [3:0] read_address_q=0;
    reg results_read_error_q=0;
    reg events_read_error_q=0;
    reg [31:0] rf_read_q;
    reg rf_valid_read_q;
    reg [31:0] result_meta [0:7];
    wire [5:0] rf_snapshot_index=snapshot_index[5:0]-6'd8;
    reg case_error=0, batch_error=0;

    wire obs_decode, obs_rf_we, obs_bus_start, obs_bus_complete;
    wire [31:0] obs_decode_pc, obs_rf_data, pc, st;
    wire [15:0] obs_decode_ir, obs_bus_rdata, ir;
    wire [5:0] obs_rf_addr;
    wire [169:0] obs_work;
    wire obs_field_pending_fault;
    wire cyc_req, cyc_ack, cyc_iaq, retire, fault;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr;
    wire [15:0] cyc_wdata, cyc_io_rdata;
    wire trace_event_now = !cpu_reset && state==S_RUN && measuring &&
                           (obs_bus_start || obs_bus_complete ||
                            (target_state==T_IDLE && cyc_req) || target_state==T_ACK);
    wire trace_overflow_now = trace_event_now &&
                              (case_event_count[case_index]>=8'd128 || event_count>=32'd4096);
    reg [15:0] cyc_rdata;
    wire [15:0] cpu_memory_data = mem_read_q;
    wire cpu_cen = !cpu_reset && state==S_RUN;
    assign avs_waitrequest=1'b0;
    assign cyc_ack=target_state==T_ACK;
    // Keep RAM output registers independent of the CSR/event selection muxes.
    // This preserves synchronous block-RAM inference while retaining the
    // one-cycle Avalon read latency.
    assign avs_readdata = read_address_q==4'd9 ?
                              (results_read_error_q ? 32'h80000003 : results_read_q) :
                          read_address_q==4'd11 ?
                              (events_read_error_q ? 32'h80000003 : events_read_q[31:0]) :
                          read_address_q==4'd12 ?
                              (events_read_error_q ? 32'h80000003 : events_read_q[63:32]) :
                          read_address_q==4'd13 ?
                              (events_read_error_q ? 32'h80000003 : events_read_q[95:64]) :
                          read_address_q==4'd14 ?
                              (events_read_error_q ? 32'h80000003 : events_read_q[127:96]) : csr_read_q;

    jttms10_system #(.CLKS_PER_STATE(8),.RESET_REFRESH(0)) u_cpu(
        .obs_decode(obs_decode),.obs_rf_we(obs_rf_we),
        .obs_decode_pc(obs_decode_pc),.obs_rf_data(obs_rf_data),
        .obs_decode_ir(obs_decode_ir),.obs_rf_addr(obs_rf_addr),.obs_work(obs_work),
        .obs_bus_start(obs_bus_start),.obs_bus_complete(obs_bus_complete),
        .obs_bus_rdata(obs_bus_rdata),.obs_field_pending_fault(obs_field_pending_fault),
        .clk(clk),.rst(cpu_reset),.cen(cpu_cen),.vclk_cen(1'b0),
        .hcs_n(1'b0),.hsync_n(1'b1),.vsync_n(1'b1),.lint1_n(1'b1),.lint2_n(1'b1),
        .hold_req(1'b0),.hold_ack(),.emu_run(1'b1),.emu_ack(),
        .host_req(1'b0),.host_we(1'b0),.host_reg(2'b0),.host_be(2'b0),.host_wdata(16'b0),
        .host_rdata(),.host_ack(),.host_busy(),.hint_n(),.hs(),.vs(),.hblank(),.vblank(),.blank(),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),.cyc_wdata(cyc_wdata),
        .cyc_io_rdata(cyc_io_rdata),.cyc_iaq(cyc_iaq),.cyc_srfaddr(),.cyc_dpytap(),.cyc_org(),
        .cyc_dram_row(),.cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack),
        .pc(pc),.st(st),.ir(ir),.retire(retire),.fault(fault),
        .intenb(),.intpend(),.irq_pending(),.nmi_pending(),.halt()
    );

    // The target captures the complete request at allocation. Its synchronous
    // memory read overlaps the fixed four-clock readiness interval.
    always @* begin
        if(target_kind_q==5) cyc_rdata=cyc_io_rdata;
        else if(target_addr_q==32'hffffffe0) cyc_rdata=16'h1000;
        else if(target_addr_q==32'hfffffff0) cyc_rdata=16'h0000;
        else if(target_addr_q<32'h00010000) cyc_rdata=mem_read_q;
        else cyc_rdata=16'h0000;
    end

    // Avalon-MM registers are word addressed. Descriptor/program writes are
    // accepted only while idle, preventing host timing from affecting RUN.
    integer q;
    reg [31:0] base;
    reg [31:0] descriptor;
    always @(posedge clk) begin
        if(!reset_n) begin
            state<=S_IDLE; cpu_reset<=1; status<=0; case_index<=0;
            case_clock<=0; cycle_counter<=0; target_state<=T_IDLE;
            target_age<=0; event_count<=0; event_overflow<=0;
            found_test<=0; measuring<=0; measure_seen<=0; desc_index<=0; rf_valid<=0; word_index<=0; case_count<=0;
            desc_ptr<=0; program_ptr<=0; result_index<=0; event_index<=0;
            timeout_limit<=32'd4000000; snapshot_index<=0;
            case_error<=0; batch_error<=0;
            csr_read_q<=0; read_address_q<=0;
        end else begin
            // Keep all test-memory writes on one synchronous port so Quartus
            // can infer block RAM instead of expanding the 64K-bit array into
            // logic cells. These phases are mutually exclusive by design.
            if(state==S_CLEAR) memory[word_index[11:0]]<=16'b0;
            else if(state==S_COPY_WRITE)
                memory[12'd256+word_index[11:0]]<=program_q;
            else if(target_state==T_ACK && target_kind_q==1 &&
                    target_addr_q<32'h00010000)
                memory[target_addr_q[15:4]]<=target_wdata_q[15:0];

            // One-cycle Avalon read latency keeps result/event memories on
            // synchronous read ports instead of wide asynchronous muxes.
            if(avs_read) begin
                read_address_q<=avs_address;
                case(avs_address)
                    0: csr_read_q<=32'h4a545231;
                    1: csr_read_q<=status;
                    2: csr_read_q<=case_count;
                    3: csr_read_q<=desc_ptr;
                    4: csr_read_q<=32'b0;
                    5: csr_read_q<=program_ptr;
                    6: csr_read_q<=32'b0;
                    7: csr_read_q<=event_count | (event_overflow ? 32'h80000000:0);
                    8: csr_read_q<=result_index;
                    9: begin
                        csr_read_q<=0;
                        results_read_error_q<=result_index>=MAX_CASES*RESULT_WORDS;
                        if(result_index<MAX_CASES*RESULT_WORDS)
                            results_read_q<=results[result_index[11:0]];
                    end
                    10: csr_read_q<=event_index;
                    11,12,13,14: begin
                        csr_read_q<=0;
                        events_read_error_q<=event_index>=MAX_CASES*EVENTS_PER_CASE;
                        if(event_index<MAX_CASES*EVENTS_PER_CASE)
                            events_read_q<=events[event_index[11:0]];
                    end
                    15: csr_read_q<=timeout_limit;
                    default: csr_read_q<=0;
                endcase
            end
            if(state==S_SNAPSHOT_READ && snapshot_index>=8) begin
                rf_read_q<=rf_shadow[rf_snapshot_index];
                rf_valid_read_q<=rf_valid[rf_snapshot_index];
            end
            if(avs_write && state==S_IDLE) begin
                case(avs_address)
                    1: if(avs_writedata[0]) begin
                        if(case_count==0 || case_count>MAX_CASES) status<=32'h80000001;
                        else begin status<=32'h1; case_index<=0; event_count<=0;
                                   event_overflow<=0; batch_error<=0; state<=S_CLEAR; end
                    end
                    2: case_count<=avs_writedata;
                    3: desc_ptr<=avs_writedata;
                    4: begin
                        if(desc_ptr<MAX_CASES*8) desc[desc_ptr]<=avs_writedata;
                        desc_ptr<=desc_ptr+1'b1;
                    end
                    5: program_ptr<=avs_writedata;
                    6: begin
                        if(program_ptr<MAX_PROGRAM_WORDS) program_store[program_ptr]<=avs_writedata[15:0];
                        program_ptr<=program_ptr+1'b1;
                    end
                    15: if(avs_writedata>=1000) timeout_limit<=avs_writedata;
                    default: ;
                endcase
            end
            if(avs_write && avs_address==1 && state==S_DONE && !avs_writedata[0]) begin
                state<=S_IDLE; status<=0; case_index<=0;
            end
            if(avs_write && avs_address==8) result_index<=avs_writedata;
            if(avs_write && avs_address==10) event_index<=avs_writedata;

            if(target_state==T_IDLE && cyc_req && !cpu_reset) begin
                target_addr_q<=cyc_addr; target_kind_q<=cyc_kind;
                target_wdata_q<=cyc_wdata; target_iaq_q<=cyc_iaq;
                target_io_data_q<=cyc_io_rdata; target_age<=1; target_state<=T_WAIT;
                if(cyc_addr<32'h00010000) mem_read_q<=memory[cyc_addr[15:4]];
            end else if(target_state==T_WAIT) begin
                if(!cyc_req || cyc_addr!=target_addr_q || cyc_kind!=target_kind_q ||
                   cyc_wdata!=target_wdata_q || cyc_iaq!=target_iaq_q ||
                   cyc_io_rdata!=target_io_data_q)
                    begin status[8]<=1'b1; case_error<=1; batch_error<=1; end
                if(target_age==3'd3) target_state<=T_ACK;
                else target_age<=target_age+1'b1;
            end else if(target_state==T_ACK) begin
                if(!cyc_req || cyc_addr!=target_addr_q || cyc_kind!=target_kind_q ||
                   cyc_wdata!=target_wdata_q || cyc_iaq!=target_iaq_q ||
                   cyc_io_rdata!=target_io_data_q)
                    begin status[8]<=1'b1; case_error<=1; batch_error<=1; end
                target_state<=T_IDLE;
            end

            // A row can represent simultaneous timer and physical-target
            // events without losing either when they occur on one clock.
            if(trace_event_now) begin
                if(case_event_count[case_index]<8'd128 && event_count<32'd4096) begin
                    events[event_count] <= {18'b0,case_index[4:0],
                        (target_state==T_IDLE && cyc_req), (target_state==T_ACK),
                        obs_bus_start, obs_bus_complete, cyc_kind, cyc_iaq,
                        cyc_addr, cyc_wdata,
                        (obs_bus_complete ? obs_bus_rdata : (target_state==T_ACK ? cyc_rdata : 16'b0)),cycle_counter};
                    case_event_count[case_index]<=case_event_count[case_index]+1'b1;
                    event_count<=event_count+1'b1;
                end else begin event_overflow<=1; case_error<=1; batch_error<=1; end
            end

            if(obs_rf_we && !cpu_reset &&
               !(state==S_RUN && obs_decode && obs_decode_pc==next_pc && measuring)) begin
                rf_shadow[obs_rf_addr]<=obs_rf_data;
                rf_valid[obs_rf_addr]<=1'b1;
            end
            if(state==S_RUN) begin
                cycle_counter<=cycle_counter+1'b1;
                case_clock<=case_clock+1'b1;
                if(obs_field_pending_fault || fault) begin case_error<=1; batch_error<=1; end
                if(obs_decode && obs_decode_pc==test_pc && !measuring) begin
                    if(measure_seen==measure_pass) begin
                        found_test<=1'b1; measuring<=1'b1; start_clock<=case_clock;
                    end else measure_seen<=measure_seen+1'b1;
                end else if(obs_decode && measuring && obs_decode_pc==next_pc) begin
                    result_meta[0]<=case_id;
                    result_meta[1]<=(case_error || fault || obs_field_pending_fault || trace_overflow_now) ? 32'h80000004 : 32'h2;
                    result_meta[2]<=case_clock-start_clock;
                    result_meta[3]<=test_pc;
                    result_meta[4]<=next_pc;
                    result_meta[5]<={16'b0,obs_decode_ir};
                    result_meta[6]<=st;
                    result_meta[7]<=start_clock;
                    measuring<=0; snapshot_index<=0; state<=S_SNAPSHOT_READ; cpu_reset<=1;
                end else if(case_clock>=timeout_limit) begin
                    result_meta[0]<=case_id; result_meta[1]<=32'h80000002;
                    result_meta[2]<=case_clock; result_meta[3]<=test_pc; result_meta[4]<=next_pc;
                    result_meta[5]<=0; result_meta[6]<=st; result_meta[7]<=start_clock;
                    batch_error<=1; measuring<=0; snapshot_index<=0; state<=S_SNAPSHOT_READ; cpu_reset<=1;
                end
            end
            case(state)
                S_IDLE: cpu_reset<=1;
                S_CLEAR: begin
                    cpu_reset<=1; rf_valid<=0; found_test<=0; measuring<=0; target_state<=T_IDLE;
                    if(word_index==4095) begin
                        word_index<=0; desc_index<=0; case_event_count[case_index]<=0; case_error<=0;
                        state<=S_DESC;
                    end else word_index<=word_index+1'b1;
                end
                S_DESC: begin
                    desc_q<=desc[case_index*8+{29'd0,desc_index}];
                    state<=S_DESC_LATCH;
                end
                S_DESC_LATCH: begin
                    case(desc_index)
                        0: case_id<=desc_q;
                        1: program_base<=desc_q;
                        2: program_length<=desc_q;
                        3: test_pc<=desc_q;
                        4: next_pc<=desc_q;
                        5: measure_pass<=desc_q;
                    endcase
                    if(desc_index==5) state<=S_VALIDATE;
                    else begin desc_index<=desc_index+1'b1; state<=S_DESC; end
                end
                S_VALIDATE: begin
                    if(program_length==0 || program_length>3840 || program_base>=MAX_PROGRAM_WORDS ||
                           program_length>MAX_PROGRAM_WORDS-program_base ||
                           test_pc[3:0]!=0 || next_pc[3:0]!=0 || measure_pass>255) begin
                            result_meta[0]<=case_id; result_meta[1]<=32'h80000003;
                            result_meta[2]<=0; result_meta[3]<=test_pc; result_meta[4]<=next_pc;
                            result_meta[5]<=0; result_meta[6]<=0; result_meta[7]<=0;
                            batch_error<=1; snapshot_index<=0; state<=S_SNAPSHOT_READ;
                        end else begin word_index<=0; state<=S_COPY_READ; end
                end
                S_COPY_READ: begin
                    program_q<=program_store[program_base+word_index];
                    state<=S_COPY_WRITE;
                end
                S_COPY_WRITE: begin
                    if(word_index+1>=program_length) begin
                        word_index<=0; case_clock<=0; cycle_counter<=0; measure_seen<=0; measuring<=0; state<=S_RESET;
                    end else begin word_index<=word_index+1'b1; state<=S_COPY_READ; end
                end
                S_RESET: begin
                    if(word_index==4) begin
                        cpu_reset<=0; state<=S_RUN; word_index<=0; case_error<=0;
                    end else word_index<=word_index+1'b1;
                end
                S_SNAPSHOT_READ: begin
                    if(snapshot_index<8) snapshot_q<=result_meta[snapshot_index[2:0]];
                    state<=S_SNAPSHOT_WRITE;
                end
                S_SNAPSHOT_WRITE: begin
                    results[case_index*RESULT_WORDS+{25'd0,snapshot_index}]<=
                        snapshot_index<8 ? snapshot_q : (rf_valid_read_q ? rf_read_q :
                        32'hdead0000+{26'd0,rf_snapshot_index});
                    if(snapshot_index==71) begin
                        if(case_index+1>=case_count) begin
                            status<=batch_error || case_error ? 32'h80000002 : 32'h2;
                            state<=S_DONE;
                        end else begin
                            case_index<=case_index+1'b1; state<=S_CLEAR; word_index<=0;
                        end
                    end else begin snapshot_index<=snapshot_index+1'b1; state<=S_SNAPSHOT_READ; end
                end
                S_DONE: cpu_reset<=1;
                default: ;
            endcase
        end
    end
endmodule
