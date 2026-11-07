`timescale 1ns/1ps
module test;

reg         rst, clk;
reg         cpu_reset_n = 0;
reg  [1:0]  phase = 0;
reg         irq_n = 1, firq_n = 1, nmi_n = 1;
wire        cen_E = phase == 2'b00;
wire        cen_Q = phase == 2'b10;
wire [7:0]  dout, cpu_dout;
wire [15:0] addr;
wire        rnw, bs, ba, avma, busy, lic, op;
wire [111:0] regs;
wire [55:0] regs6309;
reg [7:0] code_mem[0:255];
reg [7:0] stack_mem[0:63];
reg [7:0] user_stack_mem[0:63];
reg [7:0] vector_mem[0:15];
reg [7:0] direct_mem[0:255];
reg [7:0] initial_e, initial_f;
integer i;
integer stack_write_count, stack_read_count;
integer tfm_source_reads, tfm_dest_writes;
integer illegal_vector_reads, irq_vector_reads, swi_vector_reads;
reg [15:0] stack_write_addr0, stack_write_addr1;
reg [15:0] stack_read_addr0, stack_read_addr1;
reg [7:0] cc_before_target;
integer signed_op, signed_form, signed_mode, signed_combo;

`include "test_tasks.vh"

wire nreset = ~rst & cpu_reset_n;
always @(posedge clk or negedge nreset) begin
    if(!nreset) phase <= 0;
    else phase <= phase + 1'b1;
end

function [7:0] read_byte(input [15:0] a);
    begin
        read_byte=8'h12;
        if(a >= 16'h0100 && a <= 16'h01ff) read_byte=code_mem[a-16'h0100];
        else if(a < 16'h0100) read_byte=direct_mem[a[7:0]];
        else if(a >= 16'h2fe0 && a <= 16'h301f) read_byte=stack_mem[a-16'h2fe0];
        else if(a >= 16'h3fe0 && a <= 16'h401f) read_byte=user_stack_mem[a-16'h3fe0];
        else if(a >= 16'hfff0) read_byte=vector_mem[a-16'hfff0];
    end
endfunction
assign dout = read_byte(addr);

mc6809i #(.ILLEGAL_INSTRUCTIONS("GHOST"), .HD6309(1)) uut(
    .D(dout), .DOut(cpu_dout), .ADDR(addr), .RnW(rnw),
    .clk(clk), .cen_E(cen_E), .cen_Q(cen_Q), .BS(bs), .BA(ba),
    .nIRQ(irq_n), .nFIRQ(firq_n), .nNMI(nmi_n), .AVMA(avma), .BUSY(busy), .LIC(lic),
    .nHALT(1'b1), .nRESET(nreset), .nDMABREQ(1'b1), .OP(op),
    .RegData(regs), .RegData6309(regs6309)
);

always @(posedge clk) if(nreset && cen_Q && !rnw) begin
    if(addr >= 16'h0100 && addr <= 16'h01ff) code_mem[addr-16'h0100] <= cpu_dout;
    else if(addr < 16'h0100) direct_mem[addr[7:0]] <= cpu_dout;
    else if(addr >= 16'h2fe0 && addr <= 16'h301f) stack_mem[addr-16'h2fe0] <= cpu_dout;
    else if(addr >= 16'h3fe0 && addr <= 16'h401f) user_stack_mem[addr-16'h3fe0] <= cpu_dout;
    else if(addr >= 16'hfff0) vector_mem[addr-16'hfff0] <= cpu_dout;
end

always @(posedge clk) if(nreset && cen_Q) begin
    if(!rnw && ((addr >= 16'h2fe0 && addr <= 16'h2fff) ||
                (addr >= 16'h3fe0 && addr <= 16'h3fff))) begin
        if(stack_write_count==0) stack_write_addr0=addr;
        if(stack_write_count==1) stack_write_addr1=addr;
        stack_write_count=stack_write_count+1;
    end
    if(rnw && ((addr >= 16'h2fe0 && addr <= 16'h2fff) ||
               (addr >= 16'h3fe0 && addr <= 16'h3fff))) begin
        if(stack_read_count==0) stack_read_addr0=addr;
        if(stack_read_count==1) stack_read_addr1=addr;
        stack_read_count=stack_read_count+1;
    end
end

always @(posedge clk) if(nreset && cen_Q && avma) begin
    if(rnw && (addr==16'h0010 || addr==16'h0011))
        tfm_source_reads=tfm_source_reads+1;
    if(!rnw && (addr==16'h0020 || addr==16'h0021))
        tfm_dest_writes=tfm_dest_writes+1;
    if(rnw && (addr==16'hfff0 || addr==16'hfff1))
        illegal_vector_reads=illegal_vector_reads+1;
    if(rnw && (addr==16'hfff8 || addr==16'hfff9))
        irq_vector_reads=irq_vector_reads+1;
    if(rnw && (addr==16'hfff2 || addr==16'hfff3 ||
               addr==16'hfff4 || addr==16'hfff5 ||
               addr==16'hfffa || addr==16'hfffb))
        swi_vector_reads=swi_vector_reads+1;
end

task put(input [15:0] a, input [7:0] value);
    begin
        if(a >= 16'h0100 && a <= 16'h01ff) code_mem[a-16'h0100]=value;
        else if(a < 16'h0100) direct_mem[a[7:0]]=value;
        else if(a >= 16'h2fe0 && a <= 16'h301f) stack_mem[a-16'h2fe0]=value;
        else if(a >= 16'h3fe0 && a <= 16'h401f) user_stack_mem[a-16'h3fe0]=value;
        else if(a >= 16'hfff0) vector_mem[a-16'hfff0]=value;
    end
endtask

task load_program(input [7:0] mode, input [7:0] target_op,
                  input [7:0] target_postbyte,
                  input [7:0] target_extra);
    integer k;
    begin
        cpu_reset_n=0;
        irq_n=1; firq_n=1; nmi_n=1;
        stack_write_count=0; stack_read_count=0;
        stack_write_addr0=16'hffff; stack_write_addr1=16'hffff;
        stack_read_addr0=16'hffff; stack_read_addr1=16'hffff;
        for(k=0;k<256;k=k+1) code_mem[k]=8'h12;
        for(k=0;k<256;k=k+1) direct_mem[k]=8'h12;
        for(k=0;k<64;k=k+1) stack_mem[k]=8'h00;
        for(k=0;k<64;k=k+1) user_stack_mem[k]=8'h00;
        for(k=0;k<16;k=k+1) vector_mem[k]=8'h00;
        // Select MD, set E=$12/F=$34/S=$3000, and branch to the test PC.
        put(16'h0100,8'h11); put(16'h0101,8'h3d); put(16'h0102,mode);
        put(16'h0103,8'h11); put(16'h0104,8'h86); put(16'h0105,initial_e); // LDE immediate
        put(16'h0106,8'h11); put(16'h0107,8'hc6); put(16'h0108,initial_f); // LDF immediate
        put(16'h0109,8'h10); put(16'h010a,8'hce); put(16'h010b,8'h30); put(16'h010c,8'h00); // LDS #$3000
        put(16'h010f,8'hce); put(16'h0110,8'h40); put(16'h0111,8'h00); // LDU #$4000
        put(16'h0112,8'h1a); put(16'h0113,8'h02); // ORCC #$02, sentinel V=1
        put(16'h0114,8'h1c); put(16'h0115,8'haf); // ANDCC #$af, unmask IRQ/FIRQ
        put(16'h0116,8'h7e); put(16'h0117,8'h01); put(16'h0118,8'h20); // JMP $0120
        put(16'h0120,target_op); put(16'h0121,target_postbyte);
        put(16'h0122,target_extra);
        put(16'h0123,8'h12); // closing NOP fetch for three-byte forms
        put(16'hfff6,8'h01); put(16'hfff7,8'h50); // FIRQ vector
        put(16'hfff8,8'h01); put(16'hfff9,8'h50); // IRQ vector
        put(16'hfffc,8'h01); put(16'hfffd,8'h50); // NMI vector
        put(16'h0150,8'h12); // handler NOP; RTI tests replace this byte
        put(16'hfffe,8'h01); put(16'hffff,8'h00);
        repeat(8) @(posedge clk);
        @(negedge clk); cpu_reset_n=1;
    end
endtask

task measure_case(input integer expected_cycles, input [15:0] expected_pc,
                  input string label);
    integer watchdog, interval, measured;
    reg running, done, started;
    begin
        watchdog=0; interval=0; measured=-1;
        running=0; done=0;
        while(!done && watchdog<500) begin
            @(posedge clk);
            if(cen_E) begin
                watchdog=watchdog+1; started=0;
                if(op && addr==16'h0120) begin
                    if(!running) begin
                        running=1; interval=0; started=1;
                        #1 cc_before_target=regs[87:80];
                    end
                end else if(running && op && addr==expected_pc) begin
                    measured=interval+1; done=1;
                end
                if(running && !done && !started) interval=interval+1;
            end
        end
        if(!done) begin $display("FAIL: %s timed out",label); fail(); end
        assert_msg(measured==expected_cycles,
            $sformatf("%s measured %0d E cycles, expected %0d",label,measured,expected_cycles));
    end
endtask

task measure_case_at(input [15:0] start_pc, input integer expected_cycles,
                     input [15:0] expected_pc, input string label);
    integer watchdog, interval, measured;
    reg running, done, started;
    begin
        watchdog=0; interval=0; measured=-1;
        running=0; done=0;
        while(!done && watchdog<500) begin
            @(posedge clk);
            if(cen_E) begin
                watchdog=watchdog+1; started=0;
                if(op && addr==start_pc) begin
                    if(!running) begin
                        running=1; interval=0; started=1;
                        #1 cc_before_target=regs[87:80];
                    end
                end else if(running && op && addr==expected_pc) begin
                    measured=interval+1; done=1;
                end
                if(running && !done && !started) interval=interval+1;
            end
        end
        if(!done) begin $display("FAIL: %s timed out",label); fail(); end
        assert_msg(measured==expected_cycles,
            $sformatf("%s measured %0d E cycles, expected %0d",label,measured,expected_cycles));
    end
endtask

task run_native_firq(input [7:0] mode, input integer expected_stack_bytes,
                     input reg expect_entire, input string label);
    integer watchdog, stack_start;
    reg target_seen, handler_seen;
    begin
        load_program(mode,8'h12,8'h12,8'h12);
        watchdog=0; target_seen=0;
        while(!target_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0120) target_seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(target_seen,$sformatf("%s did not reach target",label));
        @(negedge clk); firq_n=0;
        watchdog=0; handler_seen=0;
        while(!handler_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0150) handler_seen=1;
            watchdog=watchdog+1;
        end
        if(!handler_seen) $display("TRACE: %s no handler after watchdog=%0d state=%0d addr=%04x op=%b irq=%b firq=%b",label,watchdog,uut.CpuState,addr,op,irq_n,firq_n);
        @(negedge clk); firq_n=1;
        assert_msg(handler_seen,$sformatf("%s did not vector",label));
        assert_msg(stack_write_count==expected_stack_bytes,
            $sformatf("%s stack writes=%0d expected %0d",label,stack_write_count,expected_stack_bytes));
        assert_msg(regs[63:48]==(16'h3000-expected_stack_bytes),
            $sformatf("%s S=%04x expected %04x",label,regs[63:48],16'h3000-expected_stack_bytes));
        stack_start=(16'h3000-expected_stack_bytes)-16'h2fe0;
        assert_msg(stack_mem[stack_start][7]==expect_entire,
            $sformatf("%s stacked CC=%02x E-bit expected %0d",label,stack_mem[stack_start],expect_entire));
        // FIRQ is asserted just after the $0120 opcode fetch. The synchronizer
        // permits the native one-E NOP path to fetch $0121 and $0122 before
        // service, so native mode stacks $0123. A two-E emulation NOP reaches
        // service at $0122.
        assert_msg(stack_mem[stack_start+expected_stack_bytes-2]==8'h01 &&
                   stack_mem[stack_start+expected_stack_bytes-1]==8'h23,
            $sformatf("%s stacked PC high/low=%02x/%02x expected 01/23",label,
                      stack_mem[stack_start+expected_stack_bytes-2],
                      stack_mem[stack_start+expected_stack_bytes-1]));
        if(expected_stack_bytes==14) begin
            assert_msg(stack_mem[stack_start+3]==8'h12 && stack_mem[stack_start+4]==8'h34,
                $sformatf("%s stacked E/F=%02x/%02x expected 12/34",label,
                          stack_mem[stack_start+3],stack_mem[stack_start+4]));
        end
    end
endtask

task run_native_short_firq_rti;
    integer watchdog, interval, measured;
    reg target_seen, handler_seen, return_seen;
    begin
        load_program(8'h01,8'h12,8'h12,8'h12);
        put(16'h0150,8'h3b); // RTI
        watchdog=0; target_seen=0;
        while(!target_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0120) target_seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(target_seen,"native short FIRQ/RTI did not reach target");
        @(negedge clk); firq_n=0;
        watchdog=0; handler_seen=0;
        while(!handler_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0150) handler_seen=1;
            watchdog=watchdog+1;
        end
        @(negedge clk); firq_n=1;
        assert_msg(handler_seen,"native short FIRQ did not vector to RTI");
        assert_msg(stack_write_count==3,
            $sformatf("native short FIRQ writes=%0d expected 3",stack_write_count));
        assert_msg(regs[63:48]==16'h2ffd,
            $sformatf("native short FIRQ S=%04x expected 2ffd",regs[63:48]));
        assert_msg(stack_mem[16'h2ffd-16'h2fe0][7]==1'b0,
            $sformatf("native short FIRQ stacked CC=%02x must have E clear",
                      stack_mem[16'h2ffd-16'h2fe0]));
        assert_msg(stack_mem[16'h2ffe-16'h2fe0]==8'h01 &&
                   stack_mem[16'h2fff-16'h2fe0]==8'h23,
            $sformatf("native short FIRQ PC=%02x/%02x expected 01/23",
                      stack_mem[16'h2ffe-16'h2fe0],stack_mem[16'h2fff-16'h2fe0]));

        watchdog=0; interval=0; measured=-1; return_seen=0;
        while(!return_seen && watchdog<200) begin
            @(posedge clk);
            if(cen_E) begin
                if(op && addr==16'h0123) begin
                    measured=interval+1; return_seen=1;
                end else interval=interval+1;
                watchdog=watchdog+1;
            end
        end
        assert_msg(return_seen,"native short FIRQ RTI did not return to $0123");
        assert_msg(measured==6,
            $sformatf("native short-frame RTI measured %0d E cycles, expected 6",measured));
        assert_msg(stack_read_count==3,
            $sformatf("native short-frame RTI reads=%0d expected 3",stack_read_count));
        assert_msg(regs[63:48]==16'h3000,
            $sformatf("native short-frame RTI S=%04x expected 3000",regs[63:48]));
        assert_msg(regs[87:80]==8'h02,
            $sformatf("native short-frame RTI CC=%02x expected 02",regs[87:80]));
        check_ef(8'h12,8'h34,8'h01,"native short-frame RTI preserves W");
    end
endtask

task run_native_irq_rti;
    integer watchdog;
    reg target_seen, handler_seen, return_seen;
    begin
        load_program(8'h01,8'h12,8'h12,8'h12);
        put(16'h0150,8'h3b); // RTI
        watchdog=0; target_seen=0;
        while(!target_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0120) target_seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(target_seen,"native IRQ/RTI did not reach target");
        @(negedge clk); irq_n=0;
        watchdog=0; handler_seen=0;
        while(!handler_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0150) handler_seen=1;
            watchdog=watchdog+1;
        end
        if(!handler_seen) $display("TRACE: IRQ did not reach handler watchdog=%0d state=%0d addr=%04x op=%b irq=%b",watchdog,uut.CpuState,addr,op,irq_n);
        assert_msg(handler_seen,"native IRQ did not vector");
        @(negedge clk); irq_n=1;
        watchdog=0; return_seen=0;
        while(!return_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0123) return_seen=1;
            watchdog=watchdog+1;
        end
        if(!return_seen) $display("TRACE: IRQ/RTI no return after watchdog=%0d state=%0d addr=%04x op=%b irq=%b writes=%0d reads=%0d",watchdog,uut.CpuState,addr,op,irq_n,stack_write_count,stack_read_count);
        assert_msg(return_seen,"native IRQ/RTI did not return to interrupted PC");
        assert_msg(stack_write_count==14 && stack_read_count==14,
            $sformatf("native IRQ/RTI stack writes/reads=%0d/%0d expected 14/14",
                      stack_write_count,stack_read_count));
        assert_msg(regs[63:48]==16'h3000,"native IRQ/RTI must restore S");
        check_ef(8'h12,8'h34,8'h01,"native IRQ/RTI restore W");
        assert_msg(stack_mem[16'h2ff2-16'h2fe0][7],
            $sformatf("native IRQ stacked CC=%02x must have E set",stack_mem[16'h2ff2-16'h2fe0]));
        assert_msg(stack_mem[16'h2ff5-16'h2fe0]==8'h12 &&
                   stack_mem[16'h2ff6-16'h2fe0]==8'h34,
            $sformatf("native IRQ stacked E/F=%02x/%02x expected 12/34",
                      stack_mem[16'h2ff5-16'h2fe0],stack_mem[16'h2ff6-16'h2fe0]));
        assert_msg(stack_mem[16'h2ffe-16'h2fe0]==8'h01 &&
                   stack_mem[16'h2fff-16'h2fe0]==8'h23,
            $sformatf("native IRQ stacked PC high/low=%02x/%02x expected 01/23",
                      stack_mem[16'h2ffe-16'h2fe0],stack_mem[16'h2fff-16'h2fe0]));
    end
endtask

task check_native_full_frame(input [15:0] saved_pc, input string label);
    integer base;
    begin
        base=16'h2ff2-16'h2fe0;
        assert_msg(stack_write_count==14 && regs[63:48]==16'h2ff2,
            $sformatf("%s frame writes/S=%0d/%04x expected 14/2ff2",
                      label,stack_write_count,regs[63:48]));
        assert_msg(stack_mem[base][7] &&
                   stack_mem[base+3]==8'h12 && stack_mem[base+4]==8'h34,
            $sformatf("%s CC/E/F=%02x/%02x/%02x expected E,12,34",
                      label,stack_mem[base],stack_mem[base+3],stack_mem[base+4]));
        assert_msg(stack_mem[base+12]==saved_pc[15:8] &&
                   stack_mem[base+13]==saved_pc[7:0],
            $sformatf("%s stacked PC=%02x/%02x expected %04x",label,
                      stack_mem[base+12],stack_mem[base+13],saved_pc));
    end
endtask

task run_native_software_interrupt(input [7:0] opcode0, input [7:0] opcode1,
                                   input [15:0] vector_addr,
                                   input [15:0] saved_pc,
                                   input integer expected_cycles,
                                   input string label);
    integer watchdog;
    reg return_seen;
    begin
        initial_e=8'h12; initial_f=8'h34;
        load_program(8'h01,opcode0,opcode1,8'h12);
        if(opcode0==8'h10 || opcode0==8'h11) begin
            put(16'h0122,8'h12);
        end
        put(vector_addr,8'h01); put(vector_addr+1'b1,8'h50);
        // Mutate E/F inside the handler so the subsequent RTI proves they came
        // from the fourteen-byte full native frame.
        put(16'h0150,8'h11); put(16'h0151,8'h86); put(16'h0152,8'haa);
        put(16'h0153,8'h11); put(16'h0154,8'hc6); put(16'h0155,8'hbb);
        put(16'h0156,8'h3b);
        swi_vector_reads=0;
        measure_case_at(16'h0120,expected_cycles,16'h0150,label);
        check_native_full_frame(saved_pc,label);
        assert_msg(swi_vector_reads>=2,
            $sformatf("%s vector reads=%0d expected >=2",label,swi_vector_reads));
        watchdog=0; return_seen=0;
        while(!return_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==saved_pc) return_seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(return_seen,
            $sformatf("%s RTI did not return to %04x",label,saved_pc));
        assert_msg(stack_read_count==14 && regs[63:48]==16'h3000,
            $sformatf("%s RTI reads/S=%0d/%04x expected 14/3000",
                      label,stack_read_count,regs[63:48]));
        check_ef(8'h12,8'h34,8'h01,label);
    end
endtask

task run_emulation_software_interrupt(input [7:0] opcode0, input [7:0] opcode1,
                                      input [15:0] vector_addr,
                                      input [15:0] saved_pc,
                                      input integer expected_cycles,
                                      input string label);
    integer base;
    begin
        initial_e=8'h12; initial_f=8'h34;
        load_program(8'h00,opcode0,opcode1,8'h12);
        put(vector_addr,8'h01); put(vector_addr+1'b1,8'h50);
        put(16'h0150,8'h12);
        swi_vector_reads=0;
        measure_case_at(16'h0120,expected_cycles,16'h0150,label);
        base=16'h2ff4-16'h2fe0;
        assert_msg(stack_write_count==12 && regs[63:48]==16'h2ff4,
            $sformatf("%s emulation frame writes/S=%0d/%04x expected 12/2ff4",
                      label,stack_write_count,regs[63:48]));
        assert_msg(stack_mem[base][7] &&
                   stack_mem[base+10]==saved_pc[15:8] &&
                   stack_mem[base+11]==saved_pc[7:0],
            $sformatf("%s frame CC/PC=%02x/%02x%02x expected E and %04x",
                      label,stack_mem[base],stack_mem[base+10],stack_mem[base+11],saved_pc));
        assert_msg(swi_vector_reads>=2,
            $sformatf("%s vector reads=%0d expected >=2",label,swi_vector_reads));
    end
endtask

task run_native_cwai_irq;
    integer watchdog, writes_before, interval, entry_cycles;
    reg cwai_wait, handler_seen, return_seen, running, started;
    begin
        initial_e=8'h12; initial_f=8'h34;
        load_program(8'h01,8'h3c,8'h00,8'h12); // CWAI #$00
        put(16'hfff8,8'h01); put(16'hfff9,8'h50);
        put(16'h0150,8'h11); put(16'h0151,8'h86); put(16'h0152,8'haa);
        put(16'h0153,8'h11); put(16'h0154,8'hc6); put(16'h0155,8'hbb);
        put(16'h0156,8'h3b);
        irq_vector_reads=0;
        watchdog=0; cwai_wait=0; interval=0; entry_cycles=-1; running=0;
        while(!cwai_wait && watchdog<1000) begin
            @(posedge clk);
            if(cen_E) begin
                watchdog=watchdog+1; started=0;
                if(op && addr==16'h0120 && !running) begin
                    running=1; interval=0; started=1;
                end
                if(running && !cwai_wait && !started) interval=interval+1;
                #1;
                if(running && uut.CpuState==8'd110) begin
                    cwai_wait=1; entry_cycles=interval+1;
                end
            end
        end
        assert_msg(cwai_wait,"native CWAI did not enter wait state");
        assert_msg(entry_cycles==20,
            $sformatf("native CWAI entry measured %0d E, Atkinson expects 20",entry_cycles));
        check_native_full_frame(16'h0122,"native CWAI");
        writes_before=stack_write_count;
        @(negedge clk); irq_n=0;
        watchdog=0; handler_seen=0;
        while(!handler_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0150) handler_seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(handler_seen,"native CWAI IRQ did not reach handler");
        assert_msg(irq_vector_reads>=2,
            $sformatf("native CWAI IRQ vector reads=%0d expected >=2",irq_vector_reads));
        assert_msg(stack_write_count==writes_before,
            "native CWAI IRQ wake must not push a second frame");
        @(negedge clk); irq_n=1;
        watchdog=0; return_seen=0;
        while(!return_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0122) return_seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(return_seen,"native CWAI RTI did not return to $0122");
        assert_msg(stack_read_count==14 && regs[63:48]==16'h3000,
            $sformatf("native CWAI RTI reads/S=%0d/%04x expected 14/3000",
                      stack_read_count,regs[63:48]));
        check_ef(8'h12,8'h34,8'h01,"native CWAI RTI");
    end
endtask

task run_emulation_cwai_timing;
    integer watchdog, interval, entry_cycles;
    reg running, entered, started;
    integer base;
    begin
        initial_e=8'h12; initial_f=8'h34;
        load_program(8'h00,8'h3c,8'h00,8'h12); // CWAI #$00
        watchdog=0; interval=0; entry_cycles=-1; running=0; entered=0;
        while(!entered && watchdog<1000) begin
            @(posedge clk);
            if(cen_E) begin
                watchdog=watchdog+1; started=0;
                if(op && addr==16'h0120 && !running) begin
                    running=1; interval=0; started=1;
                end
                if(running && !entered && !started) interval=interval+1;
                #1;
                if(running && uut.CpuState==8'd110) begin
                    entered=1; entry_cycles=interval+1;
                end
            end
        end
        assert_msg(entered,"emulation CWAI did not enter wait state");
        assert_msg(entry_cycles==22,
            $sformatf("emulation CWAI entry measured %0d E, Atkinson p.145-148 expects 22",entry_cycles));
        base=16'h2ff4-16'h2fe0;
        assert_msg(stack_write_count==12 && regs[63:48]==16'h2ff4,
            $sformatf("emulation CWAI frame writes/S=%0d/%04x expected 12/2ff4",
                      stack_write_count,regs[63:48]));
        assert_msg(stack_mem[base][7] &&
                   stack_mem[base+10]==8'h01 && stack_mem[base+11]==8'h22,
            $sformatf("emulation CWAI frame CC/PC=%02x/%02x%02x expected E/0122",
                      stack_mem[base],stack_mem[base+10],stack_mem[base+11]));
    end
endtask

task run_sync_native_minimum;
    integer watchdog, interval, entry_cycles;
    reg running, entered, started, handler_seen;
    begin
        load_program(8'h01,8'h13,8'h12,8'h12); // SYNC
        watchdog=0; interval=0; entry_cycles=-1; running=0; entered=0;
        while(!entered && watchdog<1000) begin
            @(posedge clk);
            if(cen_E) begin
                watchdog=watchdog+1; started=0;
                if(op && addr==16'h0120 && !running) begin
                    running=1; interval=0; started=1;
                end
                if(running && !entered && !started) interval=interval+1;
                #1;
                if(running && uut.CpuState==8'd113) begin
                    entered=1; entry_cycles=interval+1;
                end
            end
        end
        assert_msg(entered,"native SYNC did not enter wait state");
        assert_msg(entry_cycles>=3,
            $sformatf("native SYNC entry measured %0d E, minimum is 3",entry_cycles));
        assert_msg(!avma && ba,"native SYNC wait state bus controls mismatch");
        @(negedge clk); irq_n=0;
        watchdog=0; handler_seen=0;
        while(!handler_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E) begin
                watchdog=watchdog+1;
                if(op && addr==16'h0150) handler_seen=1;
            end
        end
        assert_msg(handler_seen,"native SYNC IRQ did not reach handler");
        @(negedge clk); irq_n=1;
    end
endtask

task run_sync_emulation_minimum;
    integer watchdog, interval, entry_cycles;
    reg running, entered, started;
    begin
        load_program(8'h00,8'h13,8'h12,8'h12); // SYNC
        watchdog=0; interval=0; entry_cycles=-1; running=0; entered=0;
        while(!entered && watchdog<1000) begin
            @(posedge clk);
            if(cen_E) begin
                watchdog=watchdog+1; started=0;
                if(op && addr==16'h0120 && !running) begin
                    running=1; interval=0; started=1;
                end
                if(running && !entered && !started) interval=interval+1;
                #1;
                if(running && uut.CpuState==8'd113) begin
                    entered=1; entry_cycles=interval+1;
                end
            end
        end
        assert_msg(entered,"emulation SYNC did not enter wait state");
        assert_msg(entry_cycles>=4,
            $sformatf("emulation SYNC entry measured %0d E, Atkinson p.148 minimum is 4",entry_cycles));
        assert_msg(!avma && ba,"emulation SYNC wait state bus controls mismatch");
    end
endtask

task run_direct_word(input [7:0] page, input [7:0] opcode,
                     input [15:0] expected, input integer emu_cycles,
                     input integer native_cycles, input string label);
    integer expected_cycles;
    begin
        initial_e=8'h12; initial_f=8'h34;
        load_program(1'b0,page,opcode,8'h40);
        if(opcode==8'h98) preload_d(16'h1234);
        direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h01;
        expected_cycles=emu_cycles;
        measure_case(expected_cycles,16'h0123,$sformatf("%s emulation",label));
        if(opcode==8'h9b || opcode==8'h90)
            assert_msg(regs6309[31:16]==expected,
                $sformatf("%s W=%04x expected %04x",label,regs6309[31:16],expected));
        else if(opcode==8'h98)
            assert_msg({regs[7:0],regs[15:8]}==expected,
                $sformatf("%s D=%04x expected %04x",label,{regs[7:0],regs[15:8]},expected));
        else if(opcode==8'h93 || opcode==8'h9c)
            assert_msg((opcode==8'h93 ? regs[79:64] : regs[63:48])==expected,
                $sformatf("%s comparison register=%04x expected %04x",label,
                          opcode==8'h93 ? regs[79:64] : regs[63:48],expected));
        load_program(1'b1,page,opcode,8'h40);
        if(opcode==8'h98) preload_d(16'h1234);
        direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h01;
        measure_case(native_cycles,16'h0123,$sformatf("%s native",label));
        if(opcode==8'h9b || opcode==8'h90)
            assert_msg(regs6309[31:16]==expected,
                $sformatf("%s native W=%04x expected %04x",label,regs6309[31:16],expected));
        else if(opcode==8'h98)
            assert_msg({regs[7:0],regs[15:8]}==expected,
                $sformatf("%s native D=%04x expected %04x",label,
                          {regs[7:0],regs[15:8]},expected));
        else if(opcode==8'h93 || opcode==8'h9c)
            assert_msg((opcode==8'h93 ? regs[79:64] : regs[63:48])==expected,
                $sformatf("%s native comparison register=%04x expected %04x",label,
                          opcode==8'h93 ? regs[79:64] : regs[63:48],expected));
    end
endtask

task run_cmpu_immediate;
    begin
        load_program(1'b0,8'h11,8'h83,8'h00); put(16'h0122,8'h01); put(16'h0123,8'h12);
        measure_case(5,16'h0124,"CMPU immediate emulation");
        assert_msg(regs[79:64]==16'h4000,"CMPU immediate changed U in emulation");
        load_program(1'b1,8'h11,8'h83,8'h00); put(16'h0122,8'h01); put(16'h0123,8'h12);
        measure_case(4,16'h0124,"CMPU immediate native");
        assert_msg(regs[79:64]==16'h4000,"CMPU immediate changed U in native");
    end
endtask

task run_bitmd(input [7:0] mode, input [7:0] mask, input reg set_il,
               input reg expected_z, input string label);
    reg [7:0] expected_md;
    begin
        initial_e=8'h12; initial_f=8'h34;
        if(set_il) load_program(mode,8'h10,8'h41,8'h12);
        else load_program(mode,8'h11,8'h3c,mask);
        expected_md=mode;
        if(set_il) begin
            // LDMD cannot write sticky status bits. Trap on an illegal
            // prefixed instruction, then execute BITMD directly in the trap
            // handler while MD.IL is set. BITMD clears the tested sticky bit.
            put(16'hfff0,8'h01); put(16'hfff1,8'h50);
            put(16'h0150,8'h11); put(16'h0151,8'h3c); put(16'h0152,mask);
            put(16'h0153,8'h12);
            measure_case_at(16'h0150,4,16'h0153,label);
        end else begin
            measure_case(4,16'h0123,label);
        end
        assert_msg(regs6309[55:48]==expected_md,
            $sformatf("%s MD=%02x expected %02x",label,regs6309[55:48],expected_md));
        assert_msg(regs[82]==expected_z,
            $sformatf("%s Z=%b expected %b",label,regs[82],expected_z));
    end
endtask

task run_ldq_direct;
    begin
        initial_e=0; initial_f=1;
        load_program(1'b0,8'h10,8'hdc,8'h40);
        direct_mem[8'h40]=8'h12; direct_mem[8'h41]=8'h34;
        direct_mem[8'h42]=8'h56; direct_mem[8'h43]=8'h78;
        measure_case(8,16'h0123,"LDQ direct emulation");
        assert_msg({regs[7:0],regs[15:8],regs6309[31:16]}==32'h12345678,
            "LDQ direct emulation Q mismatch");
        load_program(1'b1,8'h10,8'hdc,8'h40);
        direct_mem[8'h40]=8'h12; direct_mem[8'h41]=8'h34;
        direct_mem[8'h42]=8'h56; direct_mem[8'h43]=8'h78;
        measure_case(7,16'h0123,"LDQ direct native");
        assert_msg({regs[7:0],regs[15:8],regs6309[31:16]}==32'h12345678,
            "LDQ direct native Q mismatch");
    end
endtask

task run_ldq_immediate;
    begin
        load_program(1'b0,8'hcd,8'h12,8'h34);
        put(16'h0121,8'h12); put(16'h0122,8'h34);
        put(16'h0123,8'h56); put(16'h0124,8'h78); put(16'h0125,8'h12);
        measure_case(5,16'h0125,"LDQ immediate emulation");
        assert_msg({regs[7:0],regs[15:8],regs6309[31:16]}==32'h12345678,
            "LDQ immediate emulation Q mismatch");
        load_program(1'b1,8'hcd,8'h12,8'h34);
        put(16'h0121,8'h12); put(16'h0122,8'h34);
        put(16'h0123,8'h56); put(16'h0124,8'h78); put(16'h0125,8'h12);
        measure_case(5,16'h0125,"LDQ immediate native");
        assert_msg({regs[7:0],regs[15:8],regs6309[31:16]}==32'h12345678,
            "LDQ immediate native Q mismatch");
    end
endtask

task run_rr_cc_destination(input [7:0] mode, input [7:0] opcode,
                           input [7:0] expected_cc, input string label);
    begin
        initial_e=8'h12; initial_f=8'h34;
        // Postbyte $CA selects the reserved zero source and CC destination.
        // Clear CC after the register setup so each operation starts with
        // zero and the generated Z flag must be merged into the destination.
        load_program(mode,8'h10,opcode,8'hca);
        put(16'h0112,8'h1c); put(16'h0113,8'hf0); // ANDCC #$F0
        measure_case(4,16'h0123,label);
        assert_msg(regs[87:80]==expected_cc,
            $sformatf("%s CC=%02x expected %02x",label,regs[87:80],expected_cc));
    end
endtask

task run_rr_carry(input [7:0] mode, input [7:0] opcode,
                  input [7:0] src, input [7:0] dst,
                  input [7:0] expected_dst, input [3:0] expected_nzvc,
                  input string label);
    begin
        initial_e=src; initial_f=dst;
        load_program(mode,8'h10,opcode,8'hef);
        put(16'h0113,8'h03);
        measure_case(4,16'h0123,label);
        check_ef(src,expected_dst,mode[0],label);
        assert_msg(regs[83:80]==expected_nzvc,
            $sformatf("%s flags NZVC=%x expected %x",label,regs[83:80],expected_nzvc));
    end
endtask

task run_rr_mixed_width(input [7:0] mode, input [7:0] opcode,
                        input [7:0] postbyte, input [15:0] expected_d,
                        input [15:0] expected_w, input [7:0] expected_f,
                        input string label);
    begin
        initial_e=8'h12; initial_f=8'h34;
        load_program(mode,8'h10,opcode,postbyte);
        // Establish D=$1234 and DP=$12. W is already $1234 from E/F.
        // Carry is set so the CC-as-source case distinguishes $00CC from
        // sign extension and unrelated register substitutions.
        put(16'h010d,8'hcc); put(16'h010e,8'h12); put(16'h010f,8'h34); // LDD #$1234
        put(16'h0110,8'h1f); put(16'h0111,8'h8b); // TFR A,DP
        put(16'h0112,8'h1a); put(16'h0113,8'h01); // ORCC #$01
        measure_case(4,16'h0123,label);
        assert_msg({regs[7:0],regs[15:8]}==expected_d,
            $sformatf("%s D=%04x expected %04x",label,
                      {regs[7:0],regs[15:8]},expected_d));
        assert_msg(regs6309[31:16]==expected_w,
            $sformatf("%s W=%04x expected %04x",label,regs6309[31:16],expected_w));
        assert_msg(regs6309[15:8]==expected_f,
            $sformatf("%s F=%02x expected %02x",label,regs6309[15:8],expected_f));
    end
endtask

task run_lda_extended_indirect_native;
    begin
        load_program(1'b1,8'ha6,8'h9f,8'h00);
        put(16'h0122,8'h00); put(16'h0123,8'h40);
        put(16'h0040,8'h00); put(16'h0041,8'h50); put(16'h0050,8'h5a);
        measure_case(8,16'h0124,"LDA [extended] indexed native");
        assert_msg(regs[7:0]==8'h5a,
            $sformatf("LDA [extended] indexed native A=%02x expected 5a",regs[7:0]));
    end
endtask

task run_unary_mem(input [7:0] mode, input [7:0] opcode,
                   input reg extended, input integer expected_cycles,
                   input [7:0] expected_mem, input string label);
    reg [15:0] closing_pc;
    begin
        if(extended) begin
            load_program(mode,opcode,8'h00,8'h40);
            closing_pc=16'h0123;
        end else begin
            load_program(mode,opcode,8'h40,8'h12);
            closing_pc=16'h0122;
        end
        direct_mem[8'h40]=8'ha5;
        measure_case(expected_cycles,closing_pc,label);
        assert_msg(direct_mem[8'h40]==expected_mem,
            $sformatf("%s memory[40]=%02x expected %02x",label,
                      direct_mem[8'h40],expected_mem));
    end
endtask

task run_jump_call(input [7:0] mode, input [7:0] opcode,
                   input reg extended, input reg is_jsr,
                   input integer expected_cycles, input string label);
    reg [15:0] closing_pc, return_pc;
    begin
        if(extended) begin
            load_program(mode,opcode,8'h00,8'h40);
            return_pc=16'h0123;
        end else begin
            load_program(mode,opcode,8'h40,8'h12);
            return_pc=16'h0122;
        end
        direct_mem[8'h40]=8'h12;
        closing_pc=16'h0040;
        measure_case(expected_cycles,closing_pc,label);
        if(is_jsr) begin
            assert_msg(stack_write_count==2,
                $sformatf("%s stack writes=%0d expected 2",label,stack_write_count));
            assert_msg(regs[63:48]==16'h2ffe,
                $sformatf("%s S=%04x expected 2ffe",label,regs[63:48]));
            assert_msg(stack_mem[16'h2ffe-16'h2fe0]==return_pc[15:8] &&
                       stack_mem[16'h2fff-16'h2fe0]==return_pc[7:0],
                $sformatf("%s return PC bytes=%02x/%02x expected %04x",
                          label,stack_mem[16'h2ffe-16'h2fe0],
                          stack_mem[16'h2fff-16'h2fe0],return_pc));
        end else begin
            assert_msg(stack_write_count==0,
                $sformatf("%s unexpectedly wrote %0d stack bytes",label,stack_write_count));
            assert_msg(regs[63:48]==16'h3000,
                $sformatf("%s changed S=%04x",label,regs[63:48]));
        end
    end
endtask

task run_indexed_jump_call(input [7:0] mode, input [7:0] opcode,
                           input reg is_jsr, input integer expected_cycles,
                           input string label);
    begin
        load_program(mode,opcode,8'h84,8'h12); // ,X
        put(16'h010d,8'h8e); put(16'h010e,8'h00); put(16'h010f,8'h10); // LDX #$0010
        put(16'h0110,8'h10); put(16'h0111,8'h8e); put(16'h0112,8'h00); put(16'h0113,8'h20); // LDY #$0020
        direct_mem[8'h10]=8'h12;
        measure_case(expected_cycles,16'h0010,label);
        if(is_jsr) begin
            assert_msg(stack_write_count==2 && regs[63:48]==16'h2ffe,
                $sformatf("%s stack writes/S=%0d/%04x expected 2/2ffe",
                          label,stack_write_count,regs[63:48]));
            assert_msg(stack_mem[16'h2ffe-16'h2fe0]==8'h01 &&
                       stack_mem[16'h2fff-16'h2fe0]==8'h22,
                $sformatf("%s stacked return PC=%02x/%02x expected 01/22",
                          label,stack_mem[16'h2ffe-16'h2fe0],
                          stack_mem[16'h2fff-16'h2fe0]));
        end else begin
            assert_msg(stack_write_count==0 && regs[63:48]==16'h3000,
                $sformatf("%s changed stack writes/S=%0d/%04x",
                          label,stack_write_count,regs[63:48]));
        end
    end
endtask

task run_relative(input [7:0] mode, input [7:0] opcode,
                  input [15:0] target, input integer expected_cycles,
                  input reg subroutine, input [15:0] return_pc,
                  input string label);
    begin
        if(opcode==8'h8d) load_program(mode,opcode,8'h02,8'h12);
        else load_program(mode,opcode,8'h00,8'h02);
        direct_mem[8'h40]=8'h12;
        measure_case(expected_cycles,target,label);
        if(subroutine) begin
            assert_msg(stack_write_count==2 && regs[63:48]==16'h2ffe,
                $sformatf("%s stack writes/S=%0d/%04x expected 2/2ffe",
                          label,stack_write_count,regs[63:48]));
            assert_msg(stack_mem[16'h2ffe-16'h2fe0]==return_pc[15:8] &&
                       stack_mem[16'h2fff-16'h2fe0]==return_pc[7:0],
                $sformatf("%s stacked return PC=%02x/%02x expected %04x",
                          label,stack_mem[16'h2ffe-16'h2fe0],
                          stack_mem[16'h2fff-16'h2fe0],return_pc));
        end
    end
endtask

task run_puls_zero(input [7:0] mode, input integer expected_cycles,
                   input string label);
    begin
        load_program(mode,8'h35,8'h00,8'h12);
        measure_case(expected_cycles,16'h0122,label);
        assert_msg(stack_read_count==0 && regs[63:48]==16'h3000,
            $sformatf("%s stack reads/S=%0d/%04x expected 0/3000",
                      label,stack_read_count,regs[63:48]));
    end
endtask

task run_sex(input [7:0] mode, input integer expected_cycles,
             input [7:0] expected_a, input string label);
    begin
        load_program(mode,8'h1d,8'h12,8'h12);
        put(16'h0116,8'hc6); put(16'h0117,8'h22); // LDB #$22
        put(16'h0118,8'h1a); put(16'h0119,8'h02); // ORCC #$02, seed V after LDB
        put(16'h011a,8'h7e); put(16'h011b,8'h01); put(16'h011c,8'h20); // JMP $0120
        measure_case(expected_cycles,16'h0121,label);
        assert_msg(cc_before_target[1] && regs[81],
            $sformatf("%s failed to preserve V: before=%02x after=%02x",
                      label,cc_before_target,regs[87:80]));
        assert_msg(regs[7:0]==expected_a && regs[15:8]==8'h22,
            $sformatf("%s A/B=%02x/%02x expected %02x/22",
                      label,regs[7:0],regs[15:8],expected_a));
    end
endtask

task run_hd_illegal_case(input [7:0] mode, input [7:0] opcode,
                         input [7:0] postbyte, input [7:0] extra,
                         input string label);
    integer watchdog;
    reg handler_seen;
    begin
        load_program(mode,opcode,postbyte,extra);
        put(16'hfff0,8'h01); put(16'hfff1,8'h60);
        put(16'h0160,8'h12);
        watchdog=0; handler_seen=0; illegal_vector_reads=0;
        while(!handler_seen && watchdog<500) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0160) handler_seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(handler_seen,
            $sformatf("%s did not reach $fff0 handler",label));
        assert_msg(regs6309[54],
            $sformatf("%s did not set MD.IL: MD=%02x",label,regs6309[55:48]));
        assert_msg(illegal_vector_reads>=2,
            $sformatf("%s vector reads=%0d expected FFF0/FFF1",label,illegal_vector_reads));
    end
endtask

task run_bitop(input [7:0] mode, input [7:0] opcode, input [7:0] acc,
               input [7:0] memory, input [7:0] expected_acc,
               input [7:0] expected_memory, input integer expected_cycles,
               input string label);
    begin
        load_program(mode,8'h11,opcode,8'h69); // A, source bit 5, destination bit 1
        put(16'h0116,8'h86); put(16'h0117,acc);   // LDA #accumulator seed
        put(16'h0118,8'h1a); put(16'h0119,8'h0f); // ORCC #$0f, flag preservation sentinel
        put(16'h011a,8'h7e); put(16'h011b,8'h01); put(16'h011c,8'h20); // JMP $0120
        put(16'h0123,8'h40); put(16'h0124,8'h12); // direct address and closing NOP
        direct_mem[8'h40]=memory;
        measure_case(expected_cycles,16'h0124,label);
        assert_msg(regs[7:0]==expected_acc,
            $sformatf("%s A=%02x expected %02x",label,regs[7:0],expected_acc));
        assert_msg(regs[87:80]==8'h0f,
            $sformatf("%s CC=%02x expected preserved 0f",label,regs[87:80]));
        assert_msg(direct_mem[8'h40]==expected_memory,
            $sformatf("%s memory=%02x expected %02x",label,direct_mem[8'h40],expected_memory));
    end
endtask

task run_tfm_xy(input [7:0] mode, input [7:0] opcode, input [7:0] postbyte,
                input [15:0] count, input [15:0] x_start,
                input [15:0] y_start, input [15:0] expected_x,
                input [15:0] expected_y, input integer transfers,
                input [7:0] expected_y0, input [7:0] expected_y1,
                input string label);
    begin
        initial_e=count[15:8]; initial_f=count[7:0];
        load_program(mode,8'h11,opcode,postbyte);
        // LDX #x_start; LDY #y_start; JMP $0120 (ten bytes).
        put(16'h0116,8'h8e); put(16'h0117,x_start[15:8]); put(16'h0118,x_start[7:0]);
        put(16'h0119,8'h10); put(16'h011a,8'h8e);
        put(16'h011b,y_start[15:8]); put(16'h011c,y_start[7:0]);
        put(16'h011d,8'h7e); put(16'h011e,8'h01); put(16'h011f,8'h20);
        direct_mem[8'h40]=8'haa; direct_mem[8'h41]=8'hbb;
        direct_mem[8'h60]=8'h00; direct_mem[8'h61]=8'h00;
        measure_case(6+3*transfers,16'h0123,label);
        assert_msg(regs[31:16]==expected_x,
            $sformatf("%s X=%04x expected %04x",label,regs[31:16],expected_x));
        assert_msg(regs[47:32]==expected_y,
            $sformatf("%s Y=%04x expected %04x",label,regs[47:32],expected_y));
        assert_msg(regs6309[31:16]==0,
            $sformatf("%s W=%04x expected 0000",label,regs6309[31:16]));
        assert_msg(regs[82],$sformatf("%s completion must set CC.Z",label));
        assert_msg(direct_mem[8'h60]==expected_y0 && direct_mem[8'h61]==expected_y1,
            $sformatf("%s destination bytes=%02x/%02x expected %02x/%02x",label,
                      direct_mem[8'h60],direct_mem[8'h61],expected_y0,expected_y1));
    end
endtask

task run_tfm_du(input [7:0] mode, input [15:0] count, input [15:0] d_start,
                input [7:0] opcode, input [7:0] postbyte, input integer transfers,
                input string label);
    begin
        initial_e=count[15:8]; initial_f=count[7:0];
        load_program(mode,8'h11,opcode,postbyte);
        // LDD #d_start; U is already initialized to $4000; JMP $0120.
        put(16'h0116,8'hcc); put(16'h0117,d_start[15:8]); put(16'h0118,d_start[7:0]);
        put(16'h0119,8'h7e); put(16'h011a,8'h01); put(16'h011b,8'h20);
        direct_mem[8'h40]=8'hde; direct_mem[8'h41]=8'had;
        user_stack_mem[32]=8'h00; user_stack_mem[33]=8'h00;
        measure_case(6+3*transfers,16'h0123,label);
        assert_msg({regs[7:0],regs[15:8]}==16'h0042,
            $sformatf("%s D=%02x%02x expected 0042",label,regs[7:0],regs[15:8]));
        assert_msg(regs[79:64]==16'h4000+transfers,
            $sformatf("%s U=%04x expected %04x",label,regs[79:64],16'h4000+transfers));
        assert_msg(regs6309[31:16]==0,
            $sformatf("%s W=%04x expected 0000",label,regs6309[31:16]));
        if(transfers>0)
            assert_msg(user_stack_mem[32]==8'hde && user_stack_mem[33]==8'had,
                $sformatf("%s destination bytes=%02x/%02x expected de/ad",label,
                          user_stack_mem[32],user_stack_mem[33]));
    end
endtask

task run_tfm_same(input [7:0] opcode, input [15:0] x_start,
                  input [15:0] expected_x, input [15:0] count,
                  input integer transfers, input [7:0] expected_at40,
                  input [7:0] expected_at41, input string label);
    begin
        initial_e=count[15:8]; initial_f=count[7:0];
        load_program(8'h01,8'h11,opcode,8'h11); // X is both operands
        put(16'h0116,8'h8e); put(16'h0117,x_start[15:8]); put(16'h0118,x_start[7:0]);
        put(16'h0119,8'h10); put(16'h011a,8'h8e); put(16'h011b,8'h00); put(16'h011c,8'h60);
        put(16'h011d,8'h7e); put(16'h011e,8'h01); put(16'h011f,8'h20);
        direct_mem[8'h40]=8'haa; direct_mem[8'h41]=8'hbb;
        direct_mem[8'h42]=8'hcc; direct_mem[8'h43]=8'hdd;
        measure_case(6+3*transfers,16'h0123,label);
        assert_msg(regs[31:16]==expected_x,
            $sformatf("%s X=%04x expected %04x",label,regs[31:16],expected_x));
        assert_msg(regs6309[31:16]==0,
            $sformatf("%s W=%04x expected 0000",label,regs6309[31:16]));
        // Hoglet's original-device capture documents X+,X+ as a read at X,
        // write at incremented X, then repeat. The measured X+/X+ case checks
        // the serial destination address directly; X-/X- remains permissive.
        if(opcode==8'h38)
            assert_msg(direct_mem[8'h40]==expected_at40 && direct_mem[8'h41]==expected_at41 &&
                       direct_mem[8'h42]==8'hcc && direct_mem[8'h43]==8'hcc,
                $sformatf("%s memory[40:43]=%02x/%02x/%02x/%02x expected %02x/%02x/cc/cc",
                          label,direct_mem[8'h40],direct_mem[8'h41],
                          direct_mem[8'h42],direct_mem[8'h43],expected_at40,expected_at41));
        else
            assert_msg((direct_mem[8'h40]==expected_at40 && direct_mem[8'h41]==expected_at41) ||
                       (direct_mem[8'h40]==8'haa && direct_mem[8'h41]==8'hbb),
                $sformatf("%s memory[40:41]=%02x/%02x unexpected data",
                          label,direct_mem[8'h40],direct_mem[8'h41]));
    end
endtask

task run_tfm_su(input [15:0] count, input integer transfers, input string label);
    begin
        initial_e=count[15:8]; initial_f=count[7:0];
        load_program(8'h01,8'h11,8'h38,8'h43); // TFM S+,U+
        stack_mem[32]=8'hc3; stack_mem[33]=8'hd4;
        user_stack_mem[32]=8'h00; user_stack_mem[33]=8'h00;
        measure_case(6+3*transfers,16'h0123,label);
        assert_msg(regs[63:48]==16'h3000+transfers,
            $sformatf("%s S=%04x expected %04x",label,regs[63:48],16'h3000+transfers));
        assert_msg(regs[79:64]==16'h4000+transfers,
            $sformatf("%s U=%04x expected %04x",label,regs[79:64],16'h4000+transfers));
        assert_msg(regs6309[31:16]==0,
            $sformatf("%s W=%04x expected 0000",label,regs6309[31:16]));
        if(transfers>0)
            assert_msg(user_stack_mem[32]==8'hc3 && user_stack_mem[33]==8'hd4,
                $sformatf("%s destination bytes=%02x/%02x expected c3/d4",label,
                          user_stack_mem[32],user_stack_mem[33]));
    end
endtask

task run_bitop_matrix_case(input integer instruction, input integer selector,
                           input integer srcbit, input integer dstbit,
                           input integer memlevel);
    reg [7:0] before_reg, expected_reg, expected_mem, mask;
    reg oldbit, sourcebit, newbit;
    reg [7:0] postbyte;
    integer cycles;
    begin
        initial_e=0; initial_f=1;
        postbyte=(selector<<6)|(srcbit<<3)|dstbit;
        load_program(8'h00,8'h11,8'h30+instruction,postbyte);
        put(16'h0112,8'h86); put(16'h0113,8'h5a); // LDA #$5a
        put(16'h0114,8'hc6); put(16'h0115,8'ha5); // LDB #$a5
        put(16'h0116,8'h1a); put(16'h0117,8'h0f); // ORCC #$0f sentinel
        put(16'h0118,8'h7e); put(16'h0119,8'h01); put(16'h011a,8'h20); // JMP $0120
        put(16'h0123,8'h40); put(16'h0124,8'h12);
        direct_mem[8'h40]=memlevel ? 8'hff:8'h00;
        cycles=(instruction==7) ? 8:7;
        measure_case(cycles,16'h0124,"page-11 bit-op matrix");
        before_reg=(selector==0) ? cc_before_target :
                   (selector==1) ? 8'h5a : 8'ha5;
        oldbit=(before_reg>>dstbit)&1;
        sourcebit=memlevel;
        case(instruction)
            0: newbit=oldbit&sourcebit;
            1: newbit=oldbit&~sourcebit;
            2: newbit=oldbit|sourcebit;
            3: newbit=oldbit|~sourcebit;
            4: newbit=oldbit^sourcebit;
            5: newbit=oldbit^~sourcebit;
            default: newbit=sourcebit;
        endcase
        mask=8'h01<<dstbit;
        expected_reg=(before_reg&~mask)|(newbit?mask:0);
        if(instruction==7) begin
            expected_reg=before_reg;
            expected_mem=((memlevel?8'hff:8'h00)&~mask)|
                         (((before_reg>>srcbit)&1)?mask:0);
            assert_msg(direct_mem[8'h40]==expected_mem,
                $sformatf("STBT matrix memory=%02x expected %02x",direct_mem[8'h40],expected_mem));
        end
        if(selector==0)
            assert_msg(regs[87:80]==expected_reg,
                $sformatf("bit matrix CC=%02x expected %02x",regs[87:80],expected_reg));
        else if(selector==1)
            assert_msg(regs[7:0]==expected_reg,
                $sformatf("bit matrix A=%02x expected %02x",regs[7:0],expected_reg));
        else
            assert_msg(regs[15:8]==expected_reg,
                $sformatf("bit matrix B=%02x expected %02x",regs[15:8],expected_reg));
        if(selector!=0 || instruction==7)
            assert_msg(regs[87:80]==cc_before_target,
                $sformatf("bit matrix unexpected CC change %02x -> %02x",cc_before_target,regs[87:80]));
    end
endtask

task run_invalid_tfm_selector;
    integer watchdog;
    reg handler_seen;
    begin
        load_program(8'h01,8'h11,8'h38,8'h52); // Invalid source selector 5, destination Y.
        put(16'h0113,8'h06); // Seed Z=1; illegal TFM must clear it before stacking.
        put(16'hfff0,8'h01); put(16'hfff1,8'h60); // Illegal-instruction vector, distinct from FIRQ/IRQ.
        put(16'h0160,8'h12);
        watchdog=0; handler_seen=0; illegal_vector_reads=0;
        while(!handler_seen && watchdog<500) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0160) handler_seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(handler_seen,"invalid TFM selector did not vector through $fff0");
        assert_msg(illegal_vector_reads>=2,
            $sformatf("invalid TFM selector vector reads=%0d expected FFF0/FFF1 bus reads",
                      illegal_vector_reads));
        assert_msg(regs6309[54],
            $sformatf("invalid TFM selector must set MD.IL, MD=%02x",regs6309[55:48]));
        assert_msg(stack_mem[18][2]==1'b0,
            $sformatf("invalid TFM selector stacked CC.Z=%0d expected clear",stack_mem[18][2]));
        assert_msg(stack_mem[18][6]==1'b0 && stack_mem[18][4]==1'b0,
            $sformatf("invalid TFM selector stacked CC I/F=%0d/%0d expected 0/0",
                      stack_mem[18][4],stack_mem[18][6]));
        assert_msg((regs[87:80]&8'h50)==8'h00,
            $sformatf("invalid TFM selector handler CC I/F=%0d/%0d expected 0/0",
                      regs[84],regs[86]));
    end
endtask

task run_hd_illegal_opcode(input [7:0] page_opcode);
    integer watchdog;
    reg handler_seen;
    begin
        load_program(8'h01,8'h11,page_opcode,8'h12);
        put(16'hfff0,8'h01); put(16'hfff1,8'h60);
        put(16'h0160,8'h12);
        watchdog=0; handler_seen=0; illegal_vector_reads=0;
        while(!handler_seen && watchdog<500) begin
            @(posedge clk);
            if(cen_E && op && addr==16'h0160) handler_seen=1;
            watchdog=watchdog+1;
        end
        assert_msg(handler_seen,
            $sformatf("HD6309 opcode $11%02x did not reach $fff0 handler",page_opcode));
        assert_msg(regs6309[54],
            $sformatf("HD6309 opcode $11%02x did not set MD.IL: MD=%02x",
                      page_opcode,regs6309[55:48]));
        assert_msg(illegal_vector_reads>=2,
            $sformatf("HD6309 opcode $11%02x vector reads=%0d expected FFF0/FFF1",
                      page_opcode,illegal_vector_reads));
        assert_msg(stack_mem[18][6]==1'b0 && stack_mem[18][4]==1'b0,
            $sformatf("HD6309 opcode $11%02x stacked CC I/F=%0d/%0d expected 0/0",
                      page_opcode,stack_mem[18][4],stack_mem[18][6]));
        assert_msg((regs[87:80]&8'h50)==8'h00,
            $sformatf("HD6309 opcode $11%02x handler CC I/F=%0d/%0d expected 0/0",
                      page_opcode,regs[84],regs[86]));
    end
endtask

task run_divzero_trap(input [7:0] mode, input reg is_divq);
    integer watchdog, ecycle, handler_cycle, stack_cycle, vector_cycle;
    reg started, handler_seen;
    reg [15:0] closing_pc;
    integer expected_handler, expected_stack, expected_vector;
    reg [7:0] opcode;
    reg [7:0] extra;
    reg [7:0] low_operand;
    reg [31:0] opname;
    begin
        opcode=is_divq ? 8'h8e : 8'h8d;
        extra=8'h00;
        low_operand=8'h00;
        closing_pc=is_divq ? 16'h0124 : 16'h0123;
        opname=is_divq ? "DIVQ" : "DIVD";
        initial_e=is_divq ? 8'hff : 8'h00;
        initial_f=is_divq ? 8'hf9 : 8'h00;
        load_program(mode,8'h11,opcode,extra);
        put(16'h010d,8'hcc);
        put(16'h010e,is_divq ? 8'hff : 8'hff);
        put(16'h010f,is_divq ? 8'hff : 8'hf9);
        put(16'h0110,8'h12); put(16'h0111,8'h12);
        put(16'h0113,8'h0b); // Seed N/V/C; zero exception should update NZV only.
        if(is_divq) put(16'h0123,low_operand);
        put(closing_pc,8'h12);
        put(16'hfff0,8'h01); put(16'hfff1,8'h60);
        put(16'h0160,8'h12);
        watchdog=0; started=0; handler_seen=0; illegal_vector_reads=0;
        ecycle=-1; handler_cycle=-1; stack_cycle=-1; vector_cycle=-1;
        while(!handler_seen && watchdog<1000) begin
            @(posedge clk);
            if(cen_E) begin
                if(!started && op && addr==16'h0120) begin
                    started=1;
                    ecycle=0;
                end else if(started) begin
                    ecycle=ecycle+1;
                    if(op && addr==16'h0160) begin
                        handler_seen=1;
                        handler_cycle=ecycle;
                    end
                end
            end
            if(started && cen_Q && !rnw && stack_cycle<0 &&
               ((addr>=16'h2fe0 && addr<=16'h2fff) ||
                (addr>=16'h3fe0 && addr<=16'h3fff)))
                stack_cycle=ecycle;
            if(started && cen_Q && rnw && avma && addr==16'hfff0 && vector_cycle<0)
                vector_cycle=ecycle;
            watchdog=watchdog+1;
        end
        expected_handler=(is_divq ? 24 : 23) + (mode[0] ? 2 : 0);
        expected_stack=(is_divq ? 8 : 7);
        expected_vector=(is_divq ? 21 : 20) + (mode[0] ? 2 : 0);
        assert_msg(handler_seen,$sformatf("%s by zero did not reach $fff0 handler",opname));
        assert_msg(handler_cycle==expected_handler,
            $sformatf("%s zero mode=%0d handler at %0d E, expected %0d",
                      opname,mode[0],handler_cycle,expected_handler));
        assert_msg(stack_cycle==expected_stack,
            $sformatf("%s zero mode=%0d first stack write at %0d E, expected %0d",
                      opname,mode[0],stack_cycle,expected_stack));
        assert_msg(vector_cycle==expected_vector,
            $sformatf("%s zero mode=%0d vector high read at %0d E, expected %0d",
                      opname,mode[0],vector_cycle,expected_vector));
        assert_msg(regs6309[55],
            $sformatf("%s by zero did not set MD.DZ: MD=%02x",opname,regs6309[55:48]));
        assert_msg(illegal_vector_reads>=2,
            $sformatf("%s zero vector reads=%0d expected FFF0/FFF1",opname,illegal_vector_reads));
        assert_msg(stack_mem[(mode[0] ? 18 : 20)]== (is_divq ? 8'h8d : 8'h85),
            $sformatf("%s zero mode=%0d stacked CC=%02x expected %02x",
                      opname,mode[0],stack_mem[(mode[0] ? 18 : 20)],is_divq ? 8'h8d : 8'h85));
        assert_msg((regs[87:80]&8'h50)==8'h00,
            $sformatf("%s zero mode=%0d handler CC I/F=%0d/%0d expected 0/0",
                      opname,mode[0],regs[84],regs[86]));
        assert_msg({regs[7:0],regs[15:8]}==(is_divq ? 16'hffff : 16'hfff9),
            $sformatf("%s zero mode=%0d changed D=%04x",
                      opname,mode[0],{regs[7:0],regs[15:8]}));
        if(is_divq) assert_msg({regs6309[7:0],regs6309[15:8]}==16'hfff9,
            $sformatf("DIVQ zero mode=%0d changed W=%04x",
                      mode[0],{regs6309[7:0],regs6309[15:8]}));
    end
endtask

task run_divzero_memory_trap(input [7:0] mode, input reg is_divq,
                            input integer form);
    integer watchdog, ecycle, handler_cycle, stack_cycle, vector_cycle, divisor_cycle;
    reg started, handler_seen, divisor_seen;
    reg [15:0] divisor_addr;
    integer expected_handler, expected_stack, expected_vector;
    reg [7:0] opcode;
    reg [8*11-1:0] opname;
    begin
        // form: 0=direct, 1=extended, 2=indexed ,X. The source decoder's
        // original-device samples specify these handler intervals and phase
        // offsets for the zero-divisor exception.
        case(form)
            0: opcode=is_divq ? 8'h9e : 8'h9d;
            1: opcode=is_divq ? 8'hbe : 8'hbd;
            default: opcode=is_divq ? 8'hae : 8'had;
        endcase
        divisor_addr=16'h0040;
        opname=is_divq ? "DIVQ memory" : "DIVD memory";
        initial_e=is_divq ? 8'hff : 8'h00;
        initial_f=is_divq ? 8'hf9 : 8'h00;
        load_program(mode,8'h11,opcode,8'h00);
        // Install a nonzero dividend and seed N/V/C so the trap frame proves
        // the hardware-defined zero-divisor flags, including C preservation.
        put(16'h010d,8'hcc);
        put(16'h010e,is_divq ? 8'hff : 8'hff);
        put(16'h010f,is_divq ? 8'hff : 8'hf9);
        put(16'h0110,8'h12); put(16'h0111,8'h12);
        put(16'h0113,8'h0b); // ORCC #$0b
        if(form==0) begin
            put(16'h0122,8'h40); // direct address
        end else if(form==1) begin
            put(16'h0122,8'h00); put(16'h0123,8'h40); // extended address
        end else begin
            // LDX #$0040; JMP $0120, using the prelude space before the test.
            put(16'h0116,8'h8e); put(16'h0117,8'h00); put(16'h0118,8'h40);
            put(16'h0119,8'h7e); put(16'h011a,8'h01); put(16'h011b,8'h20);
            put(16'h0122,8'h84); // ,X
        end
        if(is_divq) begin
            put(divisor_addr,8'h00); put(divisor_addr+1,8'h00);
        end else put(divisor_addr,8'h00);
        put(16'hfff0,8'h01); put(16'hfff1,8'h60);
        put(16'h0160,8'h12);
        watchdog=0; started=0; handler_seen=0; divisor_seen=0;
        illegal_vector_reads=0;
        ecycle=-1; handler_cycle=-1; stack_cycle=-1; vector_cycle=-1; divisor_cycle=-1;
        while(!handler_seen && watchdog<1400) begin
            @(posedge clk);
            if(cen_E) begin
                if(!started && op && addr==16'h0120) begin
                    started=1;
                    ecycle=0;
                end else if(started) begin
                    ecycle=ecycle+1;
                    if(op && addr==16'h0160) begin
                        handler_seen=1;
                        handler_cycle=ecycle;
                    end
                end
                if(started && rnw && avma &&
                   addr==divisor_addr+(is_divq ? 1 : 0)) begin
                    divisor_seen=1;
                    divisor_cycle=ecycle;
                end
            end
            if(started && cen_Q && !rnw && stack_cycle<0 &&
               ((addr>=16'h2fe0 && addr<=16'h2fff) ||
                (addr>=16'h3fe0 && addr<=16'h3fff)))
                stack_cycle=ecycle;
            if(started && cen_Q && rnw && avma && addr==16'hfff0 && vector_cycle<0)
                vector_cycle=ecycle;
            watchdog=watchdog+1;
        end
        case(form)
            0: expected_handler=is_divq ? (mode[0] ? 27 : 26) : (mode[0] ? 26 : 25);
            1: expected_handler=is_divq ? (mode[0] ? 28 : 27) : (mode[0] ? 27 : 26);
            default: expected_handler=is_divq ? (mode[0] ? 28 : 26) : (mode[0] ? 27 : 25);
        endcase
        expected_stack=expected_handler-(mode[0] ? 18 : 16);
        expected_vector=expected_handler-3;
        assert_msg(handler_seen,$sformatf("%s zero form=%0d did not reach handler",opname,form));
        assert_msg(divisor_seen,$sformatf("%s zero form=%0d missed final divisor read at %04x",opname,form,divisor_addr));
        assert_msg(divisor_cycle<stack_cycle,
            $sformatf("%s zero form=%0d last operand read E%0d must precede stack E%0d",
                      opname,form,divisor_cycle,stack_cycle));
        assert_msg(handler_cycle==expected_handler,
            $sformatf("%s zero form=%0d mode=%0d handler=%0d E expected %0d",
                      opname,form,mode[0],handler_cycle,expected_handler));
        assert_msg(stack_cycle==expected_stack,
            $sformatf("%s zero form=%0d mode=%0d first stack=%0d E expected %0d",
                      opname,form,mode[0],stack_cycle,expected_stack));
        assert_msg(vector_cycle==expected_vector,
            $sformatf("%s zero form=%0d mode=%0d vector=%0d E expected %0d",
                      opname,form,mode[0],vector_cycle,expected_vector));
        assert_msg(stack_mem[(mode[0] ? 18 : 20)]== (is_divq ? 8'h8d : 8'h85),
            $sformatf("%s zero form=%0d stacked CC=%02x expected %02x",
                      opname,form,stack_mem[(mode[0] ? 18 : 20)],is_divq ? 8'h8d : 8'h85));
        assert_msg((regs[87:80]&8'h50)==8'h00,
            $sformatf("%s zero form=%0d handler CC I/F=%0d/%0d expected 0/0",
                      opname,form,regs[84],regs[86]));
        assert_msg({regs[7:0],regs[15:8]}==(is_divq ? 16'hffff : 16'hfff9),
            $sformatf("%s zero form=%0d changed D=%04x",opname,form,{regs[7:0],regs[15:8]}));
        if(is_divq) assert_msg({regs6309[7:0],regs6309[15:8]}==16'hfff9,
            $sformatf("DIVQ zero form=%0d changed W=%04x",form,{regs6309[7:0],regs6309[15:8]}));
    end
endtask

task preload_d(input [15:0] value);
    begin
        // LDD #value in the otherwise unused U initialization slots.
        put(16'h010d,8'hcc); put(16'h010e,value[15:8]); put(16'h010f,value[7:0]);
        // LDU's old operand bytes must not become opcodes after the shorter LDD.
        put(16'h0110,8'h12); put(16'h0111,8'h12);
    end
endtask

task preload_dx(input [15:0] value, input [15:0] index_value);
    begin
        put(16'h010d,8'hcc); put(16'h010e,value[15:8]); put(16'h010f,value[7:0]);
        put(16'h0110,8'h8e);
        put(16'h0111,index_value[15:8]); put(16'h0112,index_value[7:0]);
        put(16'h0113,8'h7e); put(16'h0114,8'h01); put(16'h0115,8'h20);
    end
endtask

task run_signed_math_case(input integer op_kind, input [7:0] mode,
                          input integer form, input integer sign_combo);
    integer base_cycles, penalty, expected_cycles;
    reg [7:0] opcode, first_operand;
    reg [15:0] dividend, divisor, expected_d, expected_w;
    reg [31:0] expected_q;
    reg [15:0] expected_pc;
    string label, opname, formname;
    begin
        dividend=(op_kind==1) ? (sign_combo[1] ? 16'hffff : 16'h0000) :
                 (sign_combo[1] ? 16'hfff9 : 16'h0007);
        divisor=(sign_combo[0]) ? 16'hfffd : 16'h0003;
        case(op_kind)
            0: begin opname="DIVD"; expected_q=0; end
            1: begin opname="DIVQ"; expected_q=0; end
            default: begin opname="MULD"; expected_q=0; end
        endcase
        case(form)
            0: begin formname="immediate"; base_cycles=(op_kind==0)?25:(op_kind==1)?34:28; end
            1: begin formname="direct"; base_cycles=(op_kind==0)?(mode[0]?26:27):(op_kind==1)?(mode[0]?35:36):(mode[0]?29:30); end
            2: begin formname="indexed"; base_cycles=(op_kind==0)?27:(op_kind==1)?36:30; end
            default: begin formname="extended"; base_cycles=(op_kind==0)?(mode[0]?27:28):(op_kind==1)?(mode[0]?36:37):(mode[0]?30:31); end
        endcase
        if(op_kind==2) penalty=(sign_combo!=0) ? 2 : 0;
        else penalty=((sign_combo[1] ? 1 : 0)+(sign_combo[0] ? 1 : 0));
        expected_cycles=base_cycles+penalty;
        if(op_kind==0) begin
            opcode=(form==0)?8'h8d:(form==1)?8'h9d:(form==2)?8'had:8'hbd;
            first_operand=(form==0)?divisor[7:0]:(form==1)?8'h40:(form==2)?8'h84:8'h00;
            expected_pc=(form==3)?16'h0124:16'h0123;
        end else if(op_kind==1) begin
            opcode=(form==0)?8'h8e:(form==1)?8'h9e:(form==2)?8'hae:8'hbe;
            first_operand=(form==0)?divisor[15:8]:(form==1)?8'h40:(form==2)?8'h84:8'h00;
            expected_pc=(form==1 || form==2)?16'h0123:16'h0124;
        end else begin
            opcode=(form==0)?8'h8f:(form==1)?8'h9f:(form==2)?8'haf:8'hbf;
            first_operand=(form==0)?divisor[15:8]:(form==1)?8'h40:(form==2)?8'h84:8'h00;
            expected_pc=(form==1 || form==2)?16'h0123:16'h0124;
        end
        initial_e=(op_kind==1 && sign_combo[1]) ? 8'hff : 8'h00;
        initial_f=(op_kind==1) ? (sign_combo[1] ? 8'hf9 : 8'h07) : 8'h00;
        load_program(mode,8'h11,opcode,first_operand);
        preload_d(dividend);
        if(form==2) begin
            preload_dx(dividend,16'h0040);
            // Recreate the I/F mask, V/C seed, and branch after LDX.
            put(16'h0113,8'h1c); put(16'h0114,8'haf);
            put(16'h0115,8'h1a); put(16'h0116,8'h03);
            put(16'h0117,8'h7e); put(16'h0118,8'h01); put(16'h0119,8'h20);
        end else put(16'h0113,8'h03); // Seed V and C to verify MULD preserves both.
        if(form==3) begin
            put(16'h0122,8'h00); put(16'h0123,8'h40);
        end else if(form==0 && op_kind!=0) begin
            put(16'h0123,divisor[7:0]);
        end
        if(form!=0) begin
            direct_mem[8'h40]= (op_kind==0) ? divisor[7:0] : divisor[15:8];
            if(op_kind!=0) direct_mem[8'h41]=divisor[7:0];
        end
        case(op_kind)
            0: case(sign_combo)
                0: expected_d=16'h0102;
                1: expected_d=16'h01fe;
                2: expected_d=16'hfffe;
                default: expected_d=16'hff02;
            endcase
            1: case(sign_combo)
                0: begin expected_d=16'h0001; expected_w=16'h0002; end
                1: begin expected_d=16'h0001; expected_w=16'hfffe; end
                2: begin expected_d=16'hffff; expected_w=16'hfffe; end
                default: begin expected_d=16'hffff; expected_w=16'h0002; end
            endcase
            default: expected_q=(sign_combo==0 || sign_combo==3) ? 32'h00000015 : 32'hffffffeb;
        endcase
        label=$sformatf("%s %s mode=%0d signs=%0d",opname,formname,mode[0],sign_combo);
        measure_case(expected_cycles,expected_pc,label);
        case(op_kind)
            0: assert_msg({regs[7:0],regs[15:8]}==expected_d,
                $sformatf("%s result D=%04x expected %04x",label,{regs[7:0],regs[15:8]},expected_d));
            1: assert_msg({regs[7:0],regs[15:8]}==expected_d && regs6309[31:16]==expected_w,
                $sformatf("%s result D/W=%04x/%04x expected %04x/%04x",label,
                          {regs[7:0],regs[15:8]},regs6309[31:16],expected_d,expected_w));
            default: assert_msg({regs[15:0],regs6309[31:16]}==expected_q,
                $sformatf("%s result Q=%04x:%04x expected %08x",label,
                          regs[15:0],regs6309[31:16],expected_q));
        endcase
        if(op_kind==2)
            assert_msg(regs[80]==cc_before_target[0],
                $sformatf("%s MULD changed C from %0d to %0d",label,
                          cc_before_target[0],regs[80]));
    end
endtask

task run_division_overflow_case(input reg is_divq, input [7:0] mode,
                               input integer form, input [31:0] dividend,
                               input [15:0] divisor, input [31:0] expected_result,
                               input [3:0] expected_flags,
                               input integer overflow_kind);
    integer base_cycles, correction, expected_cycles;
    reg [7:0] opcode, operand_hi;
    reg [15:0] expected_pc;
    reg [31:0] observed_result;
    string opname, formname, label;
    begin
        case(form)
            0: begin formname="immediate"; base_cycles=is_divq?34:25; end
            1: begin formname="direct"; base_cycles=is_divq?(mode[0]?35:36):(mode[0]?26:27); end
            2: begin formname="indexed"; base_cycles=is_divq?36:27; end
            default: begin formname="extended"; base_cycles=is_divq?(mode[0]?36:37):(mode[0]?27:28); end
        endcase
        correction=(overflow_kind==2)?(is_divq?21:13):
                   ((overflow_kind==1 && !is_divq)?1:0);
        expected_cycles=base_cycles+((is_divq?dividend[31]:dividend[15])?1:0)+
                        ((is_divq?divisor[15]:divisor[7])?1:0)-correction;
        opname=is_divq?"DIVQ":"DIVD";
        opcode=is_divq ? ((form==0)?8'h8e:(form==1)?8'h9e:(form==2)?8'hae:8'hbe) :
                         ((form==0)?8'h8d:(form==1)?8'h9d:(form==2)?8'had:8'hbd);
        operand_hi=(form==0 && is_divq)?divisor[15:8]:
                   (form==0)?divisor[7:0]:
                   (form==2)?8'h84:(form==1)?8'h40:8'h00;
        initial_e=is_divq?dividend[15:8]:8'h00;
        initial_f=is_divq?dividend[7:0]:8'h00;
        load_program(mode,8'h11,opcode,operand_hi);
        preload_d(is_divq?dividend[31:16]:dividend[15:0]);
        if(form==2) preload_dx(is_divq?dividend[31:16]:dividend[15:0],16'h0040);
        if(form==0 && is_divq) put(16'h0123,divisor[7:0]);
        if(form==3) put(16'h0123,8'h40);
        if(form!=0) begin
            if(is_divq) begin
                direct_mem[8'h40]=divisor[15:8];
                direct_mem[8'h41]=divisor[7:0];
            end else direct_mem[8'h40]=divisor[7:0];
        end
        expected_pc=(form==3 || (form==0 && is_divq))?16'h0124:16'h0123;
        label=$sformatf("%s overflow kind=%0d %s mode=%0d dividend=%08x divisor=%04x",
                        opname,overflow_kind,formname,mode[0],dividend,divisor);
        measure_case(expected_cycles,expected_pc,label);
        if(is_divq) observed_result={regs[7:0],regs[15:8],regs6309[31:16]};
        else observed_result={16'h0000,regs[7:0],regs[15:8]};
        assert_msg(observed_result==expected_result,
            $sformatf("%s result=%08x expected=%08x",label,observed_result,expected_result));
        assert_msg((regs[87:80]&8'h0f)==expected_flags,
            $sformatf("%s CC=%02x expected low flags=%01x",label,regs[87:80],expected_flags));
    end
endtask

task run_tfm_irq_restart;
    integer watchdog;
    reg seen;
    begin
        initial_e=0; initial_f=2;
        load_program(8'h00,8'h11,8'h38,8'h12); // TFM X+,Y+; W=2
        // Set up X/Y, then seed Z immediately before TFM. LDX/LDY update Z.
        put(16'h010d,8'h1c); put(16'h010e,8'haf); // ANDCC #$af unmasks IRQ/FIRQ.
        put(16'h010f,8'h8e); put(16'h0110,8'h00); put(16'h0111,8'h10);
        put(16'h0112,8'h10); put(16'h0113,8'h8e); put(16'h0114,8'h00); put(16'h0115,8'h20);
        put(16'h0116,8'h1a); put(16'h0117,8'h04); // ORCC #$04 seeds Z.
        put(16'h0118,8'h7e); put(16'h0119,8'h01); put(16'h011a,8'h20);
        put(16'h0150,8'h3b); // RTI
        direct_mem[8'h10]=8'ha5; direct_mem[8'h11]=8'hb6;
        direct_mem[8'h20]=8'h5a; direct_mem[8'h21]=8'h6b;
        tfm_source_reads=0; tfm_dest_writes=0;
        watchdog=0; seen=0;
        while(!seen && watchdog<1000) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen_Q && op && addr==16'h0121) seen=1;
        end
        assert_msg(seen,"TFM IRQ case did not fetch page-11 opcode");
        irq_n=0;
        watchdog=0; seen=0;
        while(!seen && watchdog<1000) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen_E && op && addr==16'h0150) seen=1;
        end
        assert_msg(seen,"TFM IRQ case did not vector");
        assert_msg(regs[31:16]==16'h0010 && regs[47:32]==16'h0020 &&
                   regs6309[31:16]==16'h0002,
            $sformatf("TFM interrupt modified X/Y/W early: X=%04x Y=%04x W=%04x",
                      regs[31:16],regs[47:32],regs6309[31:16]));
        assert_msg(stack_mem[30]==8'h01 && stack_mem[31]==8'h20,
            $sformatf("TFM interrupt saved PC bytes %02x/%02x expected 01/20",
                      stack_mem[30],stack_mem[31]));
        assert_msg(tfm_source_reads==1 && tfm_dest_writes==0,
            $sformatf("TFM pre-interrupt reads/writes=%0d/%0d expected 1/0",
                      tfm_source_reads,tfm_dest_writes));
        assert_msg(stack_mem[20][2]==1'b0,
            $sformatf("interrupted TFM stacked CC.Z=%0d expected clear",stack_mem[20][2]));
        @(negedge clk); irq_n=1;
        watchdog=0; seen=0;
        while(!seen && watchdog<2000) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen_E && op && addr==16'h0123) seen=1;
        end
        assert_msg(seen,"TFM did not resume and finish after RTI");
        assert_msg(direct_mem[8'h20]==8'ha5 && direct_mem[8'h21]==8'hb6,
            $sformatf("TFM resumed bytes=%02x/%02x expected a5/b6",
                      direct_mem[8'h20],direct_mem[8'h21]));
        assert_msg(tfm_source_reads==3 && tfm_dest_writes==2,
            $sformatf("TFM restart reads/writes=%0d/%0d expected 3/2",
                      tfm_source_reads,tfm_dest_writes));
        assert_msg(regs[82],"TFM restart completion must set CC.Z");
    end
endtask

task check_ef(input [7:0] expected_e, input [7:0] expected_f,
              input [7:0] expected_md,
              input string label);
    begin
        assert_msg(regs6309[7:0]==expected_e,
            $sformatf("%s E=%02x expected %02x",label,regs6309[7:0],expected_e));
        assert_msg(regs6309[15:8]==expected_f,
            $sformatf("%s F=%02x expected %02x",label,regs6309[15:8],expected_f));
        assert_msg(regs6309[55:48]==expected_md,
            $sformatf("%s MD=%02x expected %02x",label,regs6309[55:48],expected_md));
    end
endtask

task run_negd_boundary(input [7:0] mode, input string label);
    integer expected_cycles;
    begin
        initial_e = 8'h12;
        initial_f = 8'h34;
        load_program(mode,8'h10,8'h40,8'h12);
        preload_d(16'h8000);
        expected_cycles = mode[0] ? 2 : 3;
        measure_case(expected_cycles,16'h0122,label);
        assert_msg({regs[7:0],regs[15:8]}==16'h8000,
            $sformatf("%s D=%04x expected 8000",label,{regs[7:0],regs[15:8]}));
        assert_msg((regs[87:80]&8'h0f)==8'h0b,
            $sformatf("%s NZVC=%x expected b",label,regs[83:80]));
        initial_e = 8'h12;
        initial_f = 8'h34;
    end
endtask

// Install X/Y after load_program's LDS setup. The replacement LDY occupies
// the old LDU/ORCC slots; the remaining ANDCC/JMP sequence still reaches the
// target opcode at $0120.
task set_xy_prelude;
    begin
        put(16'h010d,8'h8e); put(16'h010e,8'h00); put(16'h010f,8'h10); // LDX #$0010
        put(16'h0110,8'h10); put(16'h0111,8'h8e); put(16'h0112,8'h00); put(16'h0113,8'h20); // LDY #$0020
    end
endtask

task run_mem_immediate(input [7:0] mode, input [7:0] opcode,
                       input integer form, input integer expected,
                       input [7:0] expected_mem, input string name);
    reg [7:0] addr_byte;
    begin
        initial_e=0; initial_f=1;
        addr_byte=(form==1) ? 8'h84 : 8'h40; // ,X or direct address
        load_program(mode,opcode,8'h0f,addr_byte);
        if(form==1) set_xy_prelude();
        if(form==2) begin
            put(16'h0122,8'h00); put(16'h0123,8'h40); // extended $0040
            put(16'h0124,8'h12);
        end else begin
            put(16'h0123,8'h12);
        end
        direct_mem[8'h40]=(form==1)?8'h5c:8'ha5;
        direct_mem[8'h10]=(form==1)?8'ha5:8'h5c;
        measure_case(expected,(form==2)?16'h0124:16'h0123,name);
        if(opcode==8'h0b || opcode==8'h6b || opcode==8'h7b)
            assert_msg((form==1 ? direct_mem[8'h10] : direct_mem[8'h40])==8'ha5,
                $sformatf("%s changed memory; TIM must only update flags",name));
        else
            assert_msg((form==1 ? direct_mem[8'h10] : direct_mem[8'h40])==expected_mem,
                $sformatf("%s memory=%02x expected %02x",name,
                          form==1 ? direct_mem[8'h10] : direct_mem[8'h40],expected_mem));
    end
endtask

task run_efw_index(input [7:0] mode, input [7:0] postbyte,
                   input [7:0] e_value, input [7:0] f_value,
                   input integer expected_cycles, input [7:0] mem_addr,
                   input string name);
    begin
        initial_e=e_value; initial_f=f_value;
        load_program(mode,8'ha6,postbyte,8'h12); // LDA indexed
        set_xy_prelude();
        direct_mem[mem_addr]=8'h5a;
        measure_case(expected_cycles,16'h0122,name);
        assert_msg(regs[7:0]==8'h5a,
            $sformatf("%s loaded A=%02x expected 5a",name,regs[7:0]));
        assert_msg(regs[31:16]==16'h0010,
            $sformatf("%s changed X to %04x, expected 0010",name,regs[31:16]));
    end
endtask

task run_w_postbyte(input [7:0] mode, input [7:0] postbyte,
                    input integer cycle_count, input [15:0] expected_w,
                    input integer form, input string label);
    reg [15:0] closing_pc;
    begin
        initial_e=8'h00; initial_f=8'h12; // W=$0012
        load_program(mode,8'ha6,postbyte,8'h12); // LDA indexed
        direct_mem[8'h10]=8'ha0;
        direct_mem[8'h11]=8'ha1;
        direct_mem[8'h12]=8'ha2;
        direct_mem[8'h13]=8'ha3;
        direct_mem[8'h14]=8'ha4;
        direct_mem[8'h15]=8'ha5;
        direct_mem[8'h20]=8'ha6;
        closing_pc=16'h0122;
        if(form==0 || form==1) begin
            put(16'h0122,8'h00); put(16'h0123,8'h02); // n=+2 for n,W
            put(16'h0124,8'h12); closing_pc=16'h0124;
        end else put(16'h0122,8'h12);
        case(form)
            0: direct_mem[8'h14]=8'h5a;
            1: begin direct_mem[8'h14]=8'h00; direct_mem[8'h15]=8'h20; direct_mem[8'h20]=8'h5a; end
            2: direct_mem[8'h12]=8'h5a;
            3: begin direct_mem[8'h12]=8'h00; direct_mem[8'h13]=8'h20; direct_mem[8'h20]=8'h5a; end
            4: direct_mem[8'h10]=8'h5a;
            5: begin direct_mem[8'h10]=8'h00; direct_mem[8'h11]=8'h20; direct_mem[8'h20]=8'h5a; end
        endcase
        measure_case(cycle_count,closing_pc,label);
        assert_msg(regs[7:0]==8'h5a,
            $sformatf("%s loaded A=%02x expected 5a",label,regs[7:0]));
        assert_msg(regs6309[31:16]==expected_w,
            $sformatf("%s W=%04x expected %04x",label,regs6309[31:16],expected_w));
    end
endtask

task run_memimm_after_prefix(input [7:0] mode, input [7:0] opcode,
                             input [7:0] expected_mem, input string label);
    begin
        initial_e=8'h12; initial_f=8'h34;
        load_program(mode,8'h11,8'h4c,8'h12); // INCD immediately before AIM/OIM
        put(16'h0120,8'h11); put(16'h0121,8'h4c);
        put(16'h0122,opcode); put(16'h0123,8'h0f); put(16'h0124,8'h40);
        put(16'h0125,8'h12);
        direct_mem[8'h40]=8'ha5;
        measure_case_at(16'h0122,6,16'h0125,label);
        assert_msg(direct_mem[8'h40]==expected_mem,
            $sformatf("%s after page-11 instruction wrote %02x expected %02x",
                      label,direct_mem[8'h40],expected_mem));
    end
endtask

initial begin
    for(i=0;i<256;i=i+1) code_mem[i]=8'h12;
    for(i=0;i<256;i=i+1) direct_mem[i]=8'h12;
    for(i=0;i<32;i=i+1) stack_mem[i]=8'h00;
    for(i=0;i<32;i=i+1) user_stack_mem[i]=8'h00;
    for(i=0;i<16;i=i+1) vector_mem[i]=8'h00;
    initial_e=8'h12; initial_f=8'h34;
    @(negedge rst);

    // The manual lists INCE as 3/2 cycles in emulation/native mode.
    load_program(1'b0,8'h11,8'h4c,8'h12); // INCE (emulation)
    measure_case(3,16'h0122,"INCE emulation");
    check_ef(8'h13,8'h34,8'h00,"INCE emulation");

    load_program(1'b1,8'h11,8'h4c,8'h12);
    measure_case(2,16'h0122,"INCE native");
    check_ef(8'h13,8'h34,8'h01,"INCE native");

    // TFR E,A and EXG E,F use the documented 6/4 and 8/5 E-cycle intervals.
    load_program(1'b0,8'h1f,8'he8,8'h12); // TFR E,A (emulation)
    measure_case(6,16'h0122,"TFR E,A emulation");
    check_ef(8'h12,8'h34,8'h00,"TFR E,A emulation");
    assert_msg(regs[7:0]==8'h12,$sformatf("TFR E,A emulation A=%02x expected 12",regs[7:0]));

    load_program(1'b1,8'h1f,8'he8,8'h12);
    measure_case(4,16'h0122,"TFR E,A native");
    check_ef(8'h12,8'h34,8'h01,"TFR E,A native");
    assert_msg(regs[7:0]==8'h12,$sformatf("TFR E,A native A=%02x expected 12",regs[7:0]));

    load_program(1'b0,8'h1e,8'hef,8'h12); // EXG E,F (emulation)
    measure_case(8,16'h0122,"EXG E,F emulation");
    check_ef(8'h34,8'h12,8'h00,"EXG E,F emulation");

    load_program(1'b1,8'h1e,8'hef,8'h12);
    measure_case(5,16'h0122,"EXG E,F native");
    check_ef(8'h34,8'h12,8'h01,"EXG E,F native");

    // ADDR E,F is a page-10 three-byte register operation. Its documented
    // interval is four E cycles in both modes.
    load_program(1'b0,8'h10,8'h30,8'hef);
    measure_case(4,16'h0123,"ADDR E,F emulation");
    check_ef(8'h12,8'h46,8'h00,"ADDR E,F emulation");

    load_program(1'b1,8'h10,8'h30,8'hef);
    measure_case(4,16'h0123,"ADDR E,F native");
    check_ef(8'h12,8'h46,8'h01,"ADDR E,F native");

    run_rr_carry(0,8'h31,8'h80,8'h7f,8'h00,4'h5,"ADCR E,F emulation");
    run_rr_carry(1,8'h31,8'h80,8'h7f,8'h00,4'h5,"ADCR E,F native");
    run_rr_carry(0,8'h33,8'h7f,8'h80,8'h00,4'h6,"SBCR E,F emulation");
    run_rr_carry(1,8'h33,8'h7f,8'h80,8'h00,4'h6,"SBCR E,F native");
    initial_e=8'h12; initial_f=8'h34;

    // Page-10 register ALU opcodes 34-37 overlap the 6809 PSH/PUL
    // immediate opcodes. The prefix must keep these in the HD6309 register
    // operation path. Postbyte EF selects E as source and F as destination.
    load_program(1'b0,8'h10,8'h34,8'hef); // ANDR E,F
    measure_case(4,16'h0123,"ANDR E,F emulation");
    check_ef(8'h12,8'h10,8'h00,"ANDR E,F emulation");
    assert_msg(regs[83:80]==4'h0,
        $sformatf("ANDR E,F emulation flags NZVC=%x expected 0",regs[83:80]));

    load_program(1'b1,8'h10,8'h34,8'hef);
    measure_case(4,16'h0123,"ANDR E,F native");
    check_ef(8'h12,8'h10,8'h01,"ANDR E,F native");
    assert_msg(regs[83:80]==4'h0,
        $sformatf("ANDR E,F native flags NZVC=%x expected 0",regs[83:80]));

    load_program(1'b0,8'h10,8'h35,8'hef); // ORR E,F
    measure_case(4,16'h0123,"ORR E,F emulation");
    check_ef(8'h12,8'h36,8'h00,"ORR E,F emulation");
    assert_msg(regs[83:80]==4'h0,
        $sformatf("ORR E,F emulation flags NZVC=%x expected 0",regs[83:80]));

    load_program(1'b1,8'h10,8'h35,8'hef);
    measure_case(4,16'h0123,"ORR E,F native");
    check_ef(8'h12,8'h36,8'h01,"ORR E,F native");
    assert_msg(regs[83:80]==4'h0,
        $sformatf("ORR E,F native flags NZVC=%x expected 0",regs[83:80]));

    load_program(1'b0,8'h10,8'h36,8'hef); // EORR E,F
    measure_case(4,16'h0123,"EORR E,F emulation");
    check_ef(8'h12,8'h26,8'h00,"EORR E,F emulation");
    assert_msg(regs[83:80]==4'h0,
        $sformatf("EORR E,F emulation flags NZVC=%x expected 0",regs[83:80]));

    load_program(1'b1,8'h10,8'h36,8'hef);
    measure_case(4,16'h0123,"EORR E,F native");
    check_ef(8'h12,8'h26,8'h01,"EORR E,F native");
    assert_msg(regs[83:80]==4'h0,
        $sformatf("EORR E,F native flags NZVC=%x expected 0",regs[83:80]));

    load_program(1'b0,8'h10,8'h37,8'hef); // CMPR E,F
    measure_case(4,16'h0123,"CMPR E,F emulation");
    check_ef(8'h12,8'h34,8'h00,"CMPR E,F emulation");
    assert_msg(regs[83:80]==4'h0,
        $sformatf("CMPR E,F emulation flags NZVC=%x expected 0",regs[83:80]));

    load_program(1'b1,8'h10,8'h37,8'hef);
    measure_case(4,16'h0123,"CMPR E,F native");
    check_ef(8'h12,8'h34,8'h01,"CMPR E,F native");
    assert_msg(regs[83:80]==4'h0,
        $sformatf("CMPR E,F native flags NZVC=%x expected 0",regs[83:80]));

    // CC is a legal register destination, but the raw ALU result and status
    // bits overlap. Atkinson's inter-register note specifies clearing flags,
    // writing the result, then applying generated flags. This forces Z to
    // survive when the raw result is zero.
    run_rr_cc_destination(0,8'h30,8'h04,"ADDR zero to CC emulation");
    run_rr_cc_destination(1,8'h30,8'h04,"ADDR zero to CC native");
    run_rr_cc_destination(0,8'h34,8'h04,"ANDR zero to CC emulation");
    run_rr_cc_destination(1,8'h34,8'h04,"ANDR zero to CC native");
    run_rr_cc_destination(0,8'h35,8'h04,"ORR zero to CC emulation");
    run_rr_cc_destination(1,8'h35,8'h04,"ORR zero to CC native");
    run_rr_cc_destination(0,8'h36,8'h04,"EORR zero to CC emulation");
    run_rr_cc_destination(1,8'h36,8'h04,"EORR zero to CC native");
    run_rr_cc_destination(0,8'h37,8'h04,"CMPR zero to CC emulation");
    run_rr_cc_destination(1,8'h37,8'h04,"CMPR zero to CC native");

    // The source size is coerced according to the destination: A->D means
    // source D, E->D means source W, CC->D means $00CC, DP->D means DP:$00,
    // and W->F uses the low byte of W.
    run_rr_mixed_width(0,8'h36,8'h86,16'h1234,16'h0000,8'h00,"EORR A,W emulation");
    run_rr_mixed_width(1,8'h36,8'h86,16'h1234,16'h0000,8'h00,"EORR A,W native");
    run_rr_mixed_width(0,8'h30,8'he0,16'h2468,16'h1234,8'h34,"ADDR E,D emulation");
    run_rr_mixed_width(1,8'h30,8'he0,16'h2468,16'h1234,8'h34,"ADDR E,D native");
    run_rr_mixed_width(0,8'h36,8'ha0,16'h1235,16'h1234,8'h34,"EORR CC,D emulation");
    run_rr_mixed_width(1,8'h36,8'ha0,16'h1235,16'h1234,8'h34,"EORR CC,D native");
    run_rr_mixed_width(0,8'h36,8'hb0,16'h0034,16'h1234,8'h34,"EORR DP,D emulation");
    run_rr_mixed_width(1,8'h36,8'hb0,16'h0034,16'h1234,8'h34,"EORR DP,D native");
    run_rr_mixed_width(0,8'h34,8'h6f,16'h1234,16'h1234,8'h34,"ANDR W,F emulation");
    run_rr_mixed_width(1,8'h34,8'h6f,16'h1234,16'h1234,8'h34,"ANDR W,F native");

    // Page-10 double register unary operations use the published 3/2 split.
    load_program(1'b0,8'h10,8'h5a,8'h12); // DECW
    measure_case(3,16'h0122,"DECW emulation");
    check_ef(8'h12,8'h33,8'h00,"DECW emulation");

    load_program(1'b1,8'h10,8'h5a,8'h12);
    measure_case(2,16'h0122,"DECW native");
    check_ef(8'h12,8'h33,8'h01,"DECW native");

    run_negd_boundary(1'b0,"NEGD emulation boundary");
    run_negd_boundary(1'b1,"NEGD native boundary");

    load_program(1'b0,8'h10,8'h4c,8'h12); // INCD
    measure_case(3,16'h0122,"INCD emulation");
    assert_msg(regs[15:8]==8'h01 && regs[7:0]==8'h00,
        $sformatf("INCD emulation D=%02x%02x expected 0001",regs[15:8],regs[7:0]));

    load_program(1'b1,8'h10,8'h4c,8'h12);
    measure_case(2,16'h0122,"INCD native");
    assert_msg(regs[15:8]==8'h01 && regs[7:0]==8'h00,
        $sformatf("INCD native D=%02x%02x expected 0001",regs[15:8],regs[7:0]));

    // E/F loads cover immediate, direct, and indexed forms. The source table
    // lists LDE/LDF as 3, 5/4, and 5+/3+ cycles respectively.
    load_program(1'b0,8'h11,8'h86,8'h56); // LDE #$56
    measure_case(3,16'h0123,"LDE immediate emulation");
    check_ef(8'h56,8'h34,8'h00,"LDE immediate emulation");

    load_program(1'b1,8'h11,8'hc6,8'h78); // LDF #$78
    measure_case(3,16'h0123,"LDF immediate native");
    check_ef(8'h12,8'h78,8'h01,"LDF immediate native");

    load_program(1'b0,8'h11,8'h96,8'h20); // LDE <$20
    measure_case(5,16'h0123,"LDE direct emulation");
    check_ef(8'h12,8'h34,8'h00,"LDE direct emulation");

    load_program(1'b1,8'h11,8'ha6,8'h84); // LDE ,X
    measure_case(5,16'h0123,"LDE indexed ,X native");
    check_ef(8'h12,8'h34,8'h01,"LDE indexed ,X native");

    // STE/STF extended store forms write into the backing program memory at
    // $0140; a four-byte instruction needs a separate closing fetch at $0124.
    load_program(1'b0,8'h11,8'hb7,8'h01);
    put(16'h0123,8'h40); put(16'h0124,8'h12);
    measure_case(6,16'h0124,"STE extended emulation");
    assert_msg(code_mem[8'h40]==8'h12,
        $sformatf("STE stored %02x at $0140, expected 12",code_mem[8'h40]));

    load_program(1'b1,8'h11,8'hf7,8'h01);
    put(16'h0123,8'h40); put(16'h0124,8'h12);
    measure_case(5,16'h0124,"STF extended native");
    assert_msg(code_mem[8'h40]==8'h34,
        $sformatf("STF stored %02x at $0140, expected 34",code_mem[8'h40]));

    // The 6309 stack-W operations each take six E cycles. Verify the bus
    // byte order as well as the final W and stack pointer values.
    load_program(1'b0,8'h10,8'h38,8'h12); // PSHSW
    measure_case(6,16'h0122,"PSHSW");
    assert_msg(stack_write_count==2 && stack_write_addr0==16'h2fff && stack_write_addr1==16'h2ffe,
        $sformatf("PSHSW write sequence count=%0d %04x,%04x expected 2 2fff,2ffe",
                  stack_write_count,stack_write_addr0,stack_write_addr1));
    assert_msg(stack_mem[8'h1e]==8'h12 && stack_mem[8'h1f]==8'h34,
        $sformatf("PSHSW stack bytes %02x,%02x expected 12,34",stack_mem[8'h1e],stack_mem[8'h1f]));
    assert_msg(regs[63:48]==16'h2ffe,
        $sformatf("PSHSW S=%04x expected 2ffe",regs[63:48]));

    load_program(8'h01,8'h10,8'h38,8'h12); // PSHSW native
    measure_case(6,16'h0122,"PSHSW native");
    assert_msg(stack_write_count==2 && stack_write_addr0==16'h2fff &&
               stack_write_addr1==16'h2ffe && regs[63:48]==16'h2ffe,
        $sformatf("PSHSW native writes/S=%0d/%04x,%04x/%04x expected 2/2fff,2ffe/2ffe",
                  stack_write_count,stack_write_addr0,stack_write_addr1,regs[63:48]));

    load_program(1'b0,8'h10,8'h39,8'h12); // PULSW
    put(16'h010b,8'h2f); put(16'h010c,8'hfe); // LDS #$2ffe
    stack_mem[8'h1e]=8'h56; stack_mem[8'h1f]=8'h78;
    measure_case(6,16'h0122,"PULSW");
    assert_msg(stack_read_count==2 && stack_read_addr0==16'h2ffe && stack_read_addr1==16'h2fff,
        $sformatf("PULSW read sequence count=%0d %04x,%04x expected 2 2ffe,2fff",
                  stack_read_count,stack_read_addr0,stack_read_addr1));
    check_ef(8'h56,8'h78,8'h00,"PULSW");
    assert_msg(regs[63:48]==16'h3000,
        $sformatf("PULSW S=%04x expected 3000",regs[63:48]));

    load_program(8'h01,8'h10,8'h39,8'h12); // PULSW native
    put(16'h010b,8'h2f); put(16'h010c,8'hfe);
    stack_mem[8'h1e]=8'h56; stack_mem[8'h1f]=8'h78;
    measure_case(6,16'h0122,"PULSW native");
    assert_msg(stack_read_count==2 && stack_read_addr0==16'h2ffe &&
               stack_read_addr1==16'h2fff && regs[63:48]==16'h3000,
        $sformatf("PULSW native reads/S=%0d/%04x,%04x/%04x expected 2/2ffe,2fff/3000",
                  stack_read_count,stack_read_addr0,stack_read_addr1,regs[63:48]));
    check_ef(8'h56,8'h78,8'h01,"PULSW native");

    load_program(1'b0,8'h10,8'h3a,8'h12); // PSHUW
    measure_case(6,16'h0122,"PSHUW");
    assert_msg(stack_write_count==2 && stack_write_addr0==16'h3fff && stack_write_addr1==16'h3ffe,
        $sformatf("PSHUW write sequence count=%0d %04x,%04x expected 2 3fff,3ffe",
                  stack_write_count,stack_write_addr0,stack_write_addr1));
    assert_msg(user_stack_mem[8'h1e]==8'h12 && user_stack_mem[8'h1f]==8'h34,
        $sformatf("PSHUW stack bytes %02x,%02x expected 12,34",user_stack_mem[8'h1e],user_stack_mem[8'h1f]));
    assert_msg(regs[79:64]==16'h3ffe,
        $sformatf("PSHUW U=%04x expected 3ffe",regs[79:64]));

    load_program(8'h01,8'h10,8'h3a,8'h12); // PSHUW native
    measure_case(6,16'h0122,"PSHUW native");
    assert_msg(stack_write_count==2 && stack_write_addr0==16'h3fff &&
               stack_write_addr1==16'h3ffe && regs[79:64]==16'h3ffe,
        $sformatf("PSHUW native writes/U=%0d/%04x,%04x/%04x expected 2/3fff,3ffe/3ffe",
                  stack_write_count,stack_write_addr0,stack_write_addr1,regs[79:64]));
    assert_msg(user_stack_mem[8'h1e]==8'h12 && user_stack_mem[8'h1f]==8'h34,
        "PSHUW native stored E/F in expected order");

    load_program(1'b0,8'h10,8'h3b,8'h12); // PULUW
    put(16'h0110,8'h3f); put(16'h0111,8'hfe); // LDU #$3ffe
    user_stack_mem[8'h1e]=8'h56; user_stack_mem[8'h1f]=8'h78;
    measure_case(6,16'h0122,"PULUW");
    assert_msg(stack_read_count==2 && stack_read_addr0==16'h3ffe && stack_read_addr1==16'h3fff,
        $sformatf("PULUW read sequence count=%0d %04x,%04x expected 2 3ffe,3fff",
                  stack_read_count,stack_read_addr0,stack_read_addr1));
    check_ef(8'h56,8'h78,8'h00,"PULUW");
    assert_msg(regs[79:64]==16'h4000,
        $sformatf("PULUW U=%04x expected 4000",regs[79:64]));

    load_program(8'h01,8'h10,8'h3b,8'h12); // PULUW native
    put(16'h0110,8'h3f); put(16'h0111,8'hfe);
    user_stack_mem[8'h1e]=8'h56; user_stack_mem[8'h1f]=8'h78;
    measure_case(6,16'h0122,"PULUW native");
    assert_msg(stack_read_count==2 && stack_read_addr0==16'h3ffe &&
               stack_read_addr1==16'h3fff && regs[79:64]==16'h4000,
        $sformatf("PULUW native reads/U=%0d/%04x,%04x/%04x expected 2/3ffe,3fff/4000",
                  stack_read_count,stack_read_addr0,stack_read_addr1,regs[79:64]));
    check_ef(8'h56,8'h78,8'h01,"PULUW native");

    // SEXW sign extends W into D/Q and updates N/Z in four E cycles.
    initial_e=8'h00; initial_f=8'h00;
    load_program(1'b0,8'h14,8'h12,8'h12); // SEXW, W=$0000
    measure_case(4,16'h0121,"SEXW zero");
    assert_msg(cc_before_target[1],$sformatf("SEXW zero precondition CC=%02x expected V=1",cc_before_target));
    assert_msg(regs[15:0]==16'h0000 && regs6309[31:0]==32'h00000000,
        $sformatf("SEXW zero Q=%08x expected 00000000",{regs[15:8],regs[7:0],regs6309[31:16]}));
    assert_msg(regs[82] && !regs[83] && regs[81],
        $sformatf("SEXW zero CC=%02x must set Z, clear N, preserve V",regs[87:80]));

    initial_e=8'h12; initial_f=8'h34;
    load_program(1'b0,8'h14,8'h12,8'h12); // SEXW, W=$1234
    measure_case(4,16'h0121,"SEXW positive");
    assert_msg(cc_before_target[1],$sformatf("SEXW positive precondition CC=%02x expected V=1",cc_before_target));
    assert_msg(regs[15:0]==16'h0000 && regs6309[31:16]==16'h1234,
        $sformatf("SEXW positive Q=%04x:%04x expected 0000:1234",regs[15:0],regs6309[31:16]));
    assert_msg(!regs[83] && !regs[82] && regs[81],
        $sformatf("SEXW positive CC=%02x must clear N/Z and preserve V",regs[87:80]));

    initial_e=8'h80; initial_f=8'h01;
    load_program(1'b1,8'h14,8'h12,8'h12); // SEXW, W=$8001 in native mode
    measure_case(4,16'h0121,"SEXW negative");
    assert_msg(cc_before_target[1],$sformatf("SEXW negative precondition CC=%02x expected V=1",cc_before_target));
    assert_msg(regs[15:0]==16'hffff && regs6309[31:16]==16'h8001,
        $sformatf("SEXW negative Q=%04x:%04x expected ffff:8001",regs[15:0],regs6309[31:16]));
    assert_msg(regs[83] && !regs[82] && regs[81],
        $sformatf("SEXW negative CC=%02x must set N, clear Z, preserve V",regs[87:80]));

    // LDW #$1234 consumes both operand bytes. STW stores high then low bytes
    // to direct and extended memory; cycle expectations are 6/5 and 7/6.
    initial_e=8'h12; initial_f=8'h34;
    load_program(1'b0,8'h10,8'h86,8'h12);
    put(16'h0123,8'h34); put(16'h0124,8'h12);
    measure_case(4,16'h0124,"LDW immediate emulation");
    assert_msg(regs6309[31:16]==16'h1234,
        $sformatf("LDW immediate W=%04x expected 1234",regs6309[31:16]));

    load_program(1'b0,8'h10,8'h97,8'h20); // STW <$20
    measure_case(6,16'h0123,"STW direct emulation");
    assert_msg(direct_mem[8'h20]==8'h12 && direct_mem[8'h21]==8'h34,
        $sformatf("STW direct bytes %02x,%02x expected 12,34",direct_mem[8'h20],direct_mem[8'h21]));

    load_program(1'b1,8'h10,8'hb7,8'h01); // STW $0140
    put(16'h0123,8'h40); put(16'h0124,8'h12);
    measure_case(6,16'h0124,"STW extended native");
    assert_msg(code_mem[8'h40]==8'h12 && code_mem[8'h41]==8'h34,
        $sformatf("STW extended bytes %02x,%02x expected 12,34",code_mem[8'h40],code_mem[8'h41]));

    // Inherited 6809 load timings use the documented emulation/native split.
    // These also exercise direct, extended, and indexed address sequencers.
    load_program(1'b0,8'h96,8'h20,8'h12); // LDA <$20
    measure_case(4,16'h0122,"LDA direct emulation");
    assert_msg(regs[7:0]==8'h12,$sformatf("LDA direct emulation A=%02x expected 12",regs[7:0]));

    load_program(1'b1,8'h96,8'h20,8'h12);
    measure_case(3,16'h0122,"LDA direct native");
    assert_msg(regs[7:0]==8'h12,$sformatf("LDA direct native A=%02x expected 12",regs[7:0]));

    load_program(1'b0,8'hb6,8'h20,8'h00); // LDA $2000
    measure_case(5,16'h0123,"LDA extended emulation");
    assert_msg(regs[7:0]==8'h12,$sformatf("LDA extended emulation A=%02x expected 12",regs[7:0]));

    load_program(1'b1,8'hb6,8'h20,8'h00);
    measure_case(4,16'h0123,"LDA extended native");
    assert_msg(regs[7:0]==8'h12,$sformatf("LDA extended native A=%02x expected 12",regs[7:0]));

    load_program(1'b0,8'ha6,8'h84,8'h12); // LDA ,X
    measure_case(4,16'h0122,"LDA indexed ,X emulation");

    load_program(1'b1,8'ha6,8'h84,8'h12);
    measure_case(4,16'h0122,"LDA indexed ,X native");

    load_program(1'b0,8'h3a,8'h12,8'h12); // ABX
    measure_case(3,16'h0121,"ABX emulation");

    load_program(1'b1,8'h3a,8'h12,8'h12);
    measure_case(1,16'h0121,"ABX native");

    // Additional inherited 6809 timing anchors from the Atkinson summary.
    // NOP/DAA/MUL/NEGA/PSHS and the 16-bit paths expose native-mode dispatch
    // and schedule differences while the emulation rows preserve legacy timing.
    load_program(1'b0,8'h12,8'h12,8'h12); measure_case(2,16'h0121,"NOP emulation");
    load_program(1'b1,8'h12,8'h12,8'h12); measure_case(1,16'h0121,"NOP native");
    load_program(1'b0,8'h19,8'h12,8'h12); measure_case(2,16'h0121,"DAA emulation");
    load_program(1'b1,8'h19,8'h12,8'h12); measure_case(1,16'h0121,"DAA native");
    load_program(1'b0,8'h3d,8'h12,8'h12); measure_case(11,16'h0121,"MUL emulation");
    load_program(1'b1,8'h3d,8'h12,8'h12); measure_case(10,16'h0121,"MUL native");
    load_program(1'b0,8'h40,8'h12,8'h12); measure_case(2,16'h0121,"NEGA emulation");
    load_program(1'b1,8'h40,8'h12,8'h12); measure_case(1,16'h0121,"NEGA native");
    load_program(1'b0,8'h34,8'h00,8'h12); measure_case(5,16'h0122,"PSHS empty emulation");
    load_program(1'b1,8'h34,8'h00,8'h12); measure_case(4,16'h0122,"PSHS empty native");

    // ADDD #imm and memory operands use mode-dependent counts from the same
    // table. The direct/indexed/extended sequence also exercises data reads.
    load_program(1'b0,8'hc3,8'h00,8'h02); preload_d(16'h0001);
    put(16'h0123,8'h12); measure_case(4,16'h0123,"ADDD immediate emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'h0003,"ADDD immediate emulation result expected 0003");
    load_program(1'b1,8'hc3,8'h00,8'h02); preload_d(16'h0001);
    put(16'h0123,8'h12); measure_case(3,16'h0123,"ADDD immediate native");
    assert_msg({regs[7:0],regs[15:8]}==16'h0003,"ADDD immediate native result expected 0003");
    load_program(1'b0,8'hd3,8'h40,8'h12); preload_d(16'h0001);
    direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h02;
    measure_case(6,16'h0122,"ADDD direct emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'h0003,"ADDD direct emulation result expected 0003");
    load_program(1'b1,8'hd3,8'h40,8'h12); preload_d(16'h0001);
    direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h02;
    measure_case(4,16'h0122,"ADDD direct native");
    assert_msg({regs[7:0],regs[15:8]}==16'h0003,"ADDD direct native result expected 0003");
    load_program(1'b0,8'he3,8'h84,8'h12); preload_dx(16'h0001,16'h0010);
    direct_mem[8'h10]=8'h00; direct_mem[8'h11]=8'h02;
    measure_case(6,16'h0122,"ADDD indexed ,X emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'h0003,"ADDD indexed emulation result expected 0003");
    load_program(1'b1,8'he3,8'h84,8'h12); preload_dx(16'h0001,16'h0010);
    direct_mem[8'h10]=8'h00; direct_mem[8'h11]=8'h02;
    measure_case(5,16'h0122,"ADDD indexed ,X native");
    assert_msg({regs[7:0],regs[15:8]}==16'h0003,"ADDD indexed native result expected 0003");
    load_program(1'b0,8'hf3,8'h00,8'h40); preload_d(16'h0001);
    put(16'h0123,8'h12); direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h02;
    measure_case(7,16'h0123,"ADDD extended emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'h0003,"ADDD extended emulation result expected 0003");
    load_program(1'b1,8'hf3,8'h00,8'h40); preload_d(16'h0001);
    put(16'h0123,8'h12); direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h02;
    measure_case(5,16'h0123,"ADDD extended native");
    assert_msg({regs[7:0],regs[15:8]}==16'h0003,"ADDD extended native result expected 0003");
    // The base 6809 PSHS and RTS stack timing anchors include one selected CC
    // byte and an empty stack mask, respectively.
    load_program(1'b0,8'h34,8'h01,8'h12); measure_case(6,16'h0122,"PSHS CC emulation");
    assert_msg(stack_write_count==1 && regs[63:48]==16'h2fff,"PSHS CC emulation stack result");
    load_program(1'b1,8'h34,8'h01,8'h12); measure_case(5,16'h0122,"PSHS CC native");
    assert_msg(stack_write_count==1 && regs[63:48]==16'h2fff,"PSHS CC native stack result");
    // Atkinson note 4 adds one E cycle per selected stack-mask byte. A single
    // CC byte gives PSHU 5+1 cycles in emulation and 4+1 in native mode.
    load_program(1'b0,8'h36,8'h01,8'h12); measure_case(6,16'h0122,"PSHU CC emulation");
    assert_msg(stack_write_count==1 && stack_write_addr0==16'h3fff &&
               regs[79:64]==16'h3fff,
        $sformatf("PSHU CC emulation writes/U=%0d/%04x expected 1/3fff",
                  stack_write_count,regs[79:64]));
    load_program(1'b1,8'h36,8'h01,8'h12); measure_case(5,16'h0122,"PSHU CC native");
    assert_msg(stack_write_count==1 && stack_write_addr0==16'h3fff &&
               regs[79:64]==16'h3fff,
        $sformatf("PSHU CC native writes/U=%0d/%04x expected 1/3fff",
                  stack_write_count,regs[79:64]));
    load_program(1'b0,8'h39,8'h12,8'h12); measure_case(5,16'h0000,"RTS emulation");
    load_program(1'b1,8'h39,8'h12,8'h12); measure_case(4,16'h0000,"RTS native");
    // RTI timing depends on CC.E: 15 cycles for the 12-byte emulation frame,
    // 6 cycles for the short CC+PC frame. Seed each frame in memory so the
    // timing case does not depend on an interrupt-entry interval.
    load_program(1'b0,8'h3b,8'h12,8'h12);
    put(16'h010b,8'h2f); put(16'h010c,8'hf4); // LDS #$2ff4
    stack_mem[20]=8'h80; stack_mem[30]=8'h01; stack_mem[31]=8'h30;
    stack_mem[32]=8'h00; stack_mem[33]=8'h00;
    stack_mem[34]=8'h00; stack_mem[35]=8'h00;
    stack_mem[36]=8'h00; stack_mem[37]=8'h00;
    stack_mem[38]=8'h00; stack_mem[39]=8'h00;
    stack_mem[40]=8'h01; stack_mem[41]=8'h30;
    put(16'h0130,8'h12);
    measure_case(15,16'h0130,"RTI full emulation CC.E=1");
    assert_msg(regs[63:48]==16'h3000,
        $sformatf("RTI full emulation S=%04x expected 3000",regs[63:48]));

    // Native full-frame RTI restores fourteen bytes, including E and F.
    // Seed the frame directly so the measured interval covers RTI alone.
    initial_e=8'haa; initial_f=8'hbb;
    load_program(1'b1,8'h3b,8'h12,8'h12);
    put(16'h010b,8'h2f); put(16'h010c,8'hf2); // LDS #$2ff2
    stack_mem[18]=8'h80; // stacked CC.E=1
    stack_mem[21]=8'h12; stack_mem[22]=8'h34; // E/F
    stack_mem[30]=8'h01; stack_mem[31]=8'h30; // return PC
    put(16'h0130,8'h12);
    measure_case(17,16'h0130,"RTI full native CC.E=1");
    assert_msg(stack_read_count==14 && regs[63:48]==16'h3000,
        $sformatf("RTI full native reads/S=%0d/%04x expected 14/3000",
                  stack_read_count,regs[63:48]));
    check_ef(8'h12,8'h34,8'h01,"RTI full native CC.E=1");

    load_program(1'b0,8'h3b,8'h12,8'h12);
    put(16'h010b,8'h2f); put(16'h010c,8'hfe); // LDS #$2ffe
    stack_mem[30]=8'h00; stack_mem[31]=8'h01; stack_mem[32]=8'h30;
    put(16'h0130,8'h12);
    measure_case(6,16'h0130,"RTI short emulation CC.E=0");
    assert_msg(regs[63:48]==16'h3001,
        $sformatf("RTI short emulation S=%04x expected 3001 after CC+PC frame",
                  regs[63:48]));
    load_program(1'b0,8'ha6,8'h89,8'h00); set_xy_prelude();
    put(16'h0122,8'h00); put(16'h0123,8'h02); put(16'h0124,8'h12); direct_mem[8'h12]=8'h5a;
    measure_case(8,16'h0124,"LDA indexed 16-bit offset emulation");
    load_program(1'b1,8'ha6,8'h89,8'h00); set_xy_prelude();
    put(16'h0122,8'h00); put(16'h0123,8'h02); put(16'h0124,8'h12); direct_mem[8'h12]=8'h5a;
    measure_case(7,16'h0124,"LDA indexed 16-bit offset native");
    assert_msg(regs[7:0]==8'h5a,"LDA 16-bit indexed offset native data mismatch");
    load_program(1'b0,8'ha6,8'h8b,8'h12); preload_dx(16'h0002,16'h0010);
    direct_mem[8'h12]=8'h5a; measure_case(8,16'h0122,"LDA D,X emulation");
    load_program(1'b1,8'ha6,8'h8b,8'h12); preload_dx(16'h0002,16'h0010);
    direct_mem[8'h12]=8'h5a; measure_case(6,16'h0122,"LDA D,X native");
    assert_msg(regs[7:0]==8'h5a,"LDA D,X native data mismatch");

    // Page-11 bit operations: postbyte A, memory bit 5, register/memory bit 1.
    run_bitop(8'h01,8'h30,8'h02,8'h20,8'h02,8'h20,6,"BAND native");
    run_bitop(8'h01,8'h31,8'h02,8'h20,8'h00,8'h20,6,"BIAND native");
    run_bitop(8'h01,8'h32,8'h00,8'h20,8'h02,8'h20,6,"BOR native");
    run_bitop(8'h01,8'h33,8'h00,8'h20,8'h00,8'h20,6,"BIOR native");
    run_bitop(8'h01,8'h34,8'h02,8'h20,8'h00,8'h20,6,"BEOR native");
    run_bitop(8'h01,8'h35,8'h02,8'h20,8'h02,8'h20,6,"BIEOR native");
    run_bitop(8'h01,8'h36,8'h00,8'h20,8'h02,8'h20,6,"LDBT native");
    run_bitop(8'h01,8'h37,8'h20,8'h00,8'h20,8'h02,7,"STBT native");
    for(i=0;i<8;i=i+1)
        for(integer selector=0;selector<3;selector=selector+1)
            for(integer srcbit=0;srcbit<8;srcbit=srcbit+1)
                for(integer dstbit=0;dstbit<8;dstbit=dstbit+1)
                    for(integer memlevel=0;memlevel<2;memlevel=memlevel+1)
                        run_bitop_matrix_case(i,selector,srcbit,dstbit,memlevel);

    // TFM length is the initial W value; each transfer adds three E cycles.
    run_tfm_xy(8'h00,8'h38,8'h12,16'h0002,16'h0040,16'h0060,
               16'h0042,16'h0062,2,8'haa,8'hbb,"TFM X+/Y+ n=2 emulation");
    run_tfm_xy(8'h01,8'h39,8'h12,16'h0002,16'h0041,16'h0061,
               16'h003f,16'h005f,2,8'haa,8'hbb,"TFM X-/Y- n=2 native");
    run_tfm_xy(8'h00,8'h3a,8'h12,16'h0002,16'h0040,16'h0060,
               16'h0042,16'h0060,2,8'hbb,8'h00,"TFM X+/Y n=2 emulation");
    run_tfm_xy(8'h01,8'h3b,8'h12,16'h0001,16'h0040,16'h0060,
               16'h0040,16'h0061,1,8'haa,8'h00,"TFM X/Y+ n=1 native");
    run_tfm_xy(8'h00,8'h38,8'h12,16'h0000,16'h0040,16'h0060,
               16'h0040,16'h0060,0,8'h00,8'h00,"TFM X+/Y+ n=0 emulation");
    run_tfm_xy(8'h01,8'h38,8'h12,16'h0001,16'h0040,16'h0060,
               16'h0041,16'h0061,1,8'haa,8'h00,"TFM X+/Y+ n=1 native");
    run_tfm_du(8'h01,16'h0002,16'h0040,8'h38,8'h03,2,"TFM D+/U+ n=2 native");
    run_tfm_su(16'h0002,2,"TFM S+/U+ n=2 native");
    run_divzero_trap(8'h00,1'b0); // DIVD #0 emulation
    run_divzero_trap(8'h01,1'b0); // DIVD #0 native
    run_divzero_trap(8'h00,1'b1); // DIVQ #0 emulation
    run_divzero_trap(8'h01,1'b1); // DIVQ #0 native
    run_divzero_memory_trap(8'h00,1'b0,0); // DIVD direct emulation
    run_divzero_memory_trap(8'h01,1'b0,0); // DIVD direct native
    run_divzero_memory_trap(8'h00,1'b0,1); // DIVD extended emulation
    run_divzero_memory_trap(8'h01,1'b0,1); // DIVD extended native
    run_divzero_memory_trap(8'h00,1'b0,2); // DIVD indexed emulation
    run_divzero_memory_trap(8'h01,1'b0,2); // DIVD indexed native
    run_divzero_memory_trap(8'h00,1'b1,0); // DIVQ direct emulation
    run_divzero_memory_trap(8'h01,1'b1,0); // DIVQ direct native
    run_divzero_memory_trap(8'h00,1'b1,1); // DIVQ extended emulation
    run_divzero_memory_trap(8'h01,1'b1,1); // DIVQ extended native
    run_divzero_memory_trap(8'h00,1'b1,2); // DIVQ indexed emulation
    run_divzero_memory_trap(8'h01,1'b1,2); // DIVQ indexed native
    run_tfm_same(8'h38,16'h0040,16'h0044,16'h0002,2,8'haa,8'haa,"TFM X+/X+ same register");
    run_tfm_same(8'h39,16'h0041,16'h003f,16'h0001,1,8'hbb,8'hbb,"TFM X-/X- same register");
    run_tfm_irq_restart();
    run_hd_illegal_opcode(8'h15);
    run_hd_illegal_opcode(8'h87);
    run_hd_illegal_opcode(8'hc7);
    run_invalid_tfm_selector();

    // Arithmetic instruction checks use Atkinson's page-149 timing rows and
    // signed boundary notes; register results are checked independently of
    // the combinational helper unit.
    // Representative page-10/page-11 word paths and native indexed
    // extended-indirect inherited timing. Use them before iterative divide
    // and multiply tests so a decode regression reports its own first row.
    run_direct_word(8'h10,8'h9b,16'h1235,7,5,"ADDW direct");
    run_direct_word(8'h10,8'h90,16'h1233,7,5,"SUBW direct");
    run_direct_word(8'h11,8'h93,16'h4000,7,5,"CMPU direct");
    run_direct_word(8'h11,8'h9c,16'h3000,7,5,"CMPS direct");
    run_cmpu_immediate();
    run_indexed_jump_call(0,8'h6e,1'b0,3,"JMP indexed ,X emulation");
    run_indexed_jump_call(1,8'h6e,1'b0,3,"JMP indexed ,X native");
    run_indexed_jump_call(0,8'had,1'b1,7,"JSR indexed ,X emulation");
    run_indexed_jump_call(1,8'had,1'b1,6,"JSR indexed ,X native");
    run_bitmd(8'h00,8'h01,1'b0,1'b1,"BITMD emulation low bits ignored");
    run_bitmd(8'h01,8'h01,1'b0,1'b1,"BITMD native low bits ignored");
    run_bitmd(8'h00,8'h40,1'b1,1'b0,"BITMD emulation IL status");
    run_bitmd(8'h01,8'h40,1'b1,1'b0,"BITMD native IL status");
    run_ldq_direct();
    run_ldq_immediate();
    run_lda_extended_indirect_native();
    initial_e=8'h12; initial_f=8'h34;
    run_native_software_interrupt(8'h3f,8'h12,16'hfffa,16'h0121,21,"native SWI");
    run_native_software_interrupt(8'h10,8'h3f,16'hfff4,16'h0122,22,"native SWI2");
    run_native_software_interrupt(8'h11,8'h3f,16'hfff2,16'h0122,22,"native SWI3");
    run_emulation_software_interrupt(8'h3f,8'h12,16'hfffa,16'h0121,19,"emulation SWI");
    run_emulation_software_interrupt(8'h10,8'h3f,16'hfff4,16'h0122,20,"emulation SWI2");
    run_emulation_software_interrupt(8'h11,8'h3f,16'hfff2,16'h0122,20,"emulation SWI3");
    run_native_cwai_irq();
    run_emulation_cwai_timing();
    run_direct_word(8'h10,8'h98,16'h1235,7,5,"EORD direct");

    initial_e=0; initial_f=0;
    load_program(1'b1,8'h11,8'h8f,8'h00); // MULD #$0001
    preload_d(16'h0001); put(16'h0123,8'h01); put(16'h0113,8'h03);
    measure_case(28,16'h0124,"MULD immediate native");
    assert_msg(cc_before_target[1],
        $sformatf("MULD V-preservation precondition CC=%02x expected V=1",cc_before_target));
    assert_msg(regs[15:0]==16'h0000 && regs6309[31:16]==16'h0001,
        $sformatf("MULD 1*1 Q=%04x:%04x expected 0000:0001",regs[15:0],regs6309[31:16]));
    assert_msg(regs[81] && regs[82] && regs[80] && cc_before_target[0],
        $sformatf("MULD CC=%02x pre-CC=%02x expected V/C preserved and Z set",
                  regs[87:80],cc_before_target));

    initial_e=0; initial_f=0;
    load_program(1'b0,8'h11,8'h8d,8'h03); // DIVD #$03
    preload_d(16'hfff9); // -7 / 3 = -2 remainder -1
    measure_case(26,16'h0123,"DIVD immediate negative");
    assert_msg({regs[7:0],regs[15:8]}==16'hfffe,
        $sformatf("DIVD -7/3 D=%04x expected fffe",{regs[7:0],regs[15:8]}));
    assert_msg(regs[83] && !regs[82] && !regs[81] && !regs[80],
        $sformatf("DIVD -7/3 CC=%02x expected N",regs[87:80]));

    // Native immediate baselines are fixed for non-overflowing operands:
    // Atkinson p.149 note 12 changes the count only for specified overflow.
    initial_e=0; initial_f=0;
    load_program(8'h01,8'h11,8'h8d,8'h03); // DIVD #$03
    preload_d(16'h0007); // 7 / 3 = 2 remainder 1
    measure_case(25,16'h0123,"DIVD immediate native normal quotient");

    initial_e=0; initial_f=8'h07; // Q=0000:0007
    load_program(8'h01,8'h11,8'h8e,8'h00); // DIVQ #$0003
    preload_d(16'h0000); put(16'h0123,8'h03);
    measure_case(34,16'h0124,"DIVQ immediate native normal quotient");

    load_program(1'b0,8'h11,8'h8d,8'h03); // Hard quotient range overflow.
    preload_d(16'hfc7c); // -900 / 3 cannot fit the signed 8-bit quotient.
    measure_case(13,16'h0123,"DIVD hard range overflow");
    assert_msg({regs[7:0],regs[15:8]}==16'h0384,
        $sformatf("DIVD hard overflow D=%04x expected dividend magnitude 0384",
                  {regs[7:0],regs[15:8]}));
    assert_msg(regs[83] && !regs[82] && regs[81] && !regs[80],
        $sformatf("DIVD hard overflow CC=%02x expected N,V",regs[87:80]));

    initial_e=8'hff; initial_f=8'hf9; // W={E,F}=FFF9
    load_program(1'b0,8'h11,8'h8e,8'h00); // DIVQ #$0003
    preload_d(16'hffff); put(16'h0123,8'h03); // Q = -7
    measure_case(35,16'h0124,"DIVQ immediate negative");
    assert_msg({regs[7:0],regs[15:8]}==16'hffff && regs6309[31:16]==16'hfffe,
        $sformatf("DIVQ -7/3 Q=%04x:%04x expected ffff:fffe",
                  {regs[7:0],regs[15:8]},regs6309[31:16]));
    assert_msg(regs[83] && !regs[82] && !regs[81] && !regs[80],
        $sformatf("DIVQ -7/3 CC=%02x expected N",regs[87:80]));

    initial_e=8'hcb; initial_f=8'hb0; // W={E,F}=CBB0
    load_program(1'b0,8'h11,8'h8e,8'h00); // DIVQ #$0003, hard range overflow.
    preload_d(16'hfffc); put(16'h0123,8'h03); // Q = -210000
    measure_case(14,16'h0124,"DIVQ hard range overflow");
    assert_msg({regs[7:0],regs[15:8]}==16'h0003 && regs6309[31:16]==16'h3450,
        $sformatf("DIVQ hard overflow Q=%04x:%04x expected magnitude 0003:3450",
                  {regs[7:0],regs[15:8]},regs6309[31:16]));
    assert_msg(regs[83] && !regs[82] && regs[81] && !regs[80],
        $sformatf("DIVQ hard overflow CC=%02x expected N,V",regs[87:80]));

    // Original-device signed overflow boundaries use unsigned quotient
    // magnitude and dividend-sign/remainder conventions.
    load_program(1'b0,8'h11,8'h8d,8'h01); preload_d(16'hff80);
    measure_case(25,16'h0123,"DIVD -128/1 soft overflow");
    assert_msg({regs[7:0],regs[15:8]}==16'h0080 &&
               (regs[87:80]&8'h0f)==8'h0a,
        $sformatf("DIVD -128/1 D=%04x CC=%02x expected magnitude 0080/NV",
                  {regs[7:0],regs[15:8]},regs[87:80]));
    load_program(1'b0,8'h11,8'h8d,8'h01); preload_d(16'hff7f);
    measure_case(25,16'h0123,"DIVD -129/1 boundary");
    assert_msg({regs[7:0],regs[15:8]}==16'h0081 &&
               (regs[87:80]&8'h0f)==8'h0b,
        $sformatf("DIVD -129/1 D=%04x CC=%02x expected magnitude 0081/NVC",
                  {regs[7:0],regs[15:8]},regs[87:80]));

    initial_e=8'h80; initial_f=8'h00;
    load_program(1'b0,8'h11,8'h8e,8'hff); preload_d(16'hffff); put(16'h0123,8'hff);
    measure_case(36,16'h0124,"DIVQ -32768/-1 boundary");
    assert_msg({regs[7:0],regs[15:8]}==16'h0000 && regs6309[31:16]==16'h8000 &&
               (regs[87:80]&8'h0f)==8'h02,
        $sformatf("DIVQ -32768/-1 Q=%04x:%04x CC=%02x expected magnitude 0000:8000/02",
                  {regs[7:0],regs[15:8]},regs6309[31:16],regs[87:80]));
    initial_e=8'h7f; initial_f=8'hff;
    load_program(1'b0,8'h11,8'h8e,8'h00); preload_d(16'hffff); put(16'h0123,8'h01);
    measure_case(35,16'h0124,"DIVQ -32769/1 boundary");
    assert_msg({regs[7:0],regs[15:8]}==16'h0000 && regs6309[31:16]==16'h8001 &&
               (regs[87:80]&8'h0f)==8'h03,
        $sformatf("DIVQ -32769/1 Q=%04x:%04x CC=%02x expected magnitude 0000:8001/03",
                  {regs[7:0],regs[15:8]},regs6309[31:16],regs[87:80]));

    // Memory addressing classes use the same signed operands with data at
    // $0040. Atkinson's emulation/native pairs are independent cycle oracles.
    // DIVD reads an 8-bit divisor; DIVQ and MULD read a 16-bit operand.
    load_program(1'b0,8'h11,8'h9d,8'h40); preload_d(16'hfff9); direct_mem[8'h40]=8'h03;
    measure_case(28,16'h0123,"DIVD direct emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'hfffe,"DIVD direct result mismatch");
    load_program(1'b1,8'h11,8'h9d,8'h40); preload_d(16'hfff9); direct_mem[8'h40]=8'h03;
    measure_case(27,16'h0123,"DIVD direct native");
    assert_msg({regs[7:0],regs[15:8]}==16'hfffe,"DIVD direct native result mismatch");
    load_program(1'b0,8'h11,8'had,8'h84); preload_dx(16'hfff9,16'h0040); direct_mem[8'h40]=8'h03;
    measure_case(28,16'h0123,"DIVD indexed emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'hfffe,
        $sformatf("DIVD indexed result D=%04x X=%04x CC=%02x expected fffe",
                  {regs[7:0],regs[15:8]},regs[31:16],regs[87:80]));
    load_program(1'b1,8'h11,8'had,8'h84); preload_dx(16'hfff9,16'h0040); direct_mem[8'h40]=8'h03;
    measure_case(28,16'h0123,"DIVD indexed native");
    assert_msg({regs[7:0],regs[15:8]}==16'hfffe,"DIVD indexed native result mismatch");
    load_program(1'b0,8'h11,8'hbd,8'h00); preload_d(16'hfff9);
    put(16'h0123,8'h40); direct_mem[8'h40]=8'h03;
    measure_case(29,16'h0124,"DIVD extended emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'hfffe,"DIVD extended result mismatch");
    load_program(1'b1,8'h11,8'hbd,8'h00); preload_d(16'hfff9);
    put(16'h0123,8'h40); direct_mem[8'h40]=8'h03;
    measure_case(28,16'h0124,"DIVD extended native");
    assert_msg({regs[7:0],regs[15:8]}==16'hfffe,"DIVD extended native result mismatch");

    initial_e=8'hff; initial_f=8'hf9;
    load_program(1'b0,8'h11,8'h9e,8'h40); preload_d(16'hffff);
    direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h03;
    measure_case(37,16'h0123,"DIVQ direct emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'hffff && regs6309[31:16]==16'hfffe,
        "DIVQ direct result mismatch");
    load_program(1'b1,8'h11,8'h9e,8'h40); preload_d(16'hffff);
    direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h03;
    measure_case(36,16'h0123,"DIVQ direct native");
    assert_msg({regs[7:0],regs[15:8]}==16'hffff && regs6309[31:16]==16'hfffe,
        "DIVQ direct native result mismatch");
    load_program(1'b0,8'h11,8'hae,8'h84); preload_dx(16'hffff,16'h0040);
    direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h03;
    measure_case(37,16'h0123,"DIVQ indexed emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'hffff && regs6309[31:16]==16'hfffe,
        "DIVQ indexed result mismatch");
    load_program(1'b1,8'h11,8'hae,8'h84); preload_dx(16'hffff,16'h0040);
    direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h03;
    measure_case(37,16'h0123,"DIVQ indexed native");
    assert_msg({regs[7:0],regs[15:8]}==16'hffff && regs6309[31:16]==16'hfffe,
        "DIVQ indexed native result mismatch");
    load_program(1'b0,8'h11,8'hbe,8'h00); preload_d(16'hffff);
    put(16'h0123,8'h40); direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h03;
    measure_case(38,16'h0124,"DIVQ extended emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'hffff && regs6309[31:16]==16'hfffe,
        "DIVQ extended result mismatch");
    load_program(1'b1,8'h11,8'hbe,8'h00); preload_d(16'hffff);
    put(16'h0123,8'h40); direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h03;
    measure_case(37,16'h0124,"DIVQ extended native");
    assert_msg({regs[7:0],regs[15:8]}==16'hffff && regs6309[31:16]==16'hfffe,
        "DIVQ extended native result mismatch");

    initial_e=0; initial_f=0;
    load_program(1'b0,8'h11,8'h9f,8'h40); preload_d(16'h0001);
    direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h01;
    measure_case(30,16'h0123,"MULD direct emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'h0000 && regs6309[31:16]==16'h0001,
        "MULD direct result mismatch");
    load_program(1'b1,8'h11,8'h9f,8'h40); preload_d(16'h0001);
    direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h01;
    measure_case(29,16'h0123,"MULD direct native");
    assert_msg({regs[7:0],regs[15:8]}==16'h0000 && regs6309[31:16]==16'h0001,
        "MULD direct native result mismatch");
    load_program(1'b0,8'h11,8'haf,8'h84); preload_dx(16'h0001,16'h0040);
    direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h01;
    measure_case(30,16'h0123,"MULD indexed emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'h0000 && regs6309[31:16]==16'h0001,
        "MULD indexed result mismatch");
    load_program(1'b1,8'h11,8'haf,8'h84); preload_dx(16'h0001,16'h0040);
    direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h01;
    measure_case(30,16'h0123,"MULD indexed native");
    assert_msg({regs[7:0],regs[15:8]}==16'h0000 && regs6309[31:16]==16'h0001,
        "MULD indexed native result mismatch");
    load_program(1'b0,8'h11,8'hbf,8'h00); preload_d(16'h0001);
    put(16'h0123,8'h40); direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h01;
    measure_case(31,16'h0124,"MULD extended emulation");
    assert_msg({regs[7:0],regs[15:8]}==16'h0000 && regs6309[31:16]==16'h0001,
        "MULD extended result mismatch");
    load_program(1'b1,8'h11,8'hbf,8'h00); preload_d(16'h0001);
    put(16'h0123,8'h40); direct_mem[8'h40]=8'h00; direct_mem[8'h41]=8'h01;
    measure_case(30,16'h0124,"MULD extended native");
    assert_msg({regs[7:0],regs[15:8]}==16'h0000 && regs6309[31:16]==16'h0001,
        "MULD extended native result mismatch");
    // Original-device timing adds one cycle per negative DIVD/DIVQ input and
    // two cycles for MULD when either or both inputs are negative. Exercise
    // all sign pairs across all address forms and both MD modes.
    for(signed_op=0;signed_op<3;signed_op=signed_op+1)
    for(signed_form=0;signed_form<4;signed_form=signed_form+1)
    for(signed_mode=0;signed_mode<2;signed_mode=signed_mode+1)
    for(signed_combo=0;signed_combo<4;signed_combo=signed_combo+1)
        run_signed_math_case(signed_op,signed_mode,signed_form,signed_combo);

    // Original-device divider boundary behavior, across every addressing form
    // and both MD modes. DIVD soft overflow starts at |quotient|=128 and hard
    // overflow at 256; DIVQ soft overflow starts at 32768 and hard at 65536.
    for(signed_form=0;signed_form<4;signed_form=signed_form+1)
    for(signed_mode=0;signed_mode<2;signed_mode=signed_mode+1) begin
        run_division_overflow_case(0,signed_mode,signed_form,32'h0000007f,16'h0001,32'h0000007f,4'h1,0);
        run_division_overflow_case(0,signed_mode,signed_form,32'hffffff81,16'h0001,32'h00000081,4'h9,0);
        run_division_overflow_case(0,signed_mode,signed_form,32'h00000080,16'h0001,32'h00000080,4'ha,1);
        run_division_overflow_case(0,signed_mode,signed_form,32'hffffff80,16'h0001,32'h00000080,4'ha,1);
        run_division_overflow_case(0,signed_mode,signed_form,32'h000000ff,16'h0001,32'h000000ff,4'hb,1);
        run_division_overflow_case(0,signed_mode,signed_form,32'hffffff01,16'h0001,32'h000000ff,4'hb,1);
        run_division_overflow_case(0,signed_mode,signed_form,32'h00000100,16'h0001,32'h00000100,4'h2,2);
        run_division_overflow_case(0,signed_mode,signed_form,32'hffffff00,16'h0001,32'h00000100,4'ha,2);

        run_division_overflow_case(1,signed_mode,signed_form,32'h00007fff,16'h0001,32'h00007fff,4'h1,0);
        run_division_overflow_case(1,signed_mode,signed_form,32'hffff8001,16'h0001,32'h00008001,4'h9,0);
        run_division_overflow_case(1,signed_mode,signed_form,32'h00008000,16'h0001,32'h00008000,4'h2,1);
        run_division_overflow_case(1,signed_mode,signed_form,32'hffff8000,16'h0001,32'h00008000,4'h2,1);
        run_division_overflow_case(1,signed_mode,signed_form,32'h0000ffff,16'h0001,32'h0000ffff,4'h3,1);
        run_division_overflow_case(1,signed_mode,signed_form,32'hffff0001,16'h0001,32'h0000ffff,4'h3,1);
        run_division_overflow_case(1,signed_mode,signed_form,32'h00010000,16'h0001,32'h00010000,4'h2,2);
        run_division_overflow_case(1,signed_mode,signed_form,32'hffff0000,16'h0001,32'h00010000,4'ha,2);
    end
    // Non-boundary hard-overflow cases also verify preservation of the full
    // dividend magnitude and its sign in N across both modes and all forms.
    for(signed_form=0;signed_form<4;signed_form=signed_form+1)
    for(signed_mode=0;signed_mode<2;signed_mode=signed_mode+1) begin
        run_division_overflow_case(0,signed_mode,signed_form,32'h00000385,16'h0003,32'h00000385,4'h2,2);
        run_division_overflow_case(0,signed_mode,signed_form,32'hfffffc7b,16'h0003,32'h00000385,4'ha,2);
        run_division_overflow_case(1,signed_mode,signed_form,32'h00033451,16'h0003,32'h00033451,4'h2,2);
        run_division_overflow_case(1,signed_mode,signed_form,32'hfffc_cbaf,16'h0003,32'h00033451,4'ha,2);
    end
    initial_e=8'h12; initial_f=8'h34;

    // Memory-immediate operations share the documented 6/7/7 cycle counts
    // for direct/indexed/extended addressing in both MD modes. They use the
    // same mask ($0f) and memory byte ($a5), yielding 05/af/aa for AIM/OIM/EIM;
    // TIM must leave memory unchanged.
    run_mem_immediate(0,8'h02,0,6,8'h05,"AIM direct emulation");
    run_mem_immediate(1,8'h02,0,6,8'h05,"AIM direct native");
    run_mem_immediate(0,8'h62,1,7,8'h05,"AIM indexed emulation");
    run_mem_immediate(1,8'h62,1,7,8'h05,"AIM indexed native");
    run_mem_immediate(0,8'h72,2,7,8'h05,"AIM extended emulation");
    run_mem_immediate(1,8'h72,2,7,8'h05,"AIM extended native");
    run_mem_immediate(0,8'h01,0,6,8'haf,"OIM direct emulation");
    run_mem_immediate(1,8'h01,0,6,8'haf,"OIM direct native");
    run_mem_immediate(0,8'h61,1,7,8'haf,"OIM indexed emulation");
    run_mem_immediate(1,8'h61,1,7,8'haf,"OIM indexed native");
    run_mem_immediate(0,8'h71,2,7,8'haf,"OIM extended emulation");
    run_mem_immediate(1,8'h71,2,7,8'haf,"OIM extended native");
    run_mem_immediate(0,8'h05,0,6,8'haa,"EIM direct emulation");
    run_mem_immediate(1,8'h05,0,6,8'haa,"EIM direct native");
    run_mem_immediate(0,8'h65,1,7,8'haa,"EIM indexed emulation");
    run_mem_immediate(1,8'h65,1,7,8'haa,"EIM indexed native");
    run_mem_immediate(0,8'h75,2,7,8'haa,"EIM extended emulation");
    run_mem_immediate(1,8'h75,2,7,8'haa,"EIM extended native");
    run_mem_immediate(0,8'h0b,0,6,8'ha5,"TIM direct emulation");
    run_mem_immediate(1,8'h0b,0,6,8'ha5,"TIM direct native");
    run_mem_immediate(0,8'h6b,1,7,8'ha5,"TIM indexed emulation");
    run_mem_immediate(1,8'h6b,1,7,8'ha5,"TIM indexed native");
    run_mem_immediate(0,8'h7b,2,7,8'ha5,"TIM extended emulation");
    run_mem_immediate(1,8'h7b,2,7,8'ha5,"TIM extended native");

    // A page-11 instruction immediately before an unprefixed AIM/OIM must
    // clear the old prefix decode state before fetching the next opcode.
    run_memimm_after_prefix(0,8'h02,8'h05,"AIM after page-11 emulation");
    run_memimm_after_prefix(1,8'h02,8'h05,"AIM after page-11 native");
    run_memimm_after_prefix(0,8'h01,8'haf,"OIM after page-11 emulation");
    run_memimm_after_prefix(1,8'h01,8'haf,"OIM after page-11 native");

    // Inherited 6809 instructions retain their 6809 timings in emulation and
    // use the reduced native counts transcribed in the Atkinson summary.
    run_sex(0,2,8'h00,"SEX emulation");
    run_sex(1,1,8'h00,"SEX native");
    run_puls_zero(0,5,"PULS empty mask emulation");
    run_puls_zero(1,4,"PULS empty mask native");
    run_unary_mem(0,8'h00,1'b0,6,8'h5b,"NEG direct emulation");
    run_unary_mem(1,8'h00,1'b0,5,8'h5b,"NEG direct native");
    run_unary_mem(0,8'h70,1'b1,7,8'h5b,"NEG extended emulation");
    run_unary_mem(1,8'h70,1'b1,6,8'h5b,"NEG extended native");
    run_unary_mem(0,8'h0f,1'b0,6,8'h00,"CLR direct emulation");
    run_unary_mem(1,8'h0f,1'b0,5,8'h00,"CLR direct native");
    run_unary_mem(0,8'h7f,1'b1,7,8'h00,"CLR extended emulation");
    run_unary_mem(1,8'h7f,1'b1,6,8'h00,"CLR extended native");
    run_unary_mem(0,8'h0d,1'b0,6,8'ha5,"TST direct emulation");
    run_unary_mem(1,8'h0d,1'b0,4,8'ha5,"TST direct native");
    run_unary_mem(0,8'h7d,1'b1,7,8'ha5,"TST extended emulation");
    run_unary_mem(1,8'h7d,1'b1,5,8'ha5,"TST extended native");
    run_jump_call(0,8'h0e,1'b0,1'b0,3,"JMP direct emulation");
    run_jump_call(1,8'h0e,1'b0,1'b0,2,"JMP direct native");
    run_jump_call(0,8'h7e,1'b1,1'b0,4,"JMP extended emulation");
    run_jump_call(1,8'h7e,1'b1,1'b0,3,"JMP extended native");
    run_jump_call(0,8'h9d,1'b0,1'b1,7,"JSR direct emulation");
    run_jump_call(1,8'h9d,1'b0,1'b1,6,"JSR direct native");
    run_jump_call(0,8'hbd,1'b1,1'b1,8,"JSR extended emulation");
    run_jump_call(1,8'hbd,1'b1,1'b1,7,"JSR extended native");
    run_relative(0,8'h8d,16'h0124,7,1'b1,16'h0122,"BSR emulation");
    run_relative(1,8'h8d,16'h0124,6,1'b1,16'h0122,"BSR native");
    run_relative(0,8'h16,16'h0125,5,1'b0,16'h0000,"LBRA emulation");
    run_relative(1,8'h16,16'h0125,4,1'b0,16'h0000,"LBRA native");
    run_relative(0,8'h17,16'h0125,9,1'b1,16'h0123,"LBSR emulation");
    run_relative(1,8'h17,16'h0125,7,1'b1,16'h0123,"LBSR native");
    run_hd_illegal_case(0,8'h41,8'h12,8'h12,"illegal $41 emulation");
    run_hd_illegal_case(1,8'h41,8'h12,8'h12,"illegal $41 native");
    run_hd_illegal_case(0,8'h10,8'h41,8'h12,"illegal $10 $41 emulation");
    run_hd_illegal_case(1,8'h10,8'h41,8'h12,"illegal $10 $41 native");
    run_hd_illegal_case(0,8'h10,8'h10,8'h12,"illegal repeated $10 prefix emulation");
    run_hd_illegal_case(1,8'h10,8'h10,8'h12,"illegal repeated $10 prefix native");
    run_hd_illegal_case(0,8'h10,8'h11,8'h12,"illegal mixed $10/$11 prefix emulation");
    run_hd_illegal_case(1,8'h10,8'h11,8'h12,"illegal mixed $10/$11 prefix native");
    run_hd_illegal_case(0,8'h11,8'h10,8'h12,"illegal mixed $11/$10 prefix emulation");
    run_hd_illegal_case(1,8'h11,8'h10,8'h12,"illegal mixed $11/$10 prefix native");
    run_hd_illegal_case(0,8'h11,8'h11,8'h12,"illegal repeated $11 prefix emulation");
    run_hd_illegal_case(1,8'h11,8'h11,8'h12,"illegal repeated $11 prefix native");


    // Atkinson's indexed-postbyte table gives E/F/W,R one extra E cycle and
    // ,W no extra cycles over indexed LDA's 4-cycle base.
    run_efw_index(0,8'h87,8'h02,8'h00,5,8'h12,"LDA E,X emulation");
    run_efw_index(1,8'h87,8'h02,8'h00,5,8'h12,"LDA E,X native");
    run_efw_index(0,8'h8a,8'h00,8'h02,5,8'h12,"LDA F,X emulation");
    run_efw_index(1,8'h8a,8'h00,8'h02,5,8'h12,"LDA F,X native");
    run_efw_index(0,8'h8e,8'h00,8'h02,5,8'h12,"LDA W,X emulation");
    run_efw_index(1,8'h8e,8'h00,8'h02,5,8'h12,"LDA W,X native");
    run_efw_index(0,8'h8f,8'h00,8'h12,4,8'h12,"LDA ,W emulation");
    run_efw_index(1,8'h8f,8'h00,8'h12,4,8'h12,"LDA ,W native");
    // W has separate displacement and auto-update postbytes. These values
    // are the indexed LDA base plus the Atkinson postbyte increments.
    run_w_postbyte(0,8'haf,6,16'h0012,0,"LDA n,W emulation");
    run_w_postbyte(1,8'haf,6,16'h0012,0,"LDA n,W native");
    run_w_postbyte(0,8'hb0,9,16'h0012,1,"LDA [n,W] emulation");
    run_w_postbyte(1,8'hb0,9,16'h0012,1,"LDA [n,W] native");
    run_w_postbyte(0,8'hcf,5,16'h0014,2,"LDA ,W++ emulation");
    run_w_postbyte(1,8'hcf,5,16'h0014,2,"LDA ,W++ native");
    run_w_postbyte(0,8'hd0,8,16'h0014,3,"LDA [,W++] emulation");
    run_w_postbyte(1,8'hd0,8,16'h0014,3,"LDA [,W++] native");
    run_w_postbyte(0,8'hef,5,16'h0010,4,"LDA ,--W emulation");
    run_w_postbyte(1,8'hef,5,16'h0010,4,"LDA ,--W native");
    run_w_postbyte(0,8'hf0,8,16'h0010,5,"LDA [,--W] emulation");
    run_w_postbyte(1,8'hf0,8,16'h0010,5,"LDA [,--W] native");
    initial_e=8'h12; initial_f=8'h34;

    // MD.NM selects native frames; MD.FM selects a full FIRQ frame. Short and
    // full forms check stack length, CC.E, E/F placement, and RTI restoration.
    run_native_firq(8'h01,3,1'b0,"native FIRQ short");
    run_native_firq(8'h03,14,1'b1,"native FIRQ full");
    run_native_short_firq_rti();
    run_native_irq_rti();
    run_sync_emulation_minimum();
    run_sync_native_minimum();

    pass();
end

initial begin
    clk=0; rst=1;
    forever #10 clk=~clk;
end
initial begin
    #100 rst=0;
    #100000000 $display("FAIL: testbench timeout"); $finish;
end
initial begin
    $dumpfile("test.lxt");
    $dumpvars(0,clk,rst,cpu_reset_n,phase,addr,op,lic);
    $dumpvars(0,uut.CpuState);
end
endmodule
