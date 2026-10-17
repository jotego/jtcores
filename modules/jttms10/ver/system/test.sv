`timescale 1ns/1ps
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1,cen=1,vclk_cen=0,hcs_n=1;
    reg host_req=0,host_we=0;
    reg [1:0] host_reg=0,host_be=0;
    reg [15:0] host_wdata=0;
    wire [15:0] host_rdata;
    wire host_ack,host_busy,cyc_req,cyc_iaq,cyc_org;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr,pc,st;
    wire [15:0] cyc_wdata,cyc_io_rdata,cyc_dpytap,ir;
    wire [13:0] cyc_srfaddr;
    wire [7:0] cyc_dram_row;
    reg [15:0] cyc_rdata=0;
    reg cyc_ack=0;
    wire retire,fault,irq_pending,nmi_pending,halt;
    wire [15:0] intenb,intpend;
    jttms10_system dut(
        .clk(clk),.rst(rst),.cen(cen),.vclk_cen(vclk_cen),
        .hcs_n(hcs_n),.hsync_n(1'b1),.vsync_n(1'b1),
        .lint1_n(1'b1),.lint2_n(1'b1),
        .hold_req(1'b0),.hold_ack(),.emu_run(1'b1),.emu_ack(),
        .host_req(host_req),.host_we(host_we),.host_reg(host_reg),
        .host_be(host_be),.host_wdata(host_wdata),
        .host_rdata(host_rdata),.host_ack(host_ack),.host_busy(host_busy),
        .hint_n(),.hs(),.vs(),.hblank(),.vblank(),.blank(),
        .cyc_req(cyc_req),.cyc_kind(cyc_kind),.cyc_addr(cyc_addr),
        .cyc_wdata(cyc_wdata),.cyc_io_rdata(cyc_io_rdata),
        .cyc_iaq(cyc_iaq),.cyc_srfaddr(cyc_srfaddr),
        .cyc_dpytap(cyc_dpytap),.cyc_org(cyc_org),
        .cyc_dram_row(cyc_dram_row),
        .cyc_rdata(cyc_rdata),.cyc_ack(cyc_ack),
        .pc(pc),.st(st),.ir(ir),.retire(retire),.fault(fault),
        .intenb(intenb),.intpend(intpend),
        .irq_pending(irq_pending),.nmi_pending(nmi_pending),.halt(halt)
    );
    reg [15:0] mem [0:4095];
    integer i;
    initial begin
        for(i=0;i<4096;i=i+1) mem[i]=16'h0300; // NOP
        mem['h100]=16'h09cf; mem['h101]=16'h0300; // MOVI 0x300,SP
        mem['h102]=16'h09e0; mem['h103]=16'h0110; mem['h104]=16'hc000; // INTENB,A0
        mem['h105]=16'h09c1; mem['h106]=16'h0400; // display enable,A1
        mem['h107]=16'h8020; // MOVE A1,*A0
        mem['h108]=16'h09e2; mem['h109]=16'h0080; mem['h10a]=16'hc000; // DPYCTL,A2
        mem['h10b]=16'h09c3; mem['h10c]=16'h8000; // ENV,A3
        mem['h10d]=16'h8062; // MOVE A3,*A2
        mem['h10e]=16'h09e4; mem['h10f]=16'h0010; mem['h110]=16'h0020; // IE|FS0=16,A4
        mem['h111]=16'h01a4; // PUTST A4
        mem['h112]=16'hc0ff; // JRUC -1, idle loop
        mem['h120]=16'h09e5; mem['h121]=16'h0120; mem['h122]=16'hc000; // INTPEND,A5
        mem['h123]=16'h09c6; mem['h124]=16'h0000; // 0,A6
        mem['h125]=16'h80c5; // MOVE A6,*A5 clears DIP
        mem['h126]=16'h0940; // RETI
        repeat(5) @(negedge clk); rst=0;
    end
    localparam [1:0] IDLE=0,WAIT=1,ACK=2;
    reg [1:0] state=IDLE;
    reg [3:0] kind_q;
    reg [31:0] addr_q;
    reg [15:0] data_q,io_q;
    reg iaq_q;
    integer delay_q=0,cycles=0,io_writes=0,irq_vector_reads=0;
    integer init_seen=0;
    reg host_released=0;
    integer pre_release_local_cycles=0;
    always @(posedge clk) begin
        if (rst) begin
            state<=IDLE; cyc_ack<=0; cyc_rdata<=0;
            cycles<=0; io_writes<=0; irq_vector_reads<=0; init_seen<=0;
            pre_release_local_cycles<=0;
        end else case(state)
            IDLE: if(cyc_req) begin
                if (init_seen < 8) begin
                    if (cyc_kind !== 4'd3 || cyc_addr !== 32'd0 ||
                        cyc_dram_row !== 8'd0 || cyc_iaq !== 1'b0)
                        $fatal(1,"startup cycle %0d was not RAS-only: kind=%0d addr=%h row=%h iaq=%b",
                               init_seen,cyc_kind,cyc_addr,cyc_dram_row,cyc_iaq);
                    init_seen<=init_seen+1;
                end
                // TI §8.8: host-present reset holds the processor before its
                // level-0 vector fetch. Refresh/RAS initialization may still
                // use the NARC bus while the host has HLT asserted.
                if (!host_released && (cyc_kind==0 || cyc_kind==1 ||
                                       cyc_kind==5 || cyc_kind==6 ||
                                       cyc_kind==7 || cyc_kind==8)) begin
                    pre_release_local_cycles<=pre_release_local_cycles+1;
                    $fatal(1,"CPU/local cycle %0d @%h before host HLT release",
                           cyc_kind,cyc_addr);
                end
                kind_q<=cyc_kind; addr_q<=cyc_addr;
                data_q<=cyc_wdata; io_q<=cyc_io_rdata; iaq_q<=cyc_iaq;
                delay_q<=2; state<=WAIT; cycles<=cycles+1;
            end
            WAIT: begin
                if(!cyc_req || cyc_kind!==kind_q || cyc_addr!==addr_q ||
                   cyc_wdata!==data_q || cyc_io_rdata!==io_q || cyc_iaq!==iaq_q)
                    $fatal(1,"NARC payload changed while waiting");
                if(delay_q!=0) delay_q<=delay_q-1;
                else begin
                    cyc_ack<=1; state<=ACK;
                    case(kind_q)
                        0: begin
                            if(addr_q==32'hffffffe0) cyc_rdata<=16'h1000;
                            else if(addr_q==32'hfffffff0) cyc_rdata<=0;
                            else if(addr_q==32'hfffffea0) begin
                                cyc_rdata<=16'h1200;
                                irq_vector_reads<=irq_vector_reads+1;
                            end else if(addr_q==32'hfffffeb0) cyc_rdata<=0;
                            else if(addr_q<32'h00010000) cyc_rdata<=mem[addr_q[15:4]];
                            else $fatal(1,"unexpected memory read %08x",addr_q);
                        end
                        1: begin
                            if(addr_q>=32'h00010000)
                                $fatal(1,"unexpected memory write %08x",addr_q);
                            mem[addr_q[15:4]]<=data_q;
                        end
                        5: cyc_rdata<=io_q;
                        6: io_writes<=io_writes+1;
                        2,3,4: cyc_rdata<=0;
                        default: $fatal(1,"unexpected cycle kind %0d",kind_q);
                    endcase
                end
            end
            ACK: if(!cyc_req) begin cyc_ack<=0; state<=IDLE; end
        endcase
    end
    task tick; begin @(posedge clk); #1; end endtask
    task host_release_halt;
        integer g;
        begin
            @(negedge clk); host_req=1; host_we=1;
            host_reg=2'd3; host_be=2'b10; host_wdata=0;
            g=0;
            while(!host_ack && g<30) begin tick(); g=g+1; end
            if(!host_ack) $fatal(1,"host halt-release timeout");
            host_released=1;
            @(negedge clk); host_req=0; host_we=0;
            tick();
        end
    endtask
    integer guard;
    reg [31:0] saved_pc;
    initial begin
        wait(!rst);
        repeat(20) tick();
        if(!halt) $fatal(1,"host-present reset did not assert HLT");
        repeat(50) tick(); // refresh/init cycles may continue; CPU must not
        if(pc!==32'd0 || retire || pre_release_local_cycles!=0 || init_seen!=8)
            $fatal(1,"host-present HLT allowed vector fetch/retirement pc=%08x ir=%04x cycles=%0d",
                   pc,ir,pre_release_local_cycles);
        host_release_halt();
        if(halt) $fatal(1,"host did not release reset HLT");
        guard=0;
        while(!(retire && ir==16'h01a4) && guard<4000) begin
            tick(); guard=guard+1;
            if(fault) $fatal(1,"CPU fault before IRQ ir=%04x",ir);
        end
        if(guard==4000 || intenb!==16'h0400 || st!==32'h00200010)
            $fatal(1,"display IRQ not configured pc=%08x st=%08x intenb=%04x",pc,st,intenb);
        @(negedge clk); vclk_cen=1;
        @(negedge clk); vclk_cen=0;
        guard=0;
        while(!intpend[10] && guard<20) begin tick(); guard=guard+1; end
        if(!intpend[10] || !irq_pending) $fatal(1,"display IRQ not latched");
        guard=0;
        while(pc!=32'h1200 && guard<1000) begin
            tick(); guard=guard+1;
            if(fault) $fatal(1,"CPU fault entering IRQ");
        end
        if(guard==1000 || irq_vector_reads!=1 || st!==32'h00000010)
            $fatal(1,"display IRQ entry failed pc=%08x st=%08x vectors=%0d",pc,st,irq_vector_reads);
        saved_pc={mem['h2f],mem['h2e]};
        if(saved_pc<32'h1120 || saved_pc>32'h1130 ||
           {mem['h2d],mem['h2c]}!==32'h00200010)
            $fatal(1,"IRQ stack PC/ST wrong saved=%08x ST=%08x",saved_pc,{mem['h2d],mem['h2c]});
        guard=0;
        while(!(retire && ir==16'h0940) && guard<2000) begin
            tick(); guard=guard+1;
            if(fault) $fatal(1,"CPU fault in IRQ handler");
        end
        if(guard==2000 || intpend[10] || io_writes!=3 ||
           pc!==saved_pc || st!==32'h00200010 ||
           dut.u_cpu.u_core.u_regs.ram0[15]!==32'h0300)
            $fatal(1,"IRQ clear/RETI failed pc=%08x saved=%08x st=%08x intpend=%04x writes=%0d",
                pc,saved_pc,st,intpend,io_writes);
        repeat(60) tick();
        if(irq_vector_reads!=1 || fault || intpend[10])
            $fatal(1,"duplicate IRQ/cycle after RETI");
        $display("jttms10_system PASS (%0d NARC cycles)",cycles); $finish;
    end
    initial begin #1000000; $fatal(1,"system integration timeout"); end
endmodule
