/* SPDX-License-Identifier: GPL-3.0-or-later */
`timescale 1ns/1ps
// Complete CPU/cache/field/peripheral boundary. The target supplies physical
// word cycles; it does not replace the cache or acknowledge abstract fields.
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, cen=1;
    wire cyc_req,cyc_ack,cyc_iaq,retire,fault;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr,pc,st;
    wire [15:0] cyc_wdata,cyc_io_rdata,ir;
    reg [15:0] cyc_rdata;
    jttms10_system #(.CLKS_PER_STATE(8),.RESET_REFRESH(0)) dut(
        .clk(clk),.rst(rst),.cen(cen),.vclk_cen(1'b0),
        .hcs_n(1'b0),.hsync_n(1'b1),.vsync_n(1'b1),
        .lint1_n(1'b1),.lint2_n(1'b1),.hold_req(1'b0),.hold_ack(),
        .emu_run(1'b1),.emu_ack(),.host_req(1'b0),.host_we(1'b0),
        .host_reg(2'd0),.host_be(2'd0),.host_wdata(16'd0),
        .host_rdata(),.host_ack(),.host_busy(),.hint_n(),
        .hs(),.vs(),.hblank(),.vblank(),.blank(),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),.cyc_iaq(cyc_iaq),
        .cyc_srfaddr(),.cyc_dpytap(),.cyc_org(),.cyc_dram_row(),
        .cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack),
        .pc(pc),.st(st),.ir(ir),.retire(retire),.fault(fault),
        .intenb(),.intpend(),.irq_pending(),.nmi_pending(),.halt()
    );
    reg [15:0] mem[0:4095];
    integer i,rc,delay_clocks=4,extra_wait=0;
    integer pause_clocks=0,pause_after=0,pause_left=0,paused=0;
    reg pause_done=0;
    reg [31:0] pause_pc,pause_st;
    reg [31:0] pause_regs[0:3], pause_bregs[0:4];
    reg [11:0] pause_uaddr;
    reg pause_active;
    reg [132:0] pause_work;
    integer now=0,seen=0,start_clock=0;
    reg [31:0] test_pc,next_pc;
    reg measuring=0,case_done=0,response_request_seen=0;
    integer case_id=0,batch_fd,data_fd,word_count,loaded=0,measure_pass=1,memory_count=0,watch_extra=0,drain_instructions=0,drain_left=0;
    reg draining=0;
    reg [31:0] data_address[0:15];
    reg [15:0] data_value[0:15];
    reg [15:0] input_word;
    // A combined fetch/dispatch commits IR and increments PC on the same
    // edge. The previous two-word microcode had incremented PC earlier.
    reg [31:0] follow_pc=0;
    wire [31:0] accepted_pc=dut.u_cpu.u_core.fetch ? pc : pc-32'd16;
    wire [15:0] accepted_ir=dut.u_cpu.u_core.fetch ?
                           dut.u_cpu.u_core.read_data[15:0] : dut.u_cpu.u_core.md[15:0];
    string program_path,batch_path,data_path;
    initial begin
        rc=$value$plusargs("WAIT=%d",extra_wait);
        rc=$value$plusargs("PAUSE=%d",pause_clocks);
        rc=$value$plusargs("PAUSE_AFTER=%d",pause_after);
        if(extra_wait<0) $fatal(1,"negative wait");
        delay_clocks=4+extra_wait;
        if($value$plusargs("BATCH=%s",batch_path)) begin
            batch_fd=$fopen(batch_path,"r");
            if(batch_fd==0) $fatal(1,"cannot open batch input");
            rc=$fscanf(batch_fd,"%d %h %h %d %d %d %d %d %h",case_id,test_pc,next_pc,measure_pass,word_count,memory_count,watch_extra,drain_instructions,follow_pc);
            while(rc==9) begin
                if(word_count<1 || word_count>3840) $fatal(1,"invalid program length");
                for(i=0;i<4096;i=i+1) mem[i]=0;
                for(i=0;i<word_count;i=i+1) begin
                    rc=$fscanf(batch_fd,"%h",input_word);
                    if(rc!=1) $fatal(1,"truncated batch program");
                    mem[256+i]=input_word;
                end
                if(memory_count<0 || memory_count>16) $fatal(1,"invalid sparse memory count");
                for(i=0;i<memory_count;i=i+1) begin
                    rc=$fscanf(batch_fd,"%h %h",data_address[i],data_value[i]);
                    if(rc!=2 || data_address[i][3:0]!=0) $fatal(1,"invalid sparse memory word");
                end
                $display("CASE %0d",case_id);
                repeat(5) @(negedge clk);
                rst=0;
                wait(case_done);
                @(negedge clk); rst=1;
                loaded=loaded+1;
                rc=$fscanf(batch_fd,"%d %h %h %d %d %d %d %d %h",case_id,test_pc,next_pc,measure_pass,word_count,memory_count,watch_extra,drain_instructions,follow_pc);
            end
            if(!$feof(batch_fd)) $fatal(1,"invalid batch record");
            $fclose(batch_fd);
            $display("BATCH_DONE cases=%0d",loaded);
        end else begin
            if (!$value$plusargs("PROGRAM=%s",program_path) ||
                !$value$plusargs("TEST_PC=%h",test_pc) ||
                !$value$plusargs("NEXT_PC=%h",next_pc))
                $fatal(1,"missing PROGRAM/TEST_PC/NEXT_PC");
            rc=$value$plusargs("CASE_ID=%d",case_id);
            rc=$value$plusargs("MEASURE_PASS=%d",measure_pass);
            rc=$value$plusargs("WATCH_EXTRA=%d",watch_extra);
            rc=$value$plusargs("DRAIN_INSTRUCTIONS=%d",drain_instructions);
            rc=$value$plusargs("FOLLOW_PC=%h",follow_pc);
            for(i=0;i<4096;i=i+1) mem[i]=0;
            $readmemh(program_path,mem);
            rc=$value$plusargs("DATA_COUNT=%d",memory_count);
            if(memory_count<0 || memory_count>16) $fatal(1,"invalid sparse memory count");
            if(memory_count>0) begin
                if(!$value$plusargs("DATA=%s",data_path)) $fatal(1,"missing sparse memory input");
                data_fd=$fopen(data_path,"r");
                if(data_fd==0) $fatal(1,"cannot open sparse memory input");
                for(i=0;i<memory_count;i=i+1) begin
                    rc=$fscanf(data_fd,"%h %h",data_address[i],data_value[i]);
                    if(rc!=2 || data_address[i][3:0]!=0) $fatal(1,"invalid sparse memory word");
                end
                $fclose(data_fd);
            end
            $display("CASE %0d",case_id);
            repeat(5) @(negedge clk);
            rst=0;
            wait(case_done);
        end
        @(negedge clk);
        $finish;
    end

    // Pause during CPU work, before its final writeback/next opcode read.
    // The cache/fabric remain clocked, as in the real system wrapper.
    always @(negedge clk) begin
        if(rst) begin
            cen=1; pause_done=0; pause_left=0;
        end else if(measuring && !pause_done && pause_clocks>0 && now-start_clock-1>=pause_after) begin
            cen=0;
            if($test$plusargs("RESPONSE_PAUSE")) $display("PAUSE_BEGIN %0d",now);
            pause_done=1;
            pause_left=pause_clocks;
            pause_pc=pc;
            pause_st=st;
            pause_uaddr=dut.u_cpu.u_core.u_ctrl.uaddr;
            pause_active=dut.u_cpu.u_core.active;
            pause_work={dut.u_cpu.u_core.a,dut.u_cpu.u_core.b,dut.u_cpu.u_core.md,
                        dut.u_cpu.u_core.tmp,dut.u_cpu.u_core.mul_count};
            for(integer q=0;q<4;q=q+1)
                pause_regs[q]=dut.u_cpu.u_core.u_regs.ram0[q];
            if(watch_extra!=0) begin
                for(integer q=0;q<4;q=q+1)pause_bregs[q]=dut.u_cpu.u_core.u_regs.ram0[16+q];
                pause_bregs[4]=dut.u_cpu.u_core.u_regs.ram0[15];
            end
        end else if(pause_left>0) begin
            pause_left=pause_left-1;
            if(pause_left==0) begin
                cen=1;
                if($test$plusargs("RESPONSE_PAUSE")) $display("PAUSE_END %0d",now);
            end
        end
    end

    // Raw target readiness/data: four clocks plus the requested delay.
    // The CPU fabric, not this target, supplies TI's bus duration/phase.
    localparam IDLE=0,BUSY=1,ACK=2;
    reg [1:0] bus_state=IDLE;
    integer age=0;
    reg [31:0] addr_q;
    reg [3:0] kind_q;
    reg [15:0] data_q,io_q;
    reg iaq_q;
    assign cyc_ack=bus_state==ACK;
    always @* begin
        if(kind_q==5) cyc_rdata=io_q;
        else if(addr_q==32'hffffffe0) cyc_rdata=16'h1000;
        else if(addr_q==32'hfffffff0) cyc_rdata=0;
        else if(addr_q<32'h10000) cyc_rdata=mem[addr_q[15:4]];
        else cyc_rdata=0;
        for(integer q=0;q<memory_count;q=q+1)
            if(addr_q==data_address[q]) cyc_rdata=data_value[q];
    end
    always @(posedge clk) begin
        if(rst) begin bus_state<=IDLE; age<=0; end
        else case(bus_state)
            IDLE: if(cyc_req) begin
                addr_q<=cyc_addr; kind_q<=cyc_kind; data_q<=cyc_wdata;
                io_q<=cyc_io_rdata; iaq_q<=cyc_iaq;
                age<=1; bus_state<=BUSY;
                if(measuring || $test$plusargs("TRACE"))
                    $display("TARGET_BEGIN %0d %0d %08h %04h %0d",now,
                         cyc_kind,cyc_addr,cyc_wdata,cyc_iaq);
            end
            BUSY: begin
                if(!cyc_req || cyc_addr!==addr_q || cyc_kind!==kind_q ||
                   cyc_wdata!==data_q || cyc_io_rdata!==io_q || cyc_iaq!==iaq_q)
                    $fatal(1,"bus payload changed before ACK clock=%0d",now);
                age<=age+1;
                if(age==delay_clocks-1) bus_state<=ACK;
            end
            ACK: begin
                if(!cyc_req) $fatal(1,"request disappeared before ACK");
                if(kind_q==1) begin
                    if(addr_q>=32'h10000) $fatal(1,"write outside test RAM");
                    mem[addr_q[15:4]]<=data_q;
                end
                if(kind_q==1) begin
                    for(integer q=0;q<memory_count;q=q+1)
                        if(addr_q==data_address[q]) data_value[q]<=data_q;
                end
                if(measuring || $test$plusargs("TRACE"))
                    $display("TARGET_END %0d %0d %08h %04h",now,kind_q,addr_q,cyc_rdata);
                bus_state<=IDLE;
            end
        endcase
    end

    // State boundaries are on the reset-relative eight-clock grid. Queued
    // cycles may absorb the bridge's registered handoff in their first
    // state; retain actual acceptance/target clocks separately so those
    // transport clocks cannot masquerade as pin-edge measurements.
    always @(posedge clk) if(!rst && (measuring || $test$plusargs("TRACE"))) begin
        if(dut.u_fabric.u_bus.g_timing.u_timer.start) begin
            $display("BUS_BEGIN %0d %0d %08h %04h %0d",now-now%8,
                dut.u_fabric.u_bus.cyc_kind,dut.u_fabric.u_bus.cyc_addr,
                dut.u_fabric.u_bus.cyc_wdata,dut.u_fabric.u_bus.cyc_iaq);
            $display("BUS_ACCEPT %0d",now);
        end
        if(dut.u_fabric.u_bus.complete)
            $display("BUS_END %0d %0d %08h %04h",now,
                dut.u_fabric.u_bus.cyc_kind,dut.u_fabric.u_bus.cyc_addr,
                dut.u_fabric.u_bus.cycle_rdata);
    end

    // Decode-to-decode includes extension fetches and the following opcode
    // fetch, as required by the cache-disabled timing convention (§13.1).
    // Warm pass excludes reset, cold fills, and setup from the observation.
    always @(posedge clk) begin
        if(rst) begin
            now<=0; seen<=0; start_clock<=0; measuring<=0;
            paused<=0; case_done<=0; response_request_seen<=0; draining<=0;drain_left<=0;
        end
        else begin
            now<=now+1;
            if(measuring && $test$plusargs("RESPONSE_PAUSE")) begin
                if(dut.u_cpu.field_req && !dut.u_cpu.u_core.mem_program && !response_request_seen) begin
                    $display("PAUSE_DATA_REQ %0d",now);response_request_seen<=1;
                end
                if(!cen && dut.u_cpu.field_req && dut.u_cpu.field_ack)
                    $display("PAUSE_DATA_ACK %0d",now);
            end
            if(measuring && !cen) begin
                paused<=paused+1;
                if(pc!==pause_pc || st!==pause_st || retire)
                    $fatal(1,"architectural state advanced while CEN paused");
                if(dut.u_cpu.u_core.u_ctrl.uaddr!==pause_uaddr ||
                   dut.u_cpu.u_core.active!==pause_active)
                    $fatal(1,"instruction sequencer advanced while CEN paused");
                if({dut.u_cpu.u_core.a,dut.u_cpu.u_core.b,dut.u_cpu.u_core.md,
                    dut.u_cpu.u_core.tmp,dut.u_cpu.u_core.mul_count}!==pause_work)
                    $fatal(1,"CPU working state advanced while CEN paused");
                for(integer q=0;q<4;q=q+1)
                    if(dut.u_cpu.u_core.u_regs.ram0[q]!==pause_regs[q])
                        $fatal(1,"A%0d changed while CEN paused",q);
                if(watch_extra!=0) begin
                    for(integer q=0;q<4;q=q+1)
                        if(dut.u_cpu.u_core.u_regs.ram0[16+q]!==pause_bregs[q])$fatal(1,"B%0d changed while CEN paused",q);
                    if(dut.u_cpu.u_core.u_regs.ram0[15]!==pause_bregs[4])$fatal(1,"SP changed while CEN paused");
                end
                if(cyc_req && !$test$plusargs("RESPONSE_PAUSE")) $fatal(1,"CPU launched a cycle during the early CEN pause");
            end
            if($test$plusargs("TRACE") && measuring)
                $display("CORE %0d ua=%03h active=%b step=%b req=%b ack=%b complete=%b cache=%0d word=%b/%b cycle=%b/%b",
                    now,dut.u_cpu.u_core.u_ctrl.uaddr,dut.u_cpu.u_core.active,
                    dut.u_cpu.u_core.step,dut.u_cpu.field_req,dut.u_cpu.field_ack,
                    dut.u_cpu.u_core.completed,dut.u_cpu.u_cache.state,
                    dut.word_req,dut.word_ack,cyc_req,cyc_ack);
            if(measuring && !dut.u_cpu.field_req &&
               (dut.u_cpu.field_word_req || dut.u_cpu.field_word_lock) && !dut.word_pending)
                $fatal(1,"pending field lost while physical work remains");
            if(fault) $fatal(1,"CPU fault pc=%h ir=%h",pc,ir);
            if(dut.u_cpu.u_core.step && dut.u_cpu.u_core.ld_ir) begin
                if(measuring || accepted_pc==test_pc || $test$plusargs("TRACE"))
                    $display("DECODE %0d %08h %04h",now,accepted_pc,accepted_ir);
                if(measuring && follow_pc!=0 && accepted_pc==follow_pc)
                    $display("FOLLOW clock=%0d st=%08h a0=%08h a1=%08h a2=%08h a3=%08h",now,st,
                        dut.u_cpu.u_core.u_regs.ram0[0],dut.u_cpu.u_core.u_regs.ram0[1],
                        dut.u_cpu.u_core.u_regs.ram0[2],dut.u_cpu.u_core.u_regs.ram0[3]);
                if(accepted_pc==test_pc) begin
                    seen<=seen+1;
                    if(seen==measure_pass) begin start_clock<=now; measuring<=1; end
                end
                if(measuring && !draining && accepted_pc==next_pc) begin
                    if(watch_extra!=0)
                        $display("RESULT case=%0d clocks=%0d start=%0d end=%0d paused=%0d st=%08h a0=%08h a1=%08h a2=%08h a3=%08h b0=%08h b1=%08h b2=%08h b3=%08h sp=%08h",
                            case_id,now-start_clock,start_clock,now,paused,st,
                            dut.u_cpu.u_core.u_regs.ram0[0],dut.u_cpu.u_core.u_regs.ram0[1],
                            dut.u_cpu.u_core.u_regs.ram0[2],dut.u_cpu.u_core.u_regs.ram0[3],
                            dut.u_cpu.u_core.u_regs.ram0[16],dut.u_cpu.u_core.u_regs.ram0[17],
                            dut.u_cpu.u_core.u_regs.ram0[18],dut.u_cpu.u_core.u_regs.ram0[19],
                            dut.u_cpu.u_core.u_regs.ram0[15]);
                    else
                    $display("RESULT case=%0d clocks=%0d start=%0d end=%0d paused=%0d st=%08h a0=%08h a1=%08h a2=%08h a3=%08h",
                        case_id,now-start_clock,start_clock,now,paused,st,
                        dut.u_cpu.u_core.u_regs.ram0[0],dut.u_cpu.u_core.u_regs.ram0[1],
                        dut.u_cpu.u_core.u_regs.ram0[2],dut.u_cpu.u_core.u_regs.ram0[3]);
                    if(drain_instructions>0) begin draining<=1;drain_left<=drain_instructions;end
                    else begin
                        if(drain_instructions!=0)
                            for(integer q=0;q<memory_count;q=q+1)
                                $display("MEMORY %08h %04h",data_address[q],data_value[q]);
                        case_done<=1;measuring<=0;
                    end
                end
            end
            if(draining && dut.u_cpu.u_core.step && dut.u_cpu.u_core.ld_ir) begin
                drain_left<=drain_left-1;
                if(drain_left==1) begin
                    for(integer q=0;q<memory_count;q=q+1)
                        $display("MEMORY %08h %04h",data_address[q],data_value[q]);
                    $display("DRAIN %0d",now);
                    case_done<=1;measuring<=0;draining<=0;
                end
            end
            if(now==200000) $fatal(1,"timing timeout pc=%h ir=%h seen=%0d",pc,ir,seen);
        end
    end
endmodule
