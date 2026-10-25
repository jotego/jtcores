`timescale 1ns/1ps
module test;
reg clk=0;
always #5 clk=~clk;
reg rst=1, cpu_rst=0, cen=1, enable=1, ready=1, mr_n=1;
reg ext_halt=0, irq=0, nmi=0;
wire [15:0] addr;
wire [7:0] din, dout;
wire e,vma,wr,done,instruction_end,opcode_fetch,ba;
integer checks=0, cycles=0, writes=0, failures=0, cycle_failures=0, cycle_cases=0, cycle_ok=0, boundary_failures=0;
integer delta_bins[0:40], cycle_bin, swi_trace_count, bsr_trace_count;
reg [15:0] bsr_last_u=16'hffff;
reg [15:0] manual_oracle [0:255];
reg trace_swi=0, trace_bsr=0, trace_ordinary=0;
integer opcode_index;
initial $readmemh("manifest.hex",manual_oracle);

always @(posedge clk) begin
    cycles <= cycles+1;
    if(done && wr) writes <= writes+1;
    if(done && wr && addr==16'h0030) $display("RMW_WRITE addr=%04x data=%02x",addr,dout);
    if(trace_bsr && done && bsr_trace_count<80) begin
        $display("BSR_BUS addr=%04x din=%02x dout=%02x wr=%b fetch=%b PC=%04x S=%04x U=%04x",addr,din,dout,wr,opcode_fetch,dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s,dut.u_cpu.u_ctrl.uaddr);
        bsr_trace_count=bsr_trace_count+1;
    end
    if(trace_bsr && dut.u_cpu.u_ctrl.uaddr!=bsr_last_u) begin
        bsr_last_u=dut.u_cpu.u_ctrl.uaddr;
        if(dut.u_cpu.u_ctrl.uaddr>=16'h11a8 && dut.u_cpu.u_ctrl.uaddr<=16'h11b2)
            $display("BSR_U u=%04x PC=%04x md=%04x op0=%04x op1=%04x ea=%04x alu_sel=%x rslt=%04x branch=%b ld_sel=%x",dut.u_cpu.u_ctrl.uaddr,dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.md,dut.u_cpu.op0,dut.u_cpu.op1,dut.u_cpu.u_regs.ea,dut.u_cpu.alu_sel,dut.u_cpu.rslt,dut.u_cpu.branch,dut.u_cpu.ld_sel);
    end
    if(trace_ordinary && done && (wr || (addr>=16'hB000 && addr<=16'hB050))) $display("ORD_BUS addr=%04x din=%02x dout=%02x wr=%b PC=%04x U=%04x",addr,din,dout,wr,dut.u_cpu.u_regs.pc,dut.u_cpu.u_ctrl.uaddr);
    if(trace_swi && done && swi_trace_count<32) begin
        $display("SWI_BUS addr=%04x din=%02x dout=%02x wr=%b cpuPC=%04x S=%04x u=%04x",addr,din,dout,wr,dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s,dut.u_cpu.u_ctrl.uaddr);
        swi_trace_count=swi_trace_count+1;
    end
end

jt6802 dut(
    .rst(rst),.cpu_rst(cpu_rst),.clk(clk),.cen(cen),.enable(enable),
    .ready(ready),.mr_n(mr_n),.din(din),.opcode(8'h00),.opcode_raw(),
    .addr(addr),.dout(dout),.e(e),.vma(vma),.wr(wr),.done(done),
    .instruction_end(instruction_end),.opcode_fetch(opcode_fetch),
    .ext_halt(ext_halt),.ba(ba),.irq(irq),.nmi(nmi)
);

jtframe_ram #(.AW(16),.SIMHEXFILE("program.hex"),.CEN_RD(0)) mem(
    .clk(clk),.cen(done),.data(dout),.addr(addr),.we(done && wr),.q(din)
);

task wait_retire;
    input [15:0] pc_marker;
    input [3:0] flags;
    integer timeout;
    reg fetched, found;
    reg [7:0] target_opcode;
    reg [3:0] got_flags;
    begin
        timeout=0; fetched=0; found=0; target_opcode=mem.mem[pc_marker];
        while(!found && timeout<1200) begin
            @(posedge clk); #1; timeout=timeout+1;
            if(opcode_fetch && addr==pc_marker) fetched=1;
            if(fetched && dut.u_cpu.u_regs.pc==pc_marker &&
                dut.u_cpu.u_ctrl.uaddr[12:5]==target_opcode &&
                dut.u_cpu.u_ctrl.uaddr[4:0]==0 && !dut.u_cpu.u_ctrl.stack_busy) found=1;
        end
        if(found) begin
            got_flags={dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c};
            if(got_flags !== flags) begin
                $display("FAIL CPX at dispatched PC=%04x NZVC=%b expected=%b",pc_marker,got_flags,flags);
                failures=failures+1;
            end else checks=checks+1;
        end else begin
            $display("FAIL timeout waiting for dispatched PC=%04x; CPU PC=%04x U=%04x",pc_marker,dut.u_cpu.u_regs.pc,dut.u_cpu.u_ctrl.uaddr);
            failures=failures+1;
        end
    end
endtask

task wait_pc;
    input [15:0] pc_marker;
    integer timeout;
    reg fetched, found;
    reg [7:0] target_opcode;
    begin
        timeout=0; fetched=0; found=0; target_opcode=mem.mem[pc_marker];
        while(!found && timeout<1200) begin
            @(posedge clk); #1; timeout=timeout+1;
            if(opcode_fetch && addr==pc_marker) fetched=1;
            if(fetched && dut.u_cpu.u_regs.pc==pc_marker &&
                dut.u_cpu.u_ctrl.uaddr[12:5]==target_opcode &&
                dut.u_cpu.u_ctrl.uaddr[4:0]==0 && !dut.u_cpu.u_ctrl.stack_busy) found=1;
        end
        if(!found) begin
            $display("FAIL timeout waiting for dispatched PC=%04x; CPU PC=%04x U=%04x",pc_marker,dut.u_cpu.u_regs.pc,dut.u_cpu.u_ctrl.uaddr);
            failures=failures+1;
        end
    end
endtask

task seed_stack_at_fetch;
    input [15:0] start_pc;
    input [15:0] stack_value;
    integer timeout;
    reg found;
    begin
        timeout=0; found=0;
        while(!found && timeout<1200) begin
            @(posedge clk); #1; timeout=timeout+1;
            if(opcode_fetch && addr==start_pc) begin
                dut.u_cpu.u_regs.s=stack_value;
                found=1;
            end
        end
        if(!found) begin
            failures=failures+1;
            $display("FAIL timeout seeding stack at opcode fetch PC=%04x",start_pc);
        end
    end
endtask

task cycle_one;
    input [7:0] op;
    integer timeout, start_tick, actual, expected, mode, delta_bin;
    reg began, ended;
    reg [15:0] boundary_addr, boundary_pc;
    begin
        expected=manual_oracle[op][11:8]*4;
        mode=manual_oracle[op][2:0];
        rst=1; cpu_rst=0; ready=1; mr_n=1; enable=1; ext_halt=0; irq=0; nmi=0;
        trace_swi=(op==8'h3f); swi_trace_count=0;
        mem.mem[16'hA000]=op;
        mem.mem[16'hA001]=8'h01; mem.mem[16'hA002]=8'h01; mem.mem[16'hA003]=8'h01;
        mem.mem[16'h0020]=8'h00; mem.mem[16'h0021]=8'h00;
        mem.mem[16'h0000]=8'h01; mem.mem[16'h0001]=8'hA0; mem.mem[16'h0002]=8'h02;
        mem.mem[16'h0003]=8'h00; mem.mem[16'h0004]=8'h00; mem.mem[16'h0005]=8'h00;
        mem.mem[16'h0006]=8'hA0; mem.mem[16'h0007]=8'h02;
        mem.mem[16'hFFFA]=8'hA0; mem.mem[16'hFFFB]=8'h02;
        mem.mem[16'hFFFE]=8'hA0; mem.mem[16'hFFFF]=8'h00;
        case(mode)
            1: mem.mem[16'hA001]=8'h00; // relative branch target is next instruction
            2: begin mem.mem[16'hA001]=8'h00; mem.mem[16'hA002]=8'h00; end
            3: mem.mem[16'hA001]=8'h20; // direct data at $0020
            4: mem.mem[16'hA001]=8'h00; // indexed X resets to zero
            5: begin mem.mem[16'hA001]=8'h00; mem.mem[16'hA002]=8'h20; end
            default:;
        endcase
        if(op==8'h8c || op==8'h8e || op==8'hce) mem.mem[16'hA002]=8'h00;
        if(op==8'h8c || op==8'h8e || op==8'hce) mem.mem[16'hA003]=8'h00;
        // Return from interrupt/subroutine to a known NOP after the tested byte.
        if(op==8'h3b) begin
            mem.mem[16'h0001]=8'h00; mem.mem[16'h0002]=8'h00; mem.mem[16'h0003]=8'h00;
            mem.mem[16'h0004]=8'h00; mem.mem[16'h0005]=8'h00; mem.mem[16'h0006]=8'hA0; mem.mem[16'h0007]=8'h02;
        end
        if(op==8'h39) begin mem.mem[16'h0001]=8'hA0; mem.mem[16'h0002]=8'h02; end
        if(op==8'h3f) begin mem.mem[16'hFFFA]=8'hA0; mem.mem[16'hFFFB]=8'h02; end
        repeat(6) @(negedge clk);
        rst=0; timeout=0; began=0; ended=0; start_tick=0; actual=0;
        boundary_addr=16'hxxxx; boundary_pc=16'hxxxx;
        while(!ended && timeout<1400) begin
            @(posedge clk); #1; timeout=timeout+1;
            if(!began && opcode_fetch && addr==16'hA000) begin
                began=1; start_tick=cycles;
                dut.u_cpu.u_regs.s=16'h00ff;
            end else if(began && opcode_fetch) begin
                ended=1; actual=cycles-start_tick;
                boundary_addr=addr; boundary_pc=dut.u_cpu.u_regs.pc;
            end
            else if(began && op==8'h3e && instruction_end) begin ended=1; actual=cycles-start_tick; end
        end
        cycle_cases=cycle_cases+1;
        if(!began || !ended) begin
            cycle_failures=cycle_failures+1; boundary_failures=boundary_failures+1;
            $display("CYCLE_ROW opcode=%02x expected=%0d actual=NA status=no-boundary PC=%04x U=%04x",op,expected,dut.u_cpu.u_regs.pc,dut.u_cpu.u_ctrl.uaddr);
            if(cycle_failures<=20) $display("CYCLE_FAIL opcode=%02x no public boundary start=%b ended=%b",op,began,ended);
        end else if(actual!=expected) begin
            cycle_failures=cycle_failures+1;
            delta_bin=(actual-expected)/4+20;
            if(delta_bin>=0 && delta_bin<=40) delta_bins[delta_bin]=delta_bins[delta_bin]+1;
            $display("CYCLE_ROW opcode=%02x expected=%0d actual=%0d status=delta",op,expected,actual);
            if(cycle_failures<=20) $display("CYCLE_FAIL opcode=%02x expected=%0d master ticks (%0dE) actual=%0d PC=%04x",op,expected,manual_oracle[op][11:8],actual,dut.u_cpu.u_regs.pc);
        end else begin
            cycle_ok=cycle_ok+1;
            $display("CYCLE_ROW opcode=%02x expected=%0d actual=%0d status=pass",op,expected,actual);
        end
        if(op==8'h3f && ended) begin
            if(boundary_addr!==16'hA002 || boundary_pc!==16'hA002 || dut.u_cpu.u_regs.s!==16'h00f8 ||
               dut.u_cpu.u_regs.x!==16'h0000 || dut.u_cpu.u_regs.a!==8'h00 || dut.u_cpu.u_regs.b!==8'h00 ||
               {dut.u_cpu.u_regs.h,dut.u_cpu.u_regs.i,dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}!==6'b010000 ||
               mem.mem[16'h00f9]!==8'hd0 || mem.mem[16'h00fa]!==8'h00 || mem.mem[16'h00fb]!==8'h00 ||
               mem.mem[16'h00fc]!==8'h00 || mem.mem[16'h00fd]!==8'h00 || mem.mem[16'h00fe]!==8'ha0 || mem.mem[16'h00ff]!==8'h01) begin
                failures=failures+1;
                $display("FAIL SWI vector/frame target=%04x PC=%04x S=%04x X=%04x A=%02x B=%02x HINZVC=%b frame=%02x:%02x:%02x:%02x:%02x:%02x:%02x",
                    boundary_addr,boundary_pc,dut.u_cpu.u_regs.s,dut.u_cpu.u_regs.x,dut.u_cpu.u_regs.a,dut.u_cpu.u_regs.b,
                    {dut.u_cpu.u_regs.h,dut.u_cpu.u_regs.i,dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c},
                    mem.mem[16'h00f9],mem.mem[16'h00fa],mem.mem[16'h00fb],mem.mem[16'h00fc],mem.mem[16'h00fd],mem.mem[16'h00fe],mem.mem[16'h00ff]);
            end else begin
                checks=checks+1;
                $display("SWI VERIFIED: target=A002 frame=01:A0:00:00:00:00:D0 S=00F8 HINZVC=010000");
            end
        end
        trace_swi=0;
    end
endtask

initial begin
    for(opcode_index=0;opcode_index<41;opcode_index=opcode_index+1) delta_bins[opcode_index]=0;
    repeat(8) @(negedge clk);
    rst=0;
    wait_retire(16'hA007,4'b0001); wait_retire(16'hA009,4'b0001);
    wait_retire(16'hA00B,4'b0001); wait_retire(16'hA00E,4'b0001);
    wait_retire(16'hA012,4'b0000); wait_retire(16'hA014,4'b0000);
    wait_retire(16'hA016,4'b0000); wait_retire(16'hA019,4'b0000);
    wait_retire(16'hA020,4'b1001); wait_retire(16'hA022,4'b1001);
    wait_retire(16'hA024,4'b1001); wait_retire(16'hA027,4'b1001);
    wait_retire(16'hA02B,4'b1000); wait_retire(16'hA02D,4'b1000);
    wait_retire(16'hA02F,4'b1000); wait_retire(16'hA032,4'b1000);
    if(dut.u_cpu.u_regs.x!==16'h8000) begin failures=failures+1; $display("FAIL CPX changed X=%04x",dut.u_cpu.u_regs.x); end
    wait_pc(16'hA03C); // BNE took its +2 displacement; skipped LDAA left A=$7F
    if(dut.u_cpu.u_regs.a!==8'h7f) begin failures=failures+1; $display("FAIL BRA A=%02x expected 7f",dut.u_cpu.u_regs.a); end
    wait_pc(16'hA03E); // BEQ is not taken with Z=0
    wait_pc(16'hA03F);
    if(dut.u_cpu.u_regs.s!==16'h00fe || mem.mem[16'h00ff]!==8'h7f) begin failures=failures+1; $display("FAIL PSHA stack S=%04x byte[ff]=%02x",dut.u_cpu.u_regs.s,mem.mem[16'h00ff]); end
    wait_pc(16'hA041);
    if(dut.u_cpu.u_regs.s!==16'h00ff || dut.u_cpu.u_regs.a!==8'h7f) begin failures=failures+1; $display("FAIL PULA S=%04x A=%02x",dut.u_cpu.u_regs.s,dut.u_cpu.u_regs.a); end
    wait_pc(16'hA043);
    if(mem.mem[16'h0030]!==8'h7f) begin failures=failures+1; $display("FAIL STAA memory[30]=%02x",mem.mem[16'h0030]); end
    wait_retire(16'hA048,4'b1010); // indexed INC: $7F -> $80, N/V set
    if(mem.mem[16'h0030]!==8'h80) begin failures=failures+1; $display("FAIL indexed INC memory[30]=%02x",mem.mem[16'h0030]); end
    trace_bsr=1; bsr_trace_count=0;
    wait_pc(16'hA04E);
    if(dut.u_cpu.u_regs.s!==16'h00fd || mem.mem[16'h00fe]!==8'ha0 || mem.mem[16'h00ff]!==8'h4a) begin failures=failures+1; $display("FAIL BSR frame S=%04x bytes=%02x:%02x",dut.u_cpu.u_regs.s,mem.mem[16'h00fe],mem.mem[16'h00ff]); end
    wait_pc(16'hA04A);
    trace_bsr=0;
    if(dut.u_cpu.u_regs.s!==16'h00ff) begin failures=failures+1; $display("FAIL RTS S=%04x",dut.u_cpu.u_regs.s); end
    wait_pc(16'hA051);
    if(dut.u_cpu.u_regs.a!==8'ha5 || writes!=5) begin failures=failures+1; $display("FAIL call completion A=%02x writes=%0d",dut.u_cpu.u_regs.a,writes); end
    $display("ARCHITECTURE FIXTURE complete: CPX modes, branches, indexed RMW and call/stack checks=%0d",checks+1);
    $readmemh("program.hex",mem.mem);
    for(opcode_index=0;opcode_index<256;opcode_index=opcode_index+1)
        if(manual_oracle[opcode_index][15]) cycle_one(opcode_index[7:0]);
    // Load/store, ALU/DAA, and stack-wrap architectural checks over the
    // separate $B000 program image with the same synchronous RAM instance.
    rst=1; cpu_rst=0; ready=1; mr_n=1; enable=1; ext_halt=0; irq=0; nmi=0;
    mem.mem[16'hFFFE]=8'hB0; mem.mem[16'hFFFF]=8'h00;
    repeat(8) @(negedge clk);
    rst=0; trace_ordinary=1;
    wait_pc(16'hB007);
    if(dut.u_cpu.u_regs.a!==8'h80 || {dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}!==4'b1010) begin failures=failures+1; $display("FAIL ADDA #01 A=%02x NZVC=%b",dut.u_cpu.u_regs.a,{dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}); end
    wait_pc(16'hB009);
    if(mem.mem[16'h0030]!==8'h80) begin failures=failures+1; $display("FAIL STAA direct [30]=%02x",mem.mem[16'h0030]); end
    wait_pc(16'hB00B);
    if(dut.u_cpu.u_regs.a!==8'h80 || dut.u_cpu.u_regs.n!==1'b1 || dut.u_cpu.u_regs.v!==1'b0) begin failures=failures+1; $display("FAIL LDAA direct A=%02x NZV=%b%b%b",dut.u_cpu.u_regs.a,dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v); end
    wait_pc(16'hB00E);
    if(dut.u_cpu.u_regs.x!==16'h1234) begin failures=failures+1; $display("FAIL LDX immediate X=%04x",dut.u_cpu.u_regs.x); end
    wait_pc(16'hB010);
    if(mem.mem[16'h0040]!==8'h12 || mem.mem[16'h0041]!==8'h34) begin failures=failures+1; $display("FAIL STX direct bytes=%02x:%02x",mem.mem[16'h0040],mem.mem[16'h0041]); end
    wait_pc(16'hB012);
    if(dut.u_cpu.u_regs.x!==16'h1234) begin failures=failures+1; $display("FAIL LDX direct X=%04x",dut.u_cpu.u_regs.x); end
    wait_pc(16'hB015);
    if(dut.u_cpu.u_regs.x!==16'habcd) begin failures=failures+1; $display("FAIL LDX extended X=%04x",dut.u_cpu.u_regs.x); end
    wait_pc(16'hB018);
    if(mem.mem[16'h0052]!==8'hab || mem.mem[16'h0053]!==8'hcd) begin failures=failures+1; $display("FAIL STX extended bytes=%02x:%02x",mem.mem[16'h0052],mem.mem[16'h0053]); end
    wait_pc(16'hB01A);
    if(dut.u_cpu.u_regs.x!==16'h5678) begin failures=failures+1; $display("FAIL LDX indexed X=%04x",dut.u_cpu.u_regs.x); end
    wait_pc(16'hB01C);
    if(mem.mem[16'h5678]!==8'h56 || mem.mem[16'h5679]!==8'h78) begin failures=failures+1; $display("FAIL STX indexed bytes=%02x:%02x",mem.mem[16'h5678],mem.mem[16'h5679]); end
    wait_pc(16'hB020);
    if(dut.u_cpu.u_regs.a!==8'h9a || {dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}!==4'b1010) begin failures=failures+1; $display("FAIL ADDA BCD seed A=%02x NZVC=%b",dut.u_cpu.u_regs.a,{dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}); end
    wait_pc(16'hB021);
    if(dut.u_cpu.u_regs.a!==8'h00 || dut.u_cpu.u_regs.z!==1'b1 || dut.u_cpu.u_regs.c!==1'b1) begin failures=failures+1; $display("FAIL DAA A=%02x Z=%b C=%b",dut.u_cpu.u_regs.a,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.c); end
    wait_pc(16'hB029);
    if(dut.u_cpu.u_regs.a!==8'h5a || dut.u_cpu.u_regs.s!==16'h0000 || mem.mem[16'h0000]!==8'h5a) begin failures=failures+1; $display("FAIL stack wrap A=%02x S=%04x mem[0]=%02x",dut.u_cpu.u_regs.a,dut.u_cpu.u_regs.s,mem.mem[16'h0000]); end
    wait_pc(16'hB02C);
    if(dut.u_cpu.u_regs.s!==16'h1234) begin failures=failures+1; $display("FAIL LDS immediate S=%04x",dut.u_cpu.u_regs.s); end
    wait_pc(16'hB02E);
    if(mem.mem[16'h0042]!==8'h12 || mem.mem[16'h0043]!==8'h34) begin failures=failures+1; $display("FAIL STS direct bytes=%02x:%02x",mem.mem[16'h0042],mem.mem[16'h0043]); end
    wait_pc(16'hB031);
    if(mem.mem[16'h0054]!==8'h12 || mem.mem[16'h0055]!==8'h34) begin failures=failures+1; $display("FAIL STS extended bytes=%02x:%02x",mem.mem[16'h0054],mem.mem[16'h0055]); end
    wait_pc(16'hB036);
    if(dut.u_cpu.u_regs.a!==8'h11) begin failures=failures+1; $display("FAIL ADCA A=%02x",dut.u_cpu.u_regs.a); end
    wait_pc(16'hB03B);
    if(dut.u_cpu.u_regs.a!==8'hff || {dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}!==4'b1001) begin failures=failures+1; $display("FAIL SBCA A=%02x NZVC=%b",dut.u_cpu.u_regs.a,{dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}); end
    wait_pc(16'hB03F);
    if(dut.u_cpu.u_regs.a!==8'h80 || {dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}!==4'b0010) begin failures=failures+1; $display("FAIL CMPA A=%02x NZVC=%b",dut.u_cpu.u_regs.a,{dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}); end
    wait_pc(16'hB043);
    if(dut.u_cpu.u_regs.a!==8'h00 || dut.u_cpu.u_regs.z!==1'b1 || dut.u_cpu.u_regs.v!==1'b0) begin failures=failures+1; $display("FAIL ANDA A=%02x NZV=%b%b%b",dut.u_cpu.u_regs.a,dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v); end
    wait_pc(16'hB045);
    if(dut.u_cpu.u_regs.a!==8'h55) begin failures=failures+1; $display("FAIL EORA A=%02x",dut.u_cpu.u_regs.a); end
    wait_pc(16'hB047);
    if(dut.u_cpu.u_regs.a!==8'hd5) begin failures=failures+1; $display("FAIL ORAA A=%02x",dut.u_cpu.u_regs.a); end
    wait_pc(16'hB04B);
    if(dut.u_cpu.u_regs.a!==8'h0f) begin failures=failures+1; $display("FAIL SUBA A=%02x",dut.u_cpu.u_regs.a); end
    wait_pc(16'hB04E);
    if(dut.u_cpu.u_regs.a!==8'h02 || {dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}!==4'b0011) begin failures=failures+1; $display("FAIL ASLA A=%02x NZVC=%b",dut.u_cpu.u_regs.a,{dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}); end
    wait_pc(16'hB04F);
    if(dut.u_cpu.u_regs.a!==8'h01 || dut.u_cpu.u_regs.c!==1'b0) begin failures=failures+1; $display("FAIL LSRA A=%02x C=%b",dut.u_cpu.u_regs.a,dut.u_cpu.u_regs.c); end
    wait_pc(16'hB050);
    if(dut.u_cpu.u_regs.a!==8'h00 || dut.u_cpu.u_regs.c!==1'b1 || dut.u_cpu.u_regs.z!==1'b1) begin failures=failures+1; $display("FAIL RORA A=%02x NZC=%b%b%b",dut.u_cpu.u_regs.a,dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.c); end
    trace_ordinary=0;
    $display("ORDINARY ARCHITECTURE complete: ALU, flags, logic, shifts, DAA, byte/word loads/stores, stack wrap");

    // Directed JSR checks use fresh, runtime-seeded programs so these cases
    // remain independent of the generated manifest/program image. The stack
    // stores the return PC high byte at S and low byte at S-1.
    rst=1; cpu_rst=0; ready=1; mr_n=1; enable=1; ext_halt=0; irq=0; nmi=0;
    mem.mem[16'hB100]=8'hce; mem.mem[16'hB101]=8'hb1; mem.mem[16'hB102]=8'h20; // LDX #$B120
    mem.mem[16'hB103]=8'had; mem.mem[16'hB104]=8'h00; // JSR $00,X
    mem.mem[16'hB105]=8'h01; // return marker
    mem.mem[16'hB106]=8'h20; mem.mem[16'hB107]=8'hfe; // hold here
    mem.mem[16'hB120]=8'h39; // RTS
    mem.mem[16'hB200]=8'hbd; mem.mem[16'hB201]=8'hb2; mem.mem[16'hB202]=8'h20; // JSR $B220
    mem.mem[16'hB203]=8'h01; // return marker
    mem.mem[16'hB204]=8'h20; mem.mem[16'hB205]=8'hfe; // hold here
    mem.mem[16'hB220]=8'h39; // RTS
    mem.mem[16'hFFFE]=8'hB1; mem.mem[16'hFFFF]=8'h00;
    repeat(8) @(negedge clk);
    rst=0;
    seed_stack_at_fetch(16'hB100,16'h01ff);
    wait_pc(16'hB120);
    if(dut.u_cpu.u_regs.s!==16'h01fd || mem.mem[16'h01ff]!==8'h05 || mem.mem[16'h01fe]!==8'hb1) begin
        failures=failures+1;
        $display("FAIL indexed JSR target/stack target=%04x S=%04x return=%02x:%02x expected target=B120 S=01FD return=05:B1",
            dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s,mem.mem[16'h01ff],mem.mem[16'h01fe]);
    end else checks=checks+1;
    wait_pc(16'hB105);
    if(dut.u_cpu.u_regs.s!==16'h01ff || dut.u_cpu.u_regs.pc!==16'hB105) begin
        failures=failures+1;
        $display("FAIL indexed JSR/RTS return PC=%04x S=%04x expected PC=B105 S=01FF",dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s);
    end else checks=checks+1;

    rst=1;
    mem.mem[16'hFFFE]=8'hB2; mem.mem[16'hFFFF]=8'h00;
    repeat(8) @(negedge clk);
    rst=0;
    seed_stack_at_fetch(16'hB200,16'h01ff);
    wait_pc(16'hB220);
    if(dut.u_cpu.u_regs.s!==16'h01fd || mem.mem[16'h01ff]!==8'h03 || mem.mem[16'h01fe]!==8'hb2) begin
        failures=failures+1;
        $display("FAIL extended JSR target/stack target=%04x S=%04x return=%02x:%02x expected target=B220 S=01FD return=03:B2",
            dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s,mem.mem[16'h01ff],mem.mem[16'h01fe]);
    end else checks=checks+1;
    wait_pc(16'hB203);
    if(dut.u_cpu.u_regs.s!==16'h01ff || dut.u_cpu.u_regs.pc!==16'hB203) begin
        failures=failures+1;
        $display("FAIL extended JSR/RTS return PC=%04x S=%04x expected PC=B203 S=01FF",dut.u_cpu.u_regs.pc,dut.u_cpu.u_regs.s);
    end else checks=checks+1;
    $display("JSR ARCHITECTURE complete: indexed and extended targets, return bytes, stack decrement/restore, RTS return PCs");

    $display("CYCLE SUMMARY: cases=%0d passed=%0d failures=%0d no-boundary=%0d",cycle_cases,cycle_ok,cycle_failures,boundary_failures);
    for(cycle_bin=0;cycle_bin<41;cycle_bin=cycle_bin+1)
        if(delta_bins[cycle_bin]!=0) $display("CYCLE_DELTA e_cycles=%0d count=%0d",cycle_bin-20,delta_bins[cycle_bin]);
    if(failures==0 && cycle_failures==0) $display("PASS: MC6802 documented opcode timing and architecture fixture");
    else $display("FAIL: architecture failures=%0d; cycle failures=%0d",failures,cycle_failures);
    $finish;
end

initial begin
    #20000000;
    $display("FAIL global timeout CPU PC=%04x U=%03x",dut.u_cpu.u_regs.pc,dut.u_cpu.u_ctrl.uaddr);
    $fatal(1);
end
endmodule
