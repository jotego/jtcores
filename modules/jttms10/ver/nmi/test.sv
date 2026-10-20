`timescale 1ns/1ps
// Host/peripheral recognition, distinct from the CPU's already recognized input.
module test;
    reg clk=0;
    always #5 clk=~clk;
    reg rst=1, cen=1, lint1_n=1;
    reg host_req=0, host_we=0;
    reg [15:0] host_wdata=0;
    wire [15:0] host_rdata;
    wire host_ack, cyc_req, cyc_iaq, retire, fault, nmi_pending, halt;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr, pc, st;
    wire [15:0] cyc_wdata, cyc_io_rdata;
    reg [15:0] cyc_rdata=0;
    reg cyc_ack=0;
    jttms10_system #(.RESET_REFRESH(0)) dut(
        .clk(clk),.rst(rst),.cen(cen),.vclk_cen(1'b0),
        .hcs_n(1'b0),.hsync_n(1'b1),.vsync_n(1'b1),
        .lint1_n(lint1_n),.lint2_n(1'b1),
        .hold_req(1'b0),.hold_ack(),.emu_run(1'b1),.emu_ack(),
        .host_req(host_req),.host_we(host_we),.host_reg(2'd3),.host_be(2'b10),
        .host_wdata(host_wdata),.host_rdata(host_rdata),.host_ack(host_ack),.host_busy(),
        .hint_n(),.hs(),.vs(),.hblank(),.vblank(),.blank(),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),.cyc_iaq(cyc_iaq),
        .cyc_srfaddr(),.cyc_dpytap(),.cyc_org(),.cyc_dram_row(),
        .cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack),
        .pc(pc),.st(st),.ir(),.retire(retire),.fault(fault),
        .intenb(),.intpend(),.irq_pending(),.nmi_pending(nmi_pending),.halt(halt)
    );

    reg [15:0] memory [0:4095];
    localparam [1:0] IDLE=0, WAIT=1, ACK=2;
    reg [1:0] state=IDLE;
    reg [3:0] kind_q;
    reg [31:0] addr_q;
    reg [15:0] data_q, io_q;
    reg iaq_q;
    integer delay_q, mode, short_pause=0, i, retired=0, nmi_vectors=0, irq_vectors=0, writes=0;
    reg [31:0] saved_status;

    always @(posedge clk) begin
        if(rst) begin
            state<=IDLE;cyc_ack<=0;cyc_rdata<=0;
            retired<=0;nmi_vectors<=0;irq_vectors<=0;writes<=0;
        end else begin
            if(fault) $fatal(1,"NMI system fault PC=%h",pc);
            if(retire) retired<=retired+1;
            case(state)
                IDLE: if(cyc_req) begin
                    kind_q<=cyc_kind;addr_q<=cyc_addr;data_q<=cyc_wdata;
                    io_q<=cyc_io_rdata;iaq_q<=cyc_iaq;delay_q<=2;state<=WAIT;
                    if(cyc_addr==32'hfffffee0 && cyc_kind==0) nmi_vectors<=nmi_vectors+1;
                    if(cyc_addr==32'hffffffc0 && cyc_kind==0) begin
                        irq_vectors<=irq_vectors+1;
                        if(mode==3) $fatal(1,"maskable IRQ beat pending NMI");
                    end
                end
                WAIT: begin
                    if(!cyc_req || cyc_kind!==kind_q || cyc_addr!==addr_q ||
                       cyc_wdata!==data_q || cyc_io_rdata!==io_q || cyc_iaq!==iaq_q)
                        $fatal(1,"NMI target request changed while waiting");
                    if(delay_q!=0) delay_q<=delay_q-1;
                    else begin
                        cyc_ack<=1;state<=ACK;
                        case(kind_q)
                            0: begin
                                case(addr_q)
                                    32'hffffffe0: cyc_rdata<=16'h1000;
                                    32'hfffffff0: cyc_rdata<=0;
                                    32'hfffffee0: cyc_rdata<=16'h4000;
                                    32'hfffffef0: cyc_rdata<=0;
                                    32'hffffffc0: cyc_rdata<=16'h5000;
                                    32'hffffffd0: cyc_rdata<=0;
                                    default: begin
                                        if(addr_q>=32'h10000) $fatal(1,"unexpected NMI read %h",addr_q);
                                        cyc_rdata<=memory[addr_q[15:4]];
                                    end
                                endcase
                            end
                            1: begin
                                // Independent PC-before-ST and MSW-first order.
                                case(writes%4)
                                    0: if(addr_q!==32'h2ff0 || data_q!==0) $fatal(1,"PC high order/data");
                                    1: if(addr_q!==32'h2fe0 || data_q!==16'h1120) $fatal(1,"PC low order/data");
                                    2: if(addr_q!==32'h2fd0 || data_q!==saved_status[31:16]) $fatal(1,"ST high order/data");
                                    3: if(addr_q!==32'h2fc0 || data_q!==saved_status[15:0]) $fatal(1,"ST low order/data");
                                endcase
                                memory[addr_q[15:4]]<=data_q;writes<=writes+1;
                            end
                            5: cyc_rdata<=io_q;
                            2,3,4: cyc_rdata<=0;
                            default: $fatal(1,"unexpected NMI cycle %0d",kind_q);
                        endcase
                    end
                end
                ACK: if(!cyc_req) begin cyc_ack<=0;state<=IDLE;end
                default: $fatal(1,"invalid NMI target state");
            endcase
        end
    end

    task automatic host_access(input bit write, input [15:0] value);
        integer clocks;
        begin
            @(negedge clk);host_we=write;host_wdata=value;host_req=1;clocks=0;
            do begin @(negedge clk);clocks=clocks+1;end while(!host_ack && clocks<32);
            if(!host_ack) $fatal(1,"host control timeout");
            host_req=0;
            @(negedge clk);
        end
    endtask

    task automatic await_loop;
        integer clocks;
        begin
            clocks=0;
            do begin @(negedge clk);clocks=clocks+1;end
            while(!(retire && pc==32'h1120 && st==saved_status) && clocks<20000);
            if(clocks==20000) $fatal(1,"NMI return/loop timeout PC=%h ST=%h",pc,st);
        end
    endtask

    task automatic await_entry(input integer count);
        integer clocks;
        begin
            clocks=0;
            while(!(pc==32'h4000 && st==32'h10) && clocks<5000) begin
                @(negedge clk);clocks=clocks+1;
            end
            if(clocks==5000 || nmi_vectors!=count || irq_vectors!=0 || writes!=4*count ||
               dut.u_cpu.u_core.u_regs.ram0[15]!==32'h2fc0)
                $fatal(1,"NMI entry wrong PC=%h ST=%h NMI=%0d IRQ=%0d writes=%0d",pc,st,nmi_vectors,irq_vectors,writes);
            host_access(0,0);
            if(host_rdata[8]) $fatal(1,"NMI bit did not automatically clear");
        end
    endtask

    task automatic quiet(input bit pending);
        integer old_retired, old_vectors, old_writes;
        reg [31:0] old_pc;
        begin
            old_retired=retired;old_vectors=nmi_vectors;old_writes=writes;old_pc=pc;
            repeat(32) begin
                @(negedge clk);
                if(retired!=old_retired || nmi_vectors!=old_vectors || writes!=old_writes || pc!==old_pc ||
                   nmi_pending!==pending)
                    $fatal(1,"halt/pause changed NMI context mode=%0d",mode);
            end
        end
    endtask

    initial begin
        if(!$value$plusargs("MODE=%d",mode) || mode<1 || mode>5) $fatal(1,"select NMI MODE1..5");
        i=$value$plusargs("SHORT_PAUSE=%d",short_pause);
        saved_status=mode==3 ? 32'h00200010 : 32'h10;
        for(i=0;i<4096;i=i+1) memory[i]=16'h0300;
        memory['h100]=16'h09cf;memory['h101]=16'h3000;
        if(mode==3) begin
            memory['h102]=16'h09e0;memory['h103]=16'h0110;memory['h104]=16'hc000;
            memory['h105]=16'h09c1;memory['h106]=16'h0002;
            memory['h107]=16'h8020;
            memory['h108]=16'h09e2;memory['h109]=16'h0010;memory['h10a]=16'h0020;
            memory['h10b]=16'h01a2;
        end
        memory['h112]=16'hc0ff;
        memory['h400]=16'h09e0;memory['h401]=16'h5678;memory['h402]=16'h1234;
        memory['h403]=16'h0940;
        repeat(5) @(negedge clk);rst=0;
        repeat(3) await_loop();
        if(mode==2) begin
            host_access(1,16'h8000);
            wait(dut.cpu_halted);
            host_access(1,16'h8100);
            quiet(1);
            if(!halt || nmi_vectors!=0 || writes!=0) $fatal(1,"NMI woke already halted CPU");
            host_access(1,16'h0100);
        end else begin
            if(mode==3) begin
                // Settle a maskable request while execution is paused, then
                // post the higher-priority host NMI just before resuming.
                // This exercises priority while NMI recognition is pending.
                cen=0;lint1_n=0;
                repeat(32) @(negedge clk);
                if(!dut.irq_pending) $fatal(1,"maskable IRQ did not become pending");
            end
            if(mode==5) cen=0;
            if(mode==1 && short_pause!=0) cen=0;
            host_access(1,mode==1 ? 16'h8100 : 16'h0100);
            if(mode==1 && short_pause!=0) begin
                if(dut.nmi_ready) $fatal(1,"NMI recognized before its minimum delay");
                cen=1;
            end
            if(mode==3) begin
                if(dut.nmi_ready) $fatal(1,"NMI recognized before its minimum delay");
                cen=1;
            end
            if(mode==5) begin quiet(1);cen=1;end
        end
        await_entry(1);
        lint1_n=1;
        if(mode==1) begin
            wait(dut.cpu_halted);
            if(!halt) $fatal(1,"simultaneous HLT disappeared");
            quiet(0);
            host_access(1,0);
        end
        await_loop();
        if(dut.u_cpu.u_core.u_regs.ram0[15]!==32'h3000 ||
           dut.u_cpu.u_core.u_regs.ram0[0]!==32'h12345678 ||
           memory['h2fc]!==saved_status[15:0] || memory['h2fd]!==saved_status[31:16] ||
           memory['h2fe]!==16'h1120 || memory['h2ff]!==0)
            $fatal(1,"RETI/SP/register/frame mismatch");
        if(mode==4) begin
            host_access(1,16'h0100);
            await_entry(2);
            await_loop();
            if(dut.u_cpu.u_core.u_regs.ram0[15]!==32'h3000) $fatal(1,"second NMI SP mismatch");
        end
        $display("PASS: host NMI mode%0d vectors=%0d writes=%0d",mode,nmi_vectors,writes);
        $finish;
    end
    initial begin #5000000;$fatal(1,"NMI system watchdog mode=%0d PC=%h ST=%h",mode,pc,st);end
endmodule
