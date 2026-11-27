`timescale 1ns/1ps
module test;

reg clk=0;
always #5 clk=~clk;
reg rst=1, cpu_rst=0, cen=1, enable=1, ready=1, mr_n=1;
reg ext_halt=0, irq=0, nmi=0;
wire [15:0] addr;
wire [7:0] din, dout;
reg [7:0] mem_q=8'hff;
wire e,vma,wr,done,instruction_end,opcode_fetch,ba;
reg [7:0] mem[0:65535];
integer cycles=0, writes=0, rti_trace=0;
integer frame_writes=0;
integer reset_hi=0, reset_lo=0, reset_fetch=0, reset_reads=0;
integer nmi_hi=0, nmi_lo=0, nmi_handler_fetch=0;
integer rti_return_fetch=0;
integer irq_hi=0, irq_lo=0, irq_handler_fetch=0, wai_fetch=0;
integer masked_wai_fetch=0;
integer wai_frame_writes=0, wai_extra_writes=0;
integer irq_accept_cycle=-1, irq_wake_ticks=-1;
integer normal_irq_accept_cycle=-1, normal_irq_entry_ticks=-1;
integer nmi_accept_cycle=-1, nmi_entry_ticks=-1;
integer nmi_wai_return_fetch=0;
integer reads_a000=0;
reg reset_audit=0, nmi_audit=0;
reg nmi_handler_seen=0;
reg wai_audit=0;
reg [3:0] flags_before_nmi;
reg [15:0] held_addr;
reg [7:0] held_dout;
reg held_wr, held_vma, held_e;
reg [12:0] paused_uaddr;
reg [15:0] paused_pc;
reg [1:0] paused_phase;

assign din=mem_q;
always @(posedge clk) begin
    cycles<=cycles+1;
    if(cen && enable && ready && mr_n && vma && !wr) mem_q<=mem[addr];
        if(wai_audit && irq_accept_cycle<0 && dut.cpu_irq && !ext_halt && dut.cpu_cen && dut.u_cpu.u_ctrl.halt && !dut.u_cpu.u_regs.i)
            irq_accept_cycle<=cycles;
    if(normal_irq_accept_cycle<0 && dut.cpu_irq && !ext_halt && dut.cpu_cen && dut.u_cpu.u_ctrl.ni && !dut.u_cpu.u_ctrl.halt && !dut.u_cpu.u_regs.i)
        normal_irq_accept_cycle<=cycles;
    if(nmi_audit && nmi_accept_cycle<0 && dut.cpu_nmi && !ext_halt && dut.cpu_cen &&
       (dut.u_cpu.u_ctrl.ni || dut.u_cpu.u_ctrl.halt) && dut.u_cpu.u_ctrl.pendng)
        nmi_accept_cycle<=cycles;
    if(done && !ready) $fatal(1,"done during ready wait");
    if(done && !mr_n) $fatal(1,"done during MR wait");
    if(done && (!e || !vma)) $fatal(1,"done without E/VMA");
    if(nmi_handler_seen && done && rti_trace<48) begin
        $display("RTI_BUS addr=%04x din=%02x dout=%02x wr=%b fetch=%b PC=%04x S=%04x U=%03x md=%04x op0=%04x op1=%04x ea=%04x",
            addr,din,dout,wr,dut.cpu_vma && dut.u_cpu.u_ctrl.fetch,dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s,
            dut.u_cpu.u_ctrl.uaddr,dut.u_cpu.u_regs.md,dut.u_cpu.u_regs.op0,dut.u_cpu.u_regs.op1,dut.u_cpu.u_regs.ea);
        rti_trace<=rti_trace+1;
    end
    if(done) begin
        if(wr) begin mem[addr]<=dout; writes<=writes+1; end
        if(nmi_audit && wr) begin
            frame_writes<=frame_writes+1;
            $display("NMI_FRAME_WRITE addr=%04x data=%02x S=%04x",addr,dout,dut.u_cpu.u_regs.s);
        end
        if(wai_audit && wr) begin
            wai_frame_writes<=wai_frame_writes+1;
            if(wai_frame_writes>=7) wai_extra_writes<=wai_extra_writes+1;
        end
        if(addr==16'hfffe) reset_hi<=reset_hi+1;
        if(addr==16'hffff) reset_lo<=reset_lo+1;
        if(opcode_fetch && addr==16'ha000) begin
            if(reset_audit) reset_fetch<=reset_fetch+1;
            reads_a000<=reads_a000+1;
        end
        if(addr==16'hfffc) nmi_hi<=nmi_hi+1;
        if(addr==16'hfffd) nmi_lo<=nmi_lo+1;
        if(addr==16'hfff8) irq_hi<=irq_hi+1;
        if(addr==16'hfff9) irq_lo<=irq_lo+1;
        if(opcode_fetch && addr==16'ha100) begin
            nmi_handler_fetch<=nmi_handler_fetch+1;
            if(nmi_accept_cycle>=0) nmi_entry_ticks<=cycles-nmi_accept_cycle;
        end
        if(opcode_fetch && addr==16'ha200) begin
            irq_handler_fetch<=irq_handler_fetch+1;
            if(irq_accept_cycle>=0) irq_wake_ticks<=cycles-irq_accept_cycle;
            if(normal_irq_accept_cycle>=0) normal_irq_entry_ticks<=cycles-normal_irq_accept_cycle;
        end
        if(opcode_fetch && addr==16'ha004) wai_fetch<=wai_fetch+1;
        if(opcode_fetch && addr==16'ha003 && mem[16'ha003]==8'h3e) masked_wai_fetch<=masked_wai_fetch+1;
        if(nmi_handler_seen && opcode_fetch && addr==16'ha00c) rti_return_fetch<=rti_return_fetch+1;
        if(nmi_handler_seen && opcode_fetch && addr==16'ha004) nmi_wai_return_fetch<=nmi_wai_return_fetch+1;
        if(reset_audit) begin
            case(reset_reads)
                0: if(addr!=16'hfffe) $fatal(1,"post-reset first transfer %04x, expected FFFE",addr);
                1: if(addr!=16'hffff) $fatal(1,"post-reset second transfer %04x, expected FFFF",addr);
                2: if(!opcode_fetch || addr!=16'ha000) $fatal(1,"post-reset third transfer %04x was not opcode fetch at A000",addr);
                default: $fatal(1,"unexpected extra transfer %04x during reset audit",addr);
            endcase
            reset_reads<=reset_reads+1;
        end
    end
end

jt6802 dut(
    .rst(rst),.cpu_rst(cpu_rst),.clk(clk),.cen(cen),.enable(enable),
    .ready(ready),.mr_n(mr_n),.din(din),.opcode(8'h00),.opcode_raw(),.addr(addr),.dout(dout),
    .e(e),.vma(vma),.wr(wr),.done(done),.instruction_end(instruction_end),
    .opcode_fetch(opcode_fetch),.ext_halt(ext_halt),.ba(ba),.irq(irq),.nmi(nmi)
);

task seed_memory;
    integer k;
    begin
        for(k=0;k<65536;k=k+1) mem[k]=8'h01;
        mem[16'hfffe]=8'ha0; mem[16'hffff]=8'h00;
        mem[16'hfffc]=8'ha1; mem[16'hfffd]=8'h00;
        mem[16'hfff8]=8'ha2; mem[16'hfff9]=8'h00;
        mem[16'hfffa]=8'ha3; mem[16'hfffb]=8'h00;
        mem[16'ha000]=8'h8e; mem[16'ha001]=8'h00; mem[16'ha002]=8'hff; // LDS #$00FF
        mem[16'ha003]=8'hc6; mem[16'ha004]=8'h5a;                     // LDAB #$5A
        mem[16'ha005]=8'hce; mem[16'ha006]=8'h12; mem[16'ha007]=8'h34; // LDX #$1234
        mem[16'ha008]=8'h86; mem[16'ha009]=8'h80;                     // LDAA #$80
        mem[16'ha00a]=8'h0d;                                         // SEC
        mem[16'ha00b]=8'h0e;                                         // CLI, making IRQ eligible
        mem[16'ha00c]=8'h20; mem[16'ha00d]=8'hfe;                     // loop at A00C
        mem[16'ha100]=8'h3b;                                         // RTI restores the NMI frame
        mem[16'ha101]=8'h20; mem[16'ha102]=8'hfe;                     // returned branch loop
        mem[16'ha200]=8'h20; mem[16'ha201]=8'hfe;                     // IRQ handler loop
        mem[16'ha300]=8'h20; mem[16'ha301]=8'hfe;                     // SWI handler loop
        mem_q=8'hff;
        cycles=0; writes=0; frame_writes=0; reset_hi=0; reset_lo=0; reset_fetch=0; reset_reads=0;
        nmi_hi=0; nmi_lo=0; nmi_handler_fetch=0; rti_return_fetch=0; reads_a000=0;
    end
endtask

task assert_no_completion;
    input integer count;
    integer k;
    begin
        for(k=0;k<count;k=k+1) begin
            @(posedge clk); #1;
            if(done) $fatal(1,"unexpected completion while paused/stalled at phase=%0d",dut.phase);
        end
    end
endtask

task restart_at_phase;
    input [1:0] target_phase;
    integer timeout;
    begin
        timeout=0;
        while(dut.phase!==target_phase && timeout<1000) begin @(negedge clk); timeout=timeout+1; end
        if(timeout>=1000) $fatal(1,"never reached phase %0d",target_phase);
        enable=0; cpu_rst=1;
        assert_no_completion(2);
        cpu_rst=0;
        repeat(3) begin
            @(negedge clk);
            if(dut.phase!==target_phase) $fatal(1,"phase moved while enable paused");
        end
        reset_hi=0; reset_lo=0; reset_fetch=0; reset_reads=0; reset_audit=1;
        enable=1;
        timeout=0;
        while(reset_fetch==0 && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
        if(reset_fetch!=1) $fatal(1,"phase %0d CPU reset did not fetch reset target; counts %0d/%0d/%0d",target_phase,reset_hi,reset_lo,reset_fetch);
        if(reset_hi!=1 || reset_lo!=1) $fatal(1,"phase %0d vector read counts %0d/%0d",target_phase,reset_hi,reset_lo);
        reset_audit=0;
    end
endtask

task wait_for_a000_high_e;
    integer timeout;
    begin
        timeout=0;
        while(!(e && vma && !wr && addr==16'ha00c && dut.phase==2) && timeout<2000) begin @(negedge clk); timeout=timeout+1; end
        if(timeout>=2000) $fatal(1,"did not reach A00C high-E read phase, addr=%04x PC=%04x U=%03x",addr,dut.u_cpu.u_regs.pc,dut.u_cpu.u_ctrl.uaddr);
    end
endtask

task wait_for_handler;
    integer timeout;
    begin
        timeout=0;
        while(nmi_handler_fetch==0 && timeout<2500) begin @(posedge clk); #1; timeout=timeout+1; end
        if(nmi_handler_fetch==0) $fatal(1,"NMI was not serviced, vector reads=%0d/%0d PC=%04x U=%03x",nmi_hi,nmi_lo,dut.u_cpu.u_regs.pc,dut.u_cpu.u_ctrl.uaddr);
    end
endtask

task wait_for_store;
    integer timeout;
    begin
        timeout=0;
        while(!(e && vma && wr && addr==16'h0020) && timeout<2000) begin @(negedge clk); timeout=timeout+1; end
        if(timeout>=2000) $fatal(1,"did not reach held store transaction addr=%04x vma=%b wr=%b",addr,vma,wr);
    end
endtask

task wait_for_stack_read;
    integer timeout;
    begin
        timeout=0;
        while(!(e && vma && !wr && addr==16'h00ff) && timeout<2000) begin @(negedge clk); timeout=timeout+1; end
        if(timeout>=2000) $fatal(1,"did not reach PULA stack read addr=%04x vma=%b wr=%b",addr,vma,wr);
    end
endtask

integer k, hold_count, timeout;
initial begin
    seed_memory();
    repeat(8) @(negedge clk);
    rst=0;
    // cpu_rst must resynchronize the engine from every external phase while
    // enable is stopped, then expose the reset vector as the first bus reads.
    reset_audit=1;
    for(k=0;k<4;k=k+1) restart_at_phase(k[1:0]);
    reset_audit=0;

    // Generic ready hold freezes the high-E read and preserves its visible bus.
    wait_for_a000_high_e();
    held_addr=addr; held_dout=dout; held_wr=wr; held_vma=vma; held_e=e;
    paused_uaddr=dut.u_cpu.u_ctrl.uaddr; paused_pc=dut.u_cpu.u_regs.pc; paused_phase=dut.phase;
    enable=0;
    assert_no_completion(7);
    if({addr,dout,wr,vma,e}!=={held_addr,held_dout,held_wr,held_vma,held_e} ||
       dut.u_cpu.u_ctrl.uaddr!==paused_uaddr || dut.u_cpu.u_regs.pc!==paused_pc || dut.phase!==paused_phase)
        $fatal(1,"host enable pause changed CPU or held bus state");
    @(negedge clk); enable=1;
    timeout=0;
    while(!done && timeout<20) begin @(posedge clk); #1; timeout=timeout+1; end
    if(!done || addr!==held_addr) $fatal(1,"host enable resume did not complete held transfer");

    wait_for_a000_high_e();
    held_addr=addr; held_dout=dout; held_wr=wr; held_vma=vma; held_e=e;
    ready=0;
    assert_no_completion(7);
    if({addr,dout,wr,vma,e}!=={held_addr,held_dout,held_wr,held_vma,held_e}) $fatal(1,"ready wait changed visible transfer");
    @(negedge clk); ready=1;
    timeout=0;
    while(!done && timeout<20) begin @(posedge clk); #1; timeout=timeout+1; end
    if(!done || addr!==held_addr) $fatal(1,"ready release did not complete the held transfer");

    // MR must extend a high-E phase by an even number of CEN edges for both
    // release parities, with no accepted transfer while asserted.
    for(hold_count=2;hold_count<=3;hold_count=hold_count+1) begin
        wait_for_a000_high_e();
        held_addr=addr; held_dout=dout; held_wr=wr; held_vma=vma; held_e=e;
        mr_n=0;
        assert_no_completion(hold_count);
        if({addr,dout,wr,vma,e}!=={held_addr,held_dout,held_wr,held_vma,held_e}) $fatal(1,"MR wait changed visible transfer");
        @(negedge clk); mr_n=1;
        if(hold_count==2) begin
            ready=0;
            assert_no_completion(4);
            if({addr,dout,wr,vma,e}!=={held_addr,held_dout,held_wr,held_vma,held_e})
                $fatal(1,"overlapped ready/MR wait changed visible transfer");
            @(negedge clk); ready=1;
        end
        timeout=0;
        while(!done && timeout<20) begin @(posedge clk); #1; timeout=timeout+1; end
        if(!done || addr!==held_addr) $fatal(1,"MR release failed to complete the held transfer");
    end

    // Stall an actual write with ready low. The whole transaction stays
    // stable and resumes as exactly one memory write.
    mem[16'ha000]=8'h8e; mem[16'ha001]=8'h00; mem[16'ha002]=8'hff;
    mem[16'ha003]=8'h86; mem[16'ha004]=8'h5a;
    mem[16'ha005]=8'h97; mem[16'ha006]=8'h20;
    mem[16'ha007]=8'h20; mem[16'ha008]=8'hfe;
    mem[16'h0020]=8'h00; writes=0;
    cpu_rst=1; repeat(3) @(negedge clk); cpu_rst=0;
    wait_for_store();
    held_addr=addr; held_dout=dout; held_wr=wr; held_vma=vma; held_e=e;
    ready=0;
    assert_no_completion(7);
    if({addr,dout,wr,vma,e}!=={held_addr,held_dout,held_wr,held_vma,held_e})
        $fatal(1,"ready hold changed write transaction");
    @(negedge clk); ready=1;
    timeout=0;
    while(!done && timeout<20) begin @(posedge clk); #1; timeout=timeout+1; end
    if(!done || !wr || addr!==16'h0020 || dout!==8'h5a) $fatal(1,"resumed store data/address wrong");
    @(posedge clk); #1;
    repeat(12) begin @(posedge clk); #1; if(writes!=1) $fatal(1,"held store duplicated writes=%0d",writes); end
    if(mem[16'h0020]!==8'h5a || writes!=1) $fatal(1,"held store result=%02x writes=%0d",mem[16'h0020],writes);
    seed_memory();
    cpu_rst=1; repeat(3) @(negedge clk); cpu_rst=0;
    timeout=0;
    while(reads_a000==0 && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    if(reads_a000==0) $fatal(1,"CPU reset after write hold did not restart");

    // Pulse NMI wholly inside a ready wait while the host also owns the bus.
    // The wrapper must retain it until HALT/BA is released, then vector once.
    wait_for_a000_high_e();
    ready=0; ext_halt=1;
    nmi_audit=1; frame_writes=0; nmi_handler_seen=0; rti_return_fetch=0;
    nmi_accept_cycle=-1; nmi_entry_ticks=-1;
    flags_before_nmi=4'b1001; // LDAA #$80 then SEC: N=1, Z=0, V=0, C=1
    assert_no_completion(3);
    @(negedge clk); irq=1; nmi=1;
    @(negedge clk); nmi=0;
    repeat(2) @(negedge clk); irq=0;
    if(!dut.nmi_pending) $fatal(1,"NMI pulse during held E phase was lost");
    @(negedge clk); ready=1;
    repeat(80) begin
        @(posedge clk); #1;
        if(nmi_hi || nmi_lo || nmi_handler_fetch) $fatal(1,"NMI serviced while external HALT remained asserted");
    end
    ext_halt=0;
    wait_for_handler();
    if(nmi_hi!=1 || nmi_lo!=1 || nmi_handler_fetch!=1 || irq_hi || irq_lo || irq_handler_fetch)
        $fatal(1,"NMI priority/vector counts NMI=%0d/%0d/%0d IRQ=%0d/%0d/%0d",nmi_hi,nmi_lo,nmi_handler_fetch,irq_hi,irq_lo,irq_handler_fetch);
    $display("NMI_FRAME final S=%04x bytes PC=%02x:%02x X=%02x:%02x A=%02x B=%02x CCR=%02x writes=%0d",
        dut.u_cpu.u_regs.s,mem[16'h00fe],mem[16'h00ff],mem[16'h00fc],mem[16'h00fd],mem[16'h00fb],mem[16'h00fa],mem[16'h00f9],frame_writes);
    if(frame_writes!=7 || dut.u_cpu.u_regs.s!==16'h00f8 ||
       mem[16'h00ff]!==8'h0c || mem[16'h00fe]!==8'ha0 ||
       mem[16'h00fd]!==8'h34 || mem[16'h00fc]!==8'h12 ||
       mem[16'h00fb]!==8'h80 || mem[16'h00fa]!==8'h5a || mem[16'h00f9]!==8'hc9)
        $fatal(1,"NMI frame mismatch writes=%0d S=%04x flags=%b",frame_writes,dut.u_cpu.u_regs.s,mem[16'h00f9]);
    nmi_handler_seen=1;
    timeout=0;
    while(rti_return_fetch==0 && timeout<2500) begin @(posedge clk); #1; timeout=timeout+1; end
    if(rti_return_fetch==0) $fatal(1,"RTI did not restore PC A00C S=%04x PC=%04x U=%03x",dut.u_cpu.u_regs.s,dut.u_cpu.u_regs.pc,dut.u_cpu.u_ctrl.uaddr);
    if(dut.u_cpu.u_regs.s!==16'h00ff || dut.u_cpu.u_regs.pc!==16'ha00c ||
       {dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}!==flags_before_nmi ||
       dut.u_cpu.u_regs.a!==8'h80 || dut.u_cpu.u_regs.b!==8'h5a || dut.u_cpu.u_regs.x!==16'h1234)
        $fatal(1,"RTI restore mismatch PC=%04x S=%04x NZVC=%b expected=%b A=%02x B=%02x X=%04x",dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s,
            {dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c},flags_before_nmi,
            dut.u_cpu.u_regs.a,dut.u_cpu.u_regs.b,dut.u_cpu.u_regs.x);
    if(dut.u_cpu.u_regs.i!==1'b0) $fatal(1,"RTI failed to restore I from NMI frame");
    if(nmi_entry_ticks!=48) $fatal(1,"normal NMI entry took %0d CEN clocks, expected 48 (12E)",nmi_entry_ticks);
    nmi_audit=0;

    // IRQ is masked after reset. It must not vector before CLI. Then WAI
    // stacks once, releases BA on accepted IRQ, and wakes through IVRD only.
    mem[16'ha000]=8'h8e; mem[16'ha001]=8'h00; mem[16'ha002]=8'hff; // LDS #$00FF
    mem[16'ha003]=8'h0e;                                         // CLI
    mem[16'ha004]=8'h3e;                                         // WAI
    mem[16'ha005]=8'h20; mem[16'ha006]=8'hfe;                     // loop after RTI
    mem[16'ha200]=8'h3b;                                         // IRQ handler RTI
    mem[16'ha201]=8'h20; mem[16'ha202]=8'hfe;
    irq_hi=0; irq_lo=0; irq_handler_fetch=0; wai_fetch=0;
    wai_frame_writes=0; wai_extra_writes=0; wai_audit=0;
    irq_accept_cycle=-1; irq_wake_ticks=-1;
    cpu_rst=1; repeat(3) @(negedge clk); cpu_rst=0;
    // The masked IRQ pulse is sampled while executing LDS and must not be
    // acknowledged or cause a vector access.
    irq=1; repeat(3) @(negedge clk); irq=0;
    repeat(40) begin
        @(posedge clk); #1;
        if(irq_hi || irq_lo || irq_handler_fetch) $fatal(1,"masked IRQ was serviced");
    end
    timeout=0;
    while(wai_fetch==0 && timeout<1500) begin @(posedge clk); #1; timeout=timeout+1; end
    if(wai_fetch!=1) $fatal(1,"WAI opcode boundary was not observed");
    wai_audit=1;
    timeout=0;
    while(!ba && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    if(!ba || wai_frame_writes!=7 || dut.u_cpu.u_regs.s!==16'h00f8)
        $fatal(1,"WAI frame/BA mismatch BA=%b writes=%0d S=%04x",ba,wai_frame_writes,dut.u_cpu.u_regs.s);
    if(mem[16'h00ff]!==8'h05 || mem[16'h00fe]!==8'ha0 || mem[16'h00f9]!==8'hc0)
        $fatal(1,"WAI frame contents wrong PC=%02x:%02x CCR=%02x",mem[16'h00fe],mem[16'h00ff],mem[16'h00f9]);
    repeat(12) begin
        @(posedge clk); #1;
        if(irq_hi || irq_lo || irq_handler_fetch) $fatal(1,"IRQ was not held off before request");
    end
    ext_halt=1; irq=1; repeat(3) @(negedge clk); irq=0;
    repeat(12) begin
        @(posedge clk); #1;
        if(irq_hi || irq_lo || irq_handler_fetch) $fatal(1,"IRQ serviced while external HALT asserted");
    end
    ext_halt=0;
    timeout=0;
    while(irq_handler_fetch==0 && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    if(irq_handler_fetch!=1 || irq_hi!=1 || irq_lo!=1)
        $fatal(1,"WAI IRQ vector/handler counts %0d/%0d/%0d",irq_hi,irq_lo,irq_handler_fetch);
    if(irq_wake_ticks!=16)
        $fatal(1,"WAI IRQ wake took %0d CEN clocks after accepted interrupt, expected 16 (4E)",irq_wake_ticks);
    if(wai_frame_writes!=7 || wai_extra_writes!=0)
        $fatal(1,"WAI wake pushed a second frame writes=%0d extra=%0d",wai_frame_writes,wai_extra_writes);
    timeout=0;
    while(dut.u_cpu.u_regs.pc!==16'ha005 && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    if(dut.u_cpu.u_regs.s!==16'h00ff || dut.u_cpu.u_regs.pc!==16'ha005 || dut.u_cpu.u_regs.i!==1'b0)
        $fatal(1,"WAI IRQ RTI restore failed PC=%04x S=%04x I=%b",dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s,dut.u_cpu.u_regs.i);
    wai_audit=0;

    // A normal, unmasked IRQ performs the full 12E frame-and-vector path.
    irq_hi=0; irq_lo=0; irq_handler_fetch=0; normal_irq_accept_cycle=-1; normal_irq_entry_ticks=-1;
    timeout=0;
    while(dut.u_cpu.u_regs.pc!==16'ha005 && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    irq=1;
    timeout=0;
    while(irq_handler_fetch==0 && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    irq=0;
    if(irq_handler_fetch!=1 || irq_hi!=1 || irq_lo!=1 || normal_irq_entry_ticks!=48)
        $fatal(1,"normal IRQ path handler=%0d vector=%0d/%0d entry=%0d CEN, expected48",irq_handler_fetch,irq_hi,irq_lo,normal_irq_entry_ticks);
    timeout=0;
    while(dut.u_cpu.u_regs.s!==16'h00ff && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    if(dut.u_cpu.u_regs.s!==16'h00ff || dut.u_cpu.u_regs.i!==1'b0)
        $fatal(1,"normal IRQ RTI did not restore S/I S=%04x I=%b",dut.u_cpu.u_regs.s,dut.u_cpu.u_regs.i);

    // With I set, WAI must ignore a maskable IRQ but still wake for NMI.
    // If both are pending, NMI wins and reuses the WAI frame.
    seed_memory();
    mem[16'ha003]=8'h3e; mem[16'ha004]=8'h20; mem[16'ha005]=8'hfe;
    mem[16'ha100]=8'h3b; mem[16'ha101]=8'h20; mem[16'ha102]=8'hfe;
    nmi_hi=0; nmi_lo=0; nmi_handler_fetch=0; irq_hi=0; irq_lo=0; irq_handler_fetch=0;
    masked_wai_fetch=0; wai_frame_writes=0; wai_extra_writes=0; frame_writes=0;
    nmi_accept_cycle=-1; nmi_entry_ticks=-1; nmi_wai_return_fetch=0;
    nmi_audit=1; wai_audit=1; nmi_handler_seen=0;
    cpu_rst=1; repeat(3) @(negedge clk); cpu_rst=0;
    timeout=0;
    while(masked_wai_fetch==0 && timeout<1500) begin @(posedge clk); #1; timeout=timeout+1; end
    if(masked_wai_fetch!=1) $fatal(1,"I-set WAI instruction boundary was not observed");
    timeout=0;
    while(!ba && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    if(!ba || wai_frame_writes!=7 || dut.u_cpu.u_regs.s!==16'h00f8)
        $fatal(1,"I-set WAI frame mismatch BA=%b writes=%0d S=%04x",ba,wai_frame_writes,dut.u_cpu.u_regs.s);
    ext_halt=1; irq=1; repeat(3) @(negedge clk); irq=0;
    repeat(12) begin
        @(posedge clk); #1;
        if(irq_hi || irq_lo || irq_handler_fetch || nmi_hi || nmi_lo || nmi_handler_fetch)
            $fatal(1,"masked IRQ or deferred interrupt serviced before HALT release");
    end
    nmi=1; repeat(2) @(negedge clk); nmi=0;
    if(!dut.nmi_pending) $fatal(1,"NMI pulse during I-set WAI was lost");
    repeat(12) begin
        @(posedge clk); #1;
        if(nmi_hi || nmi_lo || nmi_handler_fetch) $fatal(1,"NMI serviced while external HALT asserted");
    end
    ext_halt=0;
    wait_for_handler();
    if(nmi_hi!=1 || nmi_lo!=1 || nmi_handler_fetch!=1 || irq_hi || irq_lo || irq_handler_fetch)
        $fatal(1,"NMI priority/vector mismatch NMI=%0d/%0d/%0d IRQ=%0d/%0d/%0d",nmi_hi,nmi_lo,nmi_handler_fetch,irq_hi,irq_lo,irq_handler_fetch);
    if(nmi_entry_ticks!=16 || frame_writes!=7 || wai_extra_writes!=0)
        $fatal(1,"I-set WAI NMI wake=%0d CEN frame=%0d extra=%0d",nmi_entry_ticks,frame_writes,wai_extra_writes);
    nmi_handler_seen=1;
    timeout=0;
    while(nmi_wai_return_fetch==0 && timeout<2500) begin @(posedge clk); #1; timeout=timeout+1; end
    if(nmi_wai_return_fetch==0 || dut.u_cpu.u_regs.pc!==16'ha004 || dut.u_cpu.u_regs.s!==16'h00ff || dut.u_cpu.u_regs.i!==1'b1)
        $fatal(1,"I-set WAI NMI RTI restore failed PC=%04x S=%04x I=%b",dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s,dut.u_cpu.u_regs.i);
    nmi_audit=0; wai_audit=0;

    // JSR indexed and extended must push the post-operand return PC and land
    // on the effective target. RTS must restore the return PC and SP.
    seed_memory();
    mem[16'ha003]=8'hbd; mem[16'ha004]=8'hb1; mem[16'ha005]=8'h00; // JSR $B100
    mem[16'ha006]=8'h20; mem[16'ha007]=8'hfe;
    mem[16'hb100]=8'h39; // RTS
    cpu_rst=1; repeat(3) @(negedge clk); cpu_rst=0;
    timeout=0;
    while(reads_a000==0 && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    timeout=0;
    while(!(opcode_fetch && addr==16'hb100) && timeout<2000) begin @(posedge clk); #1; timeout=timeout+1; end
    if(timeout>=2000 || dut.u_cpu.u_regs.s!==16'h00fd || mem[16'h00ff]!==8'h06 || mem[16'h00fe]!==8'ha0)
        $fatal(1,"extended JSR target/return frame mismatch target=%b PC=%04x S=%04x bytes=%02x:%02x",opcode_fetch,dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s,mem[16'h00fe],mem[16'h00ff]);
    timeout=0;
    while(!(opcode_fetch && addr==16'ha006) && timeout<2000) begin @(posedge clk); #1; timeout=timeout+1; end
    if(timeout>=2000 || dut.u_cpu.u_regs.s!==16'h00ff || dut.u_cpu.u_regs.pc!==16'ha006)
        $fatal(1,"extended JSR/RTS did not restore PC/SP PC=%04x S=%04x",dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s);

    seed_memory();
    mem[16'ha003]=8'hce; mem[16'ha004]=8'hb1; mem[16'ha005]=8'h00; // LDX #$B100
    mem[16'ha006]=8'had; mem[16'ha007]=8'h00;                     // JSR 0,X
    mem[16'ha008]=8'h20; mem[16'ha009]=8'hfe;
    mem[16'hb100]=8'h39;
    cpu_rst=1; repeat(3) @(negedge clk); cpu_rst=0;
    timeout=0;
    while(reads_a000==0 && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    timeout=0;
    while(!(opcode_fetch && addr==16'hb100) && timeout<2000) begin @(posedge clk); #1; timeout=timeout+1; end
    if(timeout>=2000 || dut.u_cpu.u_regs.x!==16'hb100 || dut.u_cpu.u_regs.s!==16'h00fd ||
       mem[16'h00ff]!==8'h08 || mem[16'h00fe]!==8'ha0)
        $fatal(1,"indexed JSR target/return frame mismatch target=%b PC=%04x X=%04x S=%04x bytes=%02x:%02x",opcode_fetch,dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.x,dut.u_cpu.u_regs.s,mem[16'h00fe],mem[16'h00ff]);
    timeout=0;
    while(!(opcode_fetch && addr==16'ha008) && timeout<2000) begin @(posedge clk); #1; timeout=timeout+1; end
    if(timeout>=2000 || dut.u_cpu.u_regs.s!==16'h00ff || dut.u_cpu.u_regs.pc!==16'ha008)
        $fatal(1,"indexed JSR/RTS did not restore PC/SP PC=%04x S=%04x",dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s);

    // PULA must wait for an accepted high-E read before loading A. This
    // catches the stale-data path if the stack read is consumed in low E.
    seed_memory();
    mem[16'ha003]=8'h86; mem[16'ha004]=8'h5a; // LDAA #$5A
    mem[16'ha005]=8'h36;                     // PSHA
    mem[16'ha006]=8'h86; mem[16'ha007]=8'h00; // LDAA #0
    mem[16'ha008]=8'h32;                     // PULA
    mem[16'ha009]=8'h20; mem[16'ha00a]=8'hfe;
    cpu_rst=1; repeat(3) @(negedge clk); cpu_rst=0;
    timeout=0;
    while(reads_a000==0 && timeout<1000) begin @(posedge clk); #1; timeout=timeout+1; end
    wait_for_stack_read();
    if(dut.u_cpu.u_regs.a!==8'h00 || dut.u_cpu.u_regs.s!==16'h00ff)
        $fatal(1,"PULA modified register before accepted stack read A=%02x S=%04x",dut.u_cpu.u_regs.a,dut.u_cpu.u_regs.s);
    held_addr=addr; held_dout=dout; held_wr=wr; held_vma=vma; held_e=e;
    ready=0;
    assert_no_completion(7);
    if({addr,dout,wr,vma,e}!=={held_addr,held_dout,held_wr,held_vma,held_e})
        $fatal(1,"PULA ready hold changed stack read bus");
    if(dut.u_cpu.u_regs.a!==8'h00) $fatal(1,"PULA consumed stack data while ready was low");
    @(negedge clk); ready=1;
    timeout=0;
    while(dut.u_cpu.u_regs.a!==8'h5a && timeout<200) begin @(posedge clk); #1; timeout=timeout+1; end
    if(timeout>=200 || dut.u_cpu.u_regs.s!==16'h00ff || mem[16'h00ff]!==8'h5a)
        $fatal(1,"PULA failed after ready release A=%02x S=%04x stack=%02x",dut.u_cpu.u_regs.a,dut.u_cpu.u_regs.s,mem[16'h00ff]);

    $display("PASS: MC6802 wrapper reset/ready/MR/pause, NMI/HALT, IRQ mask, WAI frame/wake, and RTI");
    $finish;
end
endmodule
