/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

`timescale 1ns/1ps
module m6802_compat_tb;
reg clk=0, rst=1;
reg [3:0] divider=0;
wire cen=divider==0;
wire [15:0] addr;
wire [7:0] dout;
wire vma, wr, done, instruction_end;
reg [7:0] din;
integer transfers=0, cycles=0;
reg finished=0;
always #5 clk=~clk;
always @(posedge clk) begin
    divider <= divider+4'd1;
    case(addr)
        16'hfffe: din <= 8'h80;
        16'hffff: din <= 8'h00;
        16'h8000: din <= 8'hfc;
        16'h8001: din <= 8'h90;
        16'h8002: din <= 8'h35;
        default: din <= 8'h01;
    endcase
    if(!rst && done) begin
        if(wr) $fatal(1,"FC compatibility wrote memory");
        if(cpu.reset_stage==2) begin
            if(cycles<3 && (!vma || addr!==16'h8000+cycles))
                $fatal(1,"FC compatibility operand fetch %0d at %h VMA=%b",cycles,addr,vma);
            if(cycles==3 && vma) $fatal(1,"FC compatibility final cycle was valid");
            if(vma) transfers=transfers+1;
            cycles=cycles+1;
        end
        if(instruction_end) finished <= 1;
    end
end
initial begin
    repeat(4) @(negedge clk);
    rst=0;
    cpu.a=8'h58; cpu.b=8'ha3; cpu.x=16'hefe0; cpu.s=16'hf87f; cpu.cc=8'hf9;
    wait(finished);
    @(negedge clk);
    if(cycles!=4 || transfers!=3 ||
       {cpu.a,cpu.b,cpu.x,cpu.s,cpu.pc,cpu.cc}!==72'h58a3efe0f87f8003f9)
        $fatal(1,"FC compatibility state/cycle mismatch");
    $display("PASS Frisky Tom FC compatibility: skip two operands; preserve registers/flags; four provisional cycles");
    $finish;
end
initial begin
    #100000;
    $fatal(1,"FC compatibility timeout");
end
jtseicro_m6802 cpu(
    .rst             ( rst             ),
    .cpu_rst         ( rst             ),
    .clk             ( clk             ),
    .cen             ( cen             ),
    .enable          ( !finished       ),
    .ready           ( 1'b1            ),
    .mr_n            ( 1'b1            ),
    .din             ( din             ),
    .addr            ( addr            ),
    .dout            ( dout            ),
    .e               (                 ),
    .vma             ( vma             ),
    .wr              ( wr              ),
    .done            ( done            ),
    .instruction_end ( instruction_end )
);
endmodule
