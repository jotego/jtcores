/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-10-2026 */

`timescale 1ns/1ps
module test;
reg clk=0, rst=1, irq=0, nmi=0, ext_halt=0, enable=1;
reg [3:0] divider=0;
wire cen=divider==0;
wire [15:0] addr;
wire [7:0] dout;
wire e, vma, wr, done, instruction_end, opcode_fetch, ba;
reg [7:0] memory[0:65535];
wire [7:0] din=memory[addr];
integer stack_writes=0, irq_reads=0, nmi_reads=0, transfers=0, k;
integer wake_start, irq_start, nmi_start;
reg [15:0] saved_pc;
reg [7:0] saved_cc;
always #5 clk=~clk;
always @(posedge clk) begin
    divider <= divider+1'd1;
    if(rst) begin
        stack_writes=0;
        irq_reads=0;
        nmi_reads=0;
        transfers=0;
    end else if(done) begin
        transfers=transfers+1;
        if(vma && wr) begin
            memory[addr] <= dout;
            if(addr>=16'hf879 && addr<=16'hf87f) stack_writes=stack_writes+1;
        end
        if(vma && !wr && (addr==16'hfff8 || addr==16'hfff9)) irq_reads=irq_reads+1;
        if(vma && !wr && (addr==16'hfffc || addr==16'hfffd)) nmi_reads=nmi_reads+1;
    end
end

jt6802 cpu(
    .rst             ( rst             ),
    .cpu_rst         ( rst             ),
    .clk             ( clk             ),
    .cen             ( cen             ),
    .enable          ( enable          ),
    .ready           ( 1'b1            ),
    .mr_n            ( 1'b1            ),
    .nsc8105         ( 1'b0            ),
    .din             ( din             ),
    .addr            ( addr            ),
    .dout            ( dout            ),
    .e               ( e               ),
    .vma             ( vma             ),
    .wr              ( wr              ),
    .done            ( done            ),
    .instruction_end ( instruction_end ),
    .opcode_fetch    ( opcode_fetch    ),
    .ext_halt        ( ext_halt        ),
    .ba              ( ba              ),
    .irq             ( irq             ),
    .nmi             ( nmi             )
);

task prepare;
    input masked, waiting;
    begin
        @(negedge clk);
        rst=1; irq=0; nmi=0; ext_halt=0; enable=1;
        for(k=0;k<65536;k=k+1) memory[k]=8'h01;
        memory[16'hfffe]=8'h80; memory[16'hffff]=0;
        memory[16'hfff8]=8'h90; memory[16'hfff9]=0;
        memory[16'hfffc]=8'h91; memory[16'hfffd]=0;
        memory[16'h9000]=8'h3b; memory[16'h9100]=8'h3b;
        memory[16'h8000]=8'h8e; memory[16'h8001]=8'hf8; memory[16'h8002]=8'h7f;
        memory[16'h8003]=8'h86; memory[16'h8004]=8'h12;
        memory[16'h8005]=8'hc6; memory[16'h8006]=8'h34;
        memory[16'h8007]=8'hce; memory[16'h8008]=8'h56; memory[16'h8009]=8'h78;
        memory[16'h800a]=masked ? 8'h0f : 8'h0e;
        memory[16'h800b]=waiting ? 8'h3e : 8'h01;
        memory[16'h800c]=8'hb7; memory[16'h800d]=8'hf8; memory[16'h800e]=0;
        memory[16'h800f]=8'h20; memory[16'h8010]=8'hfe;
        repeat(8) @(negedge clk);
        rst=0;
    end
endtask

task check_frame;
    input [15:0] pc;
    input [7:0] cc;
    begin
        if(stack_writes!=7 ||
            {memory[16'hf87e],memory[16'hf87f]}!==pc ||
            {memory[16'hf87c],memory[16'hf87d]}!==16'h5678 ||
            memory[16'hf87b]!==8'h12 || memory[16'hf87a]!==8'h34 || memory[16'hf879]!==cc)
            $fatal(1,"Interrupt frame PC=%h CC=%h actual PC=%h CC=%h writes=%0d",
                pc,cc,{memory[16'hf87e],memory[16'hf87f]},memory[16'hf879],stack_writes);
    end
endtask

task check_restored;
    input [7:0] cc;
    begin
        if({cpu.u_cpu.u_regs.a,cpu.u_cpu.u_regs.b,cpu.u_cpu.u_regs.x,cpu.u_cpu.u_regs.s,cpu.u_cpu.u_regs.cc}!==
            {8'h12,8'h34,16'h5678,16'hf87f,cc})
            $fatal(1,"RTI did not restore A/B/X/SP/CC");
    end
endtask

task check_bus;
    input [15:0] expected_addr;
    input expected_vma;
    begin
        @(posedge clk);
        while(!done) @(posedge clk);
        if({addr,vma,wr}!=={expected_addr,expected_vma,1'b0})
            $fatal(1,"Bus expected %h VMA=%b, got %h VMA=%b WR=%b",expected_addr,expected_vma,addr,vma,wr);
    end
endtask

initial begin
    prepare(0,1);
    wait(ba);
    @(negedge clk);
    check_frame(16'h800c,8'hc0);
    if(vma || wr) $fatal(1,"WAI did not release the bus");
    wake_start=transfers;
    irq=1;
    wait(irq_reads==2);
    @(negedge clk);
    if(transfers-wake_start!=4 || stack_writes!=7 || !cpu.u_cpu.i)
        $fatal(1,"WAI IRQ entry must take four bus cycles without restacking");
    irq=0;
    wait(memory[16'hf800]==8'h12);
    @(negedge clk);
    check_restored(8'hc0);
    $display("CHECK MC6802 WAI IRQ: seven-byte frame, four-cycle wake, RTI and bus availability");

    prepare(1,1);
    wait(ba);
    @(negedge clk);
    check_frame(16'h800c,8'hd0);
    irq=1;
    repeat(256) @(negedge clk);
    if(!ba || irq_reads || stack_writes!=7) $fatal(1,"Masked IRQ woke WAI");
    wake_start=transfers;
    nmi=1;
    wait(nmi_reads==2);
    @(negedge clk);
    if(transfers-wake_start!=4 || irq_reads || stack_writes!=7)
        $fatal(1,"WAI NMI did not take priority over masked IRQ");
    irq=0;
    wait(memory[16'hf800]==8'h12);
    @(negedge clk);
    check_restored(8'hd0);
    repeat(256) @(negedge clk);
    if(nmi_reads!=2 || stack_writes!=7) $fatal(1,"Held NMI retriggered");
    $display("CHECK MC6802 masked WAI, NMI wake and held-level edge qualification");

    prepare(0,0);
    wait(cpu.u_cpu.u_regs.op_pc==16'h800b && !cpu.u_cpu.u_ctrl.ni);
    @(negedge clk);
    irq=1;
    wait(cpu.u_cpu.u_ctrl.uaddr==cpu.u_cpu.u_ctrl.ISRV_SEQA);
    wake_start=transfers;
    wait(irq_reads==2);
    @(negedge clk);
    if(transfers-wake_start!=12 || nmi_reads)
        $fatal(1,"Ordinary IRQ entry must take 12 bus cycles");
    check_frame(16'h800c,8'hc0);
    irq=0;
    wait(memory[16'hf800]==8'h12);
    @(negedge clk);
    check_restored(8'hc0);
    $display("CHECK MC6802 ordinary IRQ: instruction boundary, 12-cycle entry and exact RTI restore");

    prepare(0,0);
    wait(instruction_end && cpu.u_cpu.u_regs.op_pc==16'h800b);
    @(negedge clk);
    ext_halt=1;
    wait(ba);
    @(negedge clk);
    saved_pc=cpu.u_cpu.u_regs.pc;
    saved_cc=cpu.u_cpu.u_regs.cc;
    if(vma || wr || addr!=saved_pc) $fatal(1,"HALT did not release the bus at the next instruction address");
    irq=1; nmi=1;
    repeat(256) @(negedge clk);
    if(!ba || irq_reads || nmi_reads || stack_writes || cpu.u_cpu.u_regs.pc!=saved_pc)
        $fatal(1,"HALT did not retain pending interrupts");
    irq_start=irq_reads; nmi_start=nmi_reads;
    wake_start=transfers;
    ext_halt=0;
    wait(nmi_reads==2);
    @(negedge clk);
    if(irq_reads!=irq_start || transfers-wake_start!=12)
        $fatal(1,"NMI entry must precede IRQ and take 12 bus cycles");
    check_frame(saved_pc,saved_cc);
    irq=0; nmi=0;
    wait(cpu.u_cpu.u_regs.s==16'hf87f && cpu.u_cpu.u_regs.pc==saved_pc);
    @(negedge clk);
    check_restored(saved_cc);
    $display("CHECK MC6802 HALT: instruction boundary, pending NMI priority, 12-cycle entry and RTI");

    prepare(0,0);
    wait(cpu.u_cpu.u_regs.op_pc==16'h800c && !cpu.u_cpu.u_ctrl.ni);
    @(negedge clk);
    ext_halt=1;
    wait(ba);
    @(negedge clk);
    if(memory[16'hf800]!=8'h12 || cpu.u_cpu.u_regs.pc!=16'h800f || addr!=16'h800f || vma || wr)
        $fatal(1,"HALT suppressed the current instruction's store or granted the bus early");
    ext_halt=0;
    wait(!ba);
    $display("CHECK MC6802 HALT asserted during a store completes the current instruction");

    prepare(0,0);
    memory[16'h800b]=8'h30;
    memory[16'h800c]=8'h35;
    memory[16'h800d]=8'h20;
    memory[16'h800e]=8'hfe;
    wait(opcode_fetch && addr==16'h800b);
    check_bus(16'h800b,1);
    check_bus(16'h800c,1);
    check_bus(16'hf87f,0);
    check_bus(16'hf880,0);
    check_bus(16'h800c,1);
    check_bus(16'h800d,1);
    check_bus(16'hf880,0);
    check_bus(16'hf87f,0);
    check_bus(16'h800d,1);
    @(negedge clk);
    if(cpu.u_cpu.u_regs.x!==16'hf880 || cpu.u_cpu.u_regs.s!==16'hf87f)
        $fatal(1,"TSX/TXS result mismatch");
    $display("CHECK MC6802 TSX/TXS: Table 8 source and destination addresses in both VMA-low cycles");

    prepare(0,0);
    memory[16'h8000]=8'hfc;
    wait(cpu.illegal);
    @(negedge clk);
    if(cpu.raw_opcode!=8'hfc) $fatal(1,"Unexpected opcode in FC eligibility check");
    rst=1;
    $display("PASS MC6802: IRQ, NMI, WAI, HALT, bus cycles and opcode eligibility");
    $finish;
end

initial begin
    #1000000;
    $fatal(1,"MC6802 interrupt timeout PC=%h uaddr=%h",cpu.u_cpu.u_regs.pc,cpu.u_cpu.u_ctrl.uaddr);
end
endmodule
