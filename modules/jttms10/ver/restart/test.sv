`timescale 1ns/1ps
// Independent #149 warm-cache scalar timing fixture. The program is fetched
// from the real system bus and executed once before its resident loop is timed.
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, cen=1, vclk_cen=0;
    reg host_req=0, host_we=0;
    reg [1:0] host_reg=0, host_be=0;
    reg [15:0] host_wdata=0;
    wire [15:0] host_rdata;
    wire host_ack, host_busy, cyc_req, cyc_iaq;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr, pc, st;
    wire [15:0] cyc_wdata, cyc_io_rdata, ir;
    reg [15:0] cyc_rdata=0;
    reg cyc_ack=0;
    wire retire, fault, irq_pending, nmi_pending, halt;
    wire [15:0] intenb, intpend;

    jttms10_system dut(
        .clk(clk),.rst(rst),.cen(cen),.vclk_cen(vclk_cen),
        .hcs_n(1'b1),.hsync_n(1'b1),.vsync_n(1'b1),
        .lint1_n(1'b1),.lint2_n(1'b1),.hold_req(1'b0),.hold_ack(),
        .emu_run(1'b1),.emu_ack(),.host_req(host_req),.host_we(host_we),
        .host_reg(host_reg),.host_be(host_be),.host_wdata(host_wdata),
        .host_rdata(host_rdata),.host_ack(host_ack),.host_busy(host_busy),
        .hint_n(),.hs(),.vs(),.hblank(),.vblank(),.blank(),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),
        .cyc_iaq(cyc_iaq),.cyc_srfaddr(),.cyc_dpytap(),.cyc_org(),
        .cyc_dram_row(),.cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack),
        .pc(pc),.st(st),.ir(ir),.retire(retire),.fault(fault),
        .intenb(intenb),.intpend(intpend),.irq_pending(irq_pending),
        .nmi_pending(nmi_pending),.halt(halt)
    );

    reg [15:0] mem [0:4095];
    integer i;
    initial begin
        for(i=0;i<4096;i=i+1) mem[i]=16'h0300; // NOP
        // The boot path is executed first and fills the real instruction cache.
        mem['h100]=16'h09c0; mem['h101]=16'h0001; // MOVI IW 1,A0
        mem['h102]=16'h09c1; mem['h103]=16'h0002; // MOVI IW 2,A1
        // Timed stream starts at 0x1040, spanning two four-word cache groups.
        mem['h104]=16'h1820; // MOVK 1,A0
        mem['h105]=16'h4000; // ADD A0,A0
        mem['h106]=16'h4c01; // MOVE A0,A1
        mem['h107]=16'h4e02; // MOVE A0,B2
        mem['h108]=16'h0300; // NOP
        mem['h109]=16'h1860; // MOVK 3,A0
        mem['h10a]=16'h4000; // ADD A0,A0
        mem['h10b]=16'h0300; // NOP
        mem['h10c]=16'hcff7; // JRUC -9, back to the stream start
        repeat(5) @(negedge clk);
        rst=0;
    end

    // NARC bus model. Address/data are held until physical ACK; every IAQ
    // event is counted separately from logical cache hits.
    localparam [1:0] IDLE=0, WAIT=1, ACK=2;
    reg [1:0] bus_state=IDLE;
    reg [3:0] kind_q;
    reg [31:0] addr_q;
    reg [15:0] data_q, io_q;
    reg iaq_q;
    integer wait_count=0;
    integer iaq_count=0, ext_count=0;
    integer ext_writes=0, rf_writes=0, rf_writes_in_window=0;
    integer clock_count=0;
    reg active_window=0;
    integer timed_retires=0, prev_retire_cycle=-1;
    integer measured_intervals=0;
    integer setup_seen=0, boot_retires=0;
    reg [15:0] retired_ir_q=0;
    reg [31:0] retired_pc_q=0;
    reg [15:0] measured_ir [0:31];
    integer measured_cycle [0:31];
    reg pause_active=0;
    reg [31:0] pause_pc=0, pause_st=0;
    reg [15:0] pause_ir=0;
    reg [11:0] pause_uaddr=0;
    integer pause_rf_writes=0, pause_iaqs=0, pause_ext=0;
    integer pause_cases=0;

    always @(posedge clk) begin
        if(rst) begin
            bus_state<=IDLE; cyc_ack<=0; cyc_rdata<=0;
            clock_count<=0; iaq_count<=0; ext_count<=0; ext_writes<=0;
            rf_writes<=0; rf_writes_in_window<=0;
        end else begin
            retired_ir_q<=ir;
            retired_pc_q<=pc;
            clock_count<=clock_count+1;
            if(pause_active) begin
                if(pc!==pause_pc || ir!==pause_ir || st!==pause_st ||
                   dut.u_cpu.u_core.u_ctrl.uaddr!==pause_uaddr ||
                   dut.u_cpu.u_core.u_regs.we || rf_writes!==pause_rf_writes ||
                   iaq_count!==pause_iaqs || ext_count!==pause_ext)
                    $fatal(1,"CEN pause advanced state pc=%08x/%08x ir=%04x/%04x st=%08x/%08x ua=%03x/%03x retire=%b we=%b rf=%0d/%0d iaq=%0d/%0d ext=%0d/%0d",
                           pc,pause_pc,ir,pause_ir,st,pause_st,
                           dut.u_cpu.u_core.u_ctrl.uaddr,pause_uaddr,retire,
                           dut.u_cpu.u_core.u_regs.we,rf_writes,pause_rf_writes,
                           iaq_count,pause_iaqs,ext_count,pause_ext);
            end
            if(retire && retired_pc_q>=32'h1000 && retired_pc_q<=32'h10d0)
                $display("RESTART_WARM cycle=%0d pc=%08x ir=%04x",clock_count,retired_pc_q,retired_ir_q);
            if(cyc_req && cyc_iaq) iaq_count<=iaq_count+1;
            if(cyc_req && (cyc_kind==0 || cyc_kind==1)) ext_count<=ext_count+1;
            if(dut.u_cpu.u_core.u_ctrl.ld_ir && pc>=32'h1040 && pc<32'h10c0)
                setup_seen<=setup_seen+1;
            if(retire && retired_pc_q>=32'h1000 && retired_pc_q<32'h1040)
                boot_retires<=boot_retires+1;
            if(retire && active_window && retired_ir_q==16'hcff7) begin
                // Redirects end the straight-line eight-state comparison.
                // Check stream timing independently on either side.
                prev_retire_cycle=-1;
            end
            if(retire && active_window && retired_ir_q!=16'hcff7) begin
                case(timed_retires % 8)
                    0: if(retired_ir_q!==16'h1820) $fatal(1,"stream word 0: expected MOVK, got %04x",retired_ir_q);
                    1: if(retired_ir_q!==16'h4000) $fatal(1,"stream word 1: expected ADD, got %04x",retired_ir_q);
                    2: if(retired_ir_q!==16'h4c01) $fatal(1,"stream word 2: expected MOVE, got %04x",retired_ir_q);
                    3: if(retired_ir_q!==16'h4e02) $fatal(1,"stream word 3: expected cross-file MOVE, got %04x",retired_ir_q);
                    4: if(retired_ir_q!==16'h0300) $fatal(1,"stream word 4: expected NOP, got %04x",retired_ir_q);
                    5: if(retired_ir_q!==16'h1860) $fatal(1,"stream word 5: expected MOVK, got %04x",retired_ir_q);
                    6: if(retired_ir_q!==16'h4000) $fatal(1,"stream word 6: expected ADD, got %04x",retired_ir_q);
                    7: if(retired_ir_q!==16'h0300) $fatal(1,"stream word 7: expected NOP, got %04x",retired_ir_q);
                endcase
                $display("RESTART_RETIRE cycle=%0d pc=%08x ir=%04x uaddr=%03x prime=%b execute=%b rs=%02x:%08x rd=%02x:%08x rf_we=%b iaq=%b cache_req=%b cache_ack=%b hit=%b",
                         clock_count,retired_pc_q,retired_ir_q,dut.u_cpu.u_core.u_ctrl.uaddr,
                         dut.u_cpu.u_core.u_ctrl.cen,dut.u_cpu.u_core.u_ctrl.execute,
                         dut.u_cpu.u_core.u_regs.rs,dut.u_cpu.u_core.u_regs.qs,
                         dut.u_cpu.u_core.u_regs.rd,dut.u_cpu.u_core.u_regs.qd,
                         dut.u_cpu.u_core.u_regs.we,cyc_iaq,dut.u_cpu.cache_req,
                         dut.u_cpu.cache_ack,dut.u_cpu.u_cache.hit_word);
                if(timed_retires<32) begin
                    measured_ir[timed_retires]=ir;
                    measured_cycle[timed_retires]=clock_count;
                end
                if(prev_retire_cycle>=0) begin
                    if(clock_count-prev_retire_cycle!=8)
                        $fatal(1,"RESTART_TIMING_FAIL: retire spacing %0d at pc=%08x ir=%04x (expected 8 INCLK)",
                               clock_count-prev_retire_cycle,retired_pc_q,retired_ir_q);
                    measured_intervals<=measured_intervals+1;
                end
                prev_retire_cycle=clock_count;
                timed_retires<=timed_retires+1;
            end
`ifdef RESTART_HAS_PEEK
            if(active_window && (dut.u_cpu.u_core.u_ctrl.ld_ir ||
                 dut.u_cpu.u_core.u_regs.we || cyc_req || dut.u_cpu.u_cache.c_ack ||
                 dut.u_cpu.u_cache.p_ack || dut.u_cpu.u_core.u_ctrl.slot_take))
                $display("RESTART_EVENT cycle=%0d uaddr=%03x prime=%b execute=%b ld_ir=%b ir=%04x pc=%08x rf_we=%b rf_wa=%02x:%08x cache_req=%b cache_ack=%b hit=%b peek=%b peek_ack=%b peek_hit=%b peek_data=%04x slot=%b:%04x lookup=%b dispatch=%b consume=%b fam=%b:%02x physical=%b/%b addr=%08x iaq=%b",
                         clock_count,dut.u_cpu.u_core.u_ctrl.uaddr,
                         dut.u_cpu.u_core.u_ctrl.cen,dut.u_cpu.u_core.u_ctrl.execute,
                         dut.u_cpu.u_core.u_ctrl.ld_ir,ir,pc,
                         dut.u_cpu.u_core.u_regs.we,dut.u_cpu.u_core.u_regs.wa,
                         dut.u_cpu.u_core.u_regs.wd,dut.u_cpu.cache_req,
                         dut.u_cpu.cache_ack,dut.u_cpu.u_cache.hit_word,
                         dut.u_cpu.cache_peek_req,dut.u_cpu.cache_peek_ack,
                         dut.u_cpu.cache_peek_hit,dut.u_cpu.cache_peek_data,
                         dut.u_cpu.u_core.slot_valid,dut.u_cpu.u_core.slot_opcode,
                         dut.u_cpu.u_core.u_ctrl.slot_lookup,
                         dut.u_cpu.u_core.u_ctrl.slot_dispatch,
                         dut.u_cpu.u_core.u_ctrl.slot_take,
                         dut.u_cpu.u_core.u_ctrl.slot_family_valid,
                         dut.u_cpu.u_core.u_ctrl.slot_family_q,
                         cyc_req,cyc_ack,cyc_addr,cyc_iaq);
`else
            if(active_window && (dut.u_cpu.u_core.u_ctrl.ld_ir ||
                 dut.u_cpu.u_core.u_regs.we || cyc_req || dut.u_cpu.u_cache.c_ack))
                $display("RESTART_EVENT cycle=%0d uaddr=%03x prime=%b execute=%b ld_ir=%b ir=%04x pc=%08x rf_we=%b rf_wa=%02x:%08x cache_req=%b cache_ack=%b hit=%b physical=%b/%b addr=%08x iaq=%b",
                         clock_count,dut.u_cpu.u_core.u_ctrl.uaddr,
                         dut.u_cpu.u_core.u_ctrl.cen,dut.u_cpu.u_core.u_ctrl.execute,
                         dut.u_cpu.u_core.u_ctrl.ld_ir,ir,pc,
                         dut.u_cpu.u_core.u_regs.we,dut.u_cpu.u_core.u_regs.wa,
                         dut.u_cpu.u_core.u_regs.wd,dut.u_cpu.cache_req,
                         dut.u_cpu.cache_ack,dut.u_cpu.u_cache.hit_word,
                         cyc_req,cyc_ack,cyc_addr,cyc_iaq);
`endif
            if(active_window && dut.u_cpu.u_core.u_regs.we)
                rf_writes_in_window<=rf_writes_in_window+1;
            if(dut.u_cpu.u_core.u_regs.we) rf_writes<=rf_writes+1;
            case(bus_state)
                IDLE: if(cyc_req) begin
                    kind_q<=cyc_kind; addr_q<=cyc_addr; data_q<=cyc_wdata;
                    io_q<=cyc_io_rdata; iaq_q<=cyc_iaq;
                    wait_count<=1; bus_state<=WAIT;
                end
                WAIT: begin
                    if(!cyc_req || cyc_kind!==kind_q || cyc_addr!==addr_q ||
                       cyc_wdata!==data_q || cyc_io_rdata!==io_q || cyc_iaq!==iaq_q)
                        $fatal(1,"NARC request payload changed before ACK");
                    if(wait_count!=0) wait_count<=wait_count-1;
                    else begin
                        cyc_ack<=1; bus_state<=ACK;
                        case(kind_q)
                            0: begin
                                if(addr_q==32'hffffffe0) cyc_rdata<=16'h1000;
                                else if(addr_q==32'hfffffff0) cyc_rdata<=0;
                                else if(addr_q<32'h10000) cyc_rdata<=mem[addr_q[15:4]];
                                else $fatal(1,"unexpected read address %08x",addr_q);
                            end
                            1: begin
                                if(addr_q<32'h10000) begin
                                    mem[addr_q[15:4]]<=data_q;
                                    ext_writes<=ext_writes+1;
                                end else $fatal(1,"unexpected write address %08x",addr_q);
                            end
                            5: cyc_rdata<=io_q;
                            6: ;
                            2,3,4: cyc_rdata<=0;
                            default: $fatal(1,"unexpected NARC cycle %0d",kind_q);
                        endcase
                    end
                end
                ACK: if(!cyc_req) begin cyc_ack<=0; bus_state<=IDLE; end
            endcase
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

    task pause_case(input integer position, input integer duration);
        integer n;
        begin
            @(posedge retire); #1;
            repeat(position) @(posedge clk);
            @(negedge clk);
            pause_pc=pc; pause_ir=ir; pause_st=st;
            pause_uaddr=dut.u_cpu.u_core.u_ctrl.uaddr;
            pause_rf_writes=rf_writes; pause_iaqs=iaq_count; pause_ext=ext_count;
            pause_active=1; cen=0;
            repeat(duration) begin
                @(posedge clk); #1;
                if(pc!==pause_pc || ir!==pause_ir || st!==pause_st || retire ||
                   dut.u_cpu.u_core.u_ctrl.uaddr!==pause_uaddr ||
                   dut.u_cpu.u_core.u_regs.we || rf_writes!==pause_rf_writes ||
                   iaq_count!==pause_iaqs || ext_count!==pause_ext)
                    $fatal(1,"CEN pause edge advanced state position=%0d len=%0d",
                           position,duration);
            end
            @(negedge clk); cen=1; pause_active=0;
            pause_cases=pause_cases+1;
            $display("RESTART_CEN_PAUSE_PASS position=%0d length=%0d",position,duration);
        end
    endtask

    integer guard, start_rf_writes, start_iaqs, start_ext;
    initial begin
        wait(!rst); repeat(20) tick();
        $display("RESTART_PROGRAM %04x %04x %04x %04x %04x %04x %04x %04x %04x",
                 mem['h100],mem['h101],mem['h104],mem['h105],mem['h106],
                 mem['h107],mem['h10c],mem['h10d],mem['h10e]);
        if(!halt) $fatal(1,"host-present reset did not assert HLT");
        release_halt();
        guard=0;
        while(!(retire && retired_ir_q==16'h0300 && retired_pc_q>=32'h1040) && guard<8000) begin
            tick(); guard=guard+1;
            if(fault) $fatal(1,"CPU fault during cache warming at pc=%08x ir=%04x",pc,ir);
        end
        if(guard==8000) $fatal(1,"did not reach warm scalar stream");
        // Let the first execution populate all measured words, then use the
        // next pass over the same resident code as the measured interval.
        while(!(retire && retired_ir_q==16'hcff7) && guard<12000) begin
            tick(); guard=guard+1;
            if(fault) $fatal(1,"CPU fault warming scalar loop");
        end
        if(guard==12000) $fatal(1,"warm stream did not reach its redirect");
        active_window=1; timed_retires=0; prev_retire_cycle=-1;
        rf_writes_in_window=0;
        start_rf_writes=rf_writes; start_iaqs=iaq_count; start_ext=ext_count;
        while(timed_retires<16 && guard<16000) begin
            tick(); guard=guard+1;
            if(fault) $fatal(1,"CPU fault during timed stream");
        end
        active_window=0;
        if(timed_retires<16) $fatal(1,"timed retire timeout");
        if(ext_count!=start_ext || iaq_count!=start_iaqs)
            $fatal(1,"warm resident stream caused physical IAQ/external cycles (%0d/%0d)",
                   iaq_count-start_iaqs,ext_count-start_ext);
        if(rf_writes-start_rf_writes!=12 || rf_writes_in_window!=12)
            $fatal(1,"functional RF writes were duplicated/missed (%0d overall, %0d window; expected 12)",
                   rf_writes-start_rf_writes,rf_writes_in_window);
        if(dut.u_cpu.u_core.u_regs.ram0[0]!==32'd6 ||
           dut.u_cpu.u_core.u_regs.ram0[1]!==32'd2 ||
           dut.u_cpu.u_core.u_regs.ram0[18]!==32'd2 || st[31:28]!==4'b0000)
            $fatal(1,"architectural stream result mismatch A0=%08x A1=%08x B2=%08x ST=%08x",
                   dut.u_cpu.u_core.u_regs.ram0[0],
                   dut.u_cpu.u_core.u_regs.ram0[1],
                   dut.u_cpu.u_core.u_regs.ram0[18],st);
        for(i=0;i<8;i=i+1) begin
            pause_case(i,1);
            pause_case(i,7);
        end
        if(pause_cases!=16) $fatal(1,"CEN pause matrix incomplete: %0d",pause_cases);
        $display("RESTART_CEN_PAUSE_MATRIX_PASS: lengths 1 and 7 at all 8 INCLK positions");
        $display("RESTART_TIMING_PASS: 16 retirements, 8 INCLK each, no external IAQ, 12 RF writes once");
        $finish;
    end
endmodule
