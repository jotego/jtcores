`timescale 1ns/1ps
module test;

reg clk=0;
always #5 clk=~clk;
reg rst=1, cen=1, enable=1, ready=1, mr_n=1;
reg ext_halt=0, irq=0, nmi=0;
wire [15:0] addr;
wire [7:0] din, dout, opcode_raw;
wire e,vma,wr,done,instruction_end,opcode_fetch,ba;
wire [7:0] opcode = opcode_raw==8'h02 ? 8'h01 : opcode_raw;
reg [7:0] mem[0:65535];
integer writes=0, timeout;
reg found, saw_raw_opcode=0;

assign din=mem[addr];
always @(posedge clk) begin
    if(opcode_fetch && addr==16'h0106) begin
        if(opcode_raw!==8'h02 || opcode!==8'h01) begin $display("FAIL decode event raw=%02x decoded=%02x",opcode_raw,opcode); $fatal(1); end
        saw_raw_opcode=1;
    end
    if(done) begin
        if(!e || !vma) begin $display("FAIL done without public E/VMA"); $fatal(1); end
        if(wr) begin mem[addr]<=dout; writes<=writes+1; end
    end
end

jt6802 #(.EXT_DECODE(1)) dut(
    .rst(rst),.cpu_rst(1'b0),.clk(clk),.cen(cen),.enable(enable),
    .ready(ready),.mr_n(mr_n),.din(din),.opcode(opcode),.opcode_raw(opcode_raw),
    .addr(addr),.dout(dout),.e(e),.vma(vma),.wr(wr),.done(done),
    .instruction_end(instruction_end),.opcode_fetch(opcode_fetch),
    .ext_halt(ext_halt),.ba(ba),.irq(irq),.nmi(nmi)
);

integer i;
initial begin
    for(i=0;i<65536;i=i+1) mem[i]=8'h01;
    mem[16'hfffe]=8'h01; mem[16'hffff]=8'h00;
    mem[16'h0100]=8'hce; mem[16'h0101]=8'h12; mem[16'h0102]=8'h00; // LDX #$1200
    mem[16'h0103]=8'h8c; mem[16'h0104]=8'h12; mem[16'h0105]=8'h01; // CPX #$1201
    mem[16'h0106]=8'h02;                                         // translated to NOP
    repeat(5) @(negedge clk); rst=0;
    timeout=0; found=0;
    while(!found && timeout<1000) begin
        @(posedge clk); timeout=timeout+1;
        if(dut.u_cpu.u_ctrl.uaddr==12'h020 && dut.u_cpu.u_regs.pc==16'h0107) found=1;
    end
    if(!found) begin $display("FAIL translated opcode did not dispatch, raw=%02x U=%03x",opcode_raw,dut.u_cpu.u_ctrl.uaddr); $fatal(1); end
    if(!saw_raw_opcode) begin $display("FAIL decoded instruction never exposed its raw opcode fetch"); $fatal(1); end
    if({dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c} !== 4'b0000) begin
        $display("FAIL translated path disturbed CPX flags %b",{dut.u_cpu.u_regs.n,dut.u_cpu.u_regs.z,dut.u_cpu.u_regs.v,dut.u_cpu.u_regs.c}); $fatal(1);
    end
    $display("PASS: EXT_DECODE translates raw 02 to native NOP while exposing raw opcode 02");
    $finish;
end
endmodule
