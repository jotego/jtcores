`timescale 1ns/1ps
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, cen=1, host_req=0, host_we=0, cyc_ack=0;
    reg lint1_n=1, lint2_n=1;
    reg [1:0] host_reg=0, host_be=0;
    reg [15:0] host_wdata=0, cyc_rdata=0;
    wire [15:0] host_rdata, cyc_wdata, cyc_io_rdata, ir, intenb, intpend;
    wire obs_decode, obs_rf_we, obs_hw_complete;
    wire [31:0] obs_decode_pc, obs_rf_data;
    wire [15:0] obs_decode_ir;
    wire [5:0] obs_rf_addr;
    wire obs_field_pending_fault, obs_word_req, obs_word_pending;
    wire host_ack, host_busy, cyc_req, cyc_iaq, retire, fault, irq_pending, nmi_pending, halt;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr, pc, st;
    reg [15:0] mem[0:4095];
    reg [1:0] bus_state=0;
    reg [7:0] bus_age=0;
    reg [3:0] kind_q=0;
    reg [31:0] addr_q=0;
    reg [15:0] data_q=0, io_q=0;
    reg iaq_q=0;
    integer clocks=0, target_reads=0, target_writes=0, stack_writes=0;
    integer nmi_reads=0, irq_reads=0, reset_reads=0;
    integer old_owner_captures=0, old_owner_acks=0, new_req_while_paused=0;
    integer old_fill_next=0, old_fill_ack_next=0;
    integer fresh_opcode_requests=0, fresh_opcode_acks=0, fresh_opcode_decodes=0;
    integer fresh_a1_writes=0, signature_retires=0, halt_grace=0;
    integer cancel_event_old_acks=0;
    integer guard=0, irq_guard=0;
    reg drain_seen=0, accepted_seen=0, owner_epoch=0, old_released=0, vector_seen=0, return_seen=0;
    reg nop_ni_seen=0;
    reg control_event_seen=0, halted_event_seen=0, signature_armed=0, signature_decode_seen=0;
    reg [15:0] retired_ir_q=0;
    reg [31:0] retired_pc_q=0;
    reg paused_active_busop=0;
    reg paused_stack_active_drain=0;
    reg focus_bus_started_negative=0;
    reg [31:0] old_addr=0, old_st=0, return_pc=0;
    string mode;
    localparam integer TARGET_WAIT=96;

    jttms10_system dut(
        .obs_decode(obs_decode),.obs_rf_we(obs_rf_we),.obs_hw_complete(obs_hw_complete),
        .obs_decode_pc(obs_decode_pc),.obs_decode_ir(obs_decode_ir),
        .obs_rf_data(obs_rf_data),.obs_rf_addr(obs_rf_addr),
        .obs_field_pending_fault(obs_field_pending_fault),
        .obs_word_req(obs_word_req),.obs_word_pending(obs_word_pending),
        .clk(clk),.rst(rst),.cen(cen),.vclk_cen(1'b0),
        .hcs_n(1'b1),.hsync_n(1'b1),.vsync_n(1'b1),
        .lint1_n(lint1_n),.lint2_n(lint2_n),.hold_req(1'b0),.hold_ack(),
        .emu_run(1'b1),.emu_ack(),.host_req(host_req),.host_we(host_we),
        .host_reg(host_reg),.host_be(host_be),.host_wdata(host_wdata),
        .host_rdata(host_rdata),.host_ack(host_ack),.host_busy(host_busy),
        .hint_n(),.hs(),.vs(),.hblank(),.vblank(),.blank(),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),.cyc_iaq(cyc_iaq),
        .cyc_srfaddr(),.cyc_dpytap(),.cyc_org(),.cyc_dram_row(),
        .cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack),.pc(pc),.st(st),.ir(ir),
        .retire(retire),.fault(fault),.intenb(intenb),.intpend(intpend),
        .irq_pending(irq_pending),.nmi_pending(nmi_pending),.halt(halt)
    );

    task tick; begin @(posedge clk); #1; end endtask
    task host_word(input [15:0] value, input [1:0] byte_en);
        integer n;
        begin
            @(negedge clk); host_req=1; host_we=1; host_reg=3; host_be=byte_en; host_wdata=value; n=0;
            while(!host_ack && n<1000) begin tick(); n=n+1; end
            if(!host_ack) $fatal(1,"host register write timeout value=%04x",value);
            @(negedge clk); host_req=0; host_we=0; tick();
        end
    endtask
    task host_port(input [1:0] regno, input [1:0] byte_en, input [15:0] value);
        integer n;
        begin
            @(negedge clk); host_req=1; host_we=1; host_reg=regno; host_be=byte_en; host_wdata=value; n=0;
            while(!host_ack && n<1000) begin tick(); n=n+1; end
            if(!host_ack) $fatal(1,"host port write timeout reg=%0d",regno);
            @(negedge clk); host_req=0; host_we=0; tick();
        end
    endtask
    task host_indirect(input [31:0] address, input [15:0] value);
        integer n;
        begin
            host_port(0,2'b11,address[15:0]); host_port(1,2'b11,address[31:16]);
            host_port(2,2'b11,value); n=0;
            while(host_busy && n<2000) begin tick(); n=n+1; end
            if(host_busy) $fatal(1,"host indirect write timeout @%08x",address);
        end
    endtask
    task host_intin_set;
        integer n;
        begin
            @(negedge clk); host_req=1; host_we=1; host_reg=3;
            host_be=2'b01; host_wdata=16'h0008; n=0;
            while(!host_ack && n<40) begin tick(); n=n+1; end
            if(!host_ack) $fatal(1,"host INTIN set timed out");
            @(negedge clk); host_req=0; host_we=0; tick();
        end
    endtask
    task release_halt;
        begin host_word(16'h0000,2'b10); if(halt) $fatal(1,"reset HLT did not release"); end
    endtask

    task run_owner_control_cancel;
        integer n;
        begin
            // The raw request is already live and the NARC model holds its
            // response for TARGET_WAIT clocks in these directed modes.
            n=0;
            while((!cyc_req || cyc_addr!=old_addr) && n<80) begin tick(); n=n+1; end
            if(n>=80) $fatal(1,"no physical owner target launch at %08x",old_addr);
            $display("CONTROL_CANCEL_TARGET mode=%s clock=%0d addr=%08x state=%0d",mode,clocks,cyc_addr,
                     dut.u_cpu.u_core.early_fetch_state);
            case(mode)
                "HLT": begin
                    n=0;
                    while((!halted_event_seen || !drain_seen) && n<80) begin tick(); n=n+1; end
                    if(n>=80 || !halt || old_owner_acks!=0)
                        $fatal(1,"HLT was not accepted while owner WAIT before ACK state=%0d halt=%b drain=%b oldacks=%0d",
                               dut.u_cpu.u_core.early_fetch_state,halt,drain_seen,old_owner_acks);
                end
                "CF": begin
                    host_word(16'h4000,2'b10); // HSTCTLH.CF, upper byte only
                    n=0;
                    while((!control_event_seen || !drain_seen) && n<250) begin tick(); n=n+1; end
                    if(n>=250 || !dut.hstctlh[14] || !drain_seen || old_owner_acks!=0)
                        $fatal(1,"CF did not cancel WAIT owner before ACK cf=%b state=%0d oldacks=%0d",
                               dut.hstctlh[14],dut.u_cpu.u_core.early_fetch_state,old_owner_acks);
                end
                "CD": begin
                    // HSTADR was programmed before releasing reset HLT. Only
                    // the data port is written while the physical owner is live.
                    host_port(2,2'b11,16'h8000);
                    n=0;
                    while(host_busy && n<2000) begin tick(); n=n+1; end
                    if(host_busy) $fatal(1,"CONTROL data write did not complete");
                    $display("CD_WRITE_DONE clock=%0d control=%04x hstadr=%08x hstdata=%04x",
                             clocks,dut.control,dut.u_fabric.u_io.u_host.hstadr,
                             dut.u_fabric.u_io.u_host.hstdata);
                    n=0;
                    while((!control_event_seen || !drain_seen) && n<250) begin tick(); n=n+1; end
                    if(n>=250 || !dut.u_cpu.u_core.control[15] || !drain_seen || cancel_event_old_acks>=4)
                        $fatal(1,"CD did not cancel WAIT owner before ACK cd=%b state=%0d oldacks=%0d",
                               dut.u_cpu.u_core.control[15],dut.u_cpu.u_core.early_fetch_state,cancel_event_old_acks);
                end
                default: $fatal(1,"bad owner-control mode %s",mode);
            endcase
            if(dut.u_cpu.u_core.completed)
                $fatal(1,"canceled early response completed before drain mode=%s",mode);
            if((mode=="HLT" && !halted_event_seen) ||
               (mode!="HLT" && !control_event_seen))
                $fatal(1,"no sampled cancellation event mode=%s",mode);

            // The four-word cache fill is allowed to finish. Its first word
            // was independently checked as the fixture's NOP at launch.
            n=0;
            while(old_owner_acks<4 && n<700) begin tick(); n=n+1; end
            if(n>=700 || old_owner_captures!=4 || old_owner_acks!=4 || fresh_opcode_acks!=0)
                $fatal(1,"old owner did not drain exactly once mode=%s captures=%0d acks=%0d freshacks=%0d",
                       mode,old_owner_captures,old_owner_acks,fresh_opcode_acks);
            // Pause the CPU after the fourth real target ACK so the old
            // response can drain through ACK-low without launching a fresh
            // instruction request before the backing word is changed.
            @(negedge clk); cen=0;
            n=0;
            while((dut.u_cpu.u_core.early_fetch_state!=0 || dut.u_cpu.u_core.mem_req ||
                   dut.u_cpu.u_core.early_fetch_request || obs_word_pending || cyc_ack || cyc_req) && n<200) begin
                tick(); n=n+1;
            end
            if(n>=200) $fatal(1,"old target did not reach ACK-low/release mode=%s state=%0d req=%b cyc=%b",
                              mode,dut.u_cpu.u_core.early_fetch_state,dut.u_cpu.u_core.mem_req,cyc_req);
            old_released=1;
            if(dut.u_cpu.u_core.completed)
                $fatal(1,"canceled ACK incorrectly set completed mode=%s",mode);

            if(mode=="HLT") begin
                if(pc!==return_pc || stack_writes!=0 || irq_reads!=0 || nmi_reads!=0)
                    $fatal(1,"held HLT changed architectural state or entered vector pc=%08x expected=%08x",
                           pc,return_pc);
                repeat(8) begin
                    tick();
                    if(pc!==return_pc || retire || cyc_req)
                        $fatal(1,"held HLT advanced or issued bus traffic pc=%08x retire=%b req=%b",pc,retire,cyc_req);
                end
                @(negedge clk); cen=1;
                signature_armed=1;
                host_word(16'h0000,2'b10);
                n=0;
                while(signature_retires==0 && n<300) begin tick(); n=n+1; end
                if(n>=300 || signature_retires!=1 || fresh_opcode_decodes!=1 || fault)
                    $fatal(1,"released HLT did not decode/retire one programmed NOP pc=%08x decodes=%0d retires=%0d",
                           pc,fresh_opcode_decodes,signature_retires);
            end else begin
                // The old response carried the fixture's programmed opcode,
                // but cancellation must discard it. CF invalidates that fill;
                // CD bypasses it. The following MOVK signature proves a
                // fresh architectural consumption.
                mem[old_addr[15:4]]=16'h1821; // MOVK 1,A1; change only after old ACK-low
                if(mode=="CF") host_word(16'h0000,2'b10);
                $display("POST_CANCEL_RESUME clock=%0d mode=%s pc=%08x old_addr=%08x old_word=%04x cf=%b cd=%b",
                         clocks,mode,pc,old_addr,mem[old_addr[15:4]],dut.hstctlh[14],dut.u_cpu.u_core.control[15]);
                repeat(4) begin
                    tick();
                    if(cyc_req || dut.u_cpu.u_core.mem_req || obs_word_pending)
                        $fatal(1,"fresh request began before CEN resumed mode=%s",mode);
                end
                signature_armed=1;
                @(negedge clk); cen=1;
                n=0;
                while((fresh_opcode_requests==0 || !cyc_req || cyc_addr!=old_addr) && n<500) begin tick(); n=n+1; end
                if(n>=500 || fresh_opcode_requests!=1)
                    $fatal(1,"post-cancel fresh opcode request missing/duplicated mode=%s count=%0d addr=%08x",
                           mode,fresh_opcode_requests,cyc_addr);
                n=0;
                while(signature_retires==0 && n<500) begin tick(); n=n+1; end
                if(n>=500 || signature_retires!=1 || fresh_opcode_decodes!=1 ||
                   fresh_opcode_acks!=1 || fresh_a1_writes!=1 ||
                   dut.u_cpu.u_core.u_regs.ram0[1]!==32'h00000001 || fault)
                    $fatal(1,"fresh opcode signature mismatch mode=%s pc=%08x decodes=%0d retire=%0d reads=%0d acks=%0d A1writes=%0d A1=%08x",
                           mode,pc,fresh_opcode_decodes,signature_retires,fresh_opcode_requests,fresh_opcode_acks,
                           fresh_a1_writes,dut.u_cpu.u_core.u_regs.ram0[1]);
            end
            $display("OWNER_CONTROL_CANCEL_PASS mode=%s oldcaptures=%0d oldacks=%0d freshreq=%0d freshack=%0d sigretire=%0d pc=%08x A1=%08x",
                     mode,old_owner_captures,old_owner_acks,fresh_opcode_requests,fresh_opcode_acks,
                     signature_retires,pc,dut.u_cpu.u_core.u_regs.ram0[1]);
            $finish;
        end
    endtask

    initial begin
        if(!$value$plusargs("MODE=%s",mode)) mode="NMI";
        focus_bus_started_negative=$test$plusargs("FOCUS_BUS_STARTED_ONLY");
        for(integer i=0;i<4096;i=i+1) mem[i]=16'h0300;
        // Match the restart fixture's architectural setup, then let the
        // resident NOP stream reach an early miss. The test records the
        // actual early address rather than assuming a particular padding PC.
        mem['h100]=16'h09cf; mem['h101]=16'h0300; // MOVI IW 0x0300,SP
        mem['h102]=16'h09e0; mem['h103]=16'h0010; mem['h104]=16'h0020; // IE|ST,A0
        mem['h105]=16'h01a0;                     // PUTST A0
        mem['h140]=16'h0940;                     // RETI handler
        repeat(5) @(negedge clk); rst=0;
        wait(!rst); repeat(12) tick();
        if(!halt) $fatal(1,"host-present reset did not assert HLT");
        if(mode=="CD") begin
            // Preload the indirect address while reset HLT still blocks
            // instruction fetch; the test writes only HSTDATA during WAIT.
            // The zero write completes the indirect prefetch transaction.
            host_indirect(32'hc00000b0,16'h0000);
        end
        release_halt();
        if(mode=="IRQ") host_indirect(32'hc0000110,16'h0002);

        // Assert the event at the real early owner launch, before the field
        // adapter's raw target request; this leaves the NOP terminal boundary
        // available for architectural acceptance while the old read is live.
        wait(dut.u_cpu.u_core.early_fetch_start);
        $display("EARLY_START_PRE clock=%0d pc=%08x uaddr=%03x step=%b state=%0d start=%b",clocks,pc,
                 dut.u_cpu.u_core.u_ctrl.uaddr,dut.u_cpu.u_core.step,dut.u_cpu.u_core.early_fetch_state,
                 dut.u_cpu.u_core.early_fetch_start);
        if(mode=="HLT") begin
            // Present the real HSTCTLH write at the launch edge. The bit is
            // then pending for the immediately following FETCH boundary.
            @(negedge clk); host_req=1; host_we=1; host_reg=3; host_be=2'b10; host_wdata=16'h8000;
            tick();
            if(!host_ack) $fatal(1,"early-edge HLT host write was not accepted");
        end else tick();
        if(!dut.u_cpu.u_core.early_fetch_request || dut.u_cpu.u_core.early_fetch_state!=1 ||
           dut.u_cpu.u_core.early_fetch_addr!==pc || dut.u_cpu.u_core.mem_addr!==pc)
            $fatal(1,"early owner did not start on the expected PC mem=%08x pc=%08x",dut.u_cpu.u_core.mem_addr,pc);
        old_addr=dut.u_cpu.u_core.early_fetch_addr;
        return_pc=old_addr; old_st=st;
        owner_epoch=1;
        if(mode=="HLT") begin @(negedge clk); host_req=0; host_we=0; end
        if(mem[old_addr[15:4]]!==16'h0300)
            $fatal(1,"captured opcode differs from independent fixture mode=%s pc=%08x word=%04x",
                   mode,old_addr,mem[old_addr[15:4]]);
        $display("OWNER_LAUNCH clock=%0d pc=%08x st=%08x uaddr=%03x step=%b state=%0d memreq=%b addr=%08x target_req=%b cen=%b",clocks,pc,st,
                 dut.u_cpu.u_core.u_ctrl.uaddr,dut.u_cpu.u_core.step,
                 dut.u_cpu.u_core.early_fetch_state,dut.u_cpu.u_core.mem_req,dut.u_cpu.u_core.mem_addr,cyc_req,cen);
        if(mode=="HLT" || mode=="CF" || mode=="CD") begin
            run_owner_control_cancel();
        end
        if(mode=="IRQ") begin
            @(negedge clk); lint1_n=0; cen=0;
            irq_guard=0;
            while(!irq_pending && irq_guard<40) begin tick(); irq_guard=irq_guard+1; end
            if(!irq_pending) $fatal(1,"enabled external IRQ did not assert intenb=%04x intpend=%04x",intenb,intpend);
            @(negedge clk); cen=1;
        end else begin
            host_word(16'h0100,2'b10);
            if(!nmi_pending) $fatal(1,"host NMI request did not assert");
        end
        guard=0;
        while(!drain_seen && guard<300) begin tick(); guard=guard+1; end
        if(!drain_seen)
            $fatal(1,"accepted interrupt did not cancel into DRAIN mode=%s state=%0d pc=%08x ir=%04x st=%08x nmi=%b irq=%b take=%b step=%b ni=%b ack=%b uaddr=%03x icen=%b exec=%b dispatch=%b slot=%b fetch=%b ready=%b grid=%b",mode,dut.u_cpu.u_core.early_fetch_state,pc,ir,st,nmi_pending,irq_pending,dut.u_cpu.u_core.hw_take,dut.u_cpu.u_core.step,dut.u_cpu.u_core.ni,dut.u_cpu.u_core.mem_ack,dut.u_cpu.u_core.u_ctrl.uaddr,dut.u_cpu.u_core.u_ctrl.cen,dut.u_cpu.u_core.u_ctrl.execute,dut.u_cpu.u_core.u_ctrl.slot_dispatch,dut.u_cpu.u_core.slot_valid,dut.u_cpu.u_core.fetch,dut.u_cpu.u_core.ready,dut.u_cpu.grid_ready);
        accepted_seen=1;
        if(!focus_bus_started_negative && dut.u_cpu.u_core.completed)
            $fatal(1,"early owner completed before canceled request drained");
        if(mode=="IRQ") lint1_n=1;
        // Let the interrupt entry reach its active stack-write phase while
        // the old early owner is still draining. Lower top-level CEN before
        // that active phase can sample a new request.
        guard=0;
        while(!(dut.u_cpu.u_core.early_fetch_state==3 &&
                dut.u_cpu.u_core.active && dut.u_cpu.u_core.bus_op &&
                (dut.u_cpu.u_core.stack_sel!=0 || dut.u_cpu.u_core.vector)) && guard<80) begin
            tick(); guard=guard+1;
        end
        if(guard>=80 || dut.u_cpu.u_core.mem_ack)
            $fatal(1,"did not reach interrupt stack/vector active while old ACK pending state=%0d uaddr=%03x active=%b busop=%b stack=%b vector=%b ack=%b",
                   dut.u_cpu.u_core.early_fetch_state,dut.u_cpu.u_core.u_ctrl.uaddr,
                   dut.u_cpu.u_core.active,dut.u_cpu.u_core.bus_op,dut.u_cpu.u_core.stack_sel,
                   dut.u_cpu.u_core.vector,dut.u_cpu.u_core.mem_ack);
        @(negedge clk); cen=0;
        $display("OWNER_DRAIN_BEGIN clock=%0d mode=%s state=%0d req=%b addr=%08x uaddr=%03x icen=%b active=%b busop=%b",clocks,mode,
                 dut.u_cpu.u_core.early_fetch_state,dut.u_cpu.u_core.mem_req,dut.u_cpu.u_core.mem_addr,
                 dut.u_cpu.u_core.u_ctrl.uaddr,dut.u_cpu.u_core.u_ctrl.cen,dut.u_cpu.u_core.active,dut.u_cpu.u_core.bus_op);

        guard=0;
        while(!(dut.u_cpu.u_core.early_fetch_state==0 && !dut.u_cpu.u_core.mem_req &&
                !obs_word_pending && !cyc_req) && guard<1000) begin tick(); guard=guard+1; end
        if(guard>=1000) $fatal(1,"old early owner failed to drain state=%0d req=%b word_pending=%b cyc_req=%b",
                               dut.u_cpu.u_core.early_fetch_state,dut.u_cpu.u_core.mem_req,obs_word_pending,cyc_req);
        old_released=1;
        if(!focus_bus_started_negative && dut.u_cpu.u_core.completed)
            $fatal(1,"canceled ACK incorrectly set completed");
        repeat(12) begin
            tick();
            if(cyc_req || dut.u_cpu.u_core.mem_req || obs_word_pending)
                $fatal(1,"new vector/stack request issued while CEN low addr=%08x pc=%08x",cyc_addr,pc);
        end
        if(!paused_active_busop)
            $fatal(1,"CEN-low window did not overlap an active stack/vector micro-op; pause may only cover prime state");
        if(!paused_stack_active_drain)
            $fatal(1,"CEN-low DRAIN window did not overlap active stack/vector micro-op");
        $display("OWNER_DRAINED clock=%0d mode=%s old_captures=%0d old_acks=%0d state=%0d pc=%08x",clocks,mode,
                 old_owner_captures,old_owner_acks,dut.u_cpu.u_core.early_fetch_state,pc);
        @(negedge clk); cen=1;
        guard=0;
        while(pc!=32'h00001400 && guard<1200) begin tick(); guard=guard+1; end
        if(pc!=32'h00001400) $fatal(1,"interrupt vector/handler not reached pc=%08x mode=%s",pc,mode);
        vector_seen=1;
        if(dut.u_cpu.u_core.u_regs.ram0[15]!==32'h000002c0)
            $fatal(1,"interrupt stack pointer at handler %08x",dut.u_cpu.u_core.u_regs.ram0[15]);
        $display("VECTOR_ENTRY clock=%0d mode=%s pc=%08x sp=%08x st=%08x",clocks,mode,pc,
                 dut.u_cpu.u_core.u_regs.ram0[15],st);
        guard=0;
        while(!(pc==return_pc && dut.u_cpu.u_core.u_regs.ram0[15]==32'h00000300) && guard<2000) begin tick(); guard=guard+1; end
        if(guard>=2000 || st!==old_st)
            $fatal(1,"RETI did not restore interrupted PC/SP/ST pc=%08x sp=%08x st=%08x",pc,
                   dut.u_cpu.u_core.u_regs.ram0[15],st);
        return_seen=1;
        guard=0;
        while(pc!=return_pc+32'd16 && guard<100) begin tick(); guard=guard+1; end
        if(pc!=return_pc+32'd16) $fatal(1,"return NOP did not advance exactly once pc=%08x expected=%08x",pc,return_pc+32'd16);
        if(!drain_seen || !accepted_seen || !old_released || !paused_active_busop || !vector_seen || !return_seen || fault)
            $fatal(1,"lifecycle summary failed");
        if(old_owner_captures!=4 || old_owner_acks!=4) $fatal(1,"old four-word fill was not drained exactly once captures=%0d acks=%0d",old_owner_captures,old_owner_acks);
        if(stack_writes!=2) $fatal(1,"interrupt stack did not write exactly two words writes=%0d",stack_writes);
        if(reset_reads!=2) $fatal(1,"reset vector pair mismatch reads=%0d",reset_reads);
        if(mode=="IRQ" && (irq_reads!=2 || nmi_reads!=0))
            $fatal(1,"IRQ mode used wrong vector pair irq_reads=%0d nmi_reads=%0d",irq_reads,nmi_reads);
        if(mode!="IRQ" && (nmi_reads!=2 || irq_reads!=0))
            $fatal(1,"NMI mode used wrong vector pair nmi_reads=%0d irq_reads=%0d",nmi_reads,irq_reads);
        $display("OWNER_CANCEL_PASS mode=%s captures=%0d acks=%0d stack_writes=%0d vector_reads=%0d irq_reads=%0d nmi_reads=%0d pc=%08x sp=%08x st=%08x",
                 mode,old_owner_captures,old_owner_acks,stack_writes,reset_reads,irq_reads,nmi_reads,pc,
                 dut.u_cpu.u_core.u_regs.ram0[15],st);
        $finish;
    end

    always @(posedge clk) begin
        if(rst) begin bus_state<=0; cyc_ack<=0; cyc_rdata<=0; clocks<=0; end
        else begin
            clocks<=clocks+1;
            retired_pc_q<=pc; retired_ir_q<=ir;
            if(signature_armed && obs_decode && obs_decode_pc==old_addr) begin
                if((mode=="HLT" && obs_decode_ir!==16'h0300) ||
                   ((mode=="CF" || mode=="CD") && obs_decode_ir!==16'h1821))
                    $fatal(1,"post-cancel decode mismatch mode=%s pc=%08x ir=%04x",mode,obs_decode_pc,obs_decode_ir);
                fresh_opcode_decodes<=fresh_opcode_decodes+1;
                signature_decode_seen<=1;
                $display("POST_CANCEL_DECODE clock=%0d mode=%s pc=%08x ir=%04x",clocks,mode,obs_decode_pc,obs_decode_ir);
            end
            if(signature_armed && obs_rf_we && obs_rf_addr==6'd1) begin
                if(obs_rf_data!==32'h00000001)
                    $fatal(1,"post-cancel A1 write data mismatch %08x",obs_rf_data);
                fresh_a1_writes<=fresh_a1_writes+1;
            end
            if(signature_armed && signature_decode_seen && retire &&
               retired_pc_q==return_pc+32'd16 &&
               ((mode=="HLT" && retired_ir_q==16'h0300) ||
                ((mode=="CF" || mode=="CD") && retired_ir_q==16'h1821))) begin
                signature_retires<=signature_retires+1;
                $display("POST_CANCEL_RETIRE clock=%0d mode=%s sampled_pc=%08x ir=%04x current_pc=%08x",
                         clocks,mode,retired_pc_q,retired_ir_q,pc);
            end
            if(retire && (mode=="CF" || mode=="CD"))
                $display("RETIRE_SAMPLE clock=%0d pc=%08x ir=%04x current_pc=%08x current_ir=%04x",
                         clocks,retired_pc_q,retired_ir_q,pc,ir);
            if(mode=="HLT" && halted_event_seen && halt && retire && retired_pc_q==return_pc && halt_grace>=2)
                $fatal(1,"HLT retired interrupted NOP before release pc=%08x",retired_pc_q);
            if(mode=="HLT" && dut.u_cpu.u_core.u_ctrl.halt_accept &&
               dut.u_cpu.u_core.early_fetch_state==1 && !dut.u_cpu.u_core.mem_ack) begin
                halted_event_seen<=1;
                halt_grace<=0;
                cancel_event_old_acks<=old_owner_acks;
                $display("HLT_ACCEPT clock=%0d pc=%08x ir=%04x retire=%b priorpc=%08x state=%0d uaddr=%03x",
                         clocks,pc,ir,retire,retired_pc_q,dut.u_cpu.u_core.early_fetch_state,
                         dut.u_cpu.u_core.u_ctrl.uaddr);
            end else if(halted_event_seen && halt_grace<10) halt_grace<=halt_grace+1;
            if(mode=="HLT" && retire && retired_pc_q==return_pc)
                $display("HLT_RETIRE clock=%0d priorpc=%08x priorir=%04x accept=%b grace=%0d halt=%b",
                         clocks,retired_pc_q,retired_ir_q,halted_event_seen,halt_grace,halt);
            if(mode=="CF" && dut.hstctlh[14] && dut.u_cpu.u_core.early_fetch_cancel &&
               dut.u_cpu.u_core.early_fetch_state==1 && !dut.u_cpu.u_core.mem_ack) begin
                control_event_seen<=1;
                cancel_event_old_acks<=old_owner_acks;
            end
            if(mode=="CD" && dut.u_cpu.u_core.control[15] && dut.u_cpu.u_core.early_fetch_cancel &&
               dut.u_cpu.u_core.early_fetch_state==1 && !dut.u_cpu.u_core.mem_ack) begin
                control_event_seen<=1;
                cancel_event_old_acks<=old_owner_acks;
            end
            if(!nop_ni_seen && dut.u_cpu.u_core.u_ctrl.uaddr==10'h023) begin
                nop_ni_seen<=1;
                $display("NOP_NI clock=%0d pc=%08x ir=%04x state=%0d start=%b req=%b irq=%b nmi=%b",clocks,pc,ir,
                         dut.u_cpu.u_core.early_fetch_state,dut.u_cpu.u_core.early_fetch_start,
                         dut.u_cpu.u_core.mem_req,irq_pending,nmi_pending);
            end
            if(dut.u_cpu.u_core.early_fetch_state==3) drain_seen<=1;
            if(!cen && dut.u_cpu.u_core.active && dut.u_cpu.u_core.bus_op)
                paused_active_busop<=1;
            if(!cen && dut.u_cpu.u_core.early_fetch_state==3 &&
               dut.u_cpu.u_core.active && dut.u_cpu.u_core.bus_op &&
               (dut.u_cpu.u_core.stack_sel!=0 || dut.u_cpu.u_core.vector))
                paused_stack_active_drain<=1;
            if(!focus_bus_started_negative && dut.u_cpu.u_core.early_fetch_state==3 && dut.u_cpu.u_core.completed)
                $fatal(1,"completed asserted while draining canceled request");
            if(old_released && !cen && (cyc_req || dut.u_cpu.u_core.mem_req || obs_word_pending)) begin
                new_req_while_paused<=new_req_while_paused+1;
                $fatal(1,"new normal request after old owner released while CEN low");
            end
            if(!cen && old_owner_acks==4 && !cyc_ack &&
               dut.u_cpu.u_core.early_fetch_state==0 && !dut.u_cpu.u_core.early_fetch_request &&
               (cyc_req || dut.u_cpu.u_core.mem_req || obs_word_pending)) begin
                new_req_while_paused<=new_req_while_paused+1;
                $fatal(1,"normal stack/vector request after early owner ACK-low while CEN low addr=%08x pc=%08x",
                       dut.u_cpu.u_core.mem_addr,pc);
            end
            if(!old_released && dut.u_cpu.u_core.early_fetch_active && dut.u_cpu.u_core.mem_req &&
               dut.u_cpu.u_core.mem_addr!==old_addr && drain_seen)
                $fatal(1,"early request tuple changed while draining old_addr=%08x now=%08x",old_addr,dut.u_cpu.u_core.mem_addr);
            case(bus_state)
                0: if(cyc_req) begin
                    kind_q<=cyc_kind; addr_q<=cyc_addr; data_q<=cyc_wdata;
                    io_q<=cyc_io_rdata; iaq_q<=cyc_iaq; bus_age<=0; bus_state<=1;
                    if(old_owner_acks>=3 && cyc_addr==old_addr)
                        fresh_opcode_requests<=fresh_opcode_requests+1;
                    if(owner_epoch && !old_released && cyc_addr>=old_addr && cyc_addr<old_addr+32'd64) begin
                        if(cyc_addr!=old_addr+old_fill_next*16)
                            $fatal(1,"old fill address order mismatch index=%0d got=%08x",old_fill_next,cyc_addr);
                        old_fill_next<=old_fill_next+1;
                        old_owner_captures<=old_owner_captures+1;
                    end
                    $display("NARC_REQ clock=%0d cen=%b kind=%0d addr=%08x iaq=%b wdata=%04x early_state=%0d memaddr=%08x memreq=%b early_req=%b active=%b busop=%b uaddr=%03x icen=%b",clocks,cen,cyc_kind,cyc_addr,cyc_iaq,cyc_wdata,dut.u_cpu.u_core.early_fetch_state,dut.u_cpu.u_core.mem_addr,dut.u_cpu.u_core.mem_req,dut.u_cpu.u_core.early_fetch_request,dut.u_cpu.u_core.active,dut.u_cpu.u_core.bus_op,dut.u_cpu.u_core.u_ctrl.uaddr,dut.u_cpu.u_core.u_ctrl.cen);
                end
                1: begin
                    if(!cyc_req || cyc_kind!==kind_q || cyc_addr!==addr_q || cyc_wdata!==data_q ||
                       cyc_io_rdata!==io_q || cyc_iaq!==iaq_q)
                        $fatal(1,"NARC tuple changed before ACK addr=%08x",addr_q);
                    if(bus_age>=((owner_epoch && kind_q==0 &&
                                  (drain_seen || mode=="IRQ" || mode=="HLT" || mode=="CF" || mode=="CD") &&
                                  addr_q>=old_addr && addr_q<old_addr+32'd64) ? TARGET_WAIT-1 : 0)) begin
                        if((mode=="CF" || mode=="CD") && owner_epoch &&
                           addr_q>=old_addr && addr_q<old_addr+32'd64 && kind_q==0)
                            $display("TARGET_SAMPLE clock=%0d mode=%s addr=%08x memword=%04x oldacks=%0d released=%b",
                                     clocks,mode,addr_q,mem[addr_q[15:4]],old_owner_acks,old_released);
                        cyc_ack<=1; bus_state<=2;
                        case(kind_q)
                            0: begin
                                if(addr_q==32'hffffffe0) begin cyc_rdata<=16'h1000; reset_reads<=reset_reads+1; end
                                else if(addr_q==32'hfffffff0) begin cyc_rdata<=0; reset_reads<=reset_reads+1; end
                                else if(addr_q==32'hfffffee0) begin cyc_rdata<=16'h1400; nmi_reads<=nmi_reads+1; end
                                else if(addr_q==32'hfffffef0) begin cyc_rdata<=0; nmi_reads<=nmi_reads+1; end
                                else if(addr_q==32'hffffffc0) begin cyc_rdata<=16'h1400; irq_reads<=irq_reads+1; end
                                else if(addr_q==32'hffffffd0) begin cyc_rdata<=0; irq_reads<=irq_reads+1; end
                                else if(addr_q<32'h00010000) begin
                                    cyc_rdata<=mem[addr_q[15:4]]; target_reads<=target_reads+1;
                                    if(old_owner_acks>=3 && addr_q==old_addr) begin
                                        fresh_opcode_acks<=fresh_opcode_acks+1;
                                        if(mem[addr_q[15:4]]!==((mode=="HLT") ? 16'h0300 : 16'h1821))
                                            $fatal(1,"fresh opcode backing word mismatch mode=%s addr=%08x word=%04x",
                                                   mode,addr_q,mem[addr_q[15:4]]);
                                    end
                                    if(owner_epoch && !old_released && addr_q>=old_addr && addr_q<old_addr+32'd64) begin
                                        if(addr_q!=old_addr+old_fill_ack_next*16)
                                            $fatal(1,"old fill ACK order mismatch index=%0d got=%08x",old_fill_ack_next,addr_q);
                                        old_fill_ack_next<=old_fill_ack_next+1;
                                        old_owner_acks<=old_owner_acks+1;
                                    end
                                end else $fatal(1,"unexpected read %08x",addr_q);
                            end
                            1: if(addr_q<32'h00010000) begin
                                mem[addr_q[15:4]]<=data_q; target_writes<=target_writes+1;
                                if(addr_q==32'h02c0 || addr_q==32'h02e0) stack_writes<=stack_writes+1;
                            end else $fatal(1,"unexpected write %08x",addr_q);
                            5: cyc_rdata<=io_q;
                            2,3,4,6: ;
                            default: $fatal(1,"unexpected NARC kind %0d",kind_q);
                        endcase
                        $display("NARC_ACK clock=%0d cen=%b kind=%0d addr=%08x data=%04x",clocks,cen,kind_q,addr_q,cyc_rdata);
                    end else bus_age<=bus_age+1;
                end
                2: if(!cyc_req) begin cyc_ack<=0; bus_state<=0; end
                default: $fatal(1,"bad bus state");
            endcase
            if(pc==32'h00001400 && !vector_seen && accepted_seen) begin
                vector_seen<=1;
                $display("VECTOR_EDGE clock=%0d mode=%s pc=%08x sp=%08x st=%08x",clocks,mode,pc,
                         dut.u_cpu.u_core.u_regs.ram0[15],st);
            end
            if(pc==return_pc && vector_seen && !return_seen) begin
                return_seen<=1;
                if(dut.u_cpu.u_core.u_regs.ram0[15]!==32'h00000300 || st!==32'h00000810)
                    $fatal(1,"RETI restore mismatch pc=%08x sp=%08x st=%08x",pc,
                           dut.u_cpu.u_core.u_regs.ram0[15],st);
            end
            if(fault) $fatal(1,"CPU fault at clock=%0d pc=%08x ir=%04x",clocks,pc,ir);
        end
    end
    initial begin repeat(12000) @(posedge clk); $fatal(1,"timeout clock=%0d pc=%08x",clocks,pc); end
endmodule
