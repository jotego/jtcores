`timescale 1ns/1ps
module test;
reg clk=0;
always #5 clk=~clk;
reg rst=1, irq=0, nmi=0, opdec=0, phase=0;
always @(posedge clk) phase<=~phase;
wire cen=~phase;
wire wr,rd,fetch;
wire [15:0] addr;
wire [7:0] din,dout;
integer cen_count=0, cases=0, mismatches=0, bus_writes=0;
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
end

jtframe_ram #(.AW(16),.CEN_RD(0)) mem(
    .clk(clk), .cen(cen), .data(dout), .addr(addr), .we(wr), .q(din)
);
jt65c02 #(.DECO222(1)) uut(
    .rst(rst), .clk(clk), .cen(cen), .irq(irq), .nmi(nmi), .opdec(opdec),
    .wr(wr), .rd(rd), .fetch(fetch), .addr(addr), .din(din), .dout(dout)
);
`include "test_tasks.vh"

task accepted(input [15:0] pc, input integer limit,
              output integer count, output reg [7:0] decoded);
    integer k;
    reg seen;
    begin
        k=0; seen=0; count=0; decoded=0;
        while(!seen && k<limit) begin
            @(posedge clk);
            if(cen && uut.u_ctrl.enable && uut.u_ctrl.next_instruction && addr==pc) begin
                seen=1; #1;
                count=cen_count;
                decoded=uut.u_ctrl.ir;
            end
            k=k+1;
        end
        if(!seen) begin
            $display("FAIL: missing DECO accepted boundary at %04x",pc);
            $fatal(1);
        end
    end
endtask

task begin_program(input mode);
    begin
        @(negedge clk); rst=1; opdec=mode;
        repeat(8) @(negedge clk);
        rst=0;
    end
endtask

task execute_single(input [7:0] raw, input [7:0] operand1,
                    input [7:0] operand2, input [3:0] length,
                    input integer expected_cycles, input [7:0] decoded_expected,
                    input [8*24-1:0] tag);
    integer first,last,delta,actual,basewrites;
    reg [7:0] decoded;
    begin
        mem.mem[16'h1000]=raw;
        mem.mem[16'h1001]=operand1;
        mem.mem[16'h1002]=operand2;
        mem.mem[16'h1003]=8'hea;
        basewrites=bus_writes;
        begin_program(opdec);
        accepted(16'h1000,2000,first,decoded);
        if(decoded!==decoded_expected) begin
            $display("DECODE mismatch %0s raw=%02x got=%02x expected=%02x",tag,raw,decoded,decoded_expected);
            mismatches=mismatches+1;
        end
        accepted(16'h1000+length,3000,last,decoded);
        delta=last-first;
        if(delta%4!=0 || delta/4!=expected_cycles) begin
            $display("TIMING mismatch %0s raw=%02x len=%0d rawCEN=%0d actual=%0d expected=%0d",
                     tag,raw,length,delta,delta/4,expected_cycles);
            mismatches=mismatches+1;
        end
        #1;
        cases=cases+1;
    end
endtask

task run_deco_interrupt(input nmi_case);
    integer cli_count,nop_count,handler_count,handler_done,return_count,main_count,after_count,main_writes0;
    integer delta,actual,service_cycles;
    reg [7:0] decoded;
    reg [15:0] vector_pc,stacked_pc;
    begin
        // Raw $38 decrypts to CLI ($58); $C9 decrypts to LDA immediate
        // ($A9). EA and RTI ($40) are invariant under this bit swap.
        mem.mem[16'h1000]=8'h38;
        mem.mem[16'h1001]=8'hea;
        mem.mem[16'h1002]=8'h85; // return-path STA direct, identity mapped
        mem.mem[16'h1003]=8'h42;
        mem.mem[16'h1004]=8'hea;
        mem.mem[16'h2000]=8'hc9;
        mem.mem[16'h2001]=8'h40; // non-invariant immediate data must stay raw
        mem.mem[16'h2002]=8'h20; // decrypts to RTI $40
        mem.mem[16'h2100]=8'hc9;
        mem.mem[16'h2101]=8'h40;
        mem.mem[16'h2102]=8'h20;
        mem.mem[16'hfffa]=8'h00; mem.mem[16'hfffb]=8'h21;
        mem.mem[16'hfffe]=8'h00; mem.mem[16'hffff]=8'h20;
        mem.mem[16'h01fd]=0; mem.mem[16'h01fc]=0; mem.mem[16'h01fb]=0;
        mem.mem[16'h0042]=0;
        irq=0; nmi=0; opdec=1;
        vector_pc=nmi_case?16'h2100:16'h2000;
        service_cycles=nmi_case?7:9; // NMI service; IRQ interval includes 2-cycle NOP + service
        stacked_pc=nmi_case?16'h1001:16'h1002;
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        accepted(16'h1000,2000,cli_count,decoded);
        if(decoded!==8'h58) begin
            $display("DECO interrupt CLI raw=38 decoded=%02x expected=58",decoded);
            mismatches=mismatches+1;
        end
        #1;
        irq=1;
        if(nmi_case) begin
            nmi=1;
            repeat(2) @(negedge clk);
            nmi=0;
        end
        accepted(16'h1001,2000,nop_count,decoded);
        if(decoded!==8'hea) begin
            $display("DECO interrupt tail opcode=%02x expected NOP EA",decoded);
            mismatches=mismatches+1;
        end
        accepted(vector_pc,3000,handler_count,decoded);
        if(decoded!==8'ha9) begin
            $display("DECO vector %04x raw C9 decoded=%02x expected LDA A9",vector_pc,decoded);
            mismatches=mismatches+1;
        end
        delta=handler_count-nop_count;
        actual=delta/4;
        if(delta%4!=0 || actual!=service_cycles) begin
            $display("DECO %0s accepted-NOP-to-vector interval rawCEN=%0d cycles=%0d expected=%0d",
                     nmi_case?"NMI":"IRQ",delta,actual,service_cycles);
            mismatches=mismatches+1;
        end
        if(mem.mem[16'h01fd]!==stacked_pc[15:8] ||
           mem.mem[16'h01fc]!==stacked_pc[7:0]) begin
            $display("DECO %0s stacked PC=%02x%02x expected=%04x",
                     nmi_case?"NMI":"IRQ",mem.mem[16'h01fd],mem.mem[16'h01fc],stacked_pc);
            mismatches=mismatches+1;
        end
        // The handler's actual encrypted instruction executes under opdec=1.
        // Clear IRQ after vector entry so RTI returns to the mainline marker.
        irq=0;
        accepted(vector_pc+2,2000,handler_done,decoded);
        if(decoded!==8'h40) begin
            $display("DECO vector handler RTI decoded=%02x expected=40",decoded);
            mismatches=mismatches+1;
        end
        if(handler_done-handler_count!=8) begin
            $display("DECO encrypted handler LDA interval rawCEN=%0d expected=8",handler_done-handler_count);
            mismatches=mismatches+1;
        end
        #1;
        if(uut.u_regs.a!==8'h40 || mem.mem[vector_pc+1]!==8'h40) begin
            $display("DECO handler operand/result changed A=%02x raw operand=%02x expected=40",
                     uut.u_regs.a,mem.mem[vector_pc+1]);
            mismatches=mismatches+1;
        end
        accepted(stacked_pc,3000,return_count,decoded);
        delta=return_count-handler_done;
        if(delta!==24) begin
            $display("DECO %0s RTI interval from accepted RTI to stacked return PC=%04x rawCEN=%0d expected=24 (6 cycles)",
                     nmi_case?"NMI":"IRQ",stacked_pc,delta);
            mismatches=mismatches+1;
        end
        if(nmi_case) begin
            if(decoded!==8'hea) begin
                $display("DECO NMI RTI return at 1001 decoded=%02x expected NOP EA",decoded);
                mismatches=mismatches+1;
            end
            accepted(16'h1002,3000,main_count,decoded);
            if(decoded!==8'h85 || main_count-return_count!=8) begin
                $display("DECO NMI post-RTI NOP interval/next opcode decoded=%02x interval=%0d expected STA85 after 8 CEN",decoded,main_count-return_count);
                mismatches=mismatches+1;
            end
        end else begin
            main_count=return_count;
            if(decoded!==8'h85) begin
                $display("DECO IRQ RTI return at 1002 decoded=%02x expected STA85",decoded);
                mismatches=mismatches+1;
            end
        end
        main_writes0=bus_writes;
        accepted(16'h1004,3000,after_count,decoded);
        if(decoded!==8'hea || after_count-main_count!=12 ||
           mem.mem[16'h0042]!==8'h40 || bus_writes-main_writes0!=1 ||
           last_write_addr!==16'h0042 || last_write_data!==8'h40) begin
            $display("DECO %0s resumed mainline STA/marker mismatch decoded=%02x interval=%0d mem42=%02x writes=%0d last=%04x:%02x",
                     nmi_case?"NMI":"IRQ",decoded,after_count-main_count,mem.mem[16'h0042],bus_writes-main_writes0,last_write_addr,last_write_data);
            mismatches=mismatches+1;
        end
        nmi=0; irq=0;
        $display("DECO %0s opdec=1 vector=%04x raw-handler=C9->A9 operand=40 stackPC=%04x service=%0d cycles RTI=6 cycles mainline=STA42->EA",
                 nmi_case?"NMI":"IRQ",vector_pc,stacked_pc,actual);
        cases=cases+1;
    end
endtask

integer v, k, i;
reg [7:0] raw, swapped;
reg [7:0] nopops[0:13];
reg [3:0] noplen[0:13];
integer nopcycles[0:13];
integer first,last,delta;
reg [7:0] decoded;
initial begin
    $dumpfile("test.lxt"); $dumpvars;
    #1;
    for(i=0;i<65536;i=i+1) mem.mem[i]=8'hea;
    mem.mem[16'hfffc]=8'h00; mem.mem[16'hfffd]=8'h10;
    mem.mem[16'h0040]=8'h3c;

    // Exhaustively verify the implemented bit-5/bit-6 permutation and its
    // disabled identity for each possible byte. The runtime checks below
    // separately prove the decode is used for opcode acceptance only.
    force uut.u_regs.md=8'h00;
    for(v=0;v<256;v=v+1) begin
        raw=v[7:0];
        force uut.u_regs.md=raw;
        opdec=0; #1;
        if(uut.opmd!==raw || uut.u_regs.md_op!==raw) begin
            $display("DECO opdec=0 transform mismatch raw=%02x",raw); $fatal(1);
        end
        swapped={raw[7],raw[5],raw[6],raw[4:0]};
        opdec=1; #1;
        if(uut.opmd!==swapped || uut.u_regs.md_op!==swapped) begin
            $display("DECO opdec=1 transform mismatch raw=%02x got=%02x expected=%02x",raw,uut.opmd,swapped);
            $fatal(1);
        end
    end
    release uut.u_regs.md;
    rst=1; opdec=0;

    // C9 decrypts to LDA immediate only while opdec remains high through NI.
    opdec=1;
    execute_single(8'hc9,8'h40,0,2,2,8'ha9,"encrypted C9 -> LDA immediate");
    if(uut.u_regs.a!==8'h40) begin
        $display("DECO operand was altered or ALU result missed: A=%02x",uut.u_regs.a); mismatches=mismatches+1;
    end
    // With opdec low, C9 remains CMP and does not replace A.
    opdec=0;
    execute_single(8'hc9,8'h69,0,2,2,8'hc9,"unencrypted C9 -> CMP immediate");
    if(uut.u_regs.a!==8'h00) begin
        $display("DECO disabled C9 changed A=%02x",uut.u_regs.a); mismatches=mismatches+1;
    end

    // Hold opdec high for the full program: encrypted LDA then encrypted CMP.
    // Raw operand 40 stays the zero-page address. A following identity-mapped
    // STA proves public write/address/data behavior while opdec remains high.
    mem.mem[16'h1000]=8'hc9; mem.mem[16'h1001]=8'h12;
    mem.mem[16'h1002]=8'ha5; mem.mem[16'h1003]=8'h40;
    mem.mem[16'h1004]=8'h85; mem.mem[16'h1005]=8'h41;
    mem.mem[16'h1006]=8'hea; mem.mem[16'h0040]=8'h3c; mem.mem[16'h0041]=0;
    opdec=1;
    begin_program(1);
    accepted(16'h1000,2000,first,decoded);
    if(decoded!==8'ha9) begin $display("encrypted LDA decoded %02x",decoded); mismatches=mismatches+1; end
    accepted(16'h1002,2000,last,decoded);
    if(decoded!==8'hc5 || uut.u_regs.a!==8'h12) begin
        $display("encrypted CMP acceptance/result decoded=%02x A=%02x",decoded,uut.u_regs.a); mismatches=mismatches+1;
    end
    accepted(16'h1004,2000,last,decoded);
    if(decoded!==8'h85 || uut.u_regs.a!==8'h12) begin
        $display("STA opcode acceptance/result decoded=%02x A=%02x",decoded,uut.u_regs.a); mismatches=mismatches+1;
    end
    accepted(16'h1006,2000,last,decoded);
    #1;
    if(mem.mem[16'h0040]!==8'h3c || mem.mem[16'h0041]!==8'h12 || bus_writes!=1 || last_write_addr!==16'h0041 || last_write_data!==8'h12) begin
        $display("DECO public write mismatch count=%0d last=%04x:%02x mem40=%02x mem41=%02x",bus_writes,last_write_addr,last_write_data,mem.mem[16'h0040],mem.mem[16'h0041]);
        mismatches=mismatches+1;
    end
    if(mem.mem[16'h1001]!==8'h12 || mem.mem[16'h1003]!==8'h40 || mem.mem[16'h1005]!==8'h41) begin
        $display("DECO operand bytes changed in backing RAM"); mismatches=mismatches+1;
    end
    cases=cases+1;

    // Keep opcode decryption enabled throughout each interrupt, encrypted
    // vector handler, RTI and return marker. This is bounded interrupt-path
    // coverage, not an exhaustive DECO-specific interrupt specification.
    run_deco_interrupt(0);
    run_deco_interrupt(1);

    // DECO222-specific additional NOP inventory from deco222.yaml.
    nopops[0]=8'h02; nopops[1]=8'h22; nopops[2]=8'h42; nopops[3]=8'h62;
    nopops[4]=8'h82; nopops[5]=8'hc2; nopops[6]=8'he2;
    nopops[7]=8'h44; nopops[8]=8'h54; nopops[9]=8'hd4; nopops[10]=8'hf4;
    nopops[11]=8'h5c; nopops[12]=8'hdc; nopops[13]=8'hfc;
    for(i=0;i<7;i=i+1) begin noplen[i]=2; nopcycles[i]=2; end
    noplen[7]=2; nopcycles[7]=3;
    for(i=8;i<11;i=i+1) begin noplen[i]=2; nopcycles[i]=4; end
    noplen[11]=3; nopcycles[11]=4; // DECO table; WDC reserved-opcode table says 5C=8
    noplen[12]=3; nopcycles[12]=4; noplen[13]=3; nopcycles[13]=4;
    for(i=0;i<14;i=i+1) begin
        opdec=0;
        execute_single(nopops[i],8'h40,8'h20,noplen[i],nopcycles[i],nopops[i],"DECO extra NOP");
    end

    $display("DECO222 byte remap=512 states; runtime/decrypt/NOP/IRQ/NMI cases=%0d findings=%0d",cases,mismatches);
    if(mismatches!=0) $fatal(1,"DECO222 independent expectations mismatches=%0d",mismatches);
    $display("PASS: DECO222 opcode-vs-operand transform and extra-NOP profile");
    $finish;
end
initial begin #10000000; $fatal(1,"DECO222 timeout"); end
endmodule
