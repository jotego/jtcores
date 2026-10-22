`timescale 1ns/1ps
// Focused real-system regression: a resident reserved opcode follows a
// scheduled MOVK and must take TRAP30 without consuming it as a scalar slot.
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, cen=1, host_req=0, host_we=0, cyc_ack=0;
    reg lint1_n=1;
    reg [1:0] host_reg=0, host_be=0;
    reg [15:0] host_wdata=0, cyc_rdata=0;
    wire [15:0] host_rdata, cyc_wdata, cyc_io_rdata, ir, intenb, intpend;
    wire host_ack, host_busy, cyc_req, cyc_iaq, retire, fault, irq_pending, nmi_pending, halt;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr, pc, st;
    reg [15:0] mem[0:4095];
    integer i, clocks=0, vector_reads=0, nmi_vector_reads=0, irq_vector_reads=0;
    integer stack_writes=0, reserved_slot_takes=0;
    integer retires=0, transient_hlt_pulses=0;
    reg [1:0] bus_state=0;
    reg [3:0] kind_q;
    reg [31:0] addr_q;
    reg [15:0] data_q, io_q;
    reg iaq_q;
    reg [15:0] retired_ir=0;
    reg [31:0] retired_pc=0;
    reg vector_seen=0, return_seen=0;

    jttms10_system dut(
        .clk(clk),.rst(rst),.cen(cen),.vclk_cen(1'b0),
        .hcs_n(1'b1),.hsync_n(1'b1),.vsync_n(1'b1),
        .lint1_n(lint1_n),.lint2_n(1'b1),.hold_req(1'b0),.hold_ack(),
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

    initial begin
        for(i=0;i<4096;i=i+1) mem[i]=16'h0300;
`ifdef RESTART_IRQ_AT_SLOT
        mem['h100]=16'h09cf; mem['h101]=16'h0300; // MOVI IW 0x0300,SP
        mem['h102]=16'h09e0; mem['h103]=16'h0010; mem['h104]=16'h0020; // MOVI IL IE|ST,A0
        mem['h105]=16'h01a0;                     // PUTST A0 enables IRQ
        mem['h106]=16'h1820;                     // scheduled MOVK 1,A0
        mem['h107]=16'h0200;                     // reserved -> TRAP30
        mem['h108]=16'h1821;                     // MOVK 1,A1 after RETI
        mem['h110]=16'h0940;                     // RETI at IRQ and trap handlers
`else
        mem['h100]=16'h09cf; mem['h101]=16'h0300; // MOVI IW 0x0300,SP
        mem['h102]=16'h1820;                     // scheduled MOVK 1,A0
        mem['h103]=16'h0200;                     // reserved -> TRAP30
        mem['h104]=16'h1821;                     // MOVK 1,A1 after RETI
        mem['h108]=16'h0940;                     // RETI at vector handler
`endif
        repeat(5) @(negedge clk);
        rst=0;
    end

    // Slow, held-request NARC model. Trap vector reads and stack traffic are
    // observed at the system boundary; no internal state is forced.
    always @(posedge clk) begin
        if(rst) begin
            bus_state<=0; cyc_ack<=0; cyc_rdata<=0; clocks<=0;
        end else begin
            clocks<=clocks+1;
            retired_ir<=ir; retired_pc<=pc;
            case(bus_state)
                0: if(cyc_req) begin
                    kind_q<=cyc_kind; addr_q<=cyc_addr; data_q<=cyc_wdata;
                    io_q<=cyc_io_rdata; iaq_q<=cyc_iaq; bus_state<=1;
                end
                1: begin
                    if(!cyc_req || cyc_kind!==kind_q || cyc_addr!==addr_q ||
                       cyc_wdata!==data_q || cyc_io_rdata!==io_q || cyc_iaq!==iaq_q)
                        $fatal(1,"NARC request changed before ACK");
                    cyc_ack<=1; bus_state<=2;
                    case(kind_q)
                        0: begin
                            if(addr_q==32'hffffffe0) cyc_rdata<=16'h1000;
                            else if(addr_q==32'hfffffff0) cyc_rdata<=16'h0000;
                            else if(addr_q==32'hfffffc20) begin
`ifdef RESTART_IRQ_AT_SLOT
                                cyc_rdata<=16'h1100;
`else
                                cyc_rdata<=16'h1080;
`endif
                                vector_reads<=vector_reads+1;
                            end else if(addr_q==32'hfffffc30) begin
                                cyc_rdata<=16'h0000; vector_reads<=vector_reads+1;
                            end else if(addr_q==32'hfffffee0) begin
                                cyc_rdata<=16'h1080; nmi_vector_reads<=nmi_vector_reads+1;
                            end else if(addr_q==32'hfffffef0) begin
                                cyc_rdata<=16'h0000; nmi_vector_reads<=nmi_vector_reads+1;
                            end else if(addr_q==32'hfffffec0) begin
                                cyc_rdata<=16'h1100; irq_vector_reads<=irq_vector_reads+1;
                            end else if(addr_q==32'hfffffed0) begin
                                cyc_rdata<=16'h0000; irq_vector_reads<=irq_vector_reads+1;
                            end else if(addr_q<32'h10000) cyc_rdata<=mem[addr_q[15:4]];
                            else $fatal(1,"unexpected read %08x",addr_q);
                        end
                        1: if(addr_q<32'h10000) begin
                            mem[addr_q[15:4]]<=data_q;
                            if(addr_q==32'h02c0 || addr_q==32'h02e0)
                                stack_writes<=stack_writes+1;
                        end else $fatal(1,"unexpected write %08x",addr_q);
                        5: cyc_rdata<=io_q;
                        2,3,4,6: ;
                        default: $fatal(1,"unexpected NARC kind %0d",kind_q);
                    endcase
                end
                2: if(!cyc_req) begin cyc_ack<=0; bus_state<=0; end
            endcase
`ifdef RESTART_IRQ_AT_SLOT
            if(pc==32'h1100 && !vector_seen) begin
`else
            if(pc==32'h1080 && !vector_seen) begin
`endif
                if(dut.u_cpu.u_core.u_regs.ram0[15]!==32'h02c0 || st!==32'h10)
                    $fatal(1,"TRAP30 entry mismatch PC=%08x SP=%08x ST=%08x",pc,
                           dut.u_cpu.u_core.u_regs.ram0[15],st);
                vector_seen<=1;
            end
`ifdef RESTART_IRQ_AT_SLOT
            if(vector_seen && pc==32'h1090 && !return_seen) begin
`else
            if(vector_seen && pc==32'h1040 && !return_seen) begin
`endif
`ifdef RESTART_IRQ_AT_SLOT
                if(dut.u_cpu.u_core.u_regs.ram0[15]!==32'h0300 || st!==32'h00200010)
`else
                if(dut.u_cpu.u_core.u_regs.ram0[15]!==32'h0300 || st!==32'h10)
`endif
                    $fatal(1,"RETI restore mismatch PC=%08x SP=%08x ST=%08x",pc,
                           dut.u_cpu.u_core.u_regs.ram0[15],st);
                return_seen<=1;
            end
            if(retire) retires<=retires+1;
            if(dut.u_cpu.u_core.u_ctrl.slot_take &&
               dut.u_cpu.u_core.slot_opcode==16'h0200) begin
                reserved_slot_takes<=reserved_slot_takes+1;
                $display("RESTART_RESERVED_SLOT cycle=%0d uaddr=%03x opcode=%04x hit=%b",
                         clocks,dut.u_cpu.u_core.u_ctrl.uaddr,
                         dut.u_cpu.u_core.slot_opcode,dut.u_cpu.u_cache.hit_word);
            end
            if(fault) $fatal(1,"reserved opcode reported fatal CPU fault");
        end
    end

    task tick; begin @(posedge clk); #1; end endtask
    task release_halt;
        integer n;
        begin
            @(negedge clk); host_req=1; host_we=1; host_reg=3;
            host_be=2'b10; host_wdata=0; n=0;
            while(!host_ack && n<40) begin tick(); n=n+1; end
            if(!host_ack) $fatal(1,"host HLT release timed out");
            @(negedge clk); host_req=0; host_we=0; tick();
        end
    endtask

    task host_ctl_write(input [15:0] value);
        integer n;
        begin
            @(negedge clk); host_req=1; host_we=1; host_reg=3;
            host_be=2'b10; host_wdata=value; n=0;
            while(!host_ack && n<40) begin tick(); n=n+1; end
            if(!host_ack) $fatal(1,"host HSTCTL write timed out value=%04x",value);
            @(negedge clk); host_req=0; host_we=0; tick();
        end
    endtask

    task host_port_write(input [1:0] regno, input [1:0] byte_en,
                         input [15:0] value);
        integer n;
        begin
            @(negedge clk); host_req=1; host_we=1; host_reg=regno;
            host_be=byte_en; host_wdata=value; n=0;
            while(!host_ack && n<40) begin tick(); n=n+1; end
            if(!host_ack) $fatal(1,"host port write timed out reg=%0d",regno);
            @(negedge clk); host_req=0; host_we=0; tick();
        end
    endtask

    task host_indirect_write(input [31:0] address, input [15:0] value);
        integer n;
        begin
            host_port_write(0,2'b11,address[15:0]);
            host_port_write(1,2'b11,address[31:16]);
            host_port_write(2,2'b10,value);
            n=0;
            while(host_busy && n<100) begin tick(); n=n+1; end
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

    task pulse_hlt_mid_instruction;
        begin
            wait(dut.u_cpu.u_core.slot_valid &&
                 dut.u_cpu.u_core.slot_opcode==16'h0200);
`ifdef RESTART_NMI_AT_SLOT
            host_ctl_write(16'h0100);
            if(!nmi_pending) $fatal(1,"host NMI request did not assert");
            guard=0;
            while(nmi_pending && guard<200) begin tick(); guard=guard+1; end
            if(nmi_pending) $fatal(1,"NMI request was not accepted/cleared");
`elsif RESTART_IRQ_AT_SLOT
            host_intin_set();
            if(!irq_pending) $fatal(1,"enabled INTIN IRQ did not assert");
            guard=0;
            while(!vector_seen && guard<500) begin tick(); guard=guard+1; end
            if(pc!=32'h1100 || !vector_seen)
                $fatal(1,"IRQ did not preempt slot at boundary pc=%08x",pc);
            host_indirect_write(32'hc0000110,16'h0000);
`elsif RESTART_FLUSH_SLOT
            host_ctl_write(16'h4000);
            if(dut.u_cpu.u_core.slot_valid ||
               dut.u_cpu.u_core.u_ctrl.slot_family_valid)
                $fatal(1,"CF did not invalidate resident slot/family");
            host_ctl_write(16'h0000);
`else
            host_ctl_write(16'h8000);
            if(!halt) $fatal(1,"HSTCTL HLT pulse did not assert");
`ifdef RESTART_HOLD_HLT
            guard=0;
            while(!dut.u_cpu.u_core.u_ctrl.halted && guard<80) begin
                tick(); guard=guard+1;
            end
            if(!dut.u_cpu.u_core.u_ctrl.halted ||
               dut.u_cpu.u_core.slot_valid ||
               dut.u_cpu.u_core.u_ctrl.slot_family_valid)
                $fatal(1,"held HLT did not cancel slot and stop at FETCH");
            repeat(8) begin
                tick();
                if(!dut.u_cpu.u_core.u_ctrl.halted ||
                   dut.u_cpu.u_core.u_ctrl.slot_take || retire)
                    $fatal(1,"held HLT advanced while boundary remained stopped");
            end
            host_ctl_write(16'h0000);
            if(halt) $fatal(1,"held HLT did not clear on release");
`else
            host_ctl_write(16'h0000);
            if(halt) $fatal(1,"transient HLT did not clear before terminal boundary");
            transient_hlt_pulses=transient_hlt_pulses+1;
`endif
`endif
        end
    endtask

    integer guard;
    initial begin
        wait(!rst); repeat(20) tick();
        if(!halt) $fatal(1,"host-present reset did not assert HLT");
`ifdef RESTART_IRQ_AT_SLOT
        host_indirect_write(32'hc0000110,16'h0200); // INTENB bit 9: INTIN
`endif
        release_halt();
        guard=0;
        fork
            pulse_hlt_mid_instruction();
            begin while(!return_seen && guard<6000) begin tick(); guard=guard+1; end end
        join
        if(!return_seen) $fatal(1,"TRAP30/RETI sequence timed out pc=%08x ir=%04x",pc,ir);
        guard=0;
        while(dut.u_cpu.u_core.u_regs.ram0[1]!==32'd1 && guard<300) begin
            tick(); guard=guard+1;
        end
`ifdef RESTART_HOLD_HLT
        if(!vector_seen || vector_reads!=2 || stack_writes!=2 || reserved_slot_takes!=0 ||
`elsif RESTART_NMI_AT_SLOT
        if(!vector_seen || vector_reads!=2 || nmi_vector_reads!=2 ||
           stack_writes!=4 || reserved_slot_takes!=0 ||
`elsif RESTART_IRQ_AT_SLOT
        if(!vector_seen || vector_reads!=2 || irq_vector_reads!=2 ||
           stack_writes!=4 || reserved_slot_takes!=0 ||
`elsif RESTART_FLUSH_SLOT
        if(!vector_seen || vector_reads!=2 || stack_writes!=2 || reserved_slot_takes!=0 ||
`else
        if(!vector_seen || vector_reads!=2 || stack_writes!=2 || reserved_slot_takes<1 ||
           transient_hlt_pulses!=1 ||
`endif
`ifdef RESTART_IRQ_AT_SLOT
           mem['h02c]!==16'h0010 || mem['h02e]!==16'h1080 ||
           dut.u_cpu.u_core.u_regs.ram0[0]!==32'd1 ||
`else
           mem['h02c]!==16'h0010 || mem['h02e]!==16'h1040 ||
           dut.u_cpu.u_core.u_regs.ram0[0]!==32'd1 ||
`endif
           dut.u_cpu.u_core.u_regs.ram0[1]!==32'd1)
            $fatal(1,"TRAP30 architectural check failed vector=%0d stack=%0d PC=%08x SP=%08x A0=%08x A1=%08x stackST=%04x stackPC=%04x",
                   vector_reads,stack_writes,pc,dut.u_cpu.u_core.u_regs.ram0[15],
                   dut.u_cpu.u_core.u_regs.ram0[0],dut.u_cpu.u_core.u_regs.ram0[1],
                   mem['h02c],mem['h02e]);
`ifdef RESTART_HOLD_HLT
        $display("RESTART_HOLD_HLT_PASS: slot canceled at boundary; fallback TRAP30 and RETI pass");
`elsif RESTART_NMI_AT_SLOT
        $display("RESTART_NMI_PASS: slot canceled by pending NMI; handler/RETI/TRAP30 pass");
`elsif RESTART_IRQ_AT_SLOT
        $display("RESTART_IRQ_PASS: enabled INTIN IRQ canceled slot; handler/RETI/TRAP30 pass");
`elsif RESTART_FLUSH_SLOT
        $display("RESTART_CF_PASS: invalidated slot refetched; TRAP30 and RETI pass");
`else
        $display("RESTART_TRAP30_PASS: reserved slot accepted, TRAP30 vector/stack, and RETI restore");
`endif
        $finish;
    end
    initial begin repeat(8000) @(posedge clk); $fatal(1,"timeout clocks=%0d",clocks); end
endmodule
