`timescale 1ns/1ps
// Warm real-system stageB feasibility probe for TI-timed shifts and LMO.
module test;
    reg clk=0; always #5 clk=~clk;
    reg rst=1, cen=1, host_req=0, host_we=0, cyc_ack=0;
    reg [1:0] host_reg=0, host_be=0;
    reg [15:0] host_wdata=0, cyc_rdata=0;
    wire [15:0] host_rdata, cyc_wdata, cyc_io_rdata, ir, intenb, intpend;
    wire host_ack, host_busy, cyc_req, cyc_iaq, retire, fault, irq_pending, nmi_pending, halt;
    wire [3:0] cyc_kind;
    wire [31:0] cyc_addr, pc, st;
    reg [15:0] mem[0:4095];
    integer i;

    integer stageb_case_count;
    reg [31:0] stageb_stream_pc, stageb_setup_pc, stageb_branch_pc;
    reg [15:0] stageb_branch_ir, stageb_timer_nop_ir;
    reg [31:0] expected_pc[0:31], expected_result[0:31], expected_st[0:31];
    reg [15:0] expected_ir[0:31];
    integer expected_cycles[0:31];
    reg [5:0] expected_dest[0:31], expected_src[0:31];
    reg [31:0] expected_src_value[0:31];

    jttms10_system dut(
        .clk(clk),.rst(rst),.cen(cen),.vclk_cen(1'b0),
        .hcs_n(1'b1),.hsync_n(1'b1),.vsync_n(1'b1),
        .lint1_n(1'b1),.lint2_n(1'b1),.hold_req(1'b0),.hold_ack(),
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
        `include "stageb_vectors.svh"
        repeat(5) @(negedge clk);
        rst=0;
    end

    localparam [1:0] IDLE=0, WAIT_ACK=1, ACKED=2;
    reg [1:0] bus_state=IDLE;
    reg [3:0] kind_q;
    reg [31:0] addr_q;
    reg [15:0] data_q, io_q;
    reg iaq_q;
    integer iaq_count=0, external_count=0;
    always @(posedge clk) begin
        if(rst) begin
            bus_state<=IDLE; cyc_ack<=0; cyc_rdata<=0;
            iaq_count<=0; external_count<=0;
        end else begin
            if(cyc_req && cyc_iaq) iaq_count<=iaq_count+1;
            if(cyc_req && (cyc_kind==0 || cyc_kind==1))
                external_count<=external_count+1;
            case(bus_state)
                IDLE: if(cyc_req) begin
                    kind_q<=cyc_kind; addr_q<=cyc_addr; data_q<=cyc_wdata;
                    io_q<=cyc_io_rdata; iaq_q<=cyc_iaq; bus_state<=WAIT_ACK;
                end
                WAIT_ACK: begin
                    if(!cyc_req || cyc_kind!==kind_q || cyc_addr!==addr_q ||
                       cyc_wdata!==data_q || cyc_io_rdata!==io_q || cyc_iaq!==iaq_q)
                        $fatal(1,"NARC request changed before ACK");
                    cyc_ack<=1; bus_state<=ACKED;
                    case(kind_q)
                        0: begin
                            if(addr_q==32'hffffffe0) cyc_rdata<=16'h1000;
                            else if(addr_q==32'hfffffff0) cyc_rdata<=16'h0000;
                            else if(addr_q<32'h10000) cyc_rdata<=mem[addr_q[15:4]];
                            else $fatal(1,"unexpected read address %08x",addr_q);
                        end
                        1: if(addr_q<32'h10000) mem[addr_q[15:4]]<=data_q;
                           else $fatal(1,"unexpected write address %08x",addr_q);
                        5: cyc_rdata<=io_q;
                        2,3,4,6: ;
                        default: $fatal(1,"unexpected NARC cycle %0d",kind_q);
                    endcase
                end
                ACKED: if(!cyc_req) begin cyc_ack<=0; bus_state<=IDLE; end
                default: $fatal(1,"invalid NARC bus model state %0d",bus_state);
            endcase
        end
    end

    integer clock_count=0, measured_count=0, timing_failures=0, functional_failures=0;
    integer previous_retire=-1, start_iaq=0, start_external=0;
    reg active_window=0, done=0, first_pass_seen=0;
    reg sampled_retire;
    reg [15:0] sampled_ir;
    reg [31:0] sampled_pc;
    reg [15:0] retired_ir_q;
    reg [31:0] retired_pc_q;
    integer actual_cycles;
    always @(posedge clk) begin
        if(rst) begin
            clock_count=0; measured_count=0; timing_failures=0;
            functional_failures=0; previous_retire=-1;
            active_window=0; done=0; first_pass_seen=0;
            retired_ir_q=0; retired_pc_q=0;
        end else begin
            clock_count=clock_count+1;
            sampled_retire=retire; sampled_ir=retired_ir_q; sampled_pc=retired_pc_q;
            retired_ir_q<=ir; retired_pc_q<=pc;
            #1; // Let architectural writes from this sampled edge settle.
            if(sampled_retire && !active_window && !first_pass_seen &&
               sampled_ir==stageb_branch_ir) begin
                if(sampled_pc!==stageb_setup_pc) begin
                    functional_failures=functional_failures+1;
                    $display("STAGEB_BRANCH_FAIL pc=%08x expected setup=%08x",sampled_pc,stageb_setup_pc);
                end
                first_pass_seen=1;
                $display("STAGEB_WARM_PASS_END cycle=%0d pc=%08x setup=%08x",clock_count,sampled_pc,stageb_setup_pc);
            end else if(sampled_retire && first_pass_seen && !active_window &&
                        sampled_ir==stageb_timer_nop_ir) begin
                active_window=1; previous_retire=clock_count;
                start_iaq=iaq_count; start_external=external_count;
                if(sampled_pc!==stageb_stream_pc) begin
                    functional_failures=functional_failures+1;
                    $display("STAGEB_TIMER_PC_FAIL nop_retire_pc=%08x expected_stream=%08x",
                             sampled_pc,stageb_stream_pc);
                end
                $display("STAGEB_RESTORED cycle=%0d stream=%08x",clock_count,sampled_pc);
            end else if(sampled_retire && active_window) begin
                if(measured_count>=stageb_case_count)
                    $fatal(1,"extra retirement in measured stageB window pc=%08x ir=%04x",sampled_pc,sampled_ir);
                actual_cycles=clock_count-previous_retire;
                $display("STAGEB_CASE id=%0d pc=%08x ir=%04x clocks=%0d expected=%0d result=%08x st=%08x",
                         measured_count,sampled_pc,sampled_ir,actual_cycles,
                         expected_cycles[measured_count],
                         dut.u_cpu.u_core.u_regs.ram0[expected_dest[measured_count]],st);
                if(sampled_pc!==expected_pc[measured_count] ||
                   sampled_ir!==expected_ir[measured_count] ||
                   dut.u_cpu.u_core.u_regs.ram0[expected_dest[measured_count]]!==
                       expected_result[measured_count] ||
                   st!==expected_st[measured_count] ||
                   (expected_src[measured_count]!=6'd63 &&
                    dut.u_cpu.u_core.u_regs.ram0[expected_src[measured_count]]!==
                       expected_src_value[measured_count])) begin
                    functional_failures=functional_failures+1;
                    $display("STAGEB_ARCH_FAIL case=%0d pc=%08x/%08x ir=%04x/%04x dst%0d=%08x/%08x src%0d=%08x ST=%08x/%08x",
                             measured_count,sampled_pc,expected_pc[measured_count],
                             sampled_ir,expected_ir[measured_count],expected_dest[measured_count],
                             dut.u_cpu.u_core.u_regs.ram0[expected_dest[measured_count]],
                             expected_result[measured_count],expected_src[measured_count],
                             dut.u_cpu.u_core.u_regs.ram0[expected_src[measured_count]],
                             st,expected_st[measured_count]);
                end
                if(actual_cycles!=expected_cycles[measured_count]) begin
                    timing_failures=timing_failures+1;
                    $display("STAGEB_TIMING_FAIL case=%0d actual=%0d expected=%0d INCLK",
                             measured_count,actual_cycles,expected_cycles[measured_count]);
                end
                previous_retire=clock_count;
                measured_count=measured_count+1;
                if(measured_count==stageb_case_count) begin
                    active_window=0; done=1;
                    if(iaq_count!=start_iaq || external_count!=start_external) begin
                        functional_failures=functional_failures+1;
                        $display("STAGEB_CACHE_FAIL IAQ=%0d external=%0d",
                                 iaq_count-start_iaq,external_count-start_external);
                    end
                    $display("STAGEB_SUMMARY cases=%0d timing_failures=%0d functional_failures=%0d warm_iaq=%0d warm_external=%0d",
                             measured_count,timing_failures,functional_failures,
                             iaq_count-start_iaq,external_count-start_external);
                end
            end
            if(fault) begin
                functional_failures=functional_failures+1;
                $display("STAGEB_FAULT pc=%08x ir=%04x",pc,ir);
            end
        end
    end

    task tick; begin @(posedge clk); #2; end endtask
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

    integer timeout_clocks;
    initial begin
        wait(!rst); repeat(20) tick();
        if(!halt) $fatal(1,"host-present reset did not assert HLT");
        release_halt();
        timeout_clocks=0;
        while(!done && timeout_clocks<100000) begin
            tick(); timeout_clocks=timeout_clocks+1;
        end
        if(!done) $fatal(1,"stageB program timed out after %0d clocks",timeout_clocks);
        if(functional_failures!=0)
            $fatal(1,"STAGEB_ARCH_FAIL: %0d functional failures",functional_failures);
        if(timing_failures!=0)
            $fatal(1,"STAGEB_BASELINE_RED: %0d of %0d cases differ from TI timing",timing_failures,measured_count);
        $display("STAGEB_BASELINE_PASS: all selected timings meet TI");
        $finish;
    end
endmodule
