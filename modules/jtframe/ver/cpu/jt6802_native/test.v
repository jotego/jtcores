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
integer cycles=0, writes=0;
integer reset_hi_reads=0, reset_lo_reads=0, reset_op_fetch=0;
integer ldx_hi_reads=0, ldx_lo_reads=0, cpx_hi_reads=0, cpx_lo_reads=0;
reg [15:0] stalled_addr;
reg store_watch=0, cpx_watch=0;

assign din=mem_q;
always @(posedge clk) begin
    cycles<=cycles+1;
    if(cen && vma && !wr) mem_q<=mem[addr];
    if(done && !ready) begin $display("FAIL completion while ready is low"); $fatal(1); end
    if(done) begin
        if(!e || !vma) begin $display("FAIL done without public E/VMA"); $fatal(1); end
        if(wr) begin
            if(addr!==16'h0020 || dout!==8'h5a) begin $display("FAIL write transaction addr=%04x data=%02x",addr,dout); $fatal(1); end
            mem[addr]<=dout; writes<=writes+1;
        end
        if(addr==16'hfffe) begin
            if(din!==8'ha3) begin $display("FAIL reset vector high read=%02x",din); $fatal(1); end
            reset_hi_reads<=reset_hi_reads+1;
        end
        if(addr==16'hffff) begin
            if(din!==8'h5c) begin $display("FAIL reset vector low read=%02x",din); $fatal(1); end
            reset_lo_reads<=reset_lo_reads+1;
        end
        if(opcode_fetch && addr==16'ha35c) reset_op_fetch<=reset_op_fetch+1;
        if(cpx_watch && addr==16'ha35d) begin if(din!==8'h12) $fatal(1,"bad LDX high operand %02x",din); ldx_hi_reads<=ldx_hi_reads+1; end
        if(cpx_watch && addr==16'ha35e) begin if(din!==8'h00) $fatal(1,"bad LDX low operand %02x",din); ldx_lo_reads<=ldx_lo_reads+1; end
        if(cpx_watch && addr==16'ha361) begin if(din!==8'h12) $fatal(1,"bad CPX high operand %02x",din); cpx_hi_reads<=cpx_hi_reads+1; end
        if(cpx_watch && addr==16'ha362) begin if(din!==8'h01) $fatal(1,"bad CPX low operand %02x",din); cpx_lo_reads<=cpx_lo_reads+1; end
    end
end

jt6802 dut(
    .rst(rst),.cpu_rst(cpu_rst),.clk(clk),.cen(cen),.enable(enable),
    .ready(ready),.mr_n(mr_n),.din(din),.opcode(8'h00),.opcode_raw(),.addr(addr),.dout(dout),
    .e(e),.vma(vma),.wr(wr),.done(done),.instruction_end(instruction_end),
    .opcode_fetch(opcode_fetch),.ext_halt(ext_halt),.ba(ba),.irq(irq),.nmi(nmi)
);

task seed_program;
    input carry_seed;
    begin
        mem[16'hfffe]=8'ha3; mem[16'hffff]=8'h5c;
        mem[16'ha35c]=8'hce; mem[16'ha35d]=8'h12; mem[16'ha35e]=8'h00; // LDX #$1200
        mem[16'ha35f]=carry_seed ? 8'h0d : 8'h0c;                   // SEC / CLC
        mem[16'ha360]=8'h8c; mem[16'ha361]=8'h12; mem[16'ha362]=8'h01; // CPX #$1201
        mem[16'ha363]=8'h01;                                         // NOP
        reset_hi_reads=0; reset_lo_reads=0; reset_op_fetch=0;
        ldx_hi_reads=0; ldx_lo_reads=0; cpx_hi_reads=0; cpx_lo_reads=0; cpx_watch=1;
    end
endtask

task reset_cpu;
    integer stall_timeout;
    begin
        ready=1; rst=1; repeat(5) @(negedge clk); rst=0;
        stall_timeout=0;
        while((!vma || e) && stall_timeout<100) begin @(posedge clk); stall_timeout=stall_timeout+1; end
        if(!vma || e) begin $display("FAIL no low-E bus request phase=%b VMA=%b U=%03x",dut.phase,vma,dut.u_cpu.u_ctrl.uaddr); $fatal(1); end
        @(negedge clk); ready=0;
        stall_timeout=0;
        while(!(e && vma) && stall_timeout<100) begin @(posedge clk); stall_timeout=stall_timeout+1; end
        if(!(e && vma)) begin $display("FAIL no reset bus request phase=%b VMA=%b U=%03x inner=%b",dut.phase,vma,dut.u_cpu.u_ctrl.uaddr,dut.cpu_vma); $fatal(1); end
        stalled_addr=addr;
        repeat(8) begin
            @(posedge clk);
            if(done || addr!==stalled_addr) begin $display("FAIL ready hold changed transaction done=%b addr=%04x expected=%04x",done,addr,stalled_addr); $fatal(1); end
        end
        ready=1;
    end
endtask

task check_cpx;
    input carry_seed;
    integer timeout;
    reg found;
    begin
        seed_program(carry_seed); reset_cpu(); timeout=0; found=0;
        while(!found && timeout<1000) begin
            @(posedge clk); timeout=timeout+1;
            if(!found && dut.u_cpu.u_ctrl.uaddr==(carry_seed ? 12'h1a0 : 12'h180) && dut.u_cpu.u_regs.pc==16'ha35f) begin
                if(dut.u_cpu.u_regs.x!==16'h1200) begin $display("FAIL LDX immediate loaded X=%04x expected 1200",dut.u_cpu.u_regs.x); $fatal(1); end
            end
            if(dut.u_cpu.u_ctrl.uaddr==12'h020 && dut.u_cpu.u_regs.pc==16'ha363) found=1;
        end
        if(!found) begin $display("FAIL CPX program timed out, PC=%04x U=%03x",dut.u_cpu.u_regs.pc,dut.u_cpu.u_ctrl.uaddr); $fatal(1); end
        if(reset_hi_reads!=1 || reset_lo_reads!=1) begin
            $display("FAIL reset vector public reads FFFE=%0d FFFF=%0d",reset_hi_reads,reset_lo_reads); $fatal(1);
        end
        if(reset_op_fetch!=1) begin $display("FAIL public opcode_fetch for reset PC=%0d",reset_op_fetch); $fatal(1); end
        if(ldx_hi_reads!=1 || ldx_lo_reads!=1 || cpx_hi_reads!=1 || cpx_lo_reads!=1) begin
            $display("FAIL sync operand reads LDX=%0d/%0d CPX=%0d/%0d",ldx_hi_reads,ldx_lo_reads,cpx_hi_reads,cpx_lo_reads); $fatal(1);
        end
        #1;
        if({dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c} !== {3'b000,carry_seed}) begin
            $display("FAIL CPU CPX carry seed=%b flags NZVC=%b",carry_seed,{dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}); $fatal(1);
        end
        $display("CPU CPX PASS carry seed=%b cycles=%0d reset_reads=FFFE/FFFF opcode_fetch=%0d",carry_seed,timeout,reset_op_fetch);
        cpx_watch=0;
    end
endtask

task check_store;
    integer timeout;
    reg found;
    begin
        mem[16'hfffe]=8'ha3; mem[16'hffff]=8'h5c;
        mem[16'ha35c]=8'h86; mem[16'ha35d]=8'h5a; // LDAA #$5A
        mem[16'ha35e]=8'h97; mem[16'ha35f]=8'h20; // STAA $20
        mem[16'ha360]=8'h01;                     // NOP
        mem[16'h0020]=8'haa;
        writes=0; reset_hi_reads=0; reset_lo_reads=0; reset_op_fetch=0;
        store_watch=1;
        reset_cpu(); timeout=0; found=0;
        while(!found && timeout<1000) begin
            @(posedge clk); timeout=timeout+1;
            if(dut.u_cpu.u_ctrl.uaddr==12'h020 && dut.u_cpu.u_regs.pc==16'ha360) found=1;
        end
        if(!found) begin $display("FAIL store program timed out PC=%04x U=%03x",dut.u_cpu.u_regs.pc,dut.u_cpu.u_ctrl.uaddr); $fatal(1); end
        repeat(8) @(posedge clk);
        store_watch=0;
        if(writes!=1 || mem[16'h0020]!==8'h5a) begin
            $display("FAIL STAA accepted writes=%0d memory[20]=%02x",writes,mem[16'h0020]); $fatal(1);
        end
        $display("CPU STAA PASS exactly one done-qualified write to $0020");
    end
endtask

integer i;
initial begin
    for(i=0;i<65536;i=i+1) mem[i]=8'h01;
    check_cpx(1'b0);
    check_cpx(1'b1);
    check_store();
    $display("PASS: MC6802 native reset/read/write, CPX and wrapper completion contract");
    $finish;
end
endmodule
