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
    localparam integer DESCRIPTOR_WORDS=16;
    localparam integer RESULT_WORDS=292;
    localparam integer EVENTS_PER_CASE=512;
    localparam integer MAX_EVENTS=16384;
    localparam [5:0] S_IDLE=0,S_CLEAR=1,S_COPY_READ=2,S_RESET=3,S_RUN=4,S_DONE=5,
                     S_SNAPSHOT_READ=6,S_DESC=7,S_VALIDATE=8,S_DESC_LATCH=9,
                     S_COPY_WRITE=10,S_SNAPSHOT_WRITE=11,S_INIT_LO=12,
                     S_INIT_HI=13,S_INIT_DATA=14,S_INIT_LATCH=15,S_INIT_TAG=16,
                     S_INIT_WRITE=17,S_SNAPSHOT_PAUSE=18,S_SNAPSHOT_MEMCOUNT=19,
                     S_MEM_LO=20,S_MEM_HI=21,S_MEM_DATA=22,S_MEM_LOOKUP=23,
                     S_MEM_WRITE_ADDR=24,S_MEM_WRITE_DATA=25,S_MEM_ZERO=26,
                     S_EXTRA_READ=27,S_EXTRA_WRITE=28,S_STIM_READ=29,
                     S_STIM_LATCH=30,S_STIM_WRITE=31,S_STIM_LOG_READ=32,S_STIM_LOG_WRITE=33;

    reg [31:0] desc [0:MAX_CASES*DESCRIPTOR_WORDS-1];
    reg [15:0] program_store [0:MAX_PROGRAM_WORDS-1];
    reg [15:0] memory [0:4095];
    // Sparse, initialized external memory: 16 tagged regions x 64 words.
    // The single 1024x17 synchronous RAM stores {valid,data}; region tags
    // remain in registers and are compared in parallel.
    reg [16:0] sparse_mem [0:1023];
    reg [21:0] sparse_tag [0:15];
    reg [15:0] sparse_tag_valid=0;
    reg [31:0] results [0:MAX_CASES*RESULT_WORDS-1];
    reg [31:0] timeout_limit=32'd4000000;
    reg [31:0] case_count=0, desc_ptr=0, program_ptr=0, result_index=0;
    reg [31:0] status=0;
    reg [31:0] case_index=0, word_index=0, case_clock=0, start_clock=0;
    reg [31:0] test_pc=0, next_pc=0, follow_pc=0, case_id=0, program_base=0, program_length=0;
    reg [31:0] pool_word_count=0, init_base=0, init_count=0, init_index=0;
    wire [8:0] init_span = {2'b0,init_count[6:0]} + {1'b0,init_count[6:0],1'b0};
    wire [31:0] init_span_wide = {23'b0,init_span};
    reg [31:0] wait_states=0, pause_clocks=0, pause_after_clocks=0, descriptor_flags=0;
    reg [31:0] stimulus_count=0, stimulus_base=0;
    wire [31:0] stimulus_span={25'b0,stimulus_count[4:0],2'b0};
    reg [4:0] stimulus_index=0, stimulus_log_index=0;
    reg [1:0] stimulus_word=0;
    reg [63:0] stimulus_data=0;
    reg [127:0] stimulus_records [0:15];
    reg [127:0] stimulus_record_q;
    reg [31:0] stimulus_host_issued=0, stimulus_last_clock=0, stimulus_paused=0;
    reg stimulus_pause_latched=0, previous_hold_ack=0;
    reg [31:0] stimulus_pause_pc=0, stimulus_pause_st=0;
    reg [31:0] drain_mode=0, drain_remaining=0;
    reg [31:0] pool_ptr=0, init_addr=0;
    reg [15:0] init_data=0;
    reg [31:0] target_latency=4;
    reg [31:0] paused_count=0, pause_remaining=0;
    reg [31:0] measure_pass=1, measure_seen=0;
    reg [3:0] desc_index=0;
    reg measuring=0, primary_complete=0, drain_pause_active=0, drain_pause_started=0;
    reg follow_snapshot_done=0;
    reg [31:0] follow_capture_count=0, extra_index=0;
    reg [31:0] entry_count=0, entry_previous=0, entry_complete=0, entry_first_retire=0;
    reg [31:0] last_retire_clock=0;
    reg [5:0] state=S_IDLE;
    reg cpu_reset=1;

    reg [31:0] rf_shadow [0:63];
    reg [63:0] rf_valid=0;
    reg [31:0] follow_rf_shadow [0:63];
    reg [63:0] follow_rf_valid=0;
    reg [15:0] mem_read_q=0;
    reg [31:0] target_addr_q=0;
    reg [15:0] target_wdata_q=0;
    reg target_iaq_q=0;
    reg [15:0] target_io_data_q=0;
    reg [3:0] target_kind_q=0;
    reg [9:0] target_sparse_addr_q=0;
    reg target_tag_hit_q=0;
    reg [31:0] target_age=0;
    reg final_store_valid=0;
    reg [31:0] final_store_addr=0;
    reg [15:0] final_store_old_data=0;
    reg [1:0] target_state=0;
    localparam [1:0] T_IDLE=0,T_WAIT=1,T_ACK=2;
    reg [31:0] event_count=0;
    reg [127:0] events [0:MAX_CASES*EVENTS_PER_CASE-1];
    reg [9:0] case_event_count [0:MAX_CASES-1];
    reg event_overflow=0;
    reg [31:0] event_index=0;
    reg [31:0] cycle_counter=0;
    reg [6:0] snapshot_index=0;
    reg [31:0] desc_q=0;
    reg [15:0] program_read_q=0;
    reg [31:0] program_read_address=0;
    reg [31:0] snapshot_q=0;
    reg [31:0] csr_read_q=0;
    reg [31:0] results_read_q;
    reg [127:0] events_read_q;
    reg [3:0] read_address_q=0;
    reg results_read_error_q=0;
    reg events_read_error_q=0;
    reg [31:0] rf_read_q;
    reg rf_valid_read_q;
    reg [31:0] follow_rf_read_q;
    reg follow_rf_valid_read_q;
    reg [31:0] result_meta [0:15];
    reg [16:0] sparse_read_q;
    reg [16:0] target_sparse_data_q;
    reg [16:0] sparse_snapshot_data_q;
    reg [9:0] sparse_read_address=0;
    reg sparse_lookup_valid_q;
    reg [3:0] target_tag_slot, init_tag_search_slot, init_free_tag_slot;
    reg target_tag_hit, init_tag_hit, init_free_tag_found;
    integer tag_scan;
    reg [6:0] snapshot_mem_index=0;
    reg [15:0] init_addr_lo_q=0;
    reg [3:0] init_tag_slot=0;
    reg [31:0] pause_pc_q, pause_st_q;
    reg [170:0] pause_work_q;
    reg pause_active=0, pause_done=0;
    wire [5:0] rf_snapshot_index=snapshot_index[5:0]-6'd8;
    wire [5:0] follow_snapshot_index=extra_index[5:0]-6'd6;
    reg case_error=0, batch_error=0;

    // A single registered read address shares the program-store BRAM port
    // across instruction copy and initializer serialization phases.
    always @* begin
        case(state)
            S_COPY_READ: program_read_address=program_base+word_index;
            S_STIM_READ: program_read_address=stimulus_base+{25'b0,stimulus_index,2'b0}+{30'b0,stimulus_word};
            S_INIT_LO: program_read_address=pool_ptr;
            S_INIT_HI: program_read_address=pool_ptr+1'b1;
            S_INIT_DATA: program_read_address=pool_ptr+32'd2;
            S_MEM_LO: program_read_address=pool_ptr+{25'b0,snapshot_mem_index}*3;
            S_MEM_HI: program_read_address=pool_ptr+{25'b0,snapshot_mem_index}*3+1'b1;
            S_MEM_DATA: program_read_address=pool_ptr+{25'b0,snapshot_mem_index}*3+32'd2;
            default: program_read_address=0;
        endcase
    end

    // The sparse BRAM has one registered read address shared by the CPU
    // target and the post-case memory snapshot serializer.
    always @* begin
        if(state==S_MEM_LOOKUP && init_tag_hit)
            sparse_read_address={init_tag_search_slot,init_addr[9:4]};
        else if(target_state==T_IDLE && cyc_req && !cpu_reset && target_tag_hit)
            sparse_read_address={target_tag_slot,cyc_addr[9:4]};
        else
            sparse_read_address=0;
    end

    wire obs_decode, obs_rf_we, obs_hw_complete, cpu_retire, obs_bus_start, obs_bus_complete;
    wire [31:0] obs_decode_pc, obs_rf_data, pc, st;
    wire [15:0] obs_decode_ir, obs_bus_rdata;
    wire [5:0] obs_rf_addr;
    wire [170:0] obs_work;
    wire [15:0] intpend;
    wire obs_field_pending_fault, obs_word_req, obs_word_pending;
    wire cyc_req, cyc_ack, cyc_iaq, fault;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr;
    wire [15:0] cyc_wdata, cyc_io_rdata;
    wire stimulus_reset=!reset_n;
    wire stimulus_clear=state==S_CLEAR;
    wire stimulus_armed=state==S_RUN && !cpu_reset;
    wire stimulus_write=state==S_STIM_WRITE;
    wire stimulus_target_write=state==S_RUN && target_state==T_ACK && target_kind_q==4'd1;
    wire [31:0] stimulus_clock=case_clock-start_clock-32'd1;
    wire stimulus_lint1_n, stimulus_lint2_n, stimulus_hold, stimulus_emu, stimulus_cen;
    wire stimulus_host_req, stimulus_event, stimulus_error, cpu_hold_ack, cpu_host_ack;
    wire [15:0] stimulus_host_data;
    wire [4:0] stimulus_applied, stimulus_event_index;
    wire [31:0] stimulus_event_clock, stimulus_writes, stimulus_holds, stimulus_hosts;
    wire [63:0] stimulus_event_data;
    wire stimulus_unfinished=stimulus_applied!=stimulus_count[4:0] || stimulus_host_req ||
                              stimulus_hosts+{31'b0,cpu_host_ack}!=stimulus_host_issued;
    wire stimulus_entry_bad=stimulus_data[63:51]!=0 || stimulus_data[50:48]>5 ||
        (stimulus_data[47:32] & ~16'h833f)!=0 ||
        (stimulus_data[47:40]!=0 && !stimulus_data[36]) ||
        (stimulus_data[50:48]==2 && stimulus_data[3:0]!=0) ||
        ((stimulus_data[50:48]==1 || stimulus_data[50:48]>=3) && stimulus_data[31:0]==0);
    wire trace_event_now = !cpu_reset && state==S_RUN && measuring &&
                           (obs_bus_start || obs_bus_complete ||
                            (target_state==T_IDLE && cyc_req) ||
                            (target_state==T_ACK) || cpu_hold_ack!=previous_hold_ack || cpu_host_ack);
    wire trace_overflow_now = trace_event_now &&
                              (case_event_count[case_index]>=10'd512 || event_count>=MAX_EVENTS);
    wire duplicate_follow_now = state==S_RUN && measuring && follow_pc!=0 && obs_decode &&
                                obs_decode_pc==follow_pc && follow_capture_count!=0;
    reg [15:0] cyc_rdata;
    wire cpu_cen = !cpu_reset && state==S_RUN && !pause_active && !drain_pause_active && stimulus_cen;
    assign avs_waitrequest=1'b0;
    assign cyc_ack=target_state==T_ACK;

    always @* begin
        target_tag_slot=0; target_tag_hit=0;
        init_tag_search_slot=0; init_tag_hit=0;
        init_free_tag_slot=0; init_free_tag_found=0;
        for(tag_scan=0;tag_scan<16;tag_scan=tag_scan+1) begin
            if(sparse_tag_valid[tag_scan] && sparse_tag[tag_scan]==cyc_addr[31:10]) begin
                target_tag_slot=tag_scan[3:0]; target_tag_hit=1;
            end
            if(sparse_tag_valid[tag_scan] && sparse_tag[tag_scan]==init_addr[31:10]) begin
                init_tag_search_slot=tag_scan[3:0]; init_tag_hit=1;
            end
            if(!sparse_tag_valid[tag_scan] && !init_free_tag_found) begin
                init_free_tag_slot=tag_scan[3:0]; init_free_tag_found=1;
            end
        end
    end

    // Match timing/test.sv's falling-edge CEN stimulus. The CPU is held on
    // exactly pause_clocks rising edges; the external target and fabric keep
    // running. Capture the stopped architectural/working state at the same
    // falling edge that first disables CEN.
    always @(negedge clk) begin
        if(!reset_n || cpu_reset || state!=S_RUN) begin
            pause_active<=0; pause_done<=0; pause_remaining<=0;
            drain_pause_active<=0; drain_pause_started<=0;
        end else if(primary_complete && drain_mode==32'hffff_fffe && !drain_pause_started) begin
            // The original bench freezes CPU CEN at the falling edge after
            // the primary RESULT, while the target/fabric remain clocked.
            drain_pause_active<=1; drain_pause_started<=1;
        end else if(measuring && !pause_done && pause_clocks!=0 &&
                    case_clock>=start_clock &&
                    (case_clock-start_clock-1)>=pause_after_clocks) begin
            pause_active<=1; pause_done<=1; pause_remaining<=pause_clocks;
            pause_pc_q<=pc; pause_st_q<=st; pause_work_q<=obs_work;
        end else if(pause_active) begin
            if(pause_remaining<=1) begin
                pause_remaining<=0; pause_active<=0;
            end else pause_remaining<=pause_remaining-1'b1;
        end
    end
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

    jttms10_fpga_stimulus u_stimulus(
        .clk(clk),.rst(stimulus_reset),.clear(stimulus_clear),.armed(stimulus_armed),
        .measuring(measuring),.relative_clock(stimulus_clock),
        .cfg_write(stimulus_write),.cfg_index(stimulus_index[3:0]),.cfg_data(stimulus_data),
        .cfg_count(stimulus_count[4:0]),.write_complete(stimulus_target_write),
        .decode(obs_decode),.decode_pc(obs_decode_pc),.hold_ack(cpu_hold_ack),.host_ack(cpu_host_ack),
        .lint1_n(stimulus_lint1_n),.lint2_n(stimulus_lint2_n),.hold_req(stimulus_hold),
        .emu_run(stimulus_emu),.cen_enable(stimulus_cen),.host_req(stimulus_host_req),
        .host_wdata(stimulus_host_data),.event_valid(stimulus_event),
        .event_index(stimulus_event_index),.event_clock(stimulus_event_clock),
        .event_data(stimulus_event_data),.applied_count(stimulus_applied),
        .write_count(stimulus_writes),.hold_count(stimulus_holds),.host_count(stimulus_hosts),
        .error(stimulus_error)
    );

    jttms10_system #(.CLKS_PER_STATE(8),.RESET_REFRESH(0)) u_cpu(
        .obs_decode(obs_decode),.obs_rf_we(obs_rf_we),.obs_hw_complete(obs_hw_complete),
        .obs_decode_pc(obs_decode_pc),.obs_rf_data(obs_rf_data),
        .obs_decode_ir(obs_decode_ir),.obs_rf_addr(obs_rf_addr),.obs_work(obs_work),
        .obs_bus_start(obs_bus_start),.obs_bus_complete(obs_bus_complete),
        .obs_bus_rdata(obs_bus_rdata),.obs_field_pending_fault(obs_field_pending_fault),
        .obs_word_req(obs_word_req),.obs_word_pending(obs_word_pending),
        .clk(clk),.rst(cpu_reset),.cen(cpu_cen),.vclk_cen(1'b0),
        .hcs_n(1'b0),.hsync_n(1'b1),.vsync_n(1'b1),.lint1_n(stimulus_lint1_n),.lint2_n(stimulus_lint2_n),
        .hold_req(stimulus_hold),.hold_ack(cpu_hold_ack),.emu_run(stimulus_emu),.emu_ack(),
        .host_req(stimulus_host_req),.host_we(1'b1),.host_reg(2'd3),.host_be(2'b10),.host_wdata(stimulus_host_data),
        .host_rdata(),.host_ack(cpu_host_ack),.host_busy(),.hint_n(),.hs(),.vs(),.hblank(),.vblank(),.blank(),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),.cyc_wdata(cyc_wdata),
        .cyc_io_rdata(cyc_io_rdata),.cyc_iaq(cyc_iaq),.cyc_srfaddr(),.cyc_dpytap(),.cyc_org(),
        .cyc_dram_row(),.cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack),
        .pc(pc),.st(st),.ir(),.retire(cpu_retire),.fault(fault),
        .intenb(),.intpend(intpend),.irq_pending(),.nmi_pending(),.halt()
    );

    // The target captures the complete request at allocation. Its synchronous
    // memory read overlaps the fixed four-clock readiness interval.
    always @* begin
        if(sparse_lookup_valid_q && target_sparse_data_q[16]) cyc_rdata=target_sparse_data_q[15:0];
        else if(target_kind_q==5) cyc_rdata=cyc_io_rdata;
        else if(target_addr_q==32'hffffffe0) cyc_rdata=16'h1000;
        else if(target_addr_q==32'hfffffff0) cyc_rdata=16'h0000;
        else if(target_addr_q<32'h00010000) cyc_rdata=mem_read_q;
        else cyc_rdata=16'h0000;
    end

    // Avalon-MM registers are word addressed. Descriptor/program writes are
    // accepted only while idle, preventing host timing from affecting RUN.
    always @(posedge clk) begin
        if(!reset_n) begin
            state<=S_IDLE; cpu_reset<=1; status<=0; case_index<=0;
            case_clock<=0; cycle_counter<=0; target_state<=T_IDLE;
            target_age<=0; event_count<=0; event_overflow<=0;
            measuring<=0; primary_complete<=0;
            measure_seen<=0; desc_index<=0; rf_valid<=0; follow_rf_valid<=0; word_index<=0; case_count<=0;
            desc_ptr<=0; program_ptr<=0; result_index<=0; event_index<=0;
            timeout_limit<=32'd4000000; snapshot_index<=0;
            case_error<=0; batch_error<=0; sparse_tag_valid<=0;
            paused_count<=0; drain_remaining<=0; follow_capture_count<=0;
            extra_index<=0; pool_word_count<=0; init_index<=0;
            entry_count<=0; entry_previous<=0; entry_complete<=0; entry_first_retire<=0;
            last_retire_clock<=0;
            sparse_lookup_valid_q<=0;
            stimulus_index<=0; stimulus_word<=0; stimulus_data<=0;
            stimulus_log_index<=0; stimulus_host_issued<=0; stimulus_last_clock<=0;
            stimulus_paused<=0; stimulus_pause_latched<=0; previous_hold_ack<=0;
            csr_read_q<=0; read_address_q<=0;
        end else begin
            program_read_q<=program_store[program_read_address[11:0]];
            // Keep the test RAM read port enabled every cycle. The address
            // is sampled at the same edge as request allocation; the target
            // stability checks hold it through ACK, and high-address reads
            // are ignored by the response mux. This keeps the RAM's
            // registered output inside the memory inference pattern even
            // when CPU signals cross a Quartus partition boundary.
            mem_read_q<=memory[cyc_addr[15:4]];
            stimulus_record_q<=stimulus_records[stimulus_log_index[3:0]];
            // Keep all test-memory writes on one synchronous port so Quartus
            // can infer block RAM instead of expanding the 64K-bit array into
            // logic cells. These phases are mutually exclusive by design.
            if(state==S_CLEAR) memory[word_index[11:0]]<=16'b0;
            else if(state==S_COPY_WRITE)
                memory[12'd256+word_index[11:0]]<=program_read_q;
            else if(state==S_RUN && target_state==T_ACK && target_kind_q==4'd1 &&
                    target_addr_q<32'h00010000)
                memory[target_addr_q[15:4]]<=target_wdata_q;

            // One synchronous port for the sparse valid/data block RAM.
            // Clear and initializer writes are disjoint from RUN-time reads.
            if(state==S_CLEAR && word_index<1024)
                sparse_mem[word_index[9:0]]<=17'b0;
            else if(state==S_INIT_WRITE)
                sparse_mem[{init_tag_slot,init_addr[9:4]}]<={1'b1,init_data[15:0]};
            else if(state==S_RUN && target_state==T_ACK && target_kind_q==4'd1 &&
                    target_tag_hit_q && target_sparse_data_q[16])
                sparse_mem[target_sparse_addr_q]<={1'b1,target_wdata_q};
            sparse_read_q<=sparse_mem[sparse_read_address];
            if(target_state==T_WAIT && target_age==1)
                target_sparse_data_q<=sparse_read_q;
            if(state==S_MEM_WRITE_ADDR)
                sparse_snapshot_data_q<=sparse_read_q;

            // One-cycle Avalon read latency keeps result/event memories on
            // synchronous read ports instead of wide asynchronous muxes.
            if(avs_read) begin
                read_address_q<=avs_address;
                case(avs_address)
                    0: csr_read_q<=32'h4a545235;
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
                            results_read_q<=results[result_index[13:0]];
                    end
                    10: csr_read_q<=event_index;
                    11,12,13,14: begin
                        csr_read_q<=0;
                        events_read_error_q<=event_index>=MAX_EVENTS;
                        if(event_index<MAX_CASES*EVENTS_PER_CASE)
                            events_read_q<=events[event_index[13:0]];
                    end
                    15: csr_read_q<=timeout_limit;
                    default: csr_read_q<=0;
                endcase
            end
            if(state==S_SNAPSHOT_READ && snapshot_index>=8) begin
                rf_read_q<=rf_shadow[rf_snapshot_index];
                rf_valid_read_q<=rf_valid[rf_snapshot_index];
            end
            if(state==S_EXTRA_READ && extra_index>=6 && extra_index<70) begin
                follow_rf_read_q<=follow_rf_shadow[follow_snapshot_index];
                follow_rf_valid_read_q<=follow_rf_valid[follow_snapshot_index];
            end
            if(avs_write && state==S_IDLE) begin
                case(avs_address)
                    1: if(avs_writedata[0]) begin
                        if(case_count==0 || case_count>MAX_CASES || program_ptr>MAX_PROGRAM_WORDS) status<=32'h80000001;
                        else begin status<=32'h1; case_index<=0; event_count<=0;
                                   event_overflow<=0; batch_error<=0; pool_word_count<=program_ptr;
                                   state<=S_CLEAR; end
                    end
                    2: case_count<=avs_writedata;
                    3: desc_ptr<=avs_writedata;
                    4: begin
                        if(desc_ptr<MAX_CASES*DESCRIPTOR_WORDS) desc[desc_ptr]<=avs_writedata;
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
                target_latency<=32'd4+(wait_states<<3);
                sparse_lookup_valid_q<=target_tag_hit;
                target_tag_hit_q<=target_tag_hit;
                target_sparse_addr_q<={target_tag_slot,cyc_addr[9:4]};
            end else if(target_state==T_WAIT) begin
                if(!cyc_req || cyc_addr!=target_addr_q || cyc_kind!=target_kind_q ||
                   cyc_wdata!=target_wdata_q || cyc_iaq!=target_iaq_q ||
                   cyc_io_rdata!=target_io_data_q)
                    begin status[8]<=1'b1; case_error<=1; batch_error<=1; end
                if(target_age>=target_latency-1'b1) target_state<=T_ACK;
                else target_age<=target_age+1'b1;
            end else if(target_state==T_ACK) begin
                if(!cyc_req || cyc_addr!=target_addr_q || cyc_kind!=target_kind_q ||
                   cyc_wdata!=target_wdata_q || cyc_iaq!=target_iaq_q ||
                   cyc_io_rdata!=target_io_data_q)
                    begin status[8]<=1'b1; case_error<=1; batch_error<=1; end
                target_state<=T_IDLE;
                if(cyc_req && target_kind_q==4'd1 &&
                   ((target_addr_q>=32'h00010000 &&
                     !(target_tag_hit_q && target_sparse_data_q[16])))) begin
                    status[8]<=1'b1; case_error<=1; batch_error<=1;
                end
            end

            // A row can represent simultaneous timer and physical-target
            // events without losing either when they occur on one clock.
            if(trace_event_now) begin
                if(case_event_count[case_index]<10'd512 && event_count<MAX_EVENTS) begin
                    events[event_count] <= {11'b0,cpu_host_ack,(cpu_hold_ack!=previous_hold_ack),cpu_hold_ack,4'b0,case_index[4:0],
                        (target_state==T_IDLE && cyc_req), (target_state==T_ACK),
                        obs_bus_start, obs_bus_complete, cyc_kind, cyc_iaq,
                        cyc_addr, cyc_wdata,
                        (obs_bus_complete ? obs_bus_rdata : (target_state==T_ACK ? cyc_rdata : 16'b0)),cycle_counter};
                    case_event_count[case_index]<=case_event_count[case_index]+1'b1;
                    event_count<=event_count+1'b1;
                end else begin event_overflow<=1; case_error<=1; batch_error<=1; end
            end else if(state==S_STIM_LOG_WRITE &&
                        case_event_count[case_index]<10'd512 && event_count<MAX_EVENTS) begin
                events[event_count]<=stimulus_record_q;
                event_count<=event_count+1'b1;
                case_event_count[case_index]<=case_event_count[case_index]+1'b1;
            end

            if(obs_rf_we && !cpu_reset) begin
                if(!primary_complete &&
                   !(state==S_RUN && obs_decode && obs_decode_pc==next_pc && measuring)) begin
                    rf_shadow[obs_rf_addr]<=obs_rf_data;
                    rf_valid[obs_rf_addr]<=1'b1;
                end
                if(!follow_snapshot_done &&
                   !(state==S_RUN && obs_decode && obs_decode_pc==follow_pc &&
                     measuring && follow_pc!=0)) begin
                    follow_rf_shadow[obs_rf_addr]<=obs_rf_data;
                    follow_rf_valid[obs_rf_addr]<=1'b1;
                end
            end
            if(state==S_RUN) begin
                cycle_counter<=cycle_counter+1'b1;
                case_clock<=case_clock+1'b1;
                previous_hold_ack<=cpu_hold_ack;
                if(pause_active || !stimulus_cen) paused_count<=paused_count+1'b1;
                if(!stimulus_cen) stimulus_paused<=stimulus_paused+1'b1;
                if(stimulus_pause_latched && (pc!==stimulus_pause_pc || st!==stimulus_pause_st)) begin
                    case_error<=1; batch_error<=1;
                end
                if(!stimulus_cen && !stimulus_pause_latched) begin
                    stimulus_pause_pc<=pc; stimulus_pause_st<=st;
                end
                stimulus_pause_latched<=!stimulus_cen;
                if(stimulus_event) begin
                    stimulus_records[stimulus_event_index[3:0]]<=
                        {13'b0,stimulus_event_index[3:0],1'b1,case_index[4:0],9'b0,
                         stimulus_event_data[31:0],stimulus_event_data[63:32],
                         start_clock+stimulus_event_clock+32'd1};
                    if(stimulus_event_data[36]) stimulus_host_issued<=stimulus_host_issued+1'b1;
                    stimulus_last_clock<=stimulus_event_clock;
                end
                if(obs_field_pending_fault || fault || stimulus_error || (!stimulus_cen && obs_rf_we) ||
                   (pause_active && (pc!==pause_pc_q || st!==pause_st_q ||
                                     obs_work!==pause_work_q || obs_rf_we))) begin
                    case_error<=1; batch_error<=1;
                end
                if(pause_active && cyc_req) begin
                    status[8]<=1'b1; case_error<=1; batch_error<=1;
                end
                // retire is registered by the CPU: its event happened one fast clock
                // before this observer sees it. Context completion is combinational
                // and sampled at the assigning edge, so it needs no adjustment.
                if(measuring && cpu_retire) begin
                    last_retire_clock<=case_clock-32'd1;
                    if(entry_count!=0 && entry_first_retire==0)
                        entry_first_retire<=case_clock-32'd1;
                end
                if(measuring && obs_hw_complete) begin
                    entry_count<=entry_count+32'd1;
                    if(entry_count==0) begin
                        entry_complete<=case_clock;
                        entry_previous<=cpu_retire ? case_clock-32'd1 : last_retire_clock;
                    end
                end
                if(obs_decode && measuring && follow_pc!=0 && obs_decode_pc==follow_pc) begin
                    if(follow_capture_count==0) begin
                        result_meta[9]<=case_clock;
                        result_meta[10]<=st;
                        result_meta[11]<=obs_decode_pc;
                        result_meta[12]<={16'b0,obs_decode_ir};
                        follow_snapshot_done<=1'b1;
                    end else begin
                        case_error<=1; batch_error<=1;
                    end
                    follow_capture_count<=follow_capture_count+1'b1;
                end
                if(obs_decode && obs_decode_pc==test_pc && !measuring) begin
                    if(measure_seen==measure_pass) begin
                        measuring<=1'b1; start_clock<=case_clock;
                    end else measure_seen<=measure_seen+1'b1;
                end else if(obs_decode && measuring && !primary_complete && obs_decode_pc==next_pc) begin
                    result_meta[0]<=case_id;
                    result_meta[1]<=(case_error || fault || stimulus_error || stimulus_unfinished || obs_field_pending_fault || trace_overflow_now ||
                                    duplicate_follow_now) ? 32'h80000004 : 32'h2;
                    result_meta[2]<=case_clock-start_clock;
                    result_meta[3]<=test_pc;
                    result_meta[4]<=next_pc;
                    result_meta[5]<={16'b0,obs_decode_ir};
                    result_meta[6]<=st;
                    result_meta[7]<=start_clock;
                    result_meta[8]<={16'b0,intpend};
                    result_meta[14]<=paused_count;
                    primary_complete<=1'b1;
                    if(drain_mode==0 || drain_mode==32'hffff_ffff) begin
                        result_meta[13]<=0;
                        result_meta[1]<=(case_error || fault || stimulus_error || stimulus_unfinished || obs_field_pending_fault || trace_overflow_now ||
                                        duplicate_follow_now) ? 32'h80000004 : 32'h2;
                        if(target_state==T_ACK && target_kind_q==4'd1 &&
                           target_tag_hit_q && target_sparse_data_q[16]) begin
                            final_store_valid<=1'b1;
                            final_store_addr<=target_addr_q;
                            final_store_old_data<=target_sparse_data_q[15:0];
                        end
                        measuring<=0; snapshot_index<=0; stimulus_log_index<=0; state<=S_STIM_LOG_READ; cpu_reset<=1;
                    end else if(!drain_mode[31]) begin
                        drain_remaining<=drain_mode;
                    end
                end else if(obs_decode && measuring && primary_complete &&
                            drain_mode!=32'hffff_fffe && drain_mode!=32'hffff_ffff &&
                            drain_mode!=0 && drain_remaining!=0) begin
                    if(drain_remaining==1) begin
                        result_meta[13]<=case_clock;
                        result_meta[1]<=(case_error || fault || stimulus_error || stimulus_unfinished || obs_field_pending_fault ||
                                        trace_overflow_now || duplicate_follow_now || follow_capture_count>1) ? 32'h80000004 : 32'h2;
                        if(target_state==T_ACK && target_kind_q==4'd1 &&
                           target_tag_hit_q && target_sparse_data_q[16]) begin
                            final_store_valid<=1'b1;
                            final_store_addr<=target_addr_q;
                            final_store_old_data<=target_sparse_data_q[15:0];
                        end
                        measuring<=0; snapshot_index<=0; stimulus_log_index<=0; state<=S_STIM_LOG_READ; cpu_reset<=1;
                    end else drain_remaining<=drain_remaining-1'b1;
                end else if(primary_complete && drain_mode==32'hffff_fffe &&
                            !obs_word_pending && !obs_word_req && !cyc_req && target_state==T_IDLE) begin
                    result_meta[13]<=case_clock;
                    result_meta[1]<=(case_error || fault || stimulus_error || stimulus_unfinished || obs_field_pending_fault ||
                                    trace_overflow_now || duplicate_follow_now || follow_capture_count>1) ? 32'h80000004 : 32'h2;
                    measuring<=0; snapshot_index<=0; stimulus_log_index<=0; state<=S_STIM_LOG_READ; cpu_reset<=1;
                end else if(case_clock>=timeout_limit) begin
                    if(!primary_complete) begin
                        result_meta[0]<=case_id; result_meta[2]<=0;
                        result_meta[3]<=test_pc; result_meta[4]<=next_pc;
                        result_meta[5]<=0; result_meta[6]<=st; result_meta[7]<=start_clock;
                        result_meta[8]<={16'b0,intpend}; result_meta[14]<=paused_count;
                    end
                    result_meta[1]<=32'h80000002;
                    result_meta[13]<=case_clock;
                    batch_error<=1; measuring<=0; snapshot_index<=0; stimulus_log_index<=0; state<=S_STIM_LOG_READ; cpu_reset<=1;
                end
            end
            case(state)
                S_IDLE: cpu_reset<=1;
                S_CLEAR: begin
                    cpu_reset<=1; rf_valid<=0; follow_rf_valid<=0; measuring<=0;
                    primary_complete<=0; follow_snapshot_done<=0; follow_capture_count<=0;
                    entry_count<=0; entry_previous<=0; entry_complete<=0; entry_first_retire<=0;
                    last_retire_clock<=0;
                    stimulus_host_issued<=0; stimulus_last_clock<=0; stimulus_paused<=0;
                    stimulus_pause_latched<=0; previous_hold_ack<=0;
                    drain_remaining<=0; final_store_valid<=0;
                    paused_count<=0; target_state<=T_IDLE;
                    result_meta[8]<=0; result_meta[9]<=0; result_meta[10]<=0;
                    result_meta[11]<=0; result_meta[12]<=0; result_meta[13]<=0;
                    result_meta[14]<=0; result_meta[15]<=0;
                    if(word_index==4095) begin
                        word_index<=0; desc_index<=0; case_event_count[case_index]<=0; case_error<=0;
                        sparse_tag_valid<=0; init_index<=0; paused_count<=0;
                        state<=S_DESC;
                    end else word_index<=word_index+1'b1;
                end
                S_DESC: begin
                    desc_q<=desc[case_index*DESCRIPTOR_WORDS+{28'd0,desc_index}];
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
                        6: init_base<=desc_q;
                        7: init_count<=desc_q;
                        8: wait_states<=desc_q;
                        9: pause_clocks<=desc_q;
                        10: pause_after_clocks<=desc_q;
                        11: descriptor_flags<=desc_q;
                        12: drain_mode<=desc_q;
                        13: follow_pc<=desc_q;
                        14: stimulus_count<=desc_q;
                        15: stimulus_base<=desc_q;
                    endcase
                    if(desc_index==15) state<=S_VALIDATE;
                    else begin desc_index<=desc_index+1'b1; state<=S_DESC; end
                end
                S_VALIDATE: begin
                    if(program_length==0 || program_length>3840 || program_base>=MAX_PROGRAM_WORDS ||
                           program_base>pool_word_count || program_length>pool_word_count-program_base ||
                           init_count>64 || init_base>pool_word_count ||
                           init_span_wide>pool_word_count-init_base ||
                           (program_base < init_base+init_span_wide && init_base < program_base+program_length) ||
                           wait_states>32'h1fffffff || pause_clocks>timeout_limit || pause_after_clocks>timeout_limit ||
                           descriptor_flags!=0 || stimulus_count>16 || stimulus_base>pool_word_count ||
                           stimulus_span>pool_word_count-stimulus_base ||
                           (stimulus_count==0 && stimulus_base!=0) ||
                           (stimulus_count!=0 &&
                             ((program_base<stimulus_base+stimulus_span && stimulus_base<program_base+program_length) ||
                              (init_count!=0 && init_base<stimulus_base+stimulus_span && stimulus_base<init_base+init_span_wide))) ||
                           (drain_mode[31] && drain_mode!=32'hffff_fffe && drain_mode!=32'hffff_ffff) ||
                           test_pc[3:0]!=0 || next_pc[3:0]!=0 || follow_pc[3:0]!=0 || measure_pass>255) begin
                            result_meta[0]<=case_id; result_meta[1]<=32'h80000003;
                            result_meta[2]<=0; result_meta[3]<=test_pc; result_meta[4]<=next_pc;
                            result_meta[5]<=0; result_meta[6]<=0; result_meta[7]<=0;
                            batch_error<=1; case_error<=1; init_count<=0;
                            paused_count<=0; snapshot_index<=0; state<=S_SNAPSHOT_READ;
                        end else begin
                            word_index<=0; pool_ptr<=init_base; stimulus_index<=0; stimulus_word<=0;
                            state<=stimulus_count==0 ? S_COPY_READ : S_STIM_READ;
                        end
                end
                S_STIM_READ: state<=S_STIM_LATCH;
                S_STIM_LATCH: begin
                    stimulus_data<={program_read_q,stimulus_data[63:16]};
                    if(stimulus_word==3) state<=S_STIM_WRITE;
                    else begin stimulus_word<=stimulus_word+1'b1; state<=S_STIM_READ; end
                end
                S_STIM_WRITE: begin
                    if(stimulus_entry_bad) begin
                        result_meta[0]<=case_id; result_meta[1]<=32'h80000003;
                        result_meta[2]<=0; result_meta[3]<=test_pc; result_meta[4]<=next_pc;
                        result_meta[5]<=0; result_meta[6]<=0; result_meta[7]<=0;
                        batch_error<=1; case_error<=1; init_count<=0;
                        snapshot_index<=0; state<=S_SNAPSHOT_READ;
                    end else if({27'b0,stimulus_index}+32'd1>=stimulus_count) state<=S_COPY_READ;
                    else begin stimulus_index<=stimulus_index+1'b1; stimulus_word<=0; state<=S_STIM_READ; end
                end
                S_STIM_LOG_READ: begin
                    if(stimulus_log_index>=stimulus_applied) state<=S_SNAPSHOT_READ;
                    else state<=S_STIM_LOG_WRITE;
                end
                S_STIM_LOG_WRITE: begin
                    if(case_event_count[case_index]>=10'd512 || event_count>=MAX_EVENTS) begin
                        event_overflow<=1; case_error<=1; batch_error<=1;
                        // Preserve an earlier timeout/descriptor diagnosis;
                        // the independent overflow flag records this loss too.
                        if(result_meta[1]==32'h2) result_meta[1]<=32'h80000004;
                        state<=S_SNAPSHOT_READ;
                    end else begin
                        stimulus_log_index<=stimulus_log_index+1'b1;
                        state<=S_STIM_LOG_READ;
                    end
                end
                S_COPY_READ: begin
                    state<=S_COPY_WRITE;
                end
                S_COPY_WRITE: begin
                    if(word_index+1>=program_length) begin
                        word_index<=0; init_index<=0; pool_ptr<=init_base;
                        if(init_count==0) begin
                            case_clock<=0; cycle_counter<=0; measure_seen<=0; measuring<=0; state<=S_RESET;
                        end else state<=S_INIT_LO;
                    end else begin word_index<=word_index+1'b1; state<=S_COPY_READ; end
                end
                S_INIT_LO: begin
                    state<=S_INIT_HI;
                end
                S_INIT_HI: begin
                    init_addr_lo_q<=program_read_q;
                    state<=S_INIT_DATA;
                end
                S_INIT_DATA: begin
                    init_addr[15:0]<=init_addr_lo_q; init_addr[31:16]<=program_read_q;
                    state<=S_INIT_LATCH;
                end
                S_INIT_LATCH: begin
                    init_data<=program_read_q; state<=S_INIT_TAG;
                end
                S_INIT_TAG: begin
                    if(init_addr[3:0]!=0) begin
                        result_meta[0]<=case_id; result_meta[1]<=32'h80000003;
                        result_meta[2]<=0; result_meta[3]<=test_pc; result_meta[4]<=next_pc;
                        result_meta[5]<=0; result_meta[6]<=0; result_meta[7]<=0;
                        batch_error<=1; case_error<=1; init_count<=0;
                        snapshot_index<=0; cpu_reset<=1; state<=S_SNAPSHOT_READ;
                    end else if(init_tag_hit) begin
                        init_tag_slot<=init_tag_search_slot; state<=S_INIT_WRITE;
                    end else if(init_free_tag_found) begin
                        init_tag_slot<=init_free_tag_slot;
                        sparse_tag[init_free_tag_slot]<=init_addr[31:10];
                        sparse_tag_valid[init_free_tag_slot]<=1'b1; state<=S_INIT_WRITE;
                    end else begin
                        result_meta[0]<=case_id; result_meta[1]<=32'h80000003;
                        result_meta[2]<=0; result_meta[3]<=test_pc; result_meta[4]<=next_pc;
                        result_meta[5]<=0; result_meta[6]<=0; result_meta[7]<=0;
                        batch_error<=1; case_error<=1; init_count<=0;
                        snapshot_index<=0; cpu_reset<=1; state<=S_SNAPSHOT_READ;
                    end
                end
                S_INIT_WRITE: begin
                    if(init_index+1>=init_count) begin
                        word_index<=0; case_clock<=0; cycle_counter<=0; measure_seen<=0; measuring<=0; state<=S_RESET;
                    end else begin
                        init_index<=init_index+1'b1; pool_ptr<=pool_ptr+3;
                        state<=S_INIT_LO;
                    end
                end
                S_RESET: begin
                    if(word_index==4) begin
                        cpu_reset<=0; state<=S_RUN; word_index<=0; case_error<=0;
                    end else word_index<=word_index+1'b1;
                end
                S_SNAPSHOT_READ: begin
                    if(snapshot_index<8) snapshot_q<=result_meta[snapshot_index[3:0]];
                    state<=S_SNAPSHOT_WRITE;
                end
                S_SNAPSHOT_WRITE: begin
                    results[case_index*RESULT_WORDS+{25'd0,snapshot_index}]<=
                        snapshot_index<8 ? snapshot_q : (rf_valid_read_q ? rf_read_q : 32'b0);
                    if(snapshot_index==71) begin
                        state<=S_SNAPSHOT_PAUSE;
                    end else begin snapshot_index<=snapshot_index+1'b1; state<=S_SNAPSHOT_READ; end
                end
                S_SNAPSHOT_PAUSE: begin
                    results[case_index*RESULT_WORDS+72]<=result_meta[14];
                    state<=S_SNAPSHOT_MEMCOUNT;
                end
                S_SNAPSHOT_MEMCOUNT: begin
                    results[case_index*RESULT_WORDS+73]<=init_count;
                    snapshot_mem_index<=0;
                    state<=S_MEM_ZERO;
                end
                S_MEM_ZERO: begin
                    // Clear address/value snapshot slots serially so results
                    // remains a single-write-port synchronous RAM.
                    results[case_index*RESULT_WORDS+74+{25'b0,snapshot_mem_index}]<=0;
                    if(snapshot_mem_index==127) begin
                      if(init_count==0) begin
                        extra_index<=0; state<=S_EXTRA_READ;
                      end else begin snapshot_mem_index<=0; pool_ptr<=init_base; state<=S_MEM_LO; end
                    end else snapshot_mem_index<=snapshot_mem_index+1'b1;
                end
                S_MEM_LO: begin
                    state<=S_MEM_HI;
                end
                S_MEM_HI: begin
                    init_addr_lo_q<=program_read_q;
                    state<=S_MEM_DATA;
                end
                S_MEM_DATA: begin
                    init_addr[15:0]<=init_addr_lo_q; init_addr[31:16]<=program_read_q;
                    state<=S_MEM_LOOKUP;
                end
                S_MEM_LOOKUP: begin
                    sparse_lookup_valid_q<=init_tag_hit;
                    state<=S_MEM_WRITE_ADDR;
                end
                S_MEM_WRITE_ADDR: begin
                    results[case_index*RESULT_WORDS+74+({25'b0,snapshot_mem_index}<<1)]<=init_addr;
                    state<=S_MEM_WRITE_DATA;
                end
                S_MEM_WRITE_DATA: begin
                    results[case_index*RESULT_WORDS+75+({25'b0,snapshot_mem_index}<<1)]<=
                        final_store_valid && init_addr==final_store_addr ? {16'b0,final_store_old_data} :
                        sparse_lookup_valid_q && sparse_snapshot_data_q[16] ? {16'b0,sparse_snapshot_data_q[15:0]} : 32'h80000004;
                    if(!sparse_lookup_valid_q || !sparse_snapshot_data_q[16]) begin
                        case_error<=1; batch_error<=1;
                    end
                    if({25'b0,snapshot_mem_index}+32'd1>=init_count) begin
                        extra_index<=0; state<=S_EXTRA_READ;
                    end else begin snapshot_mem_index<=snapshot_mem_index+1'b1; state<=S_MEM_LO; end
                end
                S_EXTRA_READ: state<=S_EXTRA_WRITE;
                S_EXTRA_WRITE: begin
                    case(extra_index)
                        0: results[case_index*RESULT_WORDS+202]<=result_meta[8];
                        1: results[case_index*RESULT_WORDS+203]<=follow_capture_count;
                        2: results[case_index*RESULT_WORDS+204]<=result_meta[9];
                        3: results[case_index*RESULT_WORDS+205]<=result_meta[10];
                        4: results[case_index*RESULT_WORDS+206]<=result_meta[11];
                        5: results[case_index*RESULT_WORDS+207]<=result_meta[12];
                        6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,
                        24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,
                        40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,
                        56,57,58,59,60,61,62,63,64,65,66,67,68,69:
                            results[case_index*RESULT_WORDS+202+extra_index]<=
                                follow_capture_count!=0 && follow_rf_valid_read_q ? follow_rf_read_q : 32'b0;
                        70: results[case_index*RESULT_WORDS+272]<=result_meta[13];
                        71: results[case_index*RESULT_WORDS+273]<=0;
                        72: results[case_index*RESULT_WORDS+274]<=rf_valid[31:0];
                        73: results[case_index*RESULT_WORDS+275]<=rf_valid[63:32];
                        74: results[case_index*RESULT_WORDS+276]<=follow_capture_count!=0 ? follow_rf_valid[31:0] : 32'b0;
                        75: results[case_index*RESULT_WORDS+277]<=follow_capture_count!=0 ? follow_rf_valid[63:32] : 32'b0;
                        76: results[case_index*RESULT_WORDS+278]<=stimulus_count;
                        77: results[case_index*RESULT_WORDS+279]<={27'b0,stimulus_applied};
                        78: results[case_index*RESULT_WORDS+280]<=stimulus_writes;
                        79: results[case_index*RESULT_WORDS+281]<=stimulus_holds;
                        80: results[case_index*RESULT_WORDS+282]<=stimulus_hosts;
                        81: results[case_index*RESULT_WORDS+283]<=stimulus_host_issued;
                        82: results[case_index*RESULT_WORDS+284]<={31'b0,stimulus_error};
                        83: results[case_index*RESULT_WORDS+285]<=stimulus_last_clock;
                        84: results[case_index*RESULT_WORDS+286]<=stimulus_paused;
                        86: results[case_index*RESULT_WORDS+288]<=entry_count;
                        87: results[case_index*RESULT_WORDS+289]<=entry_previous;
                        88: results[case_index*RESULT_WORDS+290]<=entry_complete;
                        89: results[case_index*RESULT_WORDS+291]<=entry_first_retire;
                        default: results[case_index*RESULT_WORDS+202+extra_index]<=0;
                    endcase
                    if(extra_index==89) begin
                        if(result_meta[1]!=32'h2) batch_error<=1;
                        if(case_index+1>=case_count) begin
                            status<=batch_error || case_error || result_meta[1]!=32'h2 ? 32'h80000002 : 32'h2;
                            state<=S_DONE;
                        end else begin
                            case_index<=case_index+1'b1; state<=S_CLEAR; word_index<=0;
                        end
                    end else begin extra_index<=extra_index+1'b1; state<=S_EXTRA_READ; end
                end
                S_DONE: cpu_reset<=1;
                default: ;
            endcase
        end
    end
endmodule
