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
    integer i,rc,delay_clocks=16,extra_wait=0;
    integer now=0,seen=0,start_clock=0;
    reg [31:0] test_pc,next_pc;
    reg measuring=0;
    string program_path;
    initial begin
        if (!$value$plusargs("PROGRAM=%s",program_path) ||
            !$value$plusargs("TEST_PC=%h",test_pc) ||
            !$value$plusargs("NEXT_PC=%h",next_pc))
            $fatal(1,"missing PROGRAM/TEST_PC/NEXT_PC");
        rc=$value$plusargs("WAIT=%d",extra_wait);
        if(extra_wait<0) $fatal(1,"negative wait");
        delay_clocks=16+extra_wait;
        for(i=0;i<4096;i=i+1) mem[i]=0;
        $readmemh(program_path,mem);
        repeat(5) @(negedge clk);
        rst=0;
    end

    // ACK is consumed 16 INCLKs (two machine states) after the first
    // sampling edge, plus the explicitly requested target delay.
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
    end
    always @(posedge clk) begin
        if(rst) begin bus_state<=IDLE; age<=0; end
        else case(bus_state)
            IDLE: if(cyc_req) begin
                addr_q<=cyc_addr; kind_q<=cyc_kind; data_q<=cyc_wdata;
                io_q<=cyc_io_rdata; iaq_q<=cyc_iaq;
                age<=1; bus_state<=BUSY;
                $display("BUS_BEGIN %0d %0d %08h %04h %0d",now,
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
                $display("BUS_END %0d %0d %08h %04h",now,kind_q,addr_q,cyc_rdata);
                bus_state<=IDLE;
            end
        endcase
    end

    // Decode-to-decode includes extension fetches and the following opcode
    // fetch, as required by the cache-disabled timing convention (§13.1).
    // Warm pass excludes reset, cold fills, and setup from the observation.
    always @(posedge clk) begin
        if(rst) now<=0;
        else begin
            now<=now+1;
            if(fault) $fatal(1,"CPU fault pc=%h ir=%h",pc,ir);
            if(dut.u_cpu.u_core.step && dut.u_cpu.u_core.ld_ir) begin
                $display("DECODE %0d %08h %04h",now,pc-32'd16,dut.u_cpu.u_core.md[15:0]);
                if(pc-32'd16==test_pc) begin
                    seen<=seen+1;
                    if(seen==1) begin start_clock<=now; measuring<=1; end
                end
                if(measuring && pc-32'd16==next_pc) begin
                    $display("RESULT clocks=%0d start=%0d end=%0d st=%08h a0=%08h a1=%08h a2=%08h a3=%08h",
                        now-start_clock,start_clock,now,st,
                        dut.u_cpu.u_core.u_regs.ram0[0],dut.u_cpu.u_core.u_regs.ram0[1],
                        dut.u_cpu.u_core.u_regs.ram0[2],dut.u_cpu.u_core.u_regs.ram0[3]);
                    $finish;
                end
            end
            if(now==200000) $fatal(1,"timing timeout pc=%h ir=%h seen=%0d",pc,ir,seen);
        end
    end
endmodule
