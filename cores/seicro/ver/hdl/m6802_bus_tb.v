/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

`timescale 1ns/1ps
module m6802_bus_tb;
parameter WITH_MR=0;
parameter PHASE=0;
parameter HOST_STALL=0;
reg clk=0, rst=1, enable=1;
reg [3:0] divider=0;
wire cen=divider==0;
reg [5:0] release_divider=PHASE*6;
wire release_clk=release_divider>=24;
wire [15:0] addr;
wire [7:0] dout;
wire e, vma, wr, done, instruction_end, board_mr_n;
reg first_host_hold=HOST_STALL;
wire ready=!HOST_STALL || !vma || wr || addr>=16'hf800 ||
           (!first_host_hold && release_divider>=8);
wire mr_n=WITH_MR ? board_mr_n : 1'b1;
reg [7:0] din;
reg [7:0] memory[0:65535];
integer k, bsr_cycle=0, rts_cycle=0, writes=0, cycles=0;
integer ticks=0, last_done=0, extended=0, held=0, host_waits=0;
reg [15:0] expected_addr;
reg expected_vma, expected_wr;
reg previous_e=0;
reg [15:0] held_addr;
reg [7:0] held_dout;
reg held_vma, held_wr;

always #5 clk=~clk;
always @(posedge clk) begin
    divider <= divider+4'd1;
    release_divider <= release_divider==47 ? 0 : release_divider+6'd1;
    din <= memory[addr];
    if(cen && enable && !rst) ticks=ticks+1;
    if(cen && enable && !rst && e && !ready) host_waits=host_waits+1;
    if(done) begin
        cycles=cycles+1;
        if(last_done!=0) begin
            if(!WITH_MR && !HOST_STALL && ticks-last_done!=4)
                $fatal(1,"Nominal E cycle is not four crystal ticks");
            if(WITH_MR && !HOST_STALL && ((ticks-last_done)<4 || (ticks-last_done)%2!=0))
                $fatal(1,"MR stretch is not an integral E half-period");
            if(ticks-last_done>4) extended=extended+1;
        end
        last_done=ticks;
        if(vma && wr) begin
            memory[addr]<=dout;
            writes=writes+1;
        end
        if(dut.u_cpu.u_regs.op_pc==16'h8003 && !dut.opcode_fetch) begin
            bsr_cycle=bsr_cycle+1;
            expected_wr=0;
            expected_vma=0;
            case(bsr_cycle)
                1: begin expected_addr=16'h8004; expected_vma=1; end
                2: expected_addr=16'h8005;
                3: begin expected_addr=16'hf87f; expected_vma=1; expected_wr=1; end
                4: begin expected_addr=16'hf87e; expected_vma=1; expected_wr=1; end
                5: expected_addr=16'hf87d;
                6: expected_addr=16'h8005;
                7: expected_addr=16'h800a;
                default: $fatal(1,"Too many BSR cycles");
            endcase
            if({addr,vma,wr}!={expected_addr,expected_vma,expected_wr})
                $fatal(1,"BSR cycle%0d addr=%h vma=%b wr=%b",bsr_cycle+1,addr,vma,wr);
        end
        if(dut.u_cpu.u_regs.op_pc==16'h800c && !dut.opcode_fetch) begin
            rts_cycle=rts_cycle+1;
            expected_vma=1;
            case(rts_cycle)
                1: expected_addr=16'h800d;
                2: begin expected_addr=16'hf87d; expected_vma=0; end
                3: expected_addr=16'hf87e;
                4: expected_addr=16'hf87f;
                default: $fatal(1,"Too many RTS cycles");
            endcase
            if({addr,vma,wr}!={expected_addr,expected_vma,1'b0})
                $fatal(1,"RTS cycle%0d addr=%h vma=%b wr=%b",rts_cycle+1,addr,vma,wr);
        end
    end
    #1;
    if(!rst && previous_e && e) begin
        held=held+1;
        if({addr,dout,vma,wr}!={held_addr,held_dout,held_vma,held_wr})
            $fatal(1,"MCU bus changed while E high");
    end
    previous_e=e;
    held_addr=addr;
    held_dout=dout;
    held_vma=vma;
    held_wr=wr;
    if(dut.illegal) $fatal(1,"Illegal opcode %h at %h",dut.raw_opcode,dut.u_cpu.u_regs.op_pc);
end

jtseicro_mr u_mr(
    .rst         ( rst         ),
    .clk         ( clk         ),
    .e           ( e           ),
    .vma         ( vma         ),
    .a15         ( addr[15]    ),
    .release_clk ( release_clk ),
    .mr_n        ( board_mr_n  )
);

jt6802 #(
    .FC_COMPAT       ( 1               )
) dut(
    .irq             ( 1'b0            ),
    .nmi             ( 1'b0            ),
    .ext_halt        ( 1'b0            ),
    .ba              (                 ),
    .nsc8105         ( 1'b0            ),
    .opcode_fetch    (                 ),
    .rst             ( rst             ),
    .cpu_rst         ( rst             ),
    .clk             ( clk             ),
    .cen             ( cen             ),
    .enable          ( enable          ),
    .ready           ( ready           ),
    .mr_n            ( mr_n            ),
    .din             ( din             ),
    .addr            ( addr            ),
    .dout            ( dout            ),
    .e               ( e               ),
    .vma             ( vma             ),
    .wr              ( wr              ),
    .done            ( done            ),
    .instruction_end ( instruction_end )
);

initial begin
    if(PHASE==0) begin
        $dumpfile("m6802_bus.vcd");
        $dumpvars(0,m6802_bus_tb);
    end
    for(k=0;k<65536;k=k+1) memory[k]=8'h01;
    memory[16'hfffe]=8'h80; memory[16'hffff]=0;
    memory[16'h8000]=8'h8e; memory[16'h8001]=8'hf8; memory[16'h8002]=8'h7f;
    memory[16'h8003]=8'h8d; memory[16'h8004]=5;
    memory[16'h8005]=8'hb7; memory[16'h8006]=8'hf8; memory[16'h8007]=0;
    memory[16'h8008]=8'h20; memory[16'h8009]=8'hfe;
    memory[16'h800a]=8'h86; memory[16'h800b]=8'h5a;
    memory[16'h800c]=8'h39;
    repeat(10) @(negedge clk);
    rst=0;
    wait(memory[16'hf800]==8'h5a);
    @(negedge clk);
    if(bsr_cycle!=7 || rts_cycle!=4 || writes!=3 ||
       memory[16'hf87f]!==8'h05 || memory[16'hf87e]!==8'h80 || dut.u_cpu.u_regs.s!==16'hf87f)
        $fatal(1,"BSR/RTS result or transfer count incorrect");
    if(WITH_MR && extended==0) $fatal(1,"No MR stretch exercised");
    if(HOST_STALL && host_waits==0) $fatal(1,"No independent host stall exercised");
    $display("PASS M6802 bus MR=%0d phase=%0d host=%0d: BSR/RTS cycles, VMA, addresses, 3 writes, held bus, %0d stretched cycles",WITH_MR,PHASE,HOST_STALL,extended);
    $finish;
end

initial begin
    wait(!rst);
    wait(e && wr && vma && addr==16'hf87f);
    @(negedge clk); enable=0;
    repeat(100) @(negedge clk);
    enable=1;
end

initial begin
    wait(!rst);
    wait(e && vma && addr==16'h8000);
    repeat(160) @(negedge clk);
    first_host_hold=0;
end

initial begin #1000000; $fatal(1,"M6802 bus timeout PC=%h",dut.u_cpu.u_regs.pc); end
endmodule
