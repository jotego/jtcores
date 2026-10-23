`timescale 1ns/1ps

module test;
reg clk=0;
always #5 clk=~clk;
reg rst=1, irq=0, nmi=0, opdec=0;
reg phase=0;
reg cen_hold=0;
wire cen=phase==0 && !cen_hold;
always @(posedge clk) phase<=~phase;
wire wr,rd,fetch;
wire [15:0] addr;
wire [7:0] din,dout;
integer cen_count=0;
integer cases=0, control_cases=0, mismatches=0, bus_writes=0;
integer reserved_cases=0;
integer watched_reads=0, watched_writes=0;
integer known_findings=0;
reg [31:0] finding_hash=32'h811c9dc5;
localparam CEN_PER_PHI2=4;
reg [23:0] manifest[0:209];
reg trace_branch=0;
reg [15:0] last_write_addr=0;
reg [7:0] last_write_data=0;

always @(posedge clk) begin
    if(rst) cen_count<=0;
    else if(cen) cen_count<=cen_count+1;
    if(!rst && cen && wr) begin
        bus_writes<=bus_writes+1;
        last_write_addr<=addr;
        last_write_data<=dout;
    end
    if(rst) begin
        watched_reads<=0;
        watched_writes<=0;
    end else if(cen && addr==16'h2100) begin
        if(wr) watched_writes<=watched_writes+1;
        else if(rd) watched_reads<=watched_reads+1;
    end
end
always @(posedge clk) if(trace_branch && cen) begin
    $display("BRANCHTRACE t=%0t cen=%0d pc=%04x di=%02x do=%02x rd=%b wr=%b fetch=%b ni=%b en=%b uaddr=%03x page=%b C/Z/N/V=%b%b%b%b",
        $time,cen_count,addr,din,dout,rd,wr,fetch,uut.u_ctrl.next_instruction,
        uut.u_ctrl.enable,uut.u_ctrl.uaddr,uut.u_regs.pcpage,uut.u_regs.c,uut.u_regs.z,uut.u_regs.n,uut.u_regs.v);
end

jtframe_ram #(.AW(16),.CEN_RD(0)) mem(
    .clk(clk), .cen(cen), .data(dout), .addr(addr), .we(wr), .q(din)
);

jt65c02 #(.DECO222(0)) uut(
    .rst(rst), .clk(clk), .cen(cen), .irq(irq), .nmi(nmi), .opdec(opdec),
    .wr(wr), .rd(rd), .fetch(fetch), .addr(addr), .din(din), .dout(dout)
);

`include "test_tasks.vh"

task record_known_finding(input [31:0] key, input integer observation,
                          input integer actual_cycles, input integer expected_cycles);
    begin
        $display("KNOWN-FINDING key=%08x observed=%0d actual=%0d expected=%0d",
                 key,observation,actual_cycles,expected_cycles);
        finding_hash=(finding_hash ^ key)*32'd16777619;
        finding_hash=(finding_hash ^ observation)*32'd16777619;
        finding_hash=(finding_hash ^ actual_cycles)*32'd16777619;
        finding_hash=(finding_hash ^ expected_cycles)*32'd16777619;
        known_findings=known_findings+1;
    end
endtask


task accepted(input [15:0] pc, input integer limit,
              output integer count, output reg [7:0] opcode);
    integer k;
    reg seen;
    begin
        k=0; seen=0; count=0; opcode=0;
        while(!seen && k<limit) begin
            @(posedge clk);
            if(cen && uut.u_ctrl.enable && uut.u_ctrl.next_instruction && addr==pc) begin
                seen=1;
                #1;
                count=cen_count;
                opcode=uut.u_ctrl.ir;
            end
            k=k+1;
        end
        if(!seen) begin
            $display("FAIL: missing accepted instruction boundary at %04x",pc);
            $fatal(1);
        end
    end
endtask

function [15:0] endpoint(input [7:0] opcode, input [3:0] bytes);
    begin
        case(opcode)
            8'h00,8'h20,8'h40,8'h4c,8'h60,8'h6c,8'h7c: endpoint=16'h2000;
            default: endpoint=16'h1009+bytes;
        endcase
    end
endfunction

function reserved_opcode(input [7:0] opcode);
    begin
        case(opcode)
            8'h02,8'h03,8'h0b,8'h13,8'h1b,8'h22,8'h23,8'h2b,8'h33,8'h3b,
            8'h42,8'h43,8'h44,8'h4b,8'h53,8'h54,8'h5b,8'h5c,8'h62,8'h63,
            8'h6b,8'h73,8'h7b,8'h82,8'h83,8'h8b,8'h93,8'h9b,8'ha3,8'hab,
            8'hb3,8'hbb,8'hc2,8'hc3,8'hcb,8'hd3,8'hd4,8'hdb,8'hdc,8'he2,
            8'he3,8'heb,8'hf3,8'hf4,8'hfb,8'hfc: reserved_opcode=1'b1;
            default: reserved_opcode=1'b0;
        endcase
    end
endfunction

task run_case(input [7:0] opcode, input [7:0] expected,
              input [3:0] bytes, input integer index);
    integer first,last,delta,actual,basewrites;
    reg [7:0] accepted_op, end_op;
    reg [15:0] endpc;
    begin
        // A short real program gives defined X/Y/A and C/D/V/N/Z before every
        // target instruction while keeping setup timing outside the interval.
        mem.mem[16'h1000]=8'ha2; mem.mem[16'h1001]=8'h01; // LDX #1
        mem.mem[16'h1002]=8'ha0; mem.mem[16'h1003]=8'h01; // LDY #1
        mem.mem[16'h1004]=8'ha9; mem.mem[16'h1005]=8'h55; // LDA #$55
        mem.mem[16'h1006]=8'h18;                         // CLC
        mem.mem[16'h1007]=8'hd8;                         // CLD
        mem.mem[16'h1008]=8'hb8;                         // CLV
        mem.mem[16'h1009]=opcode;
        mem.mem[16'h100a]=8'h40;
        mem.mem[16'h100b]=8'h00;
        mem.mem[16'h0040]=8'h00;
        mem.mem[16'h0041]=8'h20; mem.mem[16'h0042]=8'h00;
        mem.mem[16'h001f]=8'h55; mem.mem[16'h0020]=8'h55; mem.mem[16'h0021]=8'h55;
        mem.mem[16'h2000]=8'h55; mem.mem[16'h2001]=8'h55;
        mem.mem[16'h2021]=8'h55;
        // Shared indirect targets; X/Y=1. The indexed-read base stays in-page.
        mem.mem[16'h12ff]=8'h00; mem.mem[16'h1300]=8'h20;
        mem.mem[16'h2100]=8'h55;
        mem.mem[16'hfffe]=8'h00; mem.mem[16'hffff]=8'h20;
        // Reset SP is FD. Provide valid return frames for RTS and RTI.
        mem.mem[16'h01fe]=8'hff; mem.mem[16'h01ff]=8'h1f;
        mem.mem[16'h0100]=8'h20;
        if(opcode==8'h6c) begin
            // Non-page-wrap base case; XXFF is covered by its own Rockwell path.
            mem.mem[16'h100a]=8'hfe; mem.mem[16'h100b]=8'h12;
            mem.mem[16'h12fe]=8'h00; mem.mem[16'h12ff]=8'h20;
        end
        if(opcode==8'h10 || opcode==8'h30 || opcode==8'h50 || opcode==8'h70 ||
           opcode==8'h80 || opcode==8'h90 || opcode==8'hb0 || opcode==8'hd0 || opcode==8'hf0)
            mem.mem[16'h100a]=8'h00;
        if(opcode==8'h7c) begin
            mem.mem[16'h100a]=8'hfe; mem.mem[16'h100b]=8'h12;
        end
        if(opcode==8'h4c || opcode==8'h20) begin
            mem.mem[16'h100a]=8'h00; mem.mem[16'h100b]=8'h20;
        end
        if(opcode==8'h40) begin
            mem.mem[16'h01fe]=8'h20; // RTI status byte
            mem.mem[16'h01ff]=8'h00;
        end

        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        basewrites=bus_writes;
        rst=0;
        accepted(16'h1009,2000,first,accepted_op);
        if(accepted_op!==opcode) begin
            $display("FAIL: opcode decode at %04x got %02x expected %02x",16'h1009,accepted_op,opcode);
            $fatal(1);
        end
        endpc=endpoint(opcode,bytes);
        mem.mem[endpc]=8'hea;
        accepted(endpc,3000,last,end_op);
        if(end_op!==8'hea) begin
            $display("ENDPOINT marker mismatch op=%02x pc=%04x got=%02x expected=ea",opcode,endpc,end_op);
            mismatches=mismatches+1;
        end
        delta=last-first;
        actual=delta/CEN_PER_PHI2;
        if(delta%CEN_PER_PHI2!=0) begin
            $display("TIMING mismatch op=%02x: partial PHI2 raw CEN delta=%0d",opcode,delta);
            record_known_finding({24'h0,opcode},delta,actual,expected);
        end
        $display("BASE row op=%02x rawCEN=%0d actualPHI2=%0d expectedRockwell=%0d",opcode,delta,actual,expected);
        if(actual!=expected) begin
            $display("TIMING mismatch op=%02x interval=%04x->%04x raw=%0d actual=%0d Rockwell=%0d",
                     opcode,16'h1009,endpc,delta,actual,expected);
            record_known_finding({24'h0,opcode},delta,actual,expected);
        end
        // The selected store/RMW groups must expose at least one CPU write on
        // the public bus; address/data details are checked in directed cases.
        if(opcode==8'h85 || opcode==8'h06 || opcode==8'h07 || opcode==8'h87) begin
            if(bus_writes==basewrites || last_write_addr!==16'h0040) begin
                $display("BUS mismatch op=%02x writes=%0d last=%04x:%02x",opcode,bus_writes-basewrites,last_write_addr,last_write_data);
                mismatches=mismatches+1;
            end
            if((opcode==8'h85 && (last_write_data!==8'h55 || mem.mem[16'h0040]!==8'h55)) ||
               (opcode==8'h06 && (last_write_data!==8'h00 || mem.mem[16'h0040]!==8'h00)) ||
               (opcode==8'h07 && (last_write_data!==8'h00 || mem.mem[16'h0040]!==8'h00)) ||
               (opcode==8'h87 && (last_write_data!==8'h01 || mem.mem[16'h0040]!==8'h01))) begin
                $display("BUS data mismatch op=%02x last=%02x memory=%02x",opcode,last_write_data,mem.mem[16'h0040]);
                mismatches=mismatches+1;
            end
        end
        if(opcode==8'h1e && (last_write_addr!==16'h0041 || last_write_data!==8'h40 || mem.mem[16'h0041]!==8'h40)) begin
            $display("ABSX RMW public write mismatch %04x:%02x memory=%02x",last_write_addr,last_write_data,mem.mem[16'h2001]);
            mismatches=mismatches+1;
        end
        if(opcode==8'h00) begin
            $display("BRK stack capture PCH/PCL/P=%02x/%02x/%02x",mem.mem[16'h01fd],mem.mem[16'h01fc],mem.mem[16'h01fb]);
            if(mem.mem[16'h01fd]!==8'h10 || mem.mem[16'h01fc]!==8'h0b || mem.mem[16'h01fb][4]!==1'b1) begin
                $display("BRK stack mismatch expected PC=100b and B=1");
                mismatches=mismatches+1;
            end
        end
        if(opcode==8'h20 && (mem.mem[16'h01fd]!==8'h10 || mem.mem[16'h01fc]!==8'h0b)) begin
            $display("JSR stack mismatch expected return address 100b got %02x%02x",mem.mem[16'h01fd],mem.mem[16'h01fc]);
            mismatches=mismatches+1;
        end
        case(opcode)
            8'h0a: if(uut.u_regs.a!==8'haa) begin $display("ASL A result=%02x expected=aa",uut.u_regs.a); mismatches=mismatches+1; end
            8'h4a: if(uut.u_regs.a!==8'h2a) begin $display("LSR A result=%02x expected=2a",uut.u_regs.a); mismatches=mismatches+1; end
            8'h2a: if(uut.u_regs.a!==8'haa) begin $display("ROL A result=%02x expected=aa",uut.u_regs.a); mismatches=mismatches+1; end
            8'h6a: if(uut.u_regs.a!==8'h2a) begin $display("ROR A result=%02x expected=2a",uut.u_regs.a); mismatches=mismatches+1; end
            8'h3a: if(uut.u_regs.a!==8'h54) begin $display("DEC A result=%02x expected=54",uut.u_regs.a); mismatches=mismatches+1; end
            8'h1a: if(uut.u_regs.a!==8'h56) begin $display("INC A result=%02x expected=56",uut.u_regs.a); mismatches=mismatches+1; end
            8'h48: if(mem.mem[16'h01fd]!==8'h55) begin $display("PHA stack data=%02x expected=55",mem.mem[16'h01fd]); mismatches=mismatches+1; end
            8'hda: if(mem.mem[16'h01fd]!==8'h01) begin $display("PHX stack data=%02x expected=01",mem.mem[16'h01fd]); mismatches=mismatches+1; end
            8'h5a: if(mem.mem[16'h01fd]!==8'h01) begin $display("PHY stack data=%02x expected=01",mem.mem[16'h01fd]); mismatches=mismatches+1; end
            8'h08: if((mem.mem[16'h01fd]&8'hef)!==8'h24) begin $display("PHP stack real flags=%02x expected=24; B=%0b is observed separately",mem.mem[16'h01fd]&8'hef,mem.mem[16'h01fd][4]); mismatches=mismatches+1; end
            8'h68: if(uut.u_regs.a!==8'hff) begin $display("PLA result=%02x expected=ff",uut.u_regs.a); mismatches=mismatches+1; end
            8'hfa: if(uut.u_regs.x!==8'hff) begin $display("PLX result=%02x expected=ff",uut.u_regs.x); mismatches=mismatches+1; end
            8'h7a: if(uut.u_regs.y!==8'hff) begin $display("PLY result=%02x expected=ff",uut.u_regs.y); mismatches=mismatches+1; end
            default:;
        endcase
        cases=cases+1;
        if((index%25)==24) $display("65C02 progress: %0d/210 opcode encodings",cases);
    end
endtask

task run_reserved_nop(input [7:0] opcode);
    integer k,first,marker,basewrites;
    reg [7:0] gotop,saved_a,saved_x,saved_y,saved_s;
    reg [5:0] saved_flags;
    begin
        mem.mem[16'h1000]=8'ha9; mem.mem[16'h1001]=8'ha5; // A
        mem.mem[16'h1002]=8'ha2; mem.mem[16'h1003]=8'h34; // X
        mem.mem[16'h1004]=8'ha0; mem.mem[16'h1005]=8'h42; // Y
        mem.mem[16'h1006]=8'hf8; // D
        mem.mem[16'h1007]=8'h38; // C
        mem.mem[16'h1008]=8'hb8; // V=0
        mem.mem[16'h1009]=opcode;
        for(k=16'h100a;k<=16'h1020;k=k+1) mem.mem[k]=8'hea;
        mem.mem[16'h0042]=8'h96;
        mem.mem[16'hfffc]=8'h00; mem.mem[16'hfffd]=8'h10;
        irq=0; nmi=0; cen_hold=0; basewrites=bus_writes;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1009,2000,first,gotop);
        if(gotop!==opcode) begin
            $display("reserved opcode decode mismatch got=%02x expected=%02x",gotop,opcode);
            mismatches=mismatches+1;
        end
        saved_a=uut.u_regs.a; saved_x=uut.u_regs.x;
        saved_y=uut.u_regs.y; saved_s=uut.u_regs.s;
        saved_flags={uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c};
        accepted(16'h1020,3000,marker,gotop);
        if(gotop!==8'hea || uut.u_regs.a!==saved_a || uut.u_regs.x!==saved_x ||
           uut.u_regs.y!==saved_y || uut.u_regs.s!==saved_s ||
           {uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c}!==saved_flags ||
           bus_writes!=basewrites || mem.mem[16'h0042]!==8'h96) begin
            $display("reserved opcode %02x changed state or failed to continue: A/X/Y/S=%02x/%02x/%02x/%02x -> %02x/%02x/%02x/%02x P=%b -> %b writes=%0d",
                     opcode,saved_a,saved_x,saved_y,saved_s,uut.u_regs.a,uut.u_regs.x,uut.u_regs.y,uut.u_regs.s,
                     saved_flags,{uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c},bus_writes-basewrites);
            mismatches=mismatches+1;
        end
        reserved_cases=reserved_cases+1;
    end
endtask

task run_branch_variant(input [7:0] opcode, input integer take, input integer direction);
    integer base, startpc, endpc, targetpc, fallthrough, first,last,delta,actual;
    integer cycles, bitnum;
    reg bitbranch, bbs;
    reg [7:0] pvalue, gotop;
    reg [3:0] observed_flags;
    begin
        bitbranch=(opcode[3:0]==4'hf);
        bbs=opcode[7];
        bitnum=opcode[6:4] & 7;
        case(direction)
            1: begin
                startpc=bitbranch?16'h10fc:16'h10fd;
                base=startpc-9;
                targetpc=16'h1100; fallthrough=startpc+(bitbranch?3:2);
            end
            2: begin
                startpc=16'h1100; base=startpc-9;
                targetpc=16'h10fe; fallthrough=startpc+(bitbranch?3:2);
            end
            3: begin
                // Negative displacement with target still on the same page.
                // Keep the setup sequence below targetpc so the branch can
                // revisit its marker without overwriting its own preamble.
                startpc=16'h1018; base=startpc-12;
                targetpc=startpc-2; fallthrough=startpc+(bitbranch?3:2);
            end
            default: begin
                startpc=16'h1009; base=16'h1000;
                targetpc=startpc+(bitbranch?4:3);
                fallthrough=startpc+(bitbranch?3:2);
            end
        endcase
        endpc=take?targetpc:fallthrough;
        // Set only the flag under test with an authentic PLP before the branch.
        pvalue=8'h24;
        case(opcode)
            8'h90: pvalue[0]=!take; // BCC
            8'hb0: pvalue[0]=take;  // BCS
            8'hd0: pvalue[1]=!take; // BNE
            8'hf0: pvalue[1]=take;  // BEQ
            8'h10: pvalue[7]=!take; // BPL
            8'h30: pvalue[7]=take;  // BMI
            8'h50: pvalue[6]=!take; // BVC
            8'h70: pvalue[6]=take;  // BVS
            default:;
        endcase
        mem.mem[base+0]=8'ha2; mem.mem[base+1]=8'h01;
        mem.mem[base+2]=8'ha0; mem.mem[base+3]=8'h01;
        mem.mem[base+4]=8'ha9; mem.mem[base+5]=8'h55;
        mem.mem[base+6]=8'h18;
        mem.mem[base+7]=8'hd8;
        mem.mem[base+8]=8'h28; // PLP replaces CLV for controlled flags
        mem.mem[startpc]=opcode;
        mem.mem[startpc+1]=0;
        mem.mem[startpc+2]=0;
        if(bitbranch) begin
            mem.mem[startpc+1]=8'h40;
            if(take) mem.mem[16'h0040]=bbs?(1<<bitnum):0;
            else mem.mem[16'h0040]=bbs?0:(1<<bitnum);
        end
        if(direction==0) mem.mem[startpc+(bitbranch?2:1)]=8'h01;
        if(direction==1) mem.mem[startpc+(bitbranch?2:1)]=8'h01;
        if(direction==2) mem.mem[startpc+(bitbranch?2:1)]=bitbranch?8'hfb:8'hfc;
        if(direction==3) mem.mem[startpc+(bitbranch?2:1)]=bitbranch?8'hfb:8'hfc;
        mem.mem[targetpc]=8'hea;
        mem.mem[fallthrough]=8'ha9;
        mem.mem[16'h01fe]=pvalue;
        mem.mem[16'hfffc]=base[7:0]; mem.mem[16'hfffd]=base[15:8];
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(startpc,2000,first,gotop);
        observed_flags={uut.u_regs.c,uut.u_regs.z,uut.u_regs.n,uut.u_regs.v};
        if(gotop!==opcode) begin
            $display("FAIL: branch opcode boundary got %02x expected %02x",gotop,opcode);
            $fatal(1);
        end
        trace_branch=(opcode==8'h90 && ((take && direction==1) || (!take && direction==0)));
        accepted(endpc,3000,last,gotop);
        trace_branch=0;
        if(gotop!==(take?8'hea:8'ha9)) begin
            $display("BRANCH destination marker op=%02x taken=%0d path=%0d gotop=%02x expected=%02x target=%04x fallthrough=%04x",
                     opcode,take,direction,gotop,take?8'hea:8'ha9,targetpc,fallthrough);
            mismatches=mismatches+1;
        end
        delta=last-first;
        if(bitbranch) cycles=take?((direction==0 || direction==3)?6:7):5;
        else cycles=take?((direction==0 || direction==3)?3:4):2;
        actual=delta/CEN_PER_PHI2;
        if(delta%CEN_PER_PHI2!=0 || actual!=cycles) begin
            $display("BRANCH timing op=%02x take=%0d direction=%0d raw=%0d actual=%0d expected=%0d",
                     opcode,take,direction,delta,actual,cycles);
            if(opcode==8'h90) $display("BRANCH state acceptedFlags C/Z/N/V=%b start=%04x end=%04x",observed_flags,startpc,endpc);
            record_known_finding(32'h10000000 | (opcode<<8) | (take<<4) | direction,delta,actual,cycles);
        end
        $display("BRANCH row op=%02x taken=%0d path=%0d rawCEN=%0d actualPHI2=%0d expectedRockwell=%0d target=%04x flags=%b",opcode,take,direction,delta,actual,cycles,endpc,observed_flags);
        cases=cases+1;
    end
endtask

task run_decimal_case(input [7:0] opcode, input [7:0] binary_cycles,
                      input [3:0] bytes);
    integer start_count,end_count,delta,expected_cycles,actual;
    reg [7:0] expected_a,accepted_op;
    reg is_sbc,is_imm;
    reg [7:0] operand;
    begin
        is_sbc=opcode[7];
        is_imm=(opcode[4:0]==5'h09);
        // Select values with simple, independently checkable BCD outcomes.
        // Direct zp and zero-page indexed use $50; indirect forms point to
        // $2000/$2001; absolute-indexed forms stay within the page.
        if(opcode[4:0]==5'h01) operand=8'h3f;       // (zp,X), X=1 -> $40
        else if(opcode[4:0]==5'h05) operand=8'h50;  // zp
        else if(opcode[4:0]==5'h15) operand=8'h4f;  // zp,X -> $50
        else if(opcode[4:0]==5'h11 || opcode[4:0]==5'h12) operand=8'h40;
        else if(is_imm) operand=8'h40;
        else if(opcode[4:0]==5'h19 || opcode[4:0]==5'h1d) operand=8'h20;
        else operand=8'h20;

        mem.mem[16'h1000]=8'ha2; mem.mem[16'h1001]=8'h01;
        mem.mem[16'h1002]=8'ha0; mem.mem[16'h1003]=8'h01;
        mem.mem[16'h1004]=8'ha9; mem.mem[16'h1005]=8'h55;
        mem.mem[16'h1006]=is_sbc?8'h38:8'h18; // SEC for SBC, CLC for ADC
        mem.mem[16'h1007]=8'hf8;               // SED
        mem.mem[16'h1008]=8'hb8;               // CLV
        mem.mem[16'h1009]=opcode;
        mem.mem[16'h100a]=operand;
        mem.mem[16'h100b]=8'h20;
        mem.mem[16'h1009+bytes]=8'hea;
        mem.mem[16'h0040]=8'h00; mem.mem[16'h0041]=8'h20; // pointer=$2000
        mem.mem[16'h0050]=8'h55;
        mem.mem[16'h2000]=8'h55; mem.mem[16'h2001]=8'h55;
        mem.mem[16'h2020]=8'h55; mem.mem[16'h2021]=8'h55;
        mem.mem[16'h0020]=8'h99; mem.mem[16'h0021]=8'h66; // poison wrong-page targets
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1009,2000,start_count,accepted_op);
        if(accepted_op!==opcode) begin $display("decimal opcode boundary %02x != %02x",accepted_op,opcode); $fatal(1); end
        accepted(16'h1009+bytes,3000,end_count,accepted_op);
        if(accepted_op!==8'hea) begin
            $display("decimal endpoint marker got=%02x expected=ea",accepted_op);
            mismatches=mismatches+1;
        end
        delta=end_count-start_count;
        expected_cycles=binary_cycles+1;
        actual=delta/CEN_PER_PHI2;
        if(delta%CEN_PER_PHI2!=0 || actual!=expected_cycles) begin
            $display("DECIMAL timing op=%02x raw=%0d actual=%0d Rockwell=%0d",opcode,delta,actual,expected_cycles);
            record_known_finding(32'h20000000 | opcode,delta,actual,expected_cycles);
        end
        $display("DECIMAL row op=%02x rawCEN=%0d actualPHI2=%0d expectedRockwell=%0d A=%02x C/V/N/Z=%b%b%b%b",opcode,delta,actual,expected_cycles,uut.u_regs.a,uut.u_regs.c,uut.u_regs.v,uut.u_regs.n,uut.u_regs.z);
        if(is_sbc) expected_a=is_imm?8'h15:8'h00;
        else expected_a=is_imm?8'h95:8'h10;
        #1;
        if(uut.u_regs.a!==expected_a || uut.u_regs.d!==1'b1) begin
            $display("DECIMAL result op=%02x A=%02x D=%b expected A=%02x D=1",opcode,uut.u_regs.a,uut.u_regs.d,expected_a);
            mismatches=mismatches+1;
        end
        if(is_sbc) begin
            if(uut.u_regs.c!==1'b1 || uut.u_regs.v!==1'b0 || uut.u_regs.n!==1'b0 || uut.u_regs.z!==(is_imm?1'b0:1'b1)) begin
                $display("DECIMAL SBC flags op=%02x C/V/N/Z=%b%b%b%b",opcode,uut.u_regs.c,uut.u_regs.v,uut.u_regs.n,uut.u_regs.z);
                mismatches=mismatches+1;
            end
        end else begin
            if(uut.u_regs.c!==(is_imm?1'b0:1'b1) || uut.u_regs.v!==1'b1 || uut.u_regs.n!==(is_imm?1'b1:1'b0) || uut.u_regs.z!==1'b0) begin
                $display("DECIMAL ADC flags op=%02x C/V/N/Z=%b%b%b%b",opcode,uut.u_regs.c,uut.u_regs.v,uut.u_regs.n,uut.u_regs.z);
                mismatches=mismatches+1;
            end
        end
        cases=cases+1;
    end
endtask

task run_decimal_boundary(input [7:0] opcode, input [7:0] initial_a,
                          input [7:0] operand, input carry_in,
                          input [7:0] expected_a, input [3:0] expected_mask,
                          input [3:0] expected_cvnz);
    integer first,last,delta,actual;
    reg [7:0] gotop;
    begin
        mem.mem[16'h1000]=8'ha9; mem.mem[16'h1001]=initial_a;
        mem.mem[16'h1002]=carry_in?8'h38:8'h18;
        mem.mem[16'h1003]=8'hf8;
        mem.mem[16'h1004]=opcode; mem.mem[16'h1005]=operand; mem.mem[16'h1006]=8'hea;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1004,2000,first,gotop);
        if(gotop!==opcode) begin $display("decimal boundary opcode got=%02x expected=%02x",gotop,opcode); mismatches=mismatches+1; end
        accepted(16'h1006,3000,last,gotop);
        delta=last-first; actual=delta/CEN_PER_PHI2;
        if(delta%CEN_PER_PHI2!=0 || actual!=3) begin
            $display("DECIMAL boundary timing op=%02x raw=%0d actual=%0d expected=3",opcode,delta,actual);
            record_known_finding(32'h30000000 | (opcode<<8) | cases[7:0],delta,actual,3);
        end
        #1;
        if(gotop!==8'hea || uut.u_regs.a!==expected_a || uut.u_regs.d!==1'b1 ||
           ((({uut.u_regs.c,uut.u_regs.v,uut.u_regs.n,uut.u_regs.z} ^ expected_cvnz)&expected_mask)!=0)) begin
            $display("DECIMAL boundary semantic op=%02x next=%02x A=%02x D=%b C/V/N/Z=%b%b%b%b expectedA=%02x expectedMask=%b expectedCVNZ=%b",
                opcode,gotop,uut.u_regs.a,uut.u_regs.d,uut.u_regs.c,uut.u_regs.v,uut.u_regs.n,uut.u_regs.z,expected_a,expected_mask,expected_cvnz);
            mismatches=mismatches+1;
        end
        cases=cases+1;
    end
endtask

function [7:0] manual_cycles(input [7:0] opcode);
    integer n;
    begin
        manual_cycles=0;
        for(n=0;n<210;n=n+1)
            if(manifest[n][23:16]==opcode) manual_cycles=manifest[n][15:8];
    end
endfunction

task run_jmp_indirect_ff;
    integer first,last,delta,actual,expected,basewrites;
    reg [7:0] gotop;
    begin
        mem.mem[16'h1000]=8'h6c; mem.mem[16'h1001]=8'hff; mem.mem[16'h1002]=8'h12;
        mem.mem[16'h2000]=8'hea;
        mem.mem[16'h12ff]=8'h00; mem.mem[16'h1300]=8'h20;
        mem.mem[16'hfffc]=8'h00; mem.mem[16'hfffd]=8'h10;
        irq=0; nmi=0; basewrites=bus_writes;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,first,gotop);
        if(gotop!==8'h6c) begin $display("JMP ($xxFF) opcode boundary=%02x",gotop); mismatches=mismatches+1; end
        accepted(16'h2000,3000,last,gotop);
        delta=last-first; actual=delta/CEN_PER_PHI2;
        expected=manual_cycles(8'h6c)+1; // Rockwell Table 4: XXFF adds one cycle
        if(gotop!==8'hea || delta%CEN_PER_PHI2!=0 || actual!=expected ||
           bus_writes!=basewrites || mem.mem[16'h12ff]!==8'h00 || mem.mem[16'h1300]!==8'h20) begin
            $display("Rockwell JMP ($xxFF) mismatch target/op=%04x/%02x raw=%0d actual=%0d expected=%0d",
                     addr,gotop,delta,actual,expected);
            record_known_finding(32'h6000006c,delta,actual,expected);
            if(gotop!==8'hea || bus_writes!=basewrites || mem.mem[16'h12ff]!==8'h00 || mem.mem[16'h1300]!==8'h20)
                mismatches=mismatches+1;
        end
        $display("JMP ($xxFF) path rawCEN=%0d PHI2=%0d expectedRockwell=%0d target=%04x",delta,actual,expected,addr);
        cases=cases+1;
    end
endtask

function timing_match(input integer raw_ticks, input integer expected_cycles);
    begin
        timing_match=(raw_ticks%CEN_PER_PHI2==0) &&
                     (raw_ticks/CEN_PER_PHI2==expected_cycles);
    end
endfunction
function byte_match(input [7:0] expected, input [7:0] observed);
    begin byte_match=(expected===observed); end
endfunction
function address_match(input [15:0] expected, input [15:0] observed);
    begin address_match=(expected===observed); end
endfunction

task run_indexed_cross(input [7:0] opcode, input integer mode,
                       input [3:0] bytes);
    integer first,last,delta,actual,expected,basewrites;
    reg [7:0] accepted_op;
    reg is_store,is_rmw;
    reg [7:0] rmw_result, store_result;
    begin
        is_store=(opcode==8'h9d || opcode==8'h99 || opcode==8'h9e || opcode==8'h91);
        is_rmw=(opcode==8'h1e || opcode==8'h3e || opcode==8'h5e || opcode==8'h7e || opcode==8'hde || opcode==8'hfe);
        store_result=(opcode==8'h9e) ? 8'h00 : 8'h55;
        case(opcode)
            8'h1e,8'h3e: rmw_result=8'haa;
            8'h5e,8'h7e: rmw_result=8'h2a;
            8'hde: rmw_result=8'h54;
            8'hfe: rmw_result=8'h56;
            default: rmw_result=0;
        endcase
        mem.mem[16'h1000]=8'ha2; mem.mem[16'h1001]=8'h01;
        mem.mem[16'h1002]=8'ha0; mem.mem[16'h1003]=8'h01;
        mem.mem[16'h1004]=8'ha9; mem.mem[16'h1005]=8'h55;
        mem.mem[16'h1006]=8'h18; mem.mem[16'h1007]=8'hd8; mem.mem[16'h1008]=8'hb8;
        mem.mem[16'h1009]=opcode;
        if(mode==2) begin
            mem.mem[16'h100a]=8'h40;
            mem.mem[16'h0040]=8'hff; mem.mem[16'h0041]=8'h20;
        end else begin
            mem.mem[16'h100a]=8'hff; mem.mem[16'h100b]=8'h20;
        end
        mem.mem[16'h2100]=8'h55;
        basewrites=bus_writes;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1009,2000,first,accepted_op);
        if(accepted_op!==opcode) begin $display("indexed opcode boundary mismatch %02x",opcode); $fatal(1); end
        accepted(16'h1009+bytes,3000,last,accepted_op);
        delta=last-first; actual=delta/CEN_PER_PHI2;
        // Rockwell marks indexed reads with a crossing footnote. Stores and
        // fixed-length read/modify/write instructions do not add a cycle here.
        expected=manual_cycles(opcode)+((!is_store && !is_rmw)?1:0);
        if(delta%CEN_PER_PHI2!=0 || actual!=expected) begin
            $display("INDEX CROSS op=%02x mode=%0d raw=%0d actual=%0d Rockwell=%0d",opcode,mode,delta,actual,expected);
            record_known_finding(32'h40000000 | (opcode<<8) | mode,delta,actual,expected);
        end
        $display("INDEX row op=%02x mode=%0d cross=1 rawCEN=%0d actualPHI2=%0d expectedRockwell=%0d",opcode,mode,delta,actual,expected);
        #1;
        if(is_store) begin
            if(bus_writes==basewrites || last_write_addr!==16'h2100 ||
               last_write_data!==store_result || mem.mem[16'h2100]!==last_write_data) begin
                $display("INDEXED STORE bus op=%02x writes=%0d last=%04x:%02x mem=%02x",opcode,bus_writes-basewrites,last_write_addr,last_write_data,mem.mem[16'h2100]);
                mismatches=mismatches+1;
            end
        end
        if(is_rmw && (watched_reads!=2 || watched_writes!=1 ||
           last_write_addr!==16'h2100 || last_write_data!==rmw_result || mem.mem[16'h2100]!==rmw_result)) begin
            $display("INDEXED RMW bus op=%02x reads=%0d writes=%0d last=%04x:%02x mem=%02x",
                     opcode,watched_reads,watched_writes,last_write_addr,last_write_data,mem.mem[16'h2100]);
            mismatches=mismatches+1;
        end
        cases=cases+1;
    end
endtask

task run_irq_service;
    integer cli_count,nop_count,handler_count,return_count,delta,actual;
    reg [7:0] gotop;
    begin
        mem.mem[16'h1000]=8'h58; // CLI
        mem.mem[16'h1001]=8'hea; // NOP whose acceptance is intercepted by IRQ
        mem.mem[16'h1002]=8'hea; // RTI return target
        mem.mem[16'h2000]=8'h40; // RTI handler
        mem.mem[16'hfffe]=8'h00; mem.mem[16'hffff]=8'h20;
        mem.mem[16'h01fd]=0; mem.mem[16'h01fc]=0; mem.mem[16'h01fb]=0;
        irq=0; nmi=0;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,cli_count,gotop);
        if(gotop!==8'h58) begin $display("IRQ setup did not accept CLI"); mismatches=mismatches+1; end
        #1; irq=1;
        accepted(16'h1001,2000,nop_count,gotop);
        if(gotop!==8'hea) begin $display("IRQ setup did not accept NOP boundary"); mismatches=mismatches+1; end
        accepted(16'h2000,3000,handler_count,gotop);
        if(gotop!==8'h40) begin $display("IRQ vector target opcode=%02x expected RTI",gotop); mismatches=mismatches+1; end
        delta=handler_count-nop_count;
        actual=delta/CEN_PER_PHI2;
        // The interval begins when the interrupted NOP is accepted, so it
        // includes that 2-cycle instruction plus the 7-cycle service path.
        if(delta%CEN_PER_PHI2!=0 || actual!=9) begin
            $display("IRQ accepted-boundary to vector raw=%0d actual=%0d expected=2+7",delta,actual);
            mismatches=mismatches+1;
        end
        #1;
        if(mem.mem[16'h01fd]!==8'h10 || mem.mem[16'h01fc]!==8'h02) begin
            $display("IRQ stacked PC expected 1002 got %02x%02x",mem.mem[16'h01fd],mem.mem[16'h01fc]);
            mismatches=mismatches+1;
        end
        $display("Rockwell hardware IRQ stacked P=%02x (B=0, D=0 expected)",mem.mem[16'h01fb]);
        if(mem.mem[16'h01fb][4]!==1'b0) begin
            $display("IRQ status mismatch: hardware IRQ B must be 0; observed P=%02x",mem.mem[16'h01fb]);
            mismatches=mismatches+1;
        end
        if(mem.mem[16'h01fb][3]!==1'b0 || uut.u_regs.d!==1'b0 || uut.u_regs.i!==1'b1) begin
            $display("IRQ D/I mismatch: stacked D=%b handler D/I=%b/%b expected 0 and 0/1",
                     mem.mem[16'h01fb][3],uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        accepted(16'h1002,3000,return_count,gotop);
        if(gotop!==8'hea) begin $display("RTI did not return to 1002, opcode=%02x",gotop); mismatches=mismatches+1; end
        irq=0;
        cases=cases+1;
    end
endtask

task run_masked_irq;
    integer first,second,third,basewrites;
    reg [7:0] gotop;
    begin
        mem.mem[16'h1000]=8'hea; mem.mem[16'h1001]=8'hea; mem.mem[16'h1002]=8'hea;
        mem.mem[16'h2000]=8'h40;
        mem.mem[16'hfffe]=8'h00; mem.mem[16'hffff]=8'h20;
        irq=1; nmi=0; basewrites=bus_writes;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        #1;
        if(uut.u_regs.i!==1'b1 || uut.u_regs.d!==1'b0) begin
            $display("reset status I/D expected 1/0 got %b/%b",uut.u_regs.i,uut.u_regs.d);
            mismatches=mismatches+1;
        end
        accepted(16'h1000,2000,first,gotop);
        accepted(16'h1001,2000,second,gotop);
        accepted(16'h1002,2000,third,gotop);
        if(gotop!==8'hea || bus_writes!=basewrites) begin
            $display("IRQ was not masked by reset I flag, final opcode=%02x new writes=%0d",gotop,bus_writes-basewrites);
            mismatches=mismatches+1;
        end
        irq=0;
        cases=cases+1;
    end
endtask

task run_cen_pause;
    integer first,last,old_count,old_writes,k;
    reg [15:0] saved_pc;
    reg [11:0] saved_uaddr;
    reg [15:0] saved_addr;
    reg [7:0] saved_dout;
    reg saved_wr,saved_rd,saved_fetch;
    reg [7:0] gotop;
    begin
        mem.mem[16'h1000]=8'ha9; mem.mem[16'h1001]=8'h55;
        mem.mem[16'h1002]=8'h85; mem.mem[16'h1003]=8'h40; mem.mem[16'h1004]=8'hea;
        mem.mem[16'h0040]=0;
        cen_hold=0; irq=0; nmi=0;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,first,gotop);
        if(gotop!==8'ha9) begin $display("CEN write setup did not accept LDA"); mismatches=mismatches+1; end
        accepted(16'h1002,2000,last,gotop);
        if(gotop!==8'h85) begin $display("CEN write setup did not accept STA"); mismatches=mismatches+1; end
        k=0;
        @(negedge clk);
        while(!(wr && addr==16'h0040) && k<100) begin @(negedge clk); k=k+1; end
        if(!(wr && addr==16'h0040)) begin
            $display("CEN write phase did not reach public $0040 transaction"); mismatches=mismatches+1;
        end
        cen_hold=1;
        saved_pc=uut.u_regs.pc; saved_uaddr=uut.u_ctrl.uaddr; old_count=cen_count;
        old_writes=bus_writes; saved_addr=addr; saved_dout=dout;
        saved_wr=wr; saved_rd=rd; saved_fetch=fetch;
        cen_hold=1;
        repeat(12) @(posedge clk);
        #1;
        if(uut.u_regs.pc!==saved_pc || uut.u_ctrl.uaddr!==saved_uaddr || cen_count!=old_count ||
           addr!==saved_addr || dout!==saved_dout || wr!==saved_wr || rd!==saved_rd || fetch!==saved_fetch ||
           bus_writes!=old_writes || mem.mem[16'h0040]!==8'h00) begin
            $display("CEN pause moved state/bus PC=%04x/%04x uaddr=%03x/%03x addr=%04x/%04x data=%02x/%02x wr=%b/%b writes=%0d/%0d mem=%02x",
                uut.u_regs.pc,saved_pc,uut.u_ctrl.uaddr,saved_uaddr,addr,saved_addr,dout,saved_dout,wr,saved_wr,bus_writes,old_writes,mem.mem[16'h0040]);
            mismatches=mismatches+1;
        end
        cen_hold=0;
        accepted(16'h1004,2000,last,gotop);
        if(gotop!==8'hea || bus_writes!=old_writes+1 || mem.mem[16'h0040]!==8'h55 ||
           last_write_addr!==16'h0040 || last_write_data!==8'h55) begin
            $display("CEN release did not commit exactly one STA, opcode=%02x writes=%0d memory=%02x last=%04x:%02x",
                gotop,bus_writes-old_writes,mem.mem[16'h0040],last_write_addr,last_write_data);
            mismatches=mismatches+1;
        end
        cases=cases+1;
    end
endtask

task run_nmi_priority;
    integer cli_count,nop_count,handler_count,return_count,delta,actual;
    reg [7:0] gotop;
    begin
        mem.mem[16'h1000]=8'h58; mem.mem[16'h1001]=8'hea; mem.mem[16'h1002]=8'hea;
        mem.mem[16'h2100]=8'h40;
        mem.mem[16'hfffa]=8'h00; mem.mem[16'hfffb]=8'h21;
        mem.mem[16'hfffe]=8'h00; mem.mem[16'hffff]=8'h20;
        mem.mem[16'h01fd]=0; mem.mem[16'h01fc]=0; mem.mem[16'h01fb]=0;
        irq=0; nmi=0;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,cli_count,gotop);
        if(gotop!==8'h58) begin $display("NMI setup did not accept CLI"); mismatches=mismatches+1; end
        #1; irq=1; nmi=1;
        repeat(2) @(negedge clk);
        nmi=0;
        accepted(16'h1001,2000,nop_count,gotop);
        if(gotop!==8'hea) begin $display("NMI setup did not accept NOP boundary"); mismatches=mismatches+1; end
        accepted(16'h2100,3000,handler_count,gotop);
        if(gotop!==8'h40) begin $display("NMI priority/vector target opcode=%02x expected RTI",gotop); mismatches=mismatches+1; end
        delta=handler_count-nop_count;
        actual=delta/CEN_PER_PHI2;
        if(delta%CEN_PER_PHI2!=0 || actual!=7) begin
            $display("NMI accepted-boundary to vector raw=%0d actual=%0d Rockwell service=7",delta,actual);
            mismatches=mismatches+1;
        end
        if(mem.mem[16'h01fd]!==8'h10 || mem.mem[16'h01fc]!==8'h01) begin
            $display("NMI stacked PC expected 1001 got %02x%02x",mem.mem[16'h01fd],mem.mem[16'h01fc]);
            mismatches=mismatches+1;
        end
        if(mem.mem[16'h01fb][4]!==1'b0 || mem.mem[16'h01fb][3]!==1'b0) begin
            $display("NMI status mismatch: hardware NMI must save B=0,D=0; P=%02x",mem.mem[16'h01fb]);
            mismatches=mismatches+1;
        end
        $display("NMI status P=%02x: B=0,D=0 before interrupt",mem.mem[16'h01fb]);
        irq=0; nmi=0;
        accepted(16'h1002,3000,return_count,gotop);
        if(gotop!==8'hea || uut.u_regs.d!==1'b0 || uut.u_regs.i!==1'b0) begin
            $display("NMI RTI did not restore D/I/PC at 1002, opcode=%02x D/I=%b/%b",gotop,uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end

        // Repeat with D=1 before NMI. The stack must retain that pre-interrupt
        // status even though the handler starts with decimal mode cleared.
        mem.mem[16'h1000]=8'hf8; // SED while I is still set
        mem.mem[16'h1001]=8'h58; // CLI
        mem.mem[16'h1002]=8'hea; // interrupted NOP, resume at $1003
        mem.mem[16'h1003]=8'hea;
        mem.mem[16'h2100]=8'h40;
        irq=0; nmi=0;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,cli_count,gotop);
        if(gotop!==8'hf8 || uut.u_regs.d!==1'b0) begin
            $display("NMI D=1 setup SED boundary/state op=%02x D=%b",gotop,uut.u_regs.d);
            mismatches=mismatches+1;
        end
        accepted(16'h1001,2000,cli_count,gotop);
        if(gotop!==8'h58 || uut.u_regs.i!==1'b1 || uut.u_regs.d!==1'b1) begin
            $display("NMI D=1 setup CLI boundary/state op=%02x D/I=%b/%b",gotop,uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        #1; nmi=1;
        accepted(16'h1002,2000,nop_count,gotop);
        accepted(16'h2100,3000,handler_count,gotop);
        #1;
        if(gotop!==8'h40 || mem.mem[16'h01fb][4]!==1'b0 || mem.mem[16'h01fb][3]!==1'b1 ||
           mem.mem[16'h01fb][2]!==1'b0 || uut.u_regs.d!==1'b0 || uut.u_regs.i!==1'b1) begin
            $display("NMI D=1 status mismatch handler=%02x frameP=%02x handlerD/I=%b/%b expected B/D=0/1 and 0/1",
                     gotop,mem.mem[16'h01fb],uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        $display("NMI D=1 status P=%02x handlerD/I=%b/%b",mem.mem[16'h01fb],uut.u_regs.d,uut.u_regs.i);
        nmi=0;
        accepted(16'h1003,3000,return_count,gotop);
        if(gotop!==8'hea || uut.u_regs.d!==1'b1 || uut.u_regs.i!==1'b0) begin
            $display("NMI RTI failed to restore D=1/I=0/PC=$1003 op=%02x D/I=%b/%b",gotop,uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        cases=cases+1;
    end
endtask

task run_brk_decimal_status;
    integer cli_count,handler_count,return_count;
    reg [7:0] gotop;
    begin
        mem.mem[16'h1000]=8'h58; // CLI: return I must be zero
        mem.mem[16'h1001]=8'hf8; // SED: stack D=1, handler D=0
        mem.mem[16'h1002]=8'h00; mem.mem[16'h1003]=8'hea; // BRK and padding
        mem.mem[16'h1004]=8'hea; // RTI return marker
        mem.mem[16'h2000]=8'h40;
        mem.mem[16'hfffe]=8'h00; mem.mem[16'hffff]=8'h20;
        irq=0; nmi=0;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,cli_count,gotop);
        accepted(16'h1002,2000,cli_count,gotop);
        accepted(16'h2000,3000,handler_count,gotop);
        #1;
        if(gotop!==8'h40 || mem.mem[16'h01fd]!==8'h10 || mem.mem[16'h01fc]!==8'h04 ||
           mem.mem[16'h01fb][4]!==1'b1 || mem.mem[16'h01fb][3]!==1'b1 || mem.mem[16'h01fb][2]!==1'b0 ||
           uut.u_regs.d!==1'b0 || uut.u_regs.i!==1'b1) begin
            $display("BRK status mismatch handler=%02x frame=%02x%02x P=%02x handlerD/I=%b/%b",
                     gotop,mem.mem[16'h01fd],mem.mem[16'h01fc],mem.mem[16'h01fb],uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        $display("BRK status P=%02x: B=1,D=1 pushed; handlerD/I=%b/%b",mem.mem[16'h01fb],uut.u_regs.d,uut.u_regs.i);
        accepted(16'h1004,3000,return_count,gotop);
        if(gotop!==8'hea || uut.u_regs.d!==1'b1 || uut.u_regs.i!==1'b0) begin
            $display("BRK RTI failed to restore D=1/I=0/PC=$1004 op=%02x D/I=%b/%b",gotop,uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        control_cases=control_cases+1;
    end
endtask

task run_irq_all_status_flags;
    integer plp_count,irq_count,handler_count,return_count;
    reg [7:0] gotop,frame_p;
    begin
        mem.mem[16'h1000]=8'h28; // PLP restores N,V,D,I,Z,C from $01FE
        mem.mem[16'h1001]=8'hea; // IRQ is accepted at this boundary
        mem.mem[16'h1002]=8'hea; // RTI return marker
        mem.mem[16'h2000]=8'h40; // RTI handler
        mem.mem[16'hfffe]=8'h00; mem.mem[16'hffff]=8'h20;
        mem.mem[16'h01fe]=8'he9; // N=V=D=C=1, I=Z=0, unused bit 5=1
        irq=0; nmi=0;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,plp_count,gotop);
        #1; irq=1;
        accepted(16'h1001,2000,irq_count,gotop);
        accepted(16'h2000,3000,handler_count,gotop);
        frame_p=mem.mem[16'h01fc];
        if(gotop!==8'h40 || frame_p!==8'he9 ||
           {uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c}!==6'b110101) begin
            $display("IRQ saved-flags mismatch P=%02x handler N/V/D/I/Z/C=%b expected frame E9, handler 110101",
                     frame_p,{uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c});
            mismatches=mismatches+1;
        end
        irq=0;
        accepted(16'h1002,3000,return_count,gotop);
        if(gotop!==8'hea || {uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c}!==6'b111001) begin
            $display("IRQ RTI did not restore every status flag/PC, op=%02x N/V/D/I/Z/C=%b",
                     gotop,{uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c});
            mismatches=mismatches+1;
        end
        $display("IRQ full-status P=%02x -> handler flags 110101 -> RTI flags 111001",frame_p);
        control_cases=control_cases+1;
    end
endtask

task run_php_plp_convention;
    integer start_count,php_count,cld_count,clc_count,plp_count,return_count;
    reg [7:0] gotop,pushed;
    reg [5:0] flags_before;
    begin
        // Establish Z=1,C=1,D=1, then prove PHP preserves all physical flags.
        // B is logged as a family-level observation, not a Rockwell target
        // requirement. CLD/CLC perturb flags before PLP restores them.
        mem.mem[16'h1000]=8'ha9; mem.mem[16'h1001]=8'h00; // LDA #0
        mem.mem[16'h1002]=8'h38;                         // SEC
        mem.mem[16'h1003]=8'hf8;                         // SED
        mem.mem[16'h1004]=8'h08;                         // PHP
        mem.mem[16'h1005]=8'hd8;                         // CLD
        mem.mem[16'h1006]=8'h18;                         // CLC
        mem.mem[16'h1007]=8'h28;                         // PLP
        mem.mem[16'h1008]=8'hea;
        irq=0; nmi=0;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,start_count,gotop);
        accepted(16'h1004,3000,php_count,gotop);
        flags_before={uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,
                      uut.u_regs.i,uut.u_regs.z,uut.u_regs.c};
        accepted(16'h1005,2000,cld_count,gotop);
        pushed=mem.mem[16'h01fd];
        if(gotop!==8'hd8 || (pushed&8'hef)!==8'h2f ||
           {uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c}!==flags_before) begin
            $display("PHP status mismatch opcode=%02x stack=%02x flags=%b expected real stack bits=2f preserved=%b",gotop,pushed,
                     {uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c},flags_before);
            mismatches=mismatches+1;
        end
        accepted(16'h1006,2000,clc_count,gotop);
        accepted(16'h1007,2000,plp_count,gotop);
        accepted(16'h1008,2000,return_count,gotop);
        if(gotop!==8'hea ||
           {uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c}!==6'b001111) begin
            $display("PLP restore mismatch opcode=%02x flags=%b expected N/V/D/I/Z/C=001111",gotop,
                     {uut.u_regs.n,uut.u_regs.v,uut.u_regs.d,uut.u_regs.i,uut.u_regs.z,uut.u_regs.c});
            mismatches=mismatches+1;
        end
        $display("PHP/PLP status P=%02x (B=%0b observed, not normative): PHP preserves flags; PLP restores D/C",pushed,pushed[4]);
        control_cases=control_cases+1;
    end
endtask

task run_sei_decimal_irq;
    integer cli_count,sei_count,nop_mask_count,sed_count,unmask_count;
    integer nop_irq_count,vector_count,handler_lda_end,handler_clc_end;
    integer handler_adc_end,handler_rti,return_count,store_end;
    integer delta,actual,basewrites,post_irq_writes;
    reg [7:0] op,handler_a,frame_p;
    reg handler_d,handler_i,return_d,return_i;
    begin
        // CLI first proves the following SEI masks a live IRQ. Keep the request
        // asserted through SED and CLI so the saved frame records D=1/I=0.
        mem.mem[16'h1000]=8'h58; // CLI
        mem.mem[16'h1001]=8'h78; // SEI
        mem.mem[16'h1002]=8'hea; // masked NOP
        mem.mem[16'h1003]=8'hf8; // SED while masked
        mem.mem[16'h1004]=8'h58; // CLI
        mem.mem[16'h1005]=8'hea; // interrupted NOP, return PC=$1006
        mem.mem[16'h1006]=8'ha9; mem.mem[16'h1007]=8'h55;
        mem.mem[16'h1008]=8'h85; mem.mem[16'h1009]=8'h42;
        mem.mem[16'h100a]=8'hea;
        // Handler starts with D-sensitive arithmetic. WDC says interrupt
        // entry clears D; 09+01 must therefore produce binary 0A, not BCD 10.
        mem.mem[16'h2000]=8'ha9; mem.mem[16'h2001]=8'h09;
        mem.mem[16'h2002]=8'h18;
        mem.mem[16'h2003]=8'h69; mem.mem[16'h2004]=8'h01;
        mem.mem[16'h2005]=8'h40;
        mem.mem[16'hfffe]=8'h00; mem.mem[16'hffff]=8'h20;
        mem.mem[16'h0042]=0;
        mem.mem[16'h01fd]=0; mem.mem[16'h01fc]=0; mem.mem[16'h01fb]=0;
        irq=0; nmi=0; basewrites=bus_writes;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,cli_count,op);
        if(op!==8'h58) begin $display("status IRQ fixture CLI decoded %02x",op); mismatches=mismatches+1; end
        accepted(16'h1001,2000,sei_count,op);
        if(op!==8'h78 || uut.u_regs.i!==1'b0) begin
            $display("CLI/SEI boundary op=%02x I=%b expected SEI with I=0",op,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        #1;
        irq=1;
        accepted(16'h1002,2000,nop_mask_count,op);
        if(op!==8'hea || uut.u_regs.i!==1'b1) begin
            $display("SEI failed to hold pending IRQ through NOP, op=%02x I=%b",op,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        accepted(16'h1003,2000,sed_count,op);
        if(op!==8'hf8 || uut.u_regs.i!==1'b1) begin
            $display("SED did not execute under masked IRQ, op=%02x I/D=%b/%b",op,uut.u_regs.i,uut.u_regs.d);
            mismatches=mismatches+1;
        end
        accepted(16'h1004,2000,unmask_count,op);
        if(op!==8'h58 || uut.u_regs.i!==1'b1 || uut.u_regs.d!==1'b1) begin
            $display("SED/CLI boundary op=%02x I/D=%b/%b expected CLI with D1/I1",op,uut.u_regs.i,uut.u_regs.d);
            mismatches=mismatches+1;
        end
        accepted(16'h1005,2000,nop_irq_count,op);
        if(op!==8'hea || uut.u_regs.i!==1'b0 || uut.u_regs.d!==1'b1) begin
            $display("pending IRQ post-CLI NOP op=%02x I/D=%b/%b expected EA,0/1",op,uut.u_regs.i,uut.u_regs.d);
            mismatches=mismatches+1;
        end
        accepted(16'h2000,3000,vector_count,op);
        if(op!==8'ha9) begin $display("decimal IRQ vector opcode=%02x expected LDA",op); mismatches=mismatches+1; end
        delta=vector_count-nop_irq_count; actual=delta/CEN_PER_PHI2;
        if(delta%CEN_PER_PHI2!=0 || actual!=9) begin
            $display("decimal IRQ accepted-NOP-to-vector raw=%0d actual=%0d expected=2+7",delta,actual);
            mismatches=mismatches+1;
        end
        #1;
        if(mem.mem[16'h01fd]!==8'h10 || mem.mem[16'h01fc]!==8'h06 ||
           mem.mem[16'h01fb][2]!==1'b0) begin
            $display("decimal IRQ stacked PC/P=%02x%02x/%02x expected PC1006/I0",
                     mem.mem[16'h01fd],mem.mem[16'h01fc],mem.mem[16'h01fb]);
            mismatches=mismatches+1;
        end
        if(mem.mem[16'h01fb][3]!==1'b1) begin
            $display("Rockwell IRQ frame must retain pre-interrupt D=1; stacked P=%02x",mem.mem[16'h01fb]);
            mismatches=mismatches+1;
        end
        frame_p=mem.mem[16'h01fb];
        if(uut.u_regs.i!==1'b1) begin $display("IRQ entry did not set I"); mismatches=mismatches+1; end
        if(uut.u_regs.d!==1'b0) begin
            $display("Rockwell IRQ entry must clear D; observed D=1");
            mismatches=mismatches+1;
        end
        handler_d=uut.u_regs.d; handler_i=uut.u_regs.i;
        accepted(16'h2002,2000,handler_lda_end,op);
        if(op!==8'h18 || uut.u_regs.a!==8'h09 || uut.u_regs.d!==1'b0 || uut.u_regs.i!==1'b1) begin
            $display("IRQ handler LDA result/state op=%02x A=%02x D/I=%b/%b expected 18,09,0/1",
                     op,uut.u_regs.a,uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        accepted(16'h2003,2000,handler_clc_end,op);
        if(op!==8'h69) begin $display("IRQ handler CLC boundary decoded %02x",op); mismatches=mismatches+1; end
        accepted(16'h2005,2000,handler_adc_end,op);
        if(op!==8'h40) begin $display("IRQ handler RTI boundary decoded %02x",op); mismatches=mismatches+1; end
        #1;
        if(uut.u_regs.a!==8'h0a || uut.u_regs.d!==1'b0 || uut.u_regs.i!==1'b1) begin
            $display("IRQ handler binary ADC/state A=%02x D/I=%b/%b expected 0a,0/1",
                     uut.u_regs.a,uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        handler_a=uut.u_regs.a;
        irq=0;
        post_irq_writes=bus_writes;
        accepted(16'h1006,3000,return_count,op);
        if(op!==8'ha9 || uut.u_regs.i!==1'b0) begin
            $display("RTI failed to restore D/I or return PC, op=%02x D/I=%b/%b expected A9,1/0",
                     op,uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        if(uut.u_regs.d!==1'b1) begin
            $display("RTI failed to restore saved D=1; resumed state D=%b",uut.u_regs.d);
            mismatches=mismatches+1;
        end
        return_d=uut.u_regs.d; return_i=uut.u_regs.i;
        accepted(16'h1008,3000,store_end,op);
        if(op!==8'h85 || uut.u_regs.a!==8'h55 || uut.u_regs.i!==1'b0) begin
            $display("post-RTI LDA/main state op=%02x A=%02x D/I=%b/%b",op,uut.u_regs.a,uut.u_regs.d,uut.u_regs.i);
            mismatches=mismatches+1;
        end
        accepted(16'h100a,3000,store_end,op);
        if(op!==8'hea || mem.mem[16'h0042]!==8'h55 || bus_writes!=post_irq_writes+1 ||
           last_write_addr!==16'h0042 || last_write_data!==8'h55) begin
            $display("RTI-return store/marker mismatch op=%02x memory=%02x writes=%0d last=%04x:%02x",
                     op,mem.mem[16'h0042],bus_writes-basewrites,last_write_addr,last_write_data);
            mismatches=mismatches+1;
        end
        $display("STATUS control observed frameP=%02x handlerD/I=%b/%b ADC=%02x returnD/I=%b/%b store=%04x:%02x",
                 frame_p,handler_d,handler_i,handler_a,return_d,return_i,last_write_addr,last_write_data);
        control_cases=control_cases+1;
    end
endtask

task run_bit_flags;
    integer lda_end,bit_mem_end,bit_imm_end,marker_end;
    reg [7:0] op;
    begin
        mem.mem[16'h1000]=8'ha9; mem.mem[16'h1001]=8'h20;
        mem.mem[16'h1002]=8'h24; mem.mem[16'h1003]=8'h40; // BIT $40
        mem.mem[16'h1004]=8'h89; mem.mem[16'h1005]=8'hff; // BIT #$FF
        mem.mem[16'h1006]=8'hea;
        mem.mem[16'h0040]=8'hc0;
        irq=0; nmi=0;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,lda_end,op);
        accepted(16'h1002,2000,bit_mem_end,op);
        if(op!==8'h24 || uut.u_regs.a!==8'h20) begin
            $display("BIT memory setup op=%02x A=%02x",op,uut.u_regs.a);
            mismatches=mismatches+1;
        end
        accepted(16'h1004,2000,bit_imm_end,op);
        #1;
        if(op!==8'h89 || uut.u_regs.a!==8'h20 || uut.u_regs.z!==1'b1 ||
           uut.u_regs.n!==1'b1 || uut.u_regs.v!==1'b1) begin
            $display("BIT $40 flags Z/N/V=%b/%b/%b expected 1/1/1",uut.u_regs.z,uut.u_regs.n,uut.u_regs.v);
            mismatches=mismatches+1;
        end
        accepted(16'h1006,2000,marker_end,op);
        #1;
        if(op!==8'hea || uut.u_regs.a!==8'h20 || uut.u_regs.z!==1'b0 ||
           uut.u_regs.n!==1'b1 || uut.u_regs.v!==1'b1) begin
            $display("BIT immediate flags A=%02x Z/N/V=%b/%b/%b expected 20,0/1/1",
                     uut.u_regs.a,uut.u_regs.z,uut.u_regs.n,uut.u_regs.v);
            mismatches=mismatches+1;
        end
        $display("BIT semantic gate: memory operand C0 with A20 yields Z/N/V=1/1/1; immediate BIT changes Z only");
        control_cases=control_cases+1;
    end
endtask

task run_wrap_semantic(input [7:0] opcode, input [7:0] operand,
                       input [15:0] expected_address, input [7:0] expected_data);
    integer first,last;
    reg [7:0] gotop;
    begin
        mem.mem[16'h1000]=8'ha2; mem.mem[16'h1001]=1;
        mem.mem[16'h1002]=8'ha0; mem.mem[16'h1003]=1;
        mem.mem[16'h1004]=8'ha9; mem.mem[16'h1005]=8'h55;
        mem.mem[16'h1006]=8'h18; mem.mem[16'h1007]=8'hd8; mem.mem[16'h1008]=8'hb8;
        mem.mem[16'h1009]=opcode; mem.mem[16'h100a]=operand; mem.mem[16'h100b]=8'hea;
        mem.mem[16'h00ff]=(opcode==8'hb1) ? expected_address[7:0]-1'b1 : expected_address[7:0];
        mem.mem[16'h0000]=expected_address[15:8];
        mem.mem[16'h0001]=expected_address[15:8];
        // Distinguish zero-page pointer wrap at $00FF->$0000 from a broken
        // 16-bit increment to $0100 and poison the wrong-path destinations.
        mem.mem[16'h0100]=8'h77;
        mem.mem[16'h7700]=8'h11;
        mem.mem[16'h7701]=8'h22;
        mem.mem[expected_address]=expected_data;
        mem.mem[16'h0000]=expected_address[15:8];
        if(opcode==8'hb5) mem.mem[16'h0000]=expected_data;
        if(opcode==8'ha1) begin
            mem.mem[16'h00ff]=expected_address[7:0];
            mem.mem[16'h0000]=expected_address[15:8];
        end
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1009,2000,first,gotop);
        accepted(16'h100b,3000,last,gotop);
        #1;
        if(gotop!==8'hea || uut.u_regs.a!==expected_data) begin
            $display("WRAP semantic op=%02x gotop=%02x A=%02x expected=%02x effective=%04x",
                     opcode,gotop,uut.u_regs.a,expected_data,expected_address);
            mismatches=mismatches+1;
        end
        cases=cases+1;
    end
endtask

integer i;
reg [7:0] opcode, expected;
reg [3:0] bytes;
initial begin
    $dumpfile("test.lxt");
    $dumpvars;
    $readmemh("expected.mem",manifest);
    // Oracle negative controls: it must reject both a whole-cycle error and
    // a partial CEN interval that integer division would otherwise hide.
    if(timing_match(12,2) || timing_match(9,2) || !timing_match(8,2) ||
       byte_match(8'h55,8'h54) || !byte_match(8'h55,8'h55) ||
       address_match(16'h2000,16'h2001) || !address_match(16'h2000,16'h2000))
        $fatal(1,"timing/result/address oracle negative controls failed");
    #1;
    for(i=0;i<65536;i=i+1) mem.mem[i]=8'hea;
    mem.mem[16'hfffc]=8'h00; mem.mem[16'hfffd]=8'h10;
    for(i=0;i<210;i=i+1) begin
        opcode=manifest[i][23:16];
        expected=manifest[i][15:8];
        bytes=manifest[i][3:0];
        run_case(opcode,expected,bytes,i);
    end
    run_jmp_indirect_ff();
    for(i=0;i<256;i=i+1) if(reserved_opcode(i[7:0])) run_reserved_nop(i[7:0]);
    // Explicit BCD boundary vectors include low-digit correction, carry in/out,
    // borrow, zero result, sign and binary overflow behavior.
    run_decimal_boundary(8'h69,8'h45,8'h55,0,8'h00,4'b1011,4'b1001); // V detail not specified by table
    run_decimal_boundary(8'h69,8'h50,8'h50,0,8'h00,4'b1011,4'b1001);
    run_decimal_boundary(8'h69,8'h09,8'h01,0,8'h10,4'b1111,4'b0000);
    run_decimal_boundary(8'h69,8'h09,8'h01,1,8'h11,4'b1111,4'b0000);
    run_decimal_boundary(8'h69,8'h99,8'h01,0,8'h00,4'b1011,4'b1001);
    run_decimal_boundary(8'he9,8'h00,8'h01,1,8'h99,4'b1111,4'b0010);
    run_decimal_boundary(8'he9,8'h00,8'h01,0,8'h98,4'b1111,4'b0010);
    run_decimal_boundary(8'he9,8'h80,8'h01,1,8'h79,4'b1111,4'b1100);
    run_decimal_boundary(8'he9,8'h00,8'h00,1,8'h00,4'b1111,4'b1001);
    for(i=0;i<210;i=i+1) begin
        opcode=manifest[i][23:16];
        if(opcode==8'h61 || opcode==8'h71 || opcode==8'h72 || opcode==8'h65 || opcode==8'h75 || opcode==8'h69 || opcode==8'h79 || opcode==8'h6d || opcode==8'h7d ||
           opcode==8'he1 || opcode==8'hf1 || opcode==8'hf2 || opcode==8'he5 || opcode==8'hf5 || opcode==8'he9 || opcode==8'hf9 || opcode==8'hed || opcode==8'hfd)
            run_decimal_case(opcode,manifest[i][15:8],manifest[i][3:0]);
    end
    // Both outcomes for every conditional branch and every BBR/BBS encoding;
    // taken paths include forward/backward same-page and page-cross targets.
    for(i=0;i<8;i=i+1) begin
        case(i)
            0: opcode=8'h90; 1: opcode=8'hb0; 2: opcode=8'hd0; 3: opcode=8'hf0;
            4: opcode=8'h10; 5: opcode=8'h30; 6: opcode=8'h50; 7: opcode=8'h70;
        endcase
        run_branch_variant(opcode,1,0);
        run_branch_variant(opcode,1,1);
        run_branch_variant(opcode,1,2);
        run_branch_variant(opcode,1,3);
        run_branch_variant(opcode,0,0);
        run_branch_variant(opcode,0,1);
        run_branch_variant(opcode,0,2);
    end
    run_branch_variant(8'h80,1,0);
    run_branch_variant(8'h80,1,1);
    run_branch_variant(8'h80,1,2);
    run_branch_variant(8'h80,1,3);
    for(i=0;i<16;i=i+1) begin
        opcode={i[3:0],4'hf};
        if(i<8) opcode={i[3:0],4'hf};
        else opcode={i[3:0],4'hf};
        run_branch_variant(opcode,1,0);
        run_branch_variant(opcode,1,1);
        run_branch_variant(opcode,1,2);
        run_branch_variant(opcode,1,3);
        run_branch_variant(opcode,0,0);
    end
    // Page-cross paths for every implemented indexed read form, indexed store
    // form, and absolute-X read/modify/write form. The base matrix above
    // supplies the corresponding same-page measurements.
    run_indexed_cross(8'h1d,0,3); run_indexed_cross(8'h3d,0,3);
    run_indexed_cross(8'h5d,0,3); run_indexed_cross(8'h7d,0,3);
    run_indexed_cross(8'hbd,0,3); run_indexed_cross(8'hdd,0,3);
    run_indexed_cross(8'hfd,0,3); run_indexed_cross(8'h3c,0,3);
    run_indexed_cross(8'hbc,0,3);
    run_indexed_cross(8'h19,1,3); run_indexed_cross(8'h39,1,3);
    run_indexed_cross(8'h59,1,3); run_indexed_cross(8'h79,1,3);
    run_indexed_cross(8'hb9,1,3); run_indexed_cross(8'hd9,1,3);
    run_indexed_cross(8'hf9,1,3); run_indexed_cross(8'hbe,1,3);
    run_indexed_cross(8'h11,2,2); run_indexed_cross(8'h31,2,2);
    run_indexed_cross(8'h51,2,2); run_indexed_cross(8'h71,2,2);
    run_indexed_cross(8'hb1,2,2); run_indexed_cross(8'hd1,2,2);
    run_indexed_cross(8'hf1,2,2);
    run_indexed_cross(8'h9d,0,3); run_indexed_cross(8'h99,1,3);
    run_indexed_cross(8'h9e,0,3); run_indexed_cross(8'h91,2,2);
    run_indexed_cross(8'h1e,0,3); run_indexed_cross(8'h3e,0,3);
    run_indexed_cross(8'h5e,0,3); run_indexed_cross(8'h7e,0,3);
    run_indexed_cross(8'hde,0,3); run_indexed_cross(8'hfe,0,3);
    run_irq_service();
    run_masked_irq();
    run_nmi_priority();
    run_irq_all_status_flags();
    run_php_plp_convention();
    run_sei_decimal_irq();
    run_bit_flags();
    run_brk_decimal_status();
    run_cen_pause();
    // Zero-page indexing and all three indirect addressing forms wrap the
    // pointer high-byte fetch at $00FF->$0000; indirect,Y then applies Y.
    run_wrap_semantic(8'hb5,8'hff,16'h0000,8'h3c);
    run_wrap_semantic(8'ha1,8'hfe,16'h2000,8'h46);
    run_wrap_semantic(8'hb2,8'hff,16'h2000,8'h59);
    run_wrap_semantic(8'hb1,8'hff,16'h2001,8'h6a);
    $display("65C02 profile timing: %0d opcode/path cases, %0d reserved NOP checks, %0d status/control gates, %0d unexpected errors, %0d Rockwell timing discrepancies hash=%08x",cases,reserved_cases,control_cases,mismatches,known_findings,finding_hash);
    if(cases!=420) $fatal(1,"opcode/branch/decimal-boundary/page-cross/JMP-FF/IRQ-mask/NMI/CEN/wrap case count incomplete");
    if(reserved_cases!=46) $fatal(1,"Rockwell reserved-opcode NOP coverage incomplete: %0d/46",reserved_cases);
    if(control_cases!=5) $fatal(1,"IRQ saved-status, BRK decimal-status, PHP/PLP and BIT semantic gates incomplete");
    if(mismatches!=0) $fatal(1,"unexpected semantic/bus errors=%0d",mismatches);
    if(known_findings!=0) begin
`ifdef STRICT_ROCKWELL
        $fatal(1,"strict Rockwell R65C02 timing mismatch count=%0d fingerprint=%08x",known_findings,finding_hash);
`else
        $fatal(1,"Rockwell R65C02 target timing mismatch count=%0d fingerprint=%08x",known_findings,finding_hash);
`endif
    end else begin
        $display("PASS: all documented Rockwell R65C02 timing paths match the independent source oracle");
    end
    $finish;
end

initial begin
    #100000000;
    $fatal(1,"65C02 opcode timing timeout");
end
endmodule
