`timescale 1ns/1ps
module test;

reg clk = 0;
always #5 clk = ~clk;
reg rst = 1;
reg [1:0] phase = 0;
reg cen_pause=0;
wire cen = phase == 0 && !cen_pause;
always @(posedge clk) phase <= phase + 1'b1;
wire wr, ba;
wire [15:0] addr;
wire [7:0] din, dout;
reg irq=0, nmi=0, ext_halt=0;
reg irq_icf=0, irq_ocf=0, irq_tof=0, irq_sci=0, irq_cmf=0, irq2=0;
integer ticks=0;
reg matrix_running=0;
reg wai_observing=0, wai_seen=0, wai_trace_started=0;
integer wai_ffff_reads=0, wai_trace_remaining=0;
always @(posedge clk) if(cen && !rst && !matrix_running) $display("BUS %0d A=%04x W=%b DIN=%02x DOUT=%02x",ticks,addr,wr,din,dout);
integer timing_active=0, timing_steps=0, timing_cycles=0;
reg [7:0] timing_opcode=0;
integer count_01=0, count_86=0, count_27=0, count_26=0;
integer branch_op, flags, wait_edges;
reg expected_taken;
reg generic_mode=0, timing_done=0;
reg [7:0] target_opcode=0;
reg [15:0] target_pc=16'h0100;
integer target_cycles=0, generic_count=0;
integer ext_write_watch=0, ext_write_count=0;
integer timing_assertions=0;
integer pula_active=0, pula_cen=0;
integer executed_by_opcode [0:255];
integer timed_by_opcode [0:255];
reg [7:0] dispatch_opcode;
reg [15:0] dispatch_pc, dispatch_bus_addr;
always @(posedge clk) begin
    if(!rst && cen && (uut.u_ctrl.ni || uut.u_ctrl.halt)) begin
        dispatch_opcode=uut.md[7:0]; dispatch_pc=uut.u_regs.pc; dispatch_bus_addr=addr;
        #1;
        if(uut.u_ctrl.uaddr=={dispatch_opcode,4'h0} && !uut.u_ctrl.stack_busy) begin
            executed_by_opcode[dispatch_opcode]=executed_by_opcode[dispatch_opcode]+1;
            $display("EXEC_EVENT opcode=%02x pc=%04x bus=%04x",dispatch_opcode,dispatch_pc,dispatch_bus_addr);
            if(dispatch_opcode==8'h32 && dispatch_pc==16'h0111) begin pula_active=1; pula_cen=0; $display("PULA_ENTRY_BOUNDARY pc=%04x U=%03x",uut.u_regs.pc,uut.u_ctrl.uaddr); end
        end
    end
end
integer cov_i;
localparam [255:0] DOC_DEFINED_MASK = 256'hffffffffffff5f7fffffffffffff7f7ff7d9f7d9b7d9b7d9ffffffff0ac3fff2;
localparam [255:0] DOC_TIMING_MASK  = 256'hffffffffffff5f7fffffffffffff7f7ff7d9f7d9b7d9b7d9ffffffff0ac3fff2;
integer rti_active=0, rti_cen=0;
always @(posedge clk) begin
    if(rst) rti_active=0;
    else if(cen) begin
        if(!rti_active && uut.u_ctrl.uaddr==12'h3b0) begin rti_active=1; rti_cen=0; end
        else if(rti_active) begin
            rti_cen=rti_cen+1;
            if(uut.u_ctrl.uaddr=={uut.md[7:0],4'h0} && uut.u_ctrl.uaddr!=12'h3b0 && !uut.u_ctrl.stack_busy) begin
                if(rti_cen==40) begin
                    timed_by_opcode[8'h3b]=timed_by_opcode[8'h3b]+1;
                    timing_assertions=timing_assertions+1;
                    $display("SPECIAL_TIMING opcode=3b CEN=%0d E=10",rti_cen);
                end else begin $display("FAIL: MC6801 RTI measured %0d CEN intervals; manual expects 40 (10E)",rti_cen); $fatal(1); end
                rti_active=0;
            end
        end
    end
end
always @(posedge clk) if(!rst && cen) begin
    if(!pula_active && (uut.u_ctrl.ni || uut.u_ctrl.halt) && uut.md[7:0]==8'h32 && uut.u_regs.pc==16'h0111) begin pula_active=1; pula_cen=0; end
    else if(pula_active) begin
        pula_cen=pula_cen+1;
        if(uut.u_ctrl.ni) begin
            if(pula_cen==16) begin timed_by_opcode[8'h32]=timed_by_opcode[8'h32]+1; timing_assertions=timing_assertions+1; $display("SPECIAL_TIMING opcode=32 CEN=%0d E=4",pula_cen); end
            else begin $display("FAIL: MC6801 PULA measured %0d CEN intervals; manual expects 16 (4E)",pula_cen); $fatal(1); end
            pula_active=0;
        end
    end
end
initial begin for(cov_i=0;cov_i<256;cov_i=cov_i+1) begin executed_by_opcode[cov_i]=0; timed_by_opcode[cov_i]=0; end end
always @(posedge clk) if (rst) begin
    timing_active=0;
    timing_steps=0;
end else if (cen) begin
    if (!timing_active) begin
        if (generic_mode) begin
            if (uut.u_regs.pc == target_pc && uut.u_ctrl.uaddr[11:4] == target_opcode) begin
                timing_active=1; timing_opcode=target_opcode; timing_cycles=target_cycles; timing_steps=1;
            end
        end else begin
            case (uut.u_ctrl.uaddr[11:4])
                8'h01: begin timing_active=1; timing_opcode=8'h01; timing_cycles=2; timing_steps=1; end
                8'h86: begin timing_active=1; timing_opcode=8'h86; timing_cycles=2; timing_steps=1;
`ifdef NEGATIVE_TIMING
                    timing_cycles=3;
`endif
                end
                default: if (uut.u_ctrl.uaddr[11:4] >= 8'h20 && uut.u_ctrl.uaddr[11:4] <= 8'h2f) begin
                    timing_active=1; timing_opcode=uut.u_ctrl.uaddr[11:4]; timing_cycles=3; timing_steps=1;
                end
            endcase
        end
    end else begin
        timing_steps=timing_steps+1;
        if (uut.u_ctrl.ni) begin
            if (timing_steps != timing_cycles*4) begin
                $display("FAIL: opcode %02x used %0d crystal enables, manual expects %0d E cycles",timing_opcode,timing_steps,timing_cycles);
                $fatal(1);
            end
            $display("TIMING: opcode %02x = %0d E cycles",timing_opcode,timing_cycles);
            timing_assertions=timing_assertions+1;
            timed_by_opcode[timing_opcode]=timed_by_opcode[timing_opcode]+1;
            if (generic_mode) timing_done=1;
            case (timing_opcode)
                8'h01: count_01=count_01+1;
                8'h86: count_86=count_86+1;
                8'h27: count_27=count_27+1;
                8'h26: count_26=count_26+1;
                default:;
            endcase
            timing_active=0;
        end
    end
end

always @(posedge clk) if(ext_write_watch && cen && wr && addr==16'h0020) ext_write_count=ext_write_count+1;

jtframe_ram #(.AW(16), .CEN_RD(0)) mem(
    .clk(clk), .cen(cen), .data(dout), .addr(addr), .we(wr), .q(din)
);

jt680x uut(
    .rst(rst), .clk(clk), .cen(cen), .wr(wr), .addr(addr), .din(din), .dout(dout),
    .ext_halt(ext_halt), .ba(ba), .irq(irq), .nmi(nmi), .irq_icf(irq_icf),
    .irq_ocf(irq_ocf), .irq_tof(irq_tof), .irq_sci(irq_sci),
    .irq_cmf(irq_cmf), .irq2(irq2)
);

always @(posedge clk) if(wai_observing && !rst && cen) begin
    if(uut.u_ctrl.uaddr[11:4]==8'h3e) wai_seen=1;
    if(wai_seen && addr==16'hffff && !wr) wai_ffff_reads=wai_ffff_reads+1;
    if(wai_seen && !wai_trace_started && (uut.u_ctrl.halt || uut.u_ctrl.ni)) begin
        wai_trace_started=1; wai_trace_remaining=2;
        $display("WAI_EDGE0 PRE: U=%03x HALT=%b NI=%b ALT=%b MD=%04x I=%b PC=%04x S=%04x A=%04x W=%b",uut.u_ctrl.uaddr,uut.u_ctrl.halt,uut.u_ctrl.ni,uut.u_ctrl.alt,uut.md,uut.u_regs.i,uut.u_regs.pc,uut.u_regs.s,addr,wr);
    end else if(wai_trace_remaining>0) begin
        $display("WAI_EDGE%0d PRE: U=%03x HALT=%b NI=%b ALT=%b MD=%04x I=%b PC=%04x S=%04x A=%04x W=%b",3-wai_trace_remaining,uut.u_ctrl.uaddr,uut.u_ctrl.halt,uut.u_ctrl.ni,uut.u_ctrl.alt,uut.md,uut.u_regs.i,uut.u_regs.pc,uut.u_regs.s,addr,wr);
        wai_trace_remaining=wai_trace_remaining-1;
    end
end

task run_acc_case;
    input [7:0] op;
    input [1:0] mode;
    input [7:0] imm;
    integer cycles, lowop, groupb;
    reg [7:0] expected, actual_op;
    reg check_mem;
    begin
        lowop=op[3:0]; groupb=(op[7:6]==2'b11);
        case(mode) 0: cycles=2; 1: cycles=3; 2: cycles=4; 3: cycles=4; endcase
        if (lowop==7) begin
            if(mode==0) begin $display("FAIL: immediate store is undefined"); $fatal(1); end
            expected=groupb ? 8'h34 : 8'h12; check_mem=1;
        end else begin
            check_mem=0;
            case(lowop)
                0,2: expected=groupb ? 8'hde : 8'hbc;
                1,5: expected=groupb ? 8'h34 : 8'h12;
                4: expected=groupb ? 8'h14 : 8'h12;
                6: expected=8'h56;
                8: expected=groupb ? 8'h62 : 8'h44;
                9,11: expected=groupb ? 8'h8a : 8'h68;
                10: expected=groupb ? 8'h76 : 8'h56;
                default: begin $display("FAIL: unsupported generic accumulator opcode %02x",op); $fatal(1); end
            endcase
        end
        actual_op=op + (mode << 4);
        target_opcode=actual_op; target_cycles=cycles; timing_done=0; generic_mode=1;
        mem.mem[16'h0020]=8'h56; mem.mem[16'h0021]=8'h78;
        mem.mem[16'h0100]=actual_op;
        case(mode)
            0: begin mem.mem[16'h0101]=imm; mem.mem[16'h0102]=8'h20; end
            1: begin mem.mem[16'h0101]=8'h20; mem.mem[16'h0102]=8'h20; end
            2: begin mem.mem[16'h0101]=8'h00; mem.mem[16'h0102]=8'h20; end
            3: begin mem.mem[16'h0101]=8'h00; mem.mem[16'h0102]=8'h20; end
        endcase
        mem.mem[16'h0103]=8'h20; mem.mem[16'h0104]=8'hfe;
        mem.mem[16'h0105]=8'h20; mem.mem[16'h0106]=8'hfe;
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030;
        rst=0;
        wait_edges=0;
        while(!timing_done && wait_edges<300) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(!timing_done) begin $display("FAIL: generic opcode %02x did not complete",op); $fatal(1); end
`ifdef NEGATIVE_RESULT
        if(actual_op==8'h80 && mode==0) expected=expected^8'h01;
`endif
        if(check_mem) begin
            if(mem.mem[16'h0020] !== expected) begin $display("FAIL: opcode %02x wrote %02x expected %02x",op,mem.mem[16'h0020],expected); $fatal(1); end
        end else if(groupb) begin
            if(uut.u_regs.b !== expected) begin $display("FAIL: opcode %02x B=%02x expected %02x",op,uut.u_regs.b,expected); $fatal(1); end
        end else if(uut.u_regs.a !== expected) begin
            $display("FAIL: opcode %02x A=%02x expected %02x",op,uut.u_regs.a,expected); $fatal(1);
        end
        if(uut.u_regs.x !== 16'h0020 || uut.u_regs.s !== 16'h0030) begin
            $display("FAIL: opcode %02x clobbered preserved index/stack state X=%04x S=%04x",op,uut.u_regs.x,uut.u_regs.s); $fatal(1);
        end
        generic_count=generic_count+1;
        rst=1; generic_mode=0;
    end
endtask

task run_word_case;
    input [7:0] baseop;
    input [1:0] mode;
    input [2:0] kind;
    input [15:0] expected;
    integer cycles;
    reg [7:0] actual_op;
    begin
        if(baseop==8'hc3 || baseop==8'h83) cycles=(2==1) ? (mode==0?3:mode==1?4:5) : (mode==0?4:mode==1?5:6);
        else if(baseop==8'h8c) cycles=(2==1) ? (mode==0?3:mode==1?4:5) : (mode==0?4:mode==1?5:6);
        else if(baseop==8'h8f || baseop==8'hcf) cycles=(mode==1?4:5);
        else cycles=(mode==0?3:mode==1?4:5);
        actual_op=baseop+(mode<<4);
        target_opcode=actual_op; target_cycles=cycles; timing_done=0; generic_mode=1;
        mem.mem[16'h0020]=8'h12; mem.mem[16'h0021]=8'h34;
        mem.mem[16'h0100]=actual_op;
        case(mode)
            0: begin mem.mem[16'h0101]=8'h12; mem.mem[16'h0102]=8'h34; end
            1: begin mem.mem[16'h0101]=8'h20; mem.mem[16'h0102]=8'h20; end
            2: begin mem.mem[16'h0101]=8'h00; mem.mem[16'h0102]=8'h20; end
            3: begin mem.mem[16'h0101]=8'h00; mem.mem[16'h0102]=8'h20; end
        endcase
        mem.mem[16'h0103]=8'h20; mem.mem[16'h0104]=8'hfe;
        mem.mem[16'h0105]=8'h20; mem.mem[16'h0106]=8'hfe;
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030;
        rst=0;
        wait_edges=0; while(!timing_done && wait_edges<300) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(!timing_done) begin $display("FAIL: word opcode %02x did not complete",actual_op); $fatal(1); end
        case(kind)
            0: if({uut.u_regs.a,uut.u_regs.b} !== expected) begin $display("FAIL: opcode %02x D=%04x expected %04x",actual_op,{uut.u_regs.a,uut.u_regs.b},expected); $fatal(1); end
            1: if(uut.u_regs.x !== expected) begin $display("FAIL: opcode %02x X=%04x expected %04x",actual_op,uut.u_regs.x,expected); $fatal(1); end
            2: if(uut.u_regs.s !== expected) begin $display("FAIL: opcode %02x S=%04x expected %04x",actual_op,uut.u_regs.s,expected); $fatal(1); end
            3: if({mem.mem[16'h0020],mem.mem[16'h0021]} !== expected) begin $display("FAIL: opcode %02x memory=%04x expected %04x",actual_op,{mem.mem[16'h0020],mem.mem[16'h0021]},expected); $fatal(1); end
            4: if(uut.u_regs.x !== expected) begin $display("FAIL: opcode %02x CPX state X=%04x expected %04x",actual_op,uut.u_regs.x,expected); $fatal(1); end
        endcase
        generic_count=generic_count+1; rst=1; generic_mode=0;
    end
endtask

task run_unary_case;
    input [7:0] indexed_op;
    input ext_mode;
    reg [7:0] actual_op, expected;
    integer cycles;
    begin
        actual_op=indexed_op+(ext_mode?8'h10:8'h00);
        if(indexed_op[3:0]==4'hf) cycles=(2==1)?5:6; else cycles=6;
        case(indexed_op[3:0])
            0: expected=8'haa; 3: expected=8'ha9; 4,6,7: expected=8'h2b;
            8,9: expected=8'hac; 10: expected=8'h55; 12: expected=8'h57;
            13: expected=8'h56; 15: expected=8'h00;
            default: begin $display("FAIL: unsupported unary %02x",indexed_op); $fatal(1); end
        endcase
        target_opcode=actual_op; target_cycles=cycles; timing_done=0; generic_mode=1;
        mem.mem[16'h0020]=8'h56; mem.mem[16'h0021]=8'h78;
        mem.mem[16'h0100]=actual_op;
        mem.mem[16'h0101]=8'h00; mem.mem[16'h0102]=8'h20;
        mem.mem[16'h0103]=8'h20; mem.mem[16'h0104]=8'hfe;
        mem.mem[16'h0105]=8'h20; mem.mem[16'h0106]=8'hfe;
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030;
        rst=0;
        wait_edges=0; while(!timing_done && wait_edges<300) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(!timing_done) begin $display("FAIL: unary opcode %02x did not complete",actual_op); $fatal(1); end
        if(mem.mem[16'h0020] !== expected) begin $display("FAIL: unary opcode %02x memory=%02x expected %02x",actual_op,mem.mem[16'h0020],expected); $fatal(1); end
        generic_count=generic_count+1; rst=1; generic_mode=0;
    end
endtask

task run_acc_unary_case;
    input [7:0] actual_op;
    reg [7:0] expected;
    integer cycles;
    begin
        case(actual_op[3:0])
            0: expected=8'haa; 3: expected=8'ha9; 4,6,7: expected=8'h2b;
            8,9: expected=8'hac; 10: expected=8'h55; 12: expected=8'h57;
            13: expected=8'h56; 15: expected=8'h00;
            default: begin $display("FAIL: unsupported accumulator unary opcode %02x",actual_op); $fatal(1); end
        endcase
        cycles=2;
        target_opcode=actual_op; target_cycles=cycles; timing_done=0; generic_mode=1;
        mem.mem[16'h0100]=actual_op; mem.mem[16'h0101]=8'h20; mem.mem[16'h0102]=8'hfe;
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=8'h56; uut.u_regs.b=8'h56; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030; uut.u_regs.c=0;
        rst=0;
        wait_edges=0; while(!timing_done && wait_edges<200) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(!timing_done) begin $display("FAIL: accumulator unary opcode %02x did not complete",actual_op); $fatal(1); end
        if(actual_op[4]) begin
            if(uut.u_regs.b !== expected) begin $display("FAIL: opcode %02x B=%02x expected %02x",actual_op,uut.u_regs.b,expected); $fatal(1); end
        end else if(uut.u_regs.a !== expected) begin
            $display("FAIL: opcode %02x A=%02x expected %02x",actual_op,uut.u_regs.a,expected); $fatal(1);
        end
        if(uut.u_regs.x !== 16'h0020 || uut.u_regs.s !== 16'h0030) begin $display("FAIL: opcode %02x clobbered preserved X/S",actual_op); $fatal(1); end
        generic_count=generic_count+1; rst=1; generic_mode=0;
    end
endtask

task run_implied_case;
    input [7:0] op;
    input integer cycles;
    reg [7:0] expect_a, expect_b;
    reg [15:0] expect_x;
    reg expect_c, expect_v, expect_i;
    reg check_flags;
    begin
        expect_a=8'h12; expect_b=8'h34; expect_x=16'h0020;
        expect_c=1; expect_v=1; expect_i=1; check_flags=0;
        case(op)
            8'h04: begin expect_a=8'h09; expect_b=8'h1a; end
            8'h05: begin expect_a=8'h24; expect_b=8'h68; end
            8'h06: begin expect_c=0; expect_v=1; expect_i=1; check_flags=1; end
            8'h07: expect_a=8'h3b;
            8'h08: expect_x=16'h0021;
            8'h09: expect_x=16'h001f;
            8'h0a: begin expect_v=0; check_flags=1; end
            8'h0b: begin expect_v=1; check_flags=1; end
            8'h0c: begin expect_c=0; check_flags=1; end
            8'h0d: begin expect_c=1; check_flags=1; end
            8'h0e: begin expect_i=0; check_flags=1; end
            8'h0f: begin expect_i=1; check_flags=1; end
            8'h10: expect_a=8'hde;
            8'h11: expect_a=8'h12;
            8'h16: expect_b=8'h12;
            8'h17: expect_a=8'h34;
            8'h1b: expect_a=8'h46;
            default: begin $display("FAIL: unsupported implied opcode %02x",op); $fatal(1); end
        endcase
        target_opcode=op; target_cycles=cycles; timing_done=0; generic_mode=1;
        mem.mem[16'h0100]=op; mem.mem[16'h0101]=8'h20; mem.mem[16'h0102]=8'hfe;
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030;
        uut.u_regs.h=1; uut.u_regs.n=1; uut.u_regs.z=0; uut.u_regs.c=1; uut.u_regs.v=1; uut.u_regs.i=1;
        rst=0;
        wait_edges=0; while(!timing_done && wait_edges<200) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(!timing_done) begin $display("FAIL: implied opcode %02x did not complete",op); $fatal(1); end
        if((op==8'h07 ? uut.u_regs.a[5:0]!==expect_a[5:0] : uut.u_regs.a!==expect_a) || uut.u_regs.b!==expect_b || uut.u_regs.x!==expect_x || uut.u_regs.s!==16'h0030 ||
           (check_flags && (uut.u_regs.c!==expect_c || uut.u_regs.v!==expect_v || uut.u_regs.i!==expect_i))) begin
            $display("FAIL: implied opcode %02x state A/B=%02x/%02x X/S=%04x/%04x C/V/I=%b%b%b",op,uut.u_regs.a,uut.u_regs.b,uut.u_regs.x,uut.u_regs.s,uut.u_regs.c,uut.u_regs.v,uut.u_regs.i); $fatal(1);
        end
        generic_count=generic_count+1; rst=1; generic_mode=0;
    end
endtask

task run_cen_pause_case;
    integer n;
    reg [15:0] saved_pc;
    reg [11:0] saved_uaddr;
    reg [7:0] saved_a;
    begin
        target_opcode=8'h86; target_pc=16'h0100; target_cycles=2; timing_done=0; generic_mode=1;
        mem.mem[16'h0100]=8'h86; mem.mem[16'h0101]=8'h5a; mem.mem[16'h0102]=8'h20; mem.mem[16'h0103]=8'hfe;
        rst=1; repeat(8) @(negedge clk); uut.u_regs.a=0; uut.u_regs.b=0; uut.u_regs.x=16'h20; uut.u_regs.s=16'h30; rst=0;
        n=0; while(!timing_active && n<100) begin @(negedge clk); n=n+1; end
        if(!timing_active) begin $display("FAIL: CEN pause case never entered LDAA"); $fatal(1); end
        @(negedge clk); cen_pause=1; saved_pc=uut.u_regs.pc; saved_uaddr=uut.u_ctrl.uaddr; saved_a=uut.u_regs.a;
        repeat(24) @(posedge clk);
        if(uut.u_regs.pc!==saved_pc || uut.u_ctrl.uaddr!==saved_uaddr || uut.u_regs.a!==saved_a) begin
            $display("FAIL: CEN-low interval advanced CPU state PC/U/A=%04x/%03x/%02x to %04x/%03x/%02x",saved_pc,saved_uaddr,saved_a,uut.u_regs.pc,uut.u_ctrl.uaddr,uut.u_regs.a); $fatal(1);
        end
        @(negedge clk); cen_pause=0; wait_edges=0;
        while(!timing_done && wait_edges<200) begin @(posedge clk); wait_edges=wait_edges+1; end
        if(!timing_done || uut.u_regs.a!==8'h5a) begin $display("FAIL: CEN resume result/timing done=%b A=%02x",timing_done,uut.u_regs.a); $fatal(1); end
        generic_count=generic_count+1; rst=1; generic_mode=0;
        $display("CHECKED: CEN low for 24 master edges held PC/U/A stable; resumed LDAA retained the 2E enabled-edge assertion");
    end
endtask

task run_mul_case;
    begin
        target_opcode=8'h3d; target_cycles=10; timing_done=0; generic_mode=1;
        mem.mem[16'h0100]=8'h3d; mem.mem[16'h0101]=8'h01; mem.mem[16'h0102]=8'h01;
        mem.mem[16'h0103]=8'h20; mem.mem[16'h0104]=8'hfe;
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030;
        rst=0; wait_edges=0;
        while(!timing_done && wait_edges<300) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(!timing_done || {uut.u_regs.a,uut.u_regs.b}!==16'h03a8) begin
            $display("FAIL: MC6801 MUL timing/result done=%b D=%04x",timing_done,{uut.u_regs.a,uut.u_regs.b}); $fatal(1);
        end
        generic_count=generic_count+1; rst=1; generic_mode=0;
    end
endtask

// Directed control/data-transfer forms that use effective-address or stack
// microsequences.  The monitor measures from the decoded opcode boundary to
// its next NI boundary; state/stack markers are checked independently.
task run_std_case;
    input [1:0] mode;
    reg [7:0] op;
    integer cycles;
    reg [15:0] ea;
    begin
        op = mode==0 ? 8'hdd : mode==1 ? 8'hed : 8'hfd;
        cycles = mode==0 ? 4 : 5;
        ea = 16'h0020;
        target_opcode=op; target_cycles=cycles; timing_done=0; generic_mode=1;
        mem.mem[16'h0100]=op;
        if(mode==0) mem.mem[16'h0101]=8'h20;
        else if(mode==1) mem.mem[16'h0101]=8'h00;
        else begin mem.mem[16'h0101]=8'h00; mem.mem[16'h0102]=8'h20; end
        mem.mem[16'h0103]=8'h20; mem.mem[16'h0104]=8'hfe;
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030;
        rst=0; wait_edges=0;
        while(!timing_done && wait_edges<300) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(!timing_done || {mem.mem[ea],mem.mem[ea+1]}!==16'h1234) begin
            $display("FAIL: STD mode=%0d done=%b memory=%04x",mode,timing_done,{mem.mem[ea],mem.mem[ea+1]}); $fatal(1);
        end
        generic_count=generic_count+1; rst=1; generic_mode=0;
    end
endtask

task run_jump_case;
    input [7:0] op;
    input [2:0] mode; // 0 indexed, 1 extended, 2 direct JSR, 3 indexed JSR, 4 extended JSR, 5 BSR
    integer cycles;
    reg [15:0] target;
    begin
        target=mode==2 ? 16'h0020 : 16'h0120;
        case(mode) 0: cycles=3; 1: cycles=3; 2: cycles=5; 3,4: cycles=6; default: cycles=6; endcase
        target_opcode=op; target_cycles=cycles; timing_done=0; generic_mode=1;
        mem.mem[16'h0100]=op;
        case(mode)
            0: begin mem.mem[16'h0101]=8'h20; uut.u_regs.x=16'h0100; end
            1: begin mem.mem[16'h0101]=8'h01; mem.mem[16'h0102]=8'h20; end
            2: mem.mem[16'h0101]=8'h20;
            3: begin mem.mem[16'h0101]=8'h20; uut.u_regs.x=16'h0100; end
            4: begin mem.mem[16'h0101]=8'h01; mem.mem[16'h0102]=8'h20; end
            5: mem.mem[16'h0101]=8'h1e;
        endcase
        mem.mem[16'h0103]=8'h20; mem.mem[16'h0104]=8'hfe;
        mem.mem[target]=8'h86; mem.mem[target+1]=8'h5a; mem.mem[target+2]=8'h97; mem.mem[target+3]=8'h20;
        mem.mem[target+4]=8'h20; mem.mem[target+5]=8'hfe;
        // JSR/BSR target writes a marker; JMP target is checked through PC.
        if(mode>=2) begin mem.mem[target]=8'h86; mem.mem[target+1]=8'ha5; mem.mem[target+2]=8'h97; mem.mem[target+3]=8'h20; end
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=(mode==0 || mode==3) ? 16'h0100 : 16'h0020; uut.u_regs.s=16'h0030;
        rst=0; wait_edges=0;
        while(!timing_done && wait_edges<300) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(!timing_done) begin $display("FAIL: control opcode %02x did not finish",op); $fatal(1); end
        if(mode<2 && uut.u_regs.pc!==target) begin $display("FAIL: JMP %02x PC=%04x expected %04x",op,uut.u_regs.pc,target); $fatal(1); end
        if(mode>=2 && (uut.u_regs.s!==16'h002e || {mem.mem[16'h002f],mem.mem[16'h002e]}===16'hxxxx)) begin
            $display("FAIL: JSR/BSR %02x stack did not receive return address S=%04x",op,uut.u_regs.s); $fatal(1);
        end
        generic_count=generic_count+1; rst=1; generic_mode=0;
    end
endtask

task run_stack_index_case;
    input [7:0] op;
    reg [15:0] old_s, old_x;
    integer cycles;
    begin
        case(op)
            8'h30,8'h31,8'h34,8'h35,8'h3a: cycles=3;
            8'h36,8'h37: cycles=3;
            8'h33: cycles=4;
            8'h38: cycles=5;
            8'h3c: cycles=4;
            default: begin $display("FAIL: bad stack/index opcode %02x",op); $fatal(1); end
        endcase
        target_opcode=op; target_cycles=cycles; timing_done=0; generic_mode=1;
        mem.mem[16'h0100]=op; mem.mem[16'h0101]=8'h01; mem.mem[16'h0102]=8'h01;
        mem.mem[16'h0103]=8'h20; mem.mem[16'h0104]=8'hfe;
        mem.mem[16'h0031]=8'h56; mem.mem[16'h0032]=8'h78;
        rst=1; repeat(8) @(negedge clk);
        old_s=16'h0030; old_x=16'h0020;
        uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=old_x; uut.u_regs.s=old_s;
        rst=0; wait_edges=0;
        while(!timing_done && wait_edges<250) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(!timing_done) begin $display("FAIL: stack/index opcode %02x did not finish",op); $fatal(1); end
        case(op)
            8'h30: if(uut.u_regs.x!==16'h0031) $fatal(1,"TSX state mismatch");
            8'h31: if(uut.u_regs.s!==16'h0031) $fatal(1,"INS state mismatch");
            8'h34: if(uut.u_regs.s!==16'h002f) $fatal(1,"DES state mismatch");
            8'h35: if(uut.u_regs.s!==16'h001f) $fatal(1,"TXS state mismatch");
            8'h3a: if(uut.u_regs.x!==16'h0054) $fatal(1,"ABX state mismatch");
            8'h36: if(uut.u_regs.s!==16'h002f || mem.mem[16'h0030]!==8'h12) $fatal(1,"PSHA stack mismatch");
            8'h37: if(uut.u_regs.s!==16'h002f || mem.mem[16'h0030]!==8'h34) $fatal(1,"PSHB stack mismatch");
            8'h33: if(uut.u_regs.b!==8'h56 || uut.u_regs.s!==16'h0031) $fatal(1,"PULB state mismatch");
            8'h38: if(uut.u_regs.x!==16'h5678 || uut.u_regs.s!==16'h0032) $fatal(1,"PULX state mismatch");
            8'h3c: if(uut.u_regs.s!==16'h002e) $fatal(1,"PSHX stack pointer mismatch");
        endcase
        generic_count=generic_count+1; rst=1; generic_mode=0;
    end
endtask

task run_daa_case;
    integer k;
    reg [7:0] expected_a;
    reg expected_c, initial_h;
    begin
        for(k=0;k<3;k=k+1) begin
            case(k)
                0: begin expected_a=8'h10; expected_c=0; initial_h=0; end
                1: begin expected_a=8'h00; expected_c=1; initial_h=0; end
                default: begin expected_a=8'h1b; expected_c=0; initial_h=1; end
            endcase
            target_opcode=8'h19; target_pc=16'h0100; target_cycles=2; timing_done=0; generic_mode=1;
            mem.mem[16'h0100]=8'h19; mem.mem[16'h0101]=8'h20; mem.mem[16'h0102]=8'hfe;
            rst=1; repeat(8) @(negedge clk);
            uut.u_regs.a=(k==0)?8'h0a:(k==1)?8'h9a:8'h15; uut.u_regs.b=0; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030;
            uut.u_regs.h=initial_h; uut.u_regs.c=0; rst=0; wait_edges=0;
            while(!timing_done && wait_edges<200) begin @(posedge clk); wait_edges=wait_edges+1; end
            @(negedge clk);
            if(!timing_done || uut.u_regs.a!==expected_a || uut.u_regs.c!==expected_c) begin
                $display("FAIL: DAA case %0d done=%b A/C=%02x/%b expected=%02x/%b",k,timing_done,uut.u_regs.a,uut.u_regs.c,expected_a,expected_c); $fatal(1);
            end
            generic_count=generic_count+1; rst=1; generic_mode=0;
        end
    end
endtask

task run_rts_case;
    begin
        target_opcode=8'h39; target_pc=16'h0100; target_cycles=5; timing_done=0; generic_mode=1;
        mem.mem[16'h0100]=8'h39; mem.mem[16'h0110]=8'h01; mem.mem[16'h0111]=8'h20;
        mem.mem[16'h0120]=8'h20; mem.mem[16'h0121]=8'hfe;
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030;
        mem.mem[16'h0031]=8'h01; mem.mem[16'h0032]=8'h20;
        rst=0; wait_edges=0;
        while(!timing_done && wait_edges<200) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(!timing_done || uut.u_regs.pc!==16'h0120 || uut.u_regs.s!==16'h0032) begin
            $display("FAIL: RTS timing/state done=%b PC=%04x S=%04x",timing_done,uut.u_regs.pc,uut.u_regs.s); $fatal(1);
        end
        generic_count=generic_count+1; rst=1; generic_mode=0;
    end
endtask

task run_swi_case;
    begin
        target_opcode=8'h3f; target_pc=16'h0100; target_cycles=12; timing_done=0; generic_mode=1;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'hfffa]=8'h02; mem.mem[16'hfffb]=8'h00;
        mem.mem[16'h0100]=8'h3f; mem.mem[16'h0101]=8'h20; mem.mem[16'h0102]=8'hfe;
        mem.mem[16'h0200]=8'h86; mem.mem[16'h0201]=8'ha5; mem.mem[16'h0202]=8'h97; mem.mem[16'h0203]=8'h22;
        mem.mem[16'h0204]=8'h3b;
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030;
        rst=0; wait_edges=0;
        while(mem.mem[16'h0022]!==8'ha5 && wait_edges<400) begin @(posedge clk); wait_edges=wait_edges+1; end
        while(uut.u_regs.s!==16'h0030 && wait_edges<600) begin @(posedge clk); wait_edges=wait_edges+1; end
        @(negedge clk);
        if(mem.mem[16'h0022]!==8'ha5 || uut.u_regs.s!==16'h0030) begin
            $display("FAIL: SWI vector/RTI marker=%02x S=%04x",mem.mem[16'h0022],uut.u_regs.s); $fatal(1);
        end
        if(!timing_done) begin $display("FAIL: SWI did not meet manual 12E service assertion"); $fatal(1); end
        generic_count=generic_count+1; rst=1; generic_mode=0;
    end
endtask

task run_wai_case;
    integer n;
    integer wai_cen, wai_timing_started, wai_timing_done, wait_i;
    reg [15:0] pc_after;
    reg [11:0] sleep_uaddr;
    reg [15:0] sleep_addr;
    reg [7:0] sleep_dout;
    reg sleep_wr;
    begin
        matrix_running=0; irq=0; nmi=0; wai_ffff_reads=0; wai_seen=0; wai_trace_started=0; wai_trace_remaining=0; wai_observing=1;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'hfff8]=8'h02; mem.mem[16'hfff9]=8'h00; mem.mem[16'hfffc]=8'h02; mem.mem[16'hfffd]=8'h00;
        mem.mem[16'h0100]=8'h0e; mem.mem[16'h0101]=8'h3e; mem.mem[16'h0102]=8'h86; mem.mem[16'h0103]=8'h5a;
        mem.mem[16'h0104]=8'h97; mem.mem[16'h0105]=8'h23; mem.mem[16'h0106]=8'h20; mem.mem[16'h0107]=8'hfe;
        mem.mem[16'h0200]=8'h86; mem.mem[16'h0201]=8'ha5; mem.mem[16'h0202]=8'h97; mem.mem[16'h0203]=8'h22; mem.mem[16'h0204]=8'h3b;
        mem.mem[16'h0022]=0; mem.mem[16'h0023]=0;
        rst=1; repeat(8) @(negedge clk); uut.u_regs.a=0; uut.u_regs.b=0; uut.u_regs.x=16'h20; uut.u_regs.s=16'h30; rst=0;
        n=0; wai_cen=0; wai_timing_started=0; wai_timing_done=0;
        while(uut.u_regs.s!==16'h0029 && n<400) begin
            @(posedge clk); n=n+1;
            if(cen) begin
                if(!wai_timing_started && uut.u_ctrl.uaddr==12'h3e0) begin wai_timing_started=1; wai_cen=0; end
                else if(wai_timing_started && !wai_timing_done) begin
                    wai_cen=wai_cen+1;
                    if(uut.u_ctrl.halt && uut.u_ctrl.uaddr==12'h3ee) wai_timing_done=1;
                end
            end
        end
        pc_after=uut.u_regs.pc;
        for(wait_i=0;wait_i<40;wait_i=wait_i+1) begin
            @(posedge clk);
            if(cen && wai_timing_started && !wai_timing_done) begin
                wai_cen=wai_cen+1;
                if(uut.u_ctrl.halt && uut.u_ctrl.uaddr==12'h3ee) wai_timing_done=1;
            end
        end
        sleep_uaddr=uut.u_ctrl.uaddr; sleep_addr=addr; sleep_dout=dout; sleep_wr=wr;
        @(negedge clk); cen_pause=1;
        repeat(24) @(posedge clk);
        #1;
        if(uut.u_regs.pc!==pc_after || uut.u_regs.s!==16'h0029 || uut.u_ctrl.uaddr!==sleep_uaddr ||
           addr!==sleep_addr || dout!==sleep_dout || wr!==sleep_wr || !uut.u_ctrl.halt) begin
            $display("FAIL: MC6801 WAI CEN pause changed held PC/uaddr/bus/stack"); $fatal(1);
        end
        $display("CHECKED: MC6801 WAI held PC/uaddr/bus/stack stable through 24 master edges with CEN paused");
        @(negedge clk); cen_pause=0;
        wai_observing=0;
        if(!wai_timing_done || wai_cen+1!=36) begin $display("FAIL: MC6801 WAI entry-to-handover measured %0d CEN samples including the opcode-entry sample, expected 36 (9E)",wai_cen+1); $fatal(1); end
        timed_by_opcode[8'h3e]=timed_by_opcode[8'h3e]+1;
        timing_assertions=timing_assertions+1;
        $display("SPECIAL_TIMING opcode=3e CEN_SAMPLES=%0d E=9",wai_cen+1);
        $display("WAI_TABLE13_OBSERVATION: profile=%s seen=%b FFFF_READS=%0d PC_AT_SP29=%04x PC_AFTER_NO_IRQ=%04x U=%03x S=%04x CCR.I=%b", "MC6801",wai_seen,wai_ffff_reads,pc_after,uut.u_regs.pc,uut.u_ctrl.uaddr,uut.u_regs.s,uut.u_regs.i);
        if(!wai_seen || uut.u_regs.s!==16'h0029) begin
            $display("FAIL: MC6801 WAI did not reach documented stack/handover boundary: seen=%b S=%04x",wai_seen,uut.u_regs.s); $fatal(1);
        end else if(pc_after===16'h0102 && uut.u_regs.pc===pc_after && uut.u_regs.s===16'h0029 &&
                    uut.u_ctrl.uaddr===12'h3ee && uut.u_ctrl.halt && uut.u_regs.i===1'b0) begin
            $display("CHECKED: MC6801 WAI held PC=%04x, S=%04x and halt for 40 master edges; observed FFFF reads=%0d",pc_after,uut.u_regs.s,wai_ffff_reads);
        end else begin
            $display("FAIL: MC6801 WAI no-interrupt hold state PC0=%04x PC1=%04x U=%03x HALT=%b S=%04x I=%b",pc_after,uut.u_regs.pc,uut.u_ctrl.uaddr,uut.u_ctrl.halt,uut.u_regs.s,uut.u_regs.i); $fatal(1);
        end
        generic_count=generic_count+1; rst=1; irq=0; nmi=0; matrix_running=1;
    end
endtask

task run_wai_wake_case;
    input use_nmi;
    integer n, handler_wait, return_wait, restored_seen;
    reg [15:0] saved_pc;
    begin
        matrix_running=0; irq=0; nmi=0; wai_ffff_reads=0; wai_seen=0; wai_trace_started=0; wai_trace_remaining=0; wai_observing=1;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'hfff8]=8'h02; mem.mem[16'hfff9]=8'h00;
        mem.mem[16'hfffc]=8'h02; mem.mem[16'hfffd]=8'h00;
        mem.mem[16'h0100]=use_nmi ? 8'h01 : 8'h0e; mem.mem[16'h0101]=8'h3e;
        mem.mem[16'h0102]=8'h86; mem.mem[16'h0103]=8'h5a;
        mem.mem[16'h0104]=8'h97; mem.mem[16'h0105]=8'h23;
        mem.mem[16'h0106]=8'h20; mem.mem[16'h0107]=8'hfe;
        mem.mem[16'h0200]=8'h86; mem.mem[16'h0201]=8'ha5;
        mem.mem[16'h0202]=8'h97; mem.mem[16'h0203]=8'h22; mem.mem[16'h0204]=8'h3b;
        mem.mem[16'h0022]=0; mem.mem[16'h0023]=0;
        rst=1; repeat(8) @(negedge clk); uut.u_regs.a=8'h12; uut.u_regs.b=8'h34; uut.u_regs.x=16'h5678; uut.u_regs.s=16'h30; {uut.u_regs.h,uut.u_regs.n,uut.u_regs.z,uut.u_regs.v,uut.u_regs.c}=5'b10110; rst=0;
        n=0;
        while(!(uut.u_ctrl.halt && uut.u_ctrl.uaddr==12'h3ee) && n<400) begin
            @(posedge clk); n=n+1;
        end
        saved_pc=uut.u_regs.pc;
        if(n>=400 || !wai_seen || saved_pc!==16'h0102 || uut.u_regs.s!==16'h0029 ||
           uut.u_regs.i!==use_nmi) begin
            $display("FAIL: MC6801 WAI %s entry PC=%04x S=%04x I=%b seen=%b",use_nmi?"NMI":"IRQ",saved_pc,uut.u_regs.s,uut.u_regs.i,wai_seen); $fatal(1);
        end
        repeat(8) @(posedge clk);
        if(uut.u_regs.pc!==saved_pc || uut.u_regs.s!==16'h0029 || uut.u_ctrl.uaddr!==12'h3ee || !uut.u_ctrl.halt) begin
            $display("FAIL: MC6801 WAI did not hold before %s wake",use_nmi?"NMI":"IRQ"); $fatal(1);
        end
        if(use_nmi) begin
            @(negedge clk); irq=1;
            repeat(8) @(posedge clk);
            if(uut.u_regs.pc!==saved_pc || uut.u_regs.s!==16'h0029 || uut.u_ctrl.uaddr!==12'h3ee || !uut.u_ctrl.halt) begin
                $display("FAIL: MC6801 masked IRQ woke WAI while I=1"); $fatal(1);
            end
            $display("CHECKED: MC6801 masked IRQ did not wake WAI while I=1; NMI remains able to wake it");
            @(negedge clk); nmi=1;
        end else begin
            @(negedge clk); irq=1;
        end
        handler_wait=0;
        while(mem.mem[16'h0022]!==8'ha5 && handler_wait<500) begin @(posedge clk); handler_wait=handler_wait+1; end
        if(handler_wait>=500 || uut.u_regs.s!==16'h0029) begin
            $display("FAIL: MC6801 WAI %s wake handler=%02x S=%04x",use_nmi?"NMI":"IRQ",mem.mem[16'h0022],uut.u_regs.s); $fatal(1);
        end
`ifdef NEGATIVE_WAI_OMIT_CC_LOAD
        if(mem.mem[16'h002a]!==8'h2b) begin
            $display("FAIL: MC6801 WAI stale-ALU CCR regression: expected old omitted-load value 2b, got %02x",mem.mem[16'h002a]); $fatal(1);
        end
`else
        if(mem.mem[16'h002a] !== (use_nmi ? 8'hf6 : 8'he6)) begin
            $display("FAIL: MC6801 WAI saved CCR expected %02x, got %02x",use_nmi?8'hf6:8'he6,mem.mem[16'h002a]); $fatal(1);
        end
`endif
        if(mem.mem[16'h002f]!==8'h01 || mem.mem[16'h0030]!==8'h02 ||
           mem.mem[16'h002d]!==8'h56 || mem.mem[16'h002e]!==8'h78 ||
           mem.mem[16'h002c]!==8'h12 || mem.mem[16'h002b]!==8'h34) begin
            $display("FAIL: MC6801 WAI pre-stacked PC/X/A/B frame is incorrect"); $fatal(1);
        end
        $display("WAI_FRAME MC6801 %s PC=%02x%02x X=%02x%02x A=%02x B=%02x CCR=%02x",use_nmi?"NMI":"IRQ",mem.mem[16'h002f],mem.mem[16'h0030],mem.mem[16'h002d],mem.mem[16'h002e],mem.mem[16'h002c],mem.mem[16'h002b],mem.mem[16'h002a]);
        irq=0; nmi=0; return_wait=0; restored_seen=0;
        while(mem.mem[16'h0023]!==8'h5a && return_wait<700) begin
            @(negedge clk); return_wait=return_wait+1;
            if(cen && uut.u_ctrl.uaddr==12'h860 && uut.u_regs.pc==16'h0102) begin
                restored_seen=1;
                if(uut.u_regs.a!==8'h12 || uut.u_regs.b!==8'h34 || uut.u_regs.x!==16'h5678 ||
                   {uut.u_regs.h,uut.u_regs.i,uut.u_regs.n,uut.u_regs.z,uut.u_regs.v,uut.u_regs.c} !== {1'b1,use_nmi,4'b0110})
                    $fatal(1,"independent WAI full context restoration failed");
            end
        end
        if(!restored_seen) $fatal(1,"independent WAI restore observer did not run");
        $display("INDEPENDENT: WAI distinct A12/B34/X5678/CCR restored before next LDA");
        wai_observing=0;
        if(return_wait>=700 || uut.u_regs.s!==16'h0030 || uut.u_regs.pc!==16'h0106) begin
            $display("FAIL: MC6801 WAI %s RTI resume marker=%02x PC=%04x S=%04x",use_nmi?"NMI":"IRQ",mem.mem[16'h0023],uut.u_regs.pc,uut.u_regs.s); $fatal(1);
        end
        $display("CHECKED: MC6801 WAI %s wake used one pre-stacked frame, RTI restored S, and mainline resumed",use_nmi?"NMI":"IRQ");
        generic_count=generic_count+1; rst=1; irq=0; nmi=0; matrix_running=1;
    end
endtask

task run_irq_rti_case;
    input use_nmi;
    integer service_wait, return_wait, service_cen, service_started, service_entry_seen;
    reg [15:0] pause_pc, pause_sp, pause_addr;
    reg [11:0] pause_uaddr;
    reg [7:0] pause_dout;
    reg pause_wr;
    begin
        matrix_running=1;
        irq=use_nmi ? 0 : 1; nmi=0;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'hfff8]=8'h02; mem.mem[16'hfff9]=8'h00;
        mem.mem[16'hfffc]=8'h02; mem.mem[16'hfffd]=8'h10;
        mem.mem[16'h0100]=8'h86; mem.mem[16'h0101]=8'h33; // LDAA #$33 (masked)
        mem.mem[16'h0102]=8'h97; mem.mem[16'h0103]=8'h24; // STAA $24 (masked)
        mem.mem[16'h0104]=8'h0e;                         // CLI
        mem.mem[16'h0105]=8'h01;                         // NOP, interrupt boundary
        mem.mem[16'h0106]=8'h86; mem.mem[16'h0107]=8'h5a;
        mem.mem[16'h0108]=8'h97; mem.mem[16'h0109]=8'h23;
        mem.mem[16'h010a]=8'h20; mem.mem[16'h010b]=8'hfe;
        mem.mem[16'h0200]=8'h86; mem.mem[16'h0201]=8'ha5;
        mem.mem[16'h0202]=8'h97; mem.mem[16'h0203]=8'h22;
        mem.mem[16'h0204]=8'h3b;                         // RTI
        mem.mem[16'h0210]=8'h86; mem.mem[16'h0211]=8'ha5;
        mem.mem[16'h0212]=8'h97; mem.mem[16'h0213]=8'h22;
        mem.mem[16'h0214]=8'h3b;
        mem.mem[16'h0022]=0; mem.mem[16'h0023]=0; mem.mem[16'h0024]=0;
        rst=1; repeat(8) @(negedge clk);
        uut.u_regs.a=0; uut.u_regs.b=8'h34; uut.u_regs.x=16'h0020; uut.u_regs.s=16'h0030;
        rst=0;
        if(use_nmi) nmi=1;
        service_wait=0; service_cen=0; service_started=0; service_entry_seen=0;
        while(!service_entry_seen && service_wait<500) begin
            @(posedge clk); service_wait=service_wait+1;
            if(cen) begin
                if(!service_started && uut.u_ctrl.uaddr==12'hc70) begin
                    service_started=1; service_cen=0;
                    $display("IRQ_SERVICE_START kind=%s PC=%04x U=%03x A=%04x W=%b",use_nmi ? "NMI" : "IRQ",uut.u_regs.pc,uut.u_ctrl.uaddr,addr,wr);
                end else if(service_started && !service_entry_seen) begin
                    service_cen=service_cen+1;
                    if(service_cen==10) begin
                        @(negedge clk); cen_pause=1;
                        pause_pc=uut.u_regs.pc; pause_sp=uut.u_regs.s; pause_uaddr=uut.u_ctrl.uaddr;
                        pause_addr=addr; pause_dout=dout; pause_wr=wr;
                        repeat(24) @(posedge clk); #1;
                        if(uut.u_regs.pc!==pause_pc || uut.u_regs.s!==pause_sp || uut.u_ctrl.uaddr!==pause_uaddr ||
                           addr!==pause_addr || dout!==pause_dout || wr!==pause_wr)
                            $fatal(1,"independent paused service state/bus changed");
                        @(negedge clk); cen_pause=0;
                        $display("INDEPENDENT: paused IRQ/NMI service held state/bus for 24 master clocks");
                    end
                    $display("IRQ_SERVICE_STEP kind=%s sample=%0d PC=%04x U=%03x NI=%b HALT=%b STACK=%b A=%04x W=%b DIN=%02x",use_nmi ? "NMI" : "IRQ",service_cen,uut.u_regs.pc,uut.u_ctrl.uaddr,uut.u_ctrl.ni,uut.u_ctrl.halt,uut.u_ctrl.stack_busy,addr,wr,din);
                    if(uut.u_ctrl.uaddr==12'h860 && uut.u_regs.pc==(use_nmi ? 16'h0210 : 16'h0200) && !uut.u_ctrl.stack_busy) begin
                        service_entry_seen=1;
                        $display("IRQ_SERVICE_HANDLER kind=%s PC=%04x U=%03x A=%04x W=%b INTERVAL_CEN=%0d",use_nmi ? "NMI" : "IRQ",uut.u_regs.pc,uut.u_ctrl.uaddr,addr,wr,service_cen);
                    end
                end
            end
        end
        if(service_wait>=500) begin $display("FAIL: %s service did not reach opcode-entry boundary",use_nmi ? "NMI" : "IRQ"); $fatal(1); end
        if(!service_entry_seen) begin $display("FAIL: MC6801 %s calibrated handler opcode boundary not observed",use_nmi ? "NMI" : "IRQ"); $fatal(1); end
        if(service_cen==48) $display("CHECKED: MC6801 %s C70→U860 service interval matches manual 12E",use_nmi ? "NMI" : "IRQ");
        else begin $display("FAIL: MC6801 %s service measured %0d CEN intervals; manual expects 48 (12E)",use_nmi ? "NMI" : "IRQ",service_cen); $fatal(1); end
        irq=0; nmi=0;
        return_wait=0;
        while(mem.mem[16'h0023]!==8'h5a && return_wait<700) begin @(posedge clk); return_wait=return_wait+1; end
        if(return_wait>=700) begin $display("FAIL: IRQ handler/RTI did not return to mainline"); $fatal(1); end
        if(mem.mem[16'h0022]!==8'ha5 || mem.mem[16'h0024]!==8'h33 || uut.u_regs.s!==16'h0030) begin
            $display("FAIL: IRQ mask/vector/RTI state markers handler=%02x masked=%02x S=%04x",mem.mem[16'h0022],mem.mem[16'h0024],uut.u_regs.s); $fatal(1);
        end
        $display("CHECKED: MC6801 %s vector/state/RTI flow; IRQ masked before CLI=%0d, ISR CEN samples=%0d wait=%0d+%0d master edges",use_nmi ? "NMI" : "IRQ",!use_nmi,service_cen,service_wait,return_wait);
        irq=0; rst=1; matrix_running=0;
    end
endtask

task run_ba_ext_halt_case;
    integer n, held_cen;
    reg [15:0] saved_pc, saved_uaddr, saved_addr;
    reg [7:0] saved_dout;
    reg saved_wr;
    begin
        matrix_running=1; irq=0; nmi=0; ext_halt=0; ext_write_watch=0; ext_write_count=0;
        generic_mode=1; target_pc=16'hffff; target_opcode=8'hff;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'h0100]=8'h01; mem.mem[16'h0101]=8'h01;
        mem.mem[16'h0102]=8'h01; mem.mem[16'h0103]=8'h01;
        mem.mem[16'h0104]=8'h86; mem.mem[16'h0105]=8'ha5;
        mem.mem[16'h0106]=8'h97; mem.mem[16'h0107]=8'h20;
        mem.mem[16'h0108]=8'h20; mem.mem[16'h0109]=8'hfe;
        mem.mem[16'h0020]=0;
        rst=1; repeat(8) @(negedge clk); uut.u_regs.s=16'h0030; rst=0;
        // Stop before the first known NOP dispatch, with no interrupt request.
        n=0;
        while(!(uut.u_ctrl.ni && uut.md[7:0]==8'h01) && n<300) begin @(negedge clk); n=n+1; end
        if(n>=300) begin $display("FAIL: MC6801 ext_halt could not find NOP NI boundary"); $fatal(1); end
        ext_halt=1;
        n=0; while(!ba && n<100) begin @(negedge clk); n=n+1; end
        if(!ba) begin $display("FAIL: MC6801 ext_halt did not assert BA"); $fatal(1); end
        saved_pc=uut.u_regs.pc; saved_uaddr=uut.u_ctrl.uaddr; saved_addr=addr; saved_dout=dout; saved_wr=wr;
        if(saved_wr) begin $display("FAIL: MC6801 BA grant began while a write was active"); $fatal(1); end
        held_cen=0; n=0;
        while(held_cen<8 && n<200) begin
            @(posedge clk); n=n+1;
            if(cen) begin
                #1;
                held_cen=held_cen+1;
                if(!ba || uut.u_regs.pc!==saved_pc || uut.u_ctrl.uaddr!==saved_uaddr ||
                   addr!==saved_addr || dout!==saved_dout || wr!==saved_wr) begin
                    $display("FAIL: MC6801 ext_halt changed grant/bus/state during CEN hold"); $fatal(1);
                end
            end
        end
        if(held_cen!=8) begin $display("FAIL: MC6801 ext_halt hold did not reach 8 CEN samples"); $fatal(1); end
        ext_write_watch=1; ext_halt=0;
        n=0; while((!mem.mem[16'h0020] || ba) && n<500) begin @(posedge clk); n=n+1; end
        ext_write_watch=0;
        if(n>=500 || mem.mem[16'h0020]!==8'ha5 || ba || ext_write_count!=1) begin
            $display("FAIL: MC6801 ext_halt release marker=%02x BA=%b writes=%0d",mem.mem[16'h0020],ba,ext_write_count); $fatal(1);
        end
        $display("CHECKED: MC6801 ext_halt BA grant held stable for 8 CEN samples, released, and resumed one mainline store");
        generic_count=generic_count+1; rst=1; generic_mode=0; matrix_running=0; ext_halt=0;
    end
endtask

task run_short_nmi_pulse_case;
    integer n, pulse_samples;
    begin
        matrix_running=1; irq=0; nmi=0; ext_halt=0; generic_mode=1; target_pc=16'hffff; target_opcode=8'hff;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'hfffc]=8'h02; mem.mem[16'hfffd]=8'h00;
        mem.mem[16'h0100]=8'h01; mem.mem[16'h0101]=8'h0e; // pulse while I=1, then CLI
        mem.mem[16'h0102]=8'h86; mem.mem[16'h0103]=8'h5a;
        mem.mem[16'h0104]=8'h97; mem.mem[16'h0105]=8'h23;
        mem.mem[16'h0106]=8'h20; mem.mem[16'h0107]=8'hfe;
        mem.mem[16'h0200]=8'h86; mem.mem[16'h0201]=8'ha5;
        mem.mem[16'h0202]=8'h97; mem.mem[16'h0203]=8'h22; mem.mem[16'h0204]=8'h3b;
        mem.mem[16'h0022]=0; mem.mem[16'h0023]=0;
        rst=1; repeat(8) @(negedge clk); uut.u_regs.s=16'h0030; rst=0;
        // Exactly one enabled sample; I remains set and no analog sub-CEN claim is made.
        @(negedge clk); while(!cen) @(negedge clk);
        nmi=1; @(posedge clk); if(!cen) begin $display("FAIL: MC6801 NMI pulse sample was not enabled"); $fatal(1); end
        pulse_samples=1; @(negedge clk); nmi=0;
        if(uut.u_regs.i!==1'b1) begin $display("FAIL: MC6801 NMI pulse was not issued while masked"); $fatal(1); end
        irq=1; // keep IRQ asserted but masked while the already-recognized NMI is serviced
        n=0; while(uut.u_regs.pc!==16'h0200 && n<500) begin @(posedge clk); n=n+1; end
        if(n>=500) begin $display("FAIL: MC6801 one-CEN NMI edge recognized with I=1 did not reach its vector after CLI"); $fatal(1); end
        irq=0; n=0;
        while((mem.mem[16'h0022]!==8'ha5 || mem.mem[16'h0023]!==8'h5a) && n<700) begin @(posedge clk); n=n+1; end
        if(n>=700 || uut.u_regs.s!==16'h0030 || mem.mem[16'h0022]!==8'ha5 || mem.mem[16'h0023]!==8'h5a) begin
            $display("FAIL: MC6801 one-CEN NMI pulse handler/RTI/resume marker mismatch PC=%04x S=%04x ISR=%02x main=%02x",uut.u_regs.pc,uut.u_regs.s,mem.mem[16'h0022],mem.mem[16'h0023]); $fatal(1);
        end
        $display("CHECKED: MC6801 one-enabled-CEN NMI pulse was recognized while I=1; RTI returned to execute CLI, ISR restored SP, and mainline resumed");
        generic_count=generic_count+1; rst=1; generic_mode=0; matrix_running=0; irq=0; nmi=0;
    end
endtask

task run_signed_pc_wrap_case;
    integer n, pass_id;
    begin
        matrix_running=1; irq=0; nmi=0; generic_mode=1; target_pc=16'hffff; target_opcode=8'hff;
        for(pass_id=0; pass_id<2; pass_id=pass_id+1) begin
            mem.mem[16'h0020]=0; mem.mem[16'h0021]=0;
            if(pass_id==0) begin
                // BRA $FFFC + 2-byte instruction +4 => $0002; $FFFE is poison fallthrough.
                mem.mem[16'hfffe]=8'hff; mem.mem[16'hffff]=8'hfc;
                mem.mem[16'hfffc]=8'h20; mem.mem[16'hfffd]=8'h04;
                mem.mem[16'h0002]=8'h86; mem.mem[16'h0003]=8'ha5;
                mem.mem[16'h0004]=8'h97; mem.mem[16'h0005]=8'h20;
                mem.mem[16'h0006]=8'h20; mem.mem[16'h0007]=8'hfe;
            end else begin
                // BRA $0030 +2 -64 => $FFF2, with a poisoned fallthrough marker.
                mem.mem[16'hfffe]=8'h00; mem.mem[16'hffff]=8'h30;
                mem.mem[16'h0030]=8'h20; mem.mem[16'h0031]=8'hc0;
                mem.mem[16'h0032]=8'h86; mem.mem[16'h0033]=8'h11;
                mem.mem[16'h0034]=8'h97; mem.mem[16'h0035]=8'h21;
                mem.mem[16'hfff2]=8'h86; mem.mem[16'hfff3]=8'ha5;
                mem.mem[16'hfff4]=8'h97; mem.mem[16'hfff5]=8'h20;
                mem.mem[16'hfff6]=8'h20; mem.mem[16'hfff7]=8'hfe;
            end
            rst=1; repeat(8) @(negedge clk); uut.u_regs.s=16'h0030; rst=0;
            if(pass_id==0) begin
                n=0; while(uut.u_regs.pc!==16'hfffc && n<100) begin @(negedge clk); n=n+1; end
                if(n>=100) begin $display("FAIL: {label} forward-wrap reset vector did not load $FFFC"); $fatal(1); end
                // Reset-vector bytes have been consumed; make the skipped path a poison instruction.
                mem.mem[16'hfffe]=8'h86; mem.mem[16'hffff]=8'h11;
            end
            n=0; while(mem.mem[16'h0020]!==8'ha5 && n<400) begin @(posedge clk); n=n+1; end
            if(n>=400 || mem.mem[16'h0020]!==8'ha5 || mem.mem[16'h0021]!==8'h00) begin
                $display("FAIL: MC6801 signed branch wrap pass=%0d marker=%02x poison=%02x PC=%04x",pass_id,mem.mem[16'h0020],mem.mem[16'h0021],uut.u_regs.pc); $fatal(1);
            end
        end
        $display("CHECKED: MC6801 signed relative branch wrapped PC both forward $FFFC->$0002 and backward $0032->$FFF2; poison fallthroughs untouched");
        generic_count=generic_count+2; rst=1; generic_mode=0; matrix_running=0;
    end
endtask

task run_stack_wrap_case;
    integer n;
    begin
        matrix_running=1; irq=0; nmi=0; generic_mode=1; target_pc=16'h0100; target_opcode=8'h36; target_cycles=3; timing_done=0;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'h0100]=8'h36; mem.mem[16'h0101]=8'h32; mem.mem[16'h0102]=8'h01;
        mem.mem[16'hffff]=0; mem.mem[16'h0000]=0;
        rst=1; repeat(8) @(negedge clk); uut.u_regs.a=8'h5a; uut.u_regs.s=16'h0000; rst=0;
        n=0; while(uut.u_regs.pc!==16'h0100 && n<100) begin @(negedge clk); n=n+1; end
        if(n>=100) begin $display("FAIL: stack-wrap reset vector did not load $0100"); $fatal(1); end
        mem.mem[16'hffff]=8'hc3; // poison the unused wrap address after reset vector fetch
        n=0; while(!timing_done && n<200) begin @(posedge clk); n=n+1; end
        if(n>=200 || uut.u_regs.s!==16'hffff || mem.mem[16'h0000]!==8'h5a || mem.mem[16'hffff]!==8'hc3) begin
            $display("FAIL: MC6801 PSHA at SP=0000 wrap result S=%04x [0000]=%02x",uut.u_regs.s,mem.mem[16'h0000]); $fatal(1);
        end
        @(negedge clk); uut.u_regs.a=8'h00;
        target_pc=16'h0101; target_opcode=8'h32; target_cycles=4; timing_done=0;
        n=0; while(!timing_done && n<200) begin @(posedge clk); n=n+1; end
        if(n>=200 || uut.u_regs.a!==8'h5a || uut.u_regs.s!==16'h0000 || mem.mem[16'hffff]!==8'hc3) begin
            $display("FAIL: MC6801 PULA at SP=FFFF wrap result A=%02x S=%04x poison[FFFF]=%02x",uut.u_regs.a,uut.u_regs.s,mem.mem[16'hffff]); $fatal(1);
        end
        $display("CHECKED: MC6801 PSHA/PULA wrapped 16-bit SP through FFFF/0000 and preserved stack byte");
        generic_count=generic_count+1; rst=1; generic_mode=0; matrix_running=0;
    end
endtask

task run_indexed_ea_wrap_case;
    integer n;
    begin
        matrix_running=1; irq=0; nmi=0; generic_mode=1; target_pc=16'h0100; target_opcode=8'ha6; target_cycles=4; timing_done=0;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'h0100]=8'ha6; mem.mem[16'h0101]=8'h30; // X=$fff0 + unsigned offset $30 => $0020
        mem.mem[16'h0102]=8'h97; mem.mem[16'h0103]=8'h21;
        mem.mem[16'h0104]=8'h20; mem.mem[16'h0105]=8'hfe;
        mem.mem[16'h0020]=8'h5a; mem.mem[16'h0021]=0;
        rst=1; repeat(8) @(negedge clk); uut.u_regs.a=0; uut.u_regs.x=16'hfff0; uut.u_regs.s=16'h0030; rst=0;
        n=0; while(!timing_done && n<250) begin @(posedge clk); n=n+1; end
        if(n>=250 || uut.u_regs.a!==8'h5a) begin $display("FAIL: MC6801 indexed effective-address carry wrap A=%02x",uut.u_regs.a); $fatal(1); end
        n=0; while(mem.mem[16'h0021]!==8'h5a && n<200) begin @(posedge clk); n=n+1; end
        if(n>=200 || mem.mem[16'h0021]!==8'h5a) begin $display("FAIL: MC6801 indexed wrap store marker=%02x",mem.mem[16'h0021]); $fatal(1); end
        $display("CHECKED: MC6801 indexed X=$FFF0 plus unsigned offset $30 carried to effective address $0020");
        generic_count=generic_count+1; rst=1; generic_mode=0; matrix_running=0;
    end
endtask

task run_manual_irq_vector_case;
    input integer source;
    input [15:0] expected_pc;
    reg [15:0] oracle_pc;
    integer n;
    begin
        matrix_running=1; irq=0; nmi=0; irq_icf=0; irq_ocf=0; irq_tof=0; oracle_pc=expected_pc;
`ifdef NEGATIVE_VECTOR
        if(source==0) oracle_pc=expected_pc^16'h0001;
`endif
        irq_sci=0; irq_cmf=0; irq2=0; generic_mode=1; target_pc=16'hffff; target_opcode=8'hff;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'hfff8]=8'h02; mem.mem[16'hfff9]=8'h00;
        mem.mem[16'hfff6]=8'h02; mem.mem[16'hfff7]=8'h10;
        mem.mem[16'hfff4]=8'h02; mem.mem[16'hfff5]=8'h20;
        mem.mem[16'hfff2]=8'h02; mem.mem[16'hfff3]=8'h30;
        mem.mem[16'hfff0]=8'h02; mem.mem[16'hfff1]=8'h40;
        mem.mem[16'h0100]=8'h0e; mem.mem[16'h0101]=8'h20; mem.mem[16'h0102]=8'hfe;
        rst=1; repeat(8) @(negedge clk); uut.u_regs.s=16'h0030; rst=0;
        case(source)
            0: irq=1;
            1: irq_icf=1;
            2: irq_ocf=1;
            3: irq_tof=1;
            4: irq_sci=1;
            5: irq_cmf=1;
            6: irq2=1;
            default: begin $display("FAIL: invalid interrupt source case %0d",source); $fatal(1); end
        endcase
        n=0; while(uut.u_regs.pc!==expected_pc && n<500) begin @(posedge clk); n=n+1; end
        irq=0; irq_icf=0; irq_ocf=0; irq_tof=0; irq_sci=0; irq_cmf=0; irq2=0;
        if(n>=500 || uut.u_regs.pc!==oracle_pc) begin
            $display("FAIL: source %0d manual vector target %04x; PC=%04x",source,oracle_pc,uut.u_regs.pc); $fatal(1);
        end
        $display("CHECKED: MC6801 IRQ source %0d reached manual vector target %04x",source,expected_pc);
        generic_count=generic_count+1; rst=1; generic_mode=0; matrix_running=0;
    end
endtask

task run_nmi_over_irq_case;
    integer n;
    begin
        matrix_running=1; irq=0; nmi=0; generic_mode=1; target_pc=16'hffff; target_opcode=8'hff;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'hfffc]=8'h02; mem.mem[16'hfffd]=8'h50;
        mem.mem[16'hfff8]=8'h02; mem.mem[16'hfff9]=8'h00;
        mem.mem[16'h0100]=8'h0e; mem.mem[16'h0101]=8'h01; mem.mem[16'h0102]=8'h20; mem.mem[16'h0103]=8'hfe;
        rst=1; repeat(8) @(negedge clk); uut.u_regs.s=16'h0030; rst=0;
        n=0; while(!(uut.u_regs.pc===16'h0101 && uut.u_ctrl.uaddr===12'h010 && uut.u_regs.i===1'b0) && n<200) begin @(negedge clk); n=n+1; end
        if(n>=200) begin $display("FAIL: MC6801 CLI did not reach unmasked NOP entry before simultaneous requests"); $fatal(1); end
        irq=1; nmi=1;
        n=0;
        while(!(cen && uut.u_ctrl.ni) && n<100) begin @(posedge clk); n=n+1; end
        if(n>=100 || uut.u_regs.i!==1'b0 || !irq || !nmi || uut.u_ctrl.pendng!==1'b1) begin
            $display("FAIL: MC6801 simultaneous IRQ/NMI were not pending at arbitration boundary I=%b irq=%b nmi=%b pendng=%b PC=%04x U=%03x",uut.u_regs.i,irq,nmi,uut.u_ctrl.pendng,uut.u_regs.pc,uut.u_ctrl.uaddr); $fatal(1);
        end
        $display("PRIORITY-BOUNDARY MC6801 I=%b IRQ=%b NMI=%b pendng=%b PC=%04x U=%03x",uut.u_regs.i,irq,nmi,uut.u_ctrl.pendng,uut.u_regs.pc,uut.u_ctrl.uaddr);
        n=0; while(uut.u_regs.pc!==16'h0250 && uut.u_regs.pc!==16'h0200 && n<500) begin @(posedge clk); n=n+1; end
        irq=0; nmi=0;
        if(n>=500 || uut.u_regs.pc!==16'h0250) begin $display("FAIL: MC6801 NMI did not win over simultaneously eligible IRQ; PC=%04x",uut.u_regs.pc); $fatal(1); end
        $display("CHECKED: MC6801 NMI took priority over simultaneously eligible IRQ at an unmasked opcode boundary");
        generic_count=generic_count+1; rst=1; generic_mode=0; matrix_running=0;
    end
endtask

task run_manual_irq_priority_case;
    integer n;
    begin
        matrix_running=1; irq=0; nmi=0; irq_icf=0; irq_ocf=0; irq_tof=0; generic_mode=1; target_pc=16'hffff; target_opcode=8'hff;
        mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
        mem.mem[16'hfff8]=8'h02; mem.mem[16'hfff9]=8'h00;
        mem.mem[16'hfff6]=8'h02; mem.mem[16'hfff7]=8'h10;
        mem.mem[16'hfff4]=8'h02; mem.mem[16'hfff5]=8'h20;
        mem.mem[16'hfff2]=8'h02; mem.mem[16'hfff3]=8'h30;
        mem.mem[16'h0100]=8'h0e; mem.mem[16'h0101]=8'h20; mem.mem[16'h0102]=8'hfe;
        rst=1; repeat(8) @(negedge clk); rst=0;
        irq=1; irq_icf=1; irq_ocf=1; irq_tof=1;
        n=0; while(uut.u_regs.pc!==16'h0200 && n<500) begin @(posedge clk); n=n+1; end
        irq=0; irq_icf=0; irq_ocf=0; irq_tof=0;
        if(n>=500 || uut.u_regs.pc!==16'h0200) begin $display("FAIL: MC6801 all-active IRQ/ICF/OCF/TOF did not select external IRQ1; PC=%04x",uut.u_regs.pc); $fatal(1); end
        $display("CHECKED: MC6801 all-active IRQ/ICF/OCF/TOF selected highest-priority IRQ1 vector");
        generic_count=generic_count+1; rst=1; generic_mode=0; matrix_running=0;
    end
endtask

initial begin
    $dumpfile("test.lxt"); $dumpvars;
    // Warm up with three NOPs, then exercise taken/not-taken branch flow.
    mem.mem[16'hfffe]=8'h01; mem.mem[16'hffff]=8'h00;
    mem.mem[16'h0001]=8'ha5; // PULA's deterministic stack byte after reset S=0
    mem.mem[16'h0100]=8'h01; mem.mem[16'h0101]=8'h01; mem.mem[16'h0102]=8'h01;
    mem.mem[16'h0103]=8'h86; mem.mem[16'h0104]=8'h00; // LDAA #0
    mem.mem[16'h0105]=8'h27; mem.mem[16'h0106]=8'h04; // BEQ $010B
    mem.mem[16'h0107]=8'h86; mem.mem[16'h0108]=8'hee; // skipped sentinel
    mem.mem[16'h0109]=8'h97; mem.mem[16'h010a]=8'h21; // STAA $21 if not skipped
    mem.mem[16'h010b]=8'h26; mem.mem[16'h010c]=8'h02; // BNE not taken
    mem.mem[16'h010d]=8'h86; mem.mem[16'h010e]=8'h5a; // LDAA #$5A
    mem.mem[16'h010f]=8'h97; mem.mem[16'h0110]=8'h20; // STAA $20
    mem.mem[16'h0111]=8'h32; mem.mem[16'h0112]=8'h01; // PULA; NOP
    repeat (8) @(negedge clk);
    rst=0;
    while (ticks < 500) begin
        @(posedge clk);
        ticks=ticks+1;
        if (mem.mem[16'h0020] === 8'h5a && uut.u_regs.a === 8'ha5 && timed_by_opcode[8'h32]!=0) begin
            if (uut.u_regs.a !== 8'ha5 || uut.u_regs.s !== 16'h0001) begin
                $display("FAIL: PULA result A=%02x S=%04x memory=%02x",uut.u_regs.a,uut.u_regs.s,mem.mem[16'h0020]);
                $fatal(1);
            end
            if (mem.mem[16'h0021] !== 8'h00) begin
                $display("FAIL: branch control sentinel changed or adjacent memory overwritten");
                $fatal(1);
            end
            if (uut.u_regs.s !== 16'h0001 || count_01 != 3 || count_86 != 2 || count_27 != 1 || count_26 != 1) begin
                $display("FAIL: expected timing observations S=%04x NOP=%0d A=%0d BEQ=%0d BNE=%0d",uut.u_regs.s,count_01,count_86,count_27,count_26);
                $fatal(1);
            end
            $display("CHECKED: MC6801 base cases at tick %0d; starting exhaustive branch-condition matrix",ticks);
            // Exercise every branch against all 16 N/Z/V/C combinations. Flags are
            // deterministic architectural pre-state; branch target/fallthrough leave
            // distinct A markers and both paths are required to match the manual rule.
            matrix_running=1;
            for (branch_op=0; branch_op<16; branch_op=branch_op+1) begin
                for (flags=0; flags<16; flags=flags+1) begin
                    mem.mem[16'h0100]=8'h20+branch_op[7:0];
                    mem.mem[16'h0101]=8'h06;
                    mem.mem[16'h0102]=8'h86; mem.mem[16'h0103]=8'h11;
                    mem.mem[16'h0104]=8'h20; mem.mem[16'h0105]=8'hfe;
                    mem.mem[16'h0106]=8'h01; mem.mem[16'h0107]=8'h01;
                    mem.mem[16'h0108]=8'h86; mem.mem[16'h0109]=8'h22;
                    mem.mem[16'h010a]=8'h20; mem.mem[16'h010b]=8'hfe;
                    case (branch_op)
                        0: expected_taken=1'b1;
                        1: expected_taken=1'b0;
                        2: expected_taken=!(flags[0] || flags[2]);
                        3: expected_taken= (flags[0] || flags[2]);
                        4: expected_taken=!flags[0];
                        5: expected_taken= flags[0];
                        6: expected_taken=!flags[2];
                        7: expected_taken= flags[2];
                        8: expected_taken=!flags[1];
                        9: expected_taken= flags[1];
                        10: expected_taken=!flags[3];
                        11: expected_taken= flags[3];
                        12: expected_taken=(flags[3] == flags[1]);
                        13: expected_taken=(flags[3] != flags[1]);
                        14: expected_taken=!flags[2] && (flags[3] == flags[1]);
                        15: expected_taken= flags[2] || (flags[3] != flags[1]);
                    endcase
                    rst=1;
                    repeat (8) @(negedge clk);
                    uut.u_regs.n=flags[3]; uut.u_regs.z=flags[2];
                    uut.u_regs.v=flags[1]; uut.u_regs.c=flags[0];
                    rst=0;
                    wait_edges=0;
                    while (uut.u_regs.a !== 8'h11 && uut.u_regs.a !== 8'h22 && wait_edges<160) begin
                        @(posedge clk); wait_edges=wait_edges+1;
                    end
                    if (wait_edges>=160 || uut.u_regs.a !== (expected_taken ? 8'h22 : 8'h11)) begin
                        $display("FAIL: branch %02x flags N/Z/V/C=%b expected_taken=%b got A=%02x",8'h20+branch_op,flags,expected_taken,uut.u_regs.a);
                        $fatal(1);
                    end
                end
            end
            $display("CHECKED: MC6801 all 256 branch/CCR combinations; manual branch cycle assertion on every executed branch");
            for (branch_op=0; branch_op<2; branch_op=branch_op+1) begin
                // Two accumulator opcode rows: arithmetic/logic/load/store modes.
                for (flags=0; flags<4; flags=flags+1) begin
                    case(flags)
                        0: run_acc_case((branch_op ? 8'hc0 : 8'h80)+0,0,8'h56);
                        1: run_acc_case((branch_op ? 8'hc0 : 8'h80)+0,1,8'h56);
                        2: run_acc_case((branch_op ? 8'hc0 : 8'h80)+0,2,8'h56);
                        3: run_acc_case((branch_op ? 8'hc0 : 8'h80)+0,3,8'h56);
                    endcase
                    run_acc_case((branch_op ? 8'hc0 : 8'h80)+1,flags[1:0],8'h56);
                    run_acc_case((branch_op ? 8'hc0 : 8'h80)+2,flags[1:0],8'h56);
                    run_acc_case((branch_op ? 8'hc0 : 8'h80)+4,flags[1:0],8'h56);
                    run_acc_case((branch_op ? 8'hc0 : 8'h80)+5,flags[1:0],8'h56);
                    run_acc_case((branch_op ? 8'hc0 : 8'h80)+6,flags[1:0],8'h56);
                    run_acc_case((branch_op ? 8'hc0 : 8'h80)+8,flags[1:0],8'h56);
                    run_acc_case((branch_op ? 8'hc0 : 8'h80)+9,flags[1:0],8'h56);
                    run_acc_case((branch_op ? 8'hc0 : 8'h80)+10,flags[1:0],8'h56);
                    run_acc_case((branch_op ? 8'hc0 : 8'h80)+11,flags[1:0],8'h56);
                end
                run_acc_case((branch_op ? 8'hc0 : 8'h80)+7,1,8'h56);
                run_acc_case((branch_op ? 8'hc0 : 8'h80)+7,2,8'h56);
                run_acc_case((branch_op ? 8'hc0 : 8'h80)+7,3,8'h56);
            end
            for (flags=0; flags<4; flags=flags+1) begin
                run_word_case(8'hc3,flags[1:0],0,16'h2468);
                run_word_case(8'h83,flags[1:0],0,16'h0000);
                run_word_case(8'hcc,flags[1:0],0,16'h1234);
                run_word_case(8'h8c,flags[1:0],4,16'h0020);
                run_word_case(8'h8e,flags[1:0],2,16'h1234);
                run_word_case(8'hce,flags[1:0],1,16'h1234);
            end
            for (flags=1; flags<4; flags=flags+1) begin
                run_word_case(8'h8f,flags[1:0],3,16'h0030);
                run_word_case(8'hcf,flags[1:0],3,16'h0020);
            end
            for (branch_op=0; branch_op<2; branch_op=branch_op+1) begin
                run_unary_case(8'h60,branch_op[0]); run_unary_case(8'h63,branch_op[0]);
                run_unary_case(8'h64,branch_op[0]); run_unary_case(8'h66,branch_op[0]);
                run_unary_case(8'h67,branch_op[0]); run_unary_case(8'h68,branch_op[0]);
                run_unary_case(8'h69,branch_op[0]); run_unary_case(8'h6a,branch_op[0]);
                run_unary_case(8'h6c,branch_op[0]); run_unary_case(8'h6d,branch_op[0]);
                run_unary_case(8'h6f,branch_op[0]);
            end
            for (branch_op=0; branch_op<2; branch_op=branch_op+1) begin
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+0);
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+3);
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+4);
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+6);
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+7);
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+8);
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+9);
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+10);
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+12);
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+13);
                run_acc_unary_case((branch_op ? 8'h50 : 8'h40)+15);
            end
            run_implied_case(8'h04,3); run_implied_case(8'h05,3);
            run_implied_case(8'h06,2); run_implied_case(8'h07,2);
            run_implied_case(8'h08,3); run_implied_case(8'h09,3);
            run_implied_case(8'h0a,2); run_implied_case(8'h0b,2);
            run_implied_case(8'h0c,2); run_implied_case(8'h0d,2);
            run_implied_case(8'h0e,2); run_implied_case(8'h0f,2);
            run_implied_case(8'h10,2); run_implied_case(8'h11,2);
            run_implied_case(8'h16,2); run_implied_case(8'h17,2);
            run_implied_case(8'h1b,2);
            run_daa_case();
            run_stack_index_case(8'h30); run_stack_index_case(8'h31);
            run_stack_index_case(8'h33); run_stack_index_case(8'h34);
            run_stack_index_case(8'h35); run_stack_index_case(8'h36);
            run_stack_index_case(8'h37); run_stack_index_case(8'h38);
            run_stack_index_case(8'h3a); run_stack_index_case(8'h3c);
            run_jump_case(8'h6e,0); run_jump_case(8'h7e,1);
            run_jump_case(8'h9d,2); run_jump_case(8'had,3); run_jump_case(8'hbd,4); run_jump_case(8'h8d,5);
            run_std_case(0); run_std_case(1); run_std_case(2);
            run_rts_case(); run_swi_case(); run_wai_case();
            run_wai_wake_case(0); run_wai_wake_case(1);
            run_cen_pause_case();
            run_mul_case();
            run_ba_ext_halt_case();
            run_short_nmi_pulse_case();
            run_signed_pc_wrap_case();
            run_stack_wrap_case();
            run_indexed_ea_wrap_case();
            run_irq_rti_case(0);
            run_irq_rti_case(1);
            run_manual_irq_vector_case(0,16'h0200);
            run_manual_irq_vector_case(1,16'h0210);
            run_manual_irq_vector_case(2,16'h0220);
            run_manual_irq_vector_case(3,16'h0230);
            run_nmi_over_irq_case();
            run_manual_irq_priority_case();
            if(generic_count!=218 || timing_assertions!=745) begin
                $display("FAIL: MC6801 case/assertion count cases=%0d timing=%0d expected=218/745",generic_count,timing_assertions); $fatal(1);
            end
            $display("PASS: MC6801 full directed assessment sequence completed; generic cases=%0d timing assertions=%0d",generic_count,timing_assertions);
            for(cov_i=0;cov_i<256;cov_i=cov_i+1) begin
                if((executed_by_opcode[cov_i]!=0)!==DOC_DEFINED_MASK[cov_i]) begin $display("FAIL: runtime opcode set mismatch opcode=%02x observed=%0d documented=%b",cov_i[7:0],executed_by_opcode[cov_i],DOC_DEFINED_MASK[cov_i]); $fatal(1); end
                if((timed_by_opcode[cov_i]!=0)!==DOC_TIMING_MASK[cov_i]) begin $display("FAIL: runtime timing set mismatch opcode=%02x observed=%0d expected=%b",cov_i[7:0],timed_by_opcode[cov_i],DOC_TIMING_MASK[cov_i]); $fatal(1); end
                $display("COVERAGE opcode=%02x executed=%0d timed=%0d",cov_i[7:0],executed_by_opcode[cov_i],timed_by_opcode[cov_i]);
            end
            $finish;
        end
    end
    $display("FAIL: MC6801 smoke program timed out; PC=%04x",uut.u_regs.pc);
    $fatal(1);
end
endmodule
