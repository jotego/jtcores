`timescale 1ns/1ps
module test;
reg clk=0, rst=0, irq=0, tirq=0, pause_cen=0;
wire cen;
reg [1:0] div=0;
wire wr, stop;
wire [12:0] addr;
wire [7:0] dout, din;
integer ticks=0, case_id=0, trace_fd=0, write_fd=0, result_fd, service_fd, detail_fd, i, executed=0, inventory_rows=0;
integer case_writes=0, write_edges=0, effects_checked=0;
integer address_effect_cases=0;
integer hmos_match=0, cmos_match=0, both_match=0, cmos_only=0;
integer neither_match=0, failures=0;
integer service_timing_deviations=0, pending_irq_deviations=0, priority_deviations=0;
integer k, timing_path_code;
reg [31:0] manual_cases[0:208];

always #5 clk=~clk;
always @(posedge clk) div<=div+1'd1;
assign cen=!pause_cen && div==0;

jt6805 uut(.rst(rst),.clk(clk),.cen(cen),.irq(irq),.tirq(tirq),
    .wr(wr),.tstop(stop),.addr(addr),.din(din),.dout(dout));

// The selected 68705P3 exposes an 11-bit program address. jtframe_6805mcu
// truncates the generic CPU's 13-bit address to ROMW=11; mirror that mapping.
jtframe_ram #(.AW(11)) u_mem(.clk(clk),.cen(cen),.data(dout),.addr(addr[10:0]),.we(wr),.q(din));

always @(posedge clk) if(cen && !rst) begin
    // Count/capture writes at the same pre-NBA edge the synchronous RAM uses.
    if(wr) begin
        case_writes=case_writes+1; write_edges=write_edges+1;
        if(write_fd!=0) $fwrite(write_fd,"%0d,%0d,%04x,%02x\n",case_id,ticks,addr,dout);
    end
    #1;
    ticks=ticks+1;
    if(trace_fd!=0)
        $fwrite(trace_fd,"%0d,%0d,%04x,%02x,%02x,%0d,%0d,%0d,%0d,%0d,%04x,%0d,%0d,%0d,%0d,%0d\n",
            case_id,ticks,addr,din,dout,wr,stop,irq,tirq,uut.fetch,uut.u_ctrl.uaddr,
            uut.u_regs.h,uut.u_regs.i,uut.u_regs.n,uut.u_regs.z,uut.u_regs.c);
end

function [7:0] unary_expected(input [3:0] op, input [7:0] value);
    begin
        case(op)
            4'h0: unary_expected=8'h00-value;
            4'h3: unary_expected=~value;
            4'h4: unary_expected=value>>1;
            4'h6: unary_expected={1'b0,value[7:1]};
            4'h7: unary_expected={value[7],value[7:1]};
            4'h8: unary_expected=value<<1;
            4'h9: unary_expected={value[6:0],1'b0};
            4'ha: unary_expected=value-1'b1;
            4'hc: unary_expected=value+1'b1;
            4'hd: unary_expected=value;
            4'hf: unary_expected=0;
            default: unary_expected=value;
        endcase
    end
endfunction

task fail(input string why);
    begin failures=failures+1; $display("FAIL: %0s",why); end
endtask

task set_bytes(input [12:0] at, input [7:0] value);
    begin u_mem.mem[at[10:0]]=value; end
endtask

task begin_reset;
    begin
        @(negedge clk); rst=1;
        repeat(8) @(negedge clk);
        rst=0;
        repeat(2) @(negedge clk);
    end
endtask

task wait_bus_case(input [12:0] first_pc, input [7:0] opcode,
                   input [12:0] next_pc, input integer limit,
                   output integer elapsed);
    integer start_tick, stop_tick, watchdog;
    reg started;
    begin
        start_tick=-1; stop_tick=-1; watchdog=0; started=0;
        // A prior back-to-back calibration interval can return on the exact
        // boundary that starts this one, so honor the current accepted opcode.
        if(cen && uut.u_ctrl.ni && addr===first_pc && uut.md[7:0]===opcode) begin
            started=1; start_tick=ticks;
        end
        while(stop_tick<0 && watchdog<limit) begin
            // Opcode acceptance is the `ni` transition at an enabled edge,
            // after fetch has latched the synchronous RAM byte into md. The
            // public bus supplies the following PC address; md distinguishes
            // an instruction from vector/operand traffic. Sampling before
            // the NBA update gives one consistent edge convention at both
            // endpoints (unlike sampling the wider fetch microstate).
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni) begin
                if(!started && addr===first_pc && uut.md[7:0]===opcode) begin
                    started=1; start_tick=ticks;
                end else if(started && addr===next_pc &&
                            uut.md[7:0]===8'h9d) begin
                    stop_tick=ticks;
                end
            end
            if(started && ((^addr)===1'bx || (^din)===1'bx || (wr!==1'b0 && wr!==1'b1))) begin
                fail("unknown on public address/data/write bus during active case");
            end
        end
        if(!started || stop_tick<0) begin
            elapsed=-1;
            fail($sformatf("bus endpoint timeout case=%0d start=%04x next=%04x",case_id,first_pc,next_pc));
        end else if(((stop_tick-start_tick)%4)!=0) begin
            elapsed=-1;
            fail($sformatf("nonintegral 4-CEN/E interval case=%0d edges=%0d",case_id,stop_tick-start_tick));
        end else elapsed=(stop_tick-start_tick)/4;
    end
endtask

task assess_one(input [7:0] opcode, input integer length,
                input integer hmos_cycles, input integer cmos_cycles,
                input integer requested_path);
    integer target, nextpc, cycles, n, watchdog;
    reg [7:0] hi, lo, offset, data_value;
    reg [4:0] cc_before;
    reg branch_taken;
    reg [7:0] expected_result;
    reg check_accumulator, check_index;
    begin
        case_id=opcode;
        case_writes=0;
        target='h0201; nextpc=target+length;
        branch_taken=0;
        expected_result=0; check_accumulator=0; check_index=0;
        for(n=0;n<12;n=n+1) set_bytes(target+n,8'h00);
        set_bytes('h0200,8'h9d); // warm-up instruction separates reset from the measured opcode
        set_bytes(target,opcode);
        set_bytes(nextpc,8'h9d);
        set_bytes('h0210,8'h9d); set_bytes('h0030,8'h5a); set_bytes('h0000,8'h5a);
        if((opcode>=8'h30 && opcode<=8'h3f) || (opcode>=8'h60 && opcode<=8'h6f)) begin
            set_bytes(target+1,8'h30);
            set_bytes('h0030,8'h5a);
        end
        set_bytes('h007f,8'h00); set_bytes('h00ff,8'h00);
        hi=0; lo='h30; offset=2; data_value='h5a;

        if(opcode<=8'h0f) begin
            set_bytes(target+1,lo); set_bytes(target+2,offset);
            // One path uses M[$30]=0: BRSET not taken, BRCLR taken.
            branch_taken=(requested_path<0) ? opcode[0] : requested_path[0];
            if(branch_taken) nextpc='h0206; else nextpc='h0204;
            set_bytes('h0204,8'h9d); set_bytes('h0206,8'h9d);
            if(opcode[0]) set_bytes('h0030,branch_taken ? 8'h00 : (8'h01 << (opcode>>1)));
            else set_bytes('h0030,branch_taken ? (8'h01 << (opcode>>1)) : 8'h00);
        end else if(opcode<=8'h1f) begin
            set_bytes(target+1,lo); set_bytes('h0030,8'h5a);
        end else if(opcode>=8'h20 && opcode<=8'h2f) begin
            set_bytes(target+1,offset);
            case(opcode)
                8'h20,8'h22,8'h24,8'h26,8'h28,8'h2a,8'h2d,8'h2f: branch_taken=1;
                default: branch_taken=0;
            endcase
            if(requested_path>=0 && opcode!=8'h20 && opcode!=8'h21) branch_taken=requested_path[0];
            // Reset flags are H/N/Z/C=0 and I=1; irq=0 means the line is low.
            if(branch_taken) begin nextpc='h0205; set_bytes('h0205,8'h9d); end
            else begin nextpc='h0203; set_bytes('h0203,8'h9d); end
        end else if(opcode==8'had) begin
            set_bytes(target+1,offset); nextpc='h0205; set_bytes(nextpc,8'h9d);
        end else if(opcode>=8'ha0 && opcode<=8'haf) begin
            set_bytes(target+1,data_value);
        end else if(opcode>=8'hb0 && opcode<=8'hbf) begin
            set_bytes(target+1,lo); set_bytes('h0030,8'h5a);
            if(opcode==8'hbc || opcode==8'hbd) begin
                nextpc='h0030;
            end
        end else if(opcode>=8'hc0 && opcode<=8'hcf) begin
            hi=0; lo='h30;
            if(opcode==8'hcc || opcode==8'hcd) begin
                hi=4; lo=0; nextpc='h0400;
            end
            set_bytes(target+1,hi); set_bytes(target+2,lo); set_bytes('h0030,8'h5a);
        end else if(opcode>=8'hd0 && opcode<=8'hdf) begin
            hi=0; lo='h30;
            if(opcode==8'hdc || opcode==8'hdd) begin nextpc='h0030; end
            set_bytes(target+1,hi); set_bytes(target+2,lo); set_bytes('h0030,8'h5a);
        end else if(opcode>=8'he0 && opcode<=8'hef) begin
            set_bytes(target+1,lo); set_bytes('h0030,8'h5a);
            if(opcode==8'hec || opcode==8'hed) begin nextpc='h0030; end
        end else if(opcode>=8'hf0) begin
            set_bytes('h0000,8'h5a);
            if(opcode==8'hfc || opcode==8'hfd) begin nextpc=0; end
        end

        // Reset/interrupt entries have distinct vectors. SWI's public bus path
        // is measured to its handler; STOP/WAIT are CMOS-only and run separately.
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffc,8'h03); set_bytes('h1ffd,8'h00);
        set_bytes('h01ff,8'h00); set_bytes('h01fe,8'h04);
        if(opcode==8'hbc || opcode==8'hbd || opcode==8'hdc || opcode==8'hdd ||
           opcode==8'hec || opcode==8'hed) set_bytes('h0030,8'h9d);
        if(opcode==8'hcc || opcode==8'hcd) set_bytes('h0400,8'h9d);
        if(opcode==8'hfc || opcode==8'hfd) set_bytes('h0000,8'h9d);
        set_bytes('h0204,8'h9d); set_bytes('h0300,8'h9d); set_bytes('h0400,8'h9d);
        irq=0; tirq=0; begin_reset();
        if(opcode>=8'h22 && opcode<=8'h2f && requested_path>=0) begin
            watchdog=0;
            while(!(uut.fetch && addr===target && din===opcode) && watchdog<600) begin
                @(negedge clk); watchdog=watchdog+1;
            end
            if(watchdog==600) fail("conditional-branch setup could not reach public opcode bus event");
            uut.u_regs.h=0; uut.u_regs.n=0; uut.u_regs.z=0; uut.u_regs.c=0; uut.u_regs.i=1;
            case(opcode)
                8'h22: if(!requested_path[0]) uut.u_regs.c=1;
                8'h23: if( requested_path[0]) uut.u_regs.z=1;
                8'h24: if(!requested_path[0]) uut.u_regs.c=1;
                8'h25: if( requested_path[0]) uut.u_regs.c=1;
                8'h26: if(!requested_path[0]) uut.u_regs.z=1;
                8'h27: if( requested_path[0]) uut.u_regs.z=1;
                8'h28: if(!requested_path[0]) uut.u_regs.h=1;
                8'h29: if( requested_path[0]) uut.u_regs.h=1;
                8'h2a: if(!requested_path[0]) uut.u_regs.n=1;
                8'h2b: if( requested_path[0]) uut.u_regs.n=1;
                8'h2c: if( requested_path[0]) uut.u_regs.i=0;
                8'h2d: if(!requested_path[0]) uut.u_regs.i=0;
                8'h2e: irq=requested_path[0];
                8'h2f: irq=!requested_path[0];
            endcase
        end
        // RTS/RTI need a valid frame; seed the documented internal stack
        // pointer for RTI after the warm-up instruction completes.
        if(opcode==8'h80) begin
            watchdog=0;
            while(!(addr==='h0201 && din===opcode) && watchdog<600) begin @(negedge clk); watchdog=watchdog+1; end
            if(watchdog==600) fail("RTI setup could not reach public opcode bus event");
            uut.u_regs.s=5'h1a;
            set_bytes('h007b,8'h00); set_bytes('h007c,8'h00);
            set_bytes('h007d,8'h00); set_bytes('h007e,8'hfc); set_bytes('h007f,8'h00);
            set_bytes('h0400,8'h9d); nextpc='h0400;
        end
        if(opcode==8'h81) begin
            watchdog=0;
            while(!(addr==='h0201 && din===opcode) && watchdog<600) begin @(negedge clk); watchdog=watchdog+1; end
            if(watchdog==600) fail("RTS setup could not reach public opcode bus event");
            uut.u_regs.s=5'h1d;
            set_bytes('h007e,8'hfc); set_bytes('h007f,8'h00);
            set_bytes('h0400,8'h9d); nextpc='h0400;
        end
        if(opcode==8'h83) begin nextpc='h0300; end
        // Seed ALU/register-unary cases at the public opcode fetch. These
        // checks deliberately sample architectural results independently of
        // the selected timing profile.
        if((opcode>=8'ha0 && opcode<=8'hab) || opcode==8'hae ||
           (opcode>=8'h40 && opcode<=8'h5f &&
            (opcode[3:0]==0 || opcode[3:0]==3 || opcode[3:0]==4 || opcode[3:0]==6 || opcode[3:0]==7 || opcode[3:0]==8 || opcode[3:0]==9 || opcode[3:0]==10 || opcode[3:0]==12 || opcode[3:0]==13 || opcode[3:0]==15))) begin
            watchdog=0;
            while(!(uut.fetch && addr===target && din===opcode) && watchdog<600) begin @(negedge clk); watchdog=watchdog+1; end
            if(watchdog==600) fail($sformatf("semantic setup could not reach opcode fetch %02x",opcode));
            if(opcode>=8'ha0 && opcode<=8'hae) begin
                uut.u_regs.a=8'h3c; uut.u_regs.x=8'h5a;
                uut.u_regs.h=0; uut.u_regs.n=0; uut.u_regs.z=0; uut.u_regs.c=0;
                case(opcode)
                    8'ha0: begin expected_result=8'he2; check_accumulator=1; end
                    8'ha1: begin expected_result=8'h3c; check_accumulator=1; end
                    8'ha2: begin expected_result=8'he2; check_accumulator=1; end
                    8'ha3: begin expected_result=8'h5a; check_index=1; end
                    8'ha4: begin expected_result=8'h18; check_accumulator=1; end
                    8'ha5: begin expected_result=8'h3c; check_accumulator=1; end
                    8'ha6: begin expected_result=8'h5a; check_accumulator=1; end
                    8'ha8: begin expected_result=8'h66; check_accumulator=1; end
                    8'ha9: begin expected_result=8'h96; check_accumulator=1; end
                    8'haa: begin expected_result=8'h7e; check_accumulator=1; end
                    8'hab: begin expected_result=8'h96; check_accumulator=1; end
                    8'hae: begin expected_result=8'h5a; check_index=1; end
                endcase
            end else begin
                uut.u_regs.a=8'h5a; uut.u_regs.x=8'h5a;
                expected_result=unary_expected(opcode[3:0],8'h5a);
                if(opcode[4]) check_index=1; else check_accumulator=1;
            end
        end
        cc_before={uut.u_regs.h,uut.u_regs.i,uut.u_regs.n,uut.u_regs.z,uut.u_regs.c};
        wait_bus_case(target,opcode,nextpc,600,cycles);
        executed=executed+1;
        timing_path_code=(requested_path<0) ? 255 : requested_path;
        if(executed>237) fail($sformatf("unexpected extra timing case %0d op=%02x",executed,opcode));
        #2; // observe architectural state after the accepted endpoint edge's NBAs
        // Architectural checks are independent of the timing classification.
        if(opcode<=8'h0f) begin
            n=(opcode>>1)&7;
            if(uut.u_regs.c !== u_mem.mem['h30][n])
                fail($sformatf("BRSET/BRCLR carry result mismatch op=%02x bit=%0d C=%b memory=%02x",opcode,n,uut.u_regs.c,u_mem.mem['h30]));
            if({uut.u_regs.h,uut.u_regs.i,uut.u_regs.n,uut.u_regs.z} !== cc_before[4:1])
                fail($sformatf("BRSET/BRCLR changed H/I/N/Z op=%02x",opcode));
            effects_checked=effects_checked+1;
        end else if(opcode>=8'h10 && opcode<=8'h1f) begin
            n=(opcode>>1)&7;
            if(opcode[0]) data_value=8'h5a & ~(8'h01<<n);
            else data_value=8'h5a | (8'h01<<n);
            if(u_mem.mem['h30] !== data_value)
                fail($sformatf("BSET/BCLR memory result mismatch op=%02x got=%02x expected=%02x",opcode,u_mem.mem['h30],data_value));
            if(case_writes!=1) fail($sformatf("BSET/BCLR write count op=%02x got=%0d expected=1",opcode,case_writes));
            if({uut.u_regs.h,uut.u_regs.n,uut.u_regs.z,uut.u_regs.c} !== 4'b0000)
                fail($sformatf("BSET/BCLR changed condition codes op=%02x",opcode));
            effects_checked=effects_checked+1;
        end else if((opcode[7:4]==3 || opcode[7:4]==6 || opcode[7:4]==7) &&
                    (opcode[3:0]==0 || opcode[3:0]==3 || opcode[3:0]==4 || opcode[3:0]==6 || opcode[3:0]==7 || opcode[3:0]==8 || opcode[3:0]==9 || opcode[3:0]==10 || opcode[3:0]==12 || opcode[3:0]==13 || opcode[3:0]==15)) begin
            n=(opcode[7:4]==7) ? 0 : 'h30;
            data_value=unary_expected(opcode[3:0],8'h5a);
            if(u_mem.mem[n] !== data_value)
                fail($sformatf("memory unary result mismatch op=%02x addr=%02x got=%02x expected=%02x",opcode,n,u_mem.mem[n],data_value));
            if(opcode[3:0]==13) begin
                if(case_writes!=0) fail($sformatf("TST must not write memory op=%02x writes=%0d",opcode,case_writes));
            end else if(case_writes!=1) fail($sformatf("memory unary write count op=%02x got=%0d expected=1",opcode,case_writes));
            if(uut.u_regs.n !== data_value[7] || uut.u_regs.z !== (data_value==0))
                fail($sformatf("memory unary N/Z result op=%02x N/Z=%b%b result=%02x",opcode,uut.u_regs.n,uut.u_regs.z,data_value));
            effects_checked=effects_checked+1;
        end else if(opcode>=8'hb0 && opcode<=8'hff && (opcode[3:0]==7 || opcode[3:0]==15)) begin
            n=(opcode[7:4]==15) ? 0 : 'h30;
            data_value=(opcode[3:0]==7) ? 0 : 0;
            if(u_mem.mem[n] !== data_value)
                fail($sformatf("store result mismatch op=%02x addr=%02x got=%02x expected=00",opcode,n,u_mem.mem[n]));
            if(case_writes!=1) fail($sformatf("store write count op=%02x got=%0d expected=1",opcode,case_writes));
            effects_checked=effects_checked+1;
        end else if((opcode>=8'ha0 && opcode<=8'haf && (opcode==8'ha6 || opcode==8'hae)) ||
                    (opcode>=8'hb0 && opcode<=8'hff && (opcode[3:0]==6 || opcode[3:0]==14))) begin
            if(opcode==8'ha6 || opcode[3:0]==6) begin
                if(uut.u_regs.a !== 8'h5a) fail($sformatf("LDA result mismatch op=%02x A=%02x",opcode,uut.u_regs.a));
            end else if(uut.u_regs.x !== 8'h5a) fail($sformatf("LDX result mismatch op=%02x X=%02x",opcode,uut.u_regs.x));
            effects_checked=effects_checked+1;
        end else if(check_accumulator || check_index) begin
            if(check_accumulator && uut.u_regs.a!==expected_result)
                fail($sformatf("accumulator ALU/unary result op=%02x got=%02x expected=%02x",opcode,uut.u_regs.a,expected_result));
            if(check_index && uut.u_regs.x!==expected_result)
                fail($sformatf("index ALU/unary result op=%02x got=%02x expected=%02x",opcode,uut.u_regs.x,expected_result));
            effects_checked=effects_checked+1;
        end else if(opcode>=8'h22 && opcode<=8'h2f) begin
            if({uut.u_regs.h,uut.u_regs.i,uut.u_regs.n,uut.u_regs.z,uut.u_regs.c} !== cc_before)
                fail($sformatf("relative branch changed H/N/Z/C op=%02x",opcode));
            effects_checked=effects_checked+1;
        end else if(opcode==8'h83) begin
            if(uut.u_regs.s!==5'h1a || uut.u_regs.i!==1 || addr!==13'h0300)
                fail($sformatf("SWI vector/stack entry mismatch S=%02x I=%0d addr=%04x",uut.u_regs.s,uut.u_regs.i,addr));
            if(u_mem.mem['h7f]!==8'h01 || u_mem.mem['h7d]!==8'h00 || u_mem.mem['h7c]!==8'h00 || u_mem.mem['h7b][4:0]!==5'h08)
                fail($sformatf("SWI stack PCL/X/A/CCR-low mismatch PCL=%02x X=%02x A=%02x CC=%02x",u_mem.mem['h7f],u_mem.mem['h7d],u_mem.mem['h7c],u_mem.mem['h7b]));
            if(u_mem.mem['h7e]!==8'hfa)
                fail($sformatf("SWI stacked PCH=%02x expected FA",u_mem.mem['h7e]));
            if(u_mem.mem['h7b][7:5]!==3'b111 || u_mem.mem['h7b]!==8'he8)
                fail($sformatf("SWI stacked CCR=%02x expected E8 (unused high bits set)",u_mem.mem['h7b]));
            effects_checked=effects_checked+1;
        end else if(opcode>=8'hb0 && opcode<=8'hff && opcode[3:0]==13) begin
            if(uut.u_regs.s!==5'h1d || case_writes!=2)
                fail($sformatf("JSR stack wrap op=%02x S=%02x writes=%0d",opcode,uut.u_regs.s,case_writes));
            if(u_mem.mem['h7f] !== ((target+length)&'hff))
                fail($sformatf("JSR stack PCL mismatch op=%02x actual=%02x expected=%02x",opcode,u_mem.mem['h7f],(target+length)&'hff));
            if(u_mem.mem['h7e]!==8'hfa)
                fail($sformatf("JSR stacked PCH op=%02x actual=%02x expected=FA",opcode,u_mem.mem['h7e]));
            effects_checked=effects_checked+1;
        end
        if(cycles>=0) begin
            if(hmos_cycles>=0 && cycles==hmos_cycles) hmos_match=hmos_match+1;
            if(cycles==cmos_cycles) cmos_match=cmos_match+1;
            if(hmos_cycles>=0 && cycles==hmos_cycles && cycles==cmos_cycles) begin
                both_match=both_match+1;
                $fwrite(result_fd,"%02x,%0d,%0d,%0d,%0d,%0d,HMOS+CMOS-match\n",opcode,length,hmos_cycles,cmos_cycles,cycles,requested_path);
            end else if(hmos_cycles>=0 && cycles==hmos_cycles) begin
                $fwrite(result_fd,"%02x,%0d,%0d,%0d,%0d,%0d,HMOS-match\n",opcode,length,hmos_cycles,cmos_cycles,cycles,requested_path);
            end else if(cycles==cmos_cycles) begin
                cmos_only=cmos_only+1;
                $fwrite(result_fd,"%02x,%0d,%0d,%0d,%0d,%0d,CMOS-match-only\n",opcode,length,hmos_cycles,cmos_cycles,cycles,requested_path);
            end else begin
                neither_match=neither_match+1;
                $fwrite(result_fd,"%02x,%0d,%0d,%0d,%0d,%0d,neither\n",opcode,length,hmos_cycles,cmos_cycles,cycles,requested_path);
                $display("TIMING-UNCLASSIFIED opcode=%02x measured=%0d HMOS=%0d CMOS=%0d",opcode,cycles,hmos_cycles,cmos_cycles);
            end
        end
    end
endtask

// The manual's HMOS P3 sequence is 11 E cycles from the next-opcode
// boundary through the handler prefetch (M6805 User's Manual, 2nd ed.,
// App. G2, printed p.243). IRQ and timer vectors are distinct. The core's
// generic vector addresses alias the P3's 11-bit map through jtframe_ram.
task assess_interrupt(input integer timer_source);
    integer edge0, edge1, watchdog, writes0, return_watchdog, k;
    reg got_handler;
    reg [12:0] vector_pc;
    begin
        edge0=-1; edge1=-1; watchdog=0; writes0=write_edges;
        vector_pc=timer_source ? 13'h0310 : 13'h0300;
        for(k=0;k<32;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h0200,8'h9a); // CLI enables the selected source
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffa,vector_pc[12:8]); set_bytes('h1ffb,vector_pc[7:0]);
        set_bytes('h1ff8,vector_pc[12:8]); set_bytes('h1ff9,vector_pc[7:0]);
        set_bytes(vector_pc,8'ha6); set_bytes(vector_pc+1,8'ha5);
        set_bytes(vector_pc+2,8'hb7); set_bytes(vector_pc+3,8'h30);
        set_bytes(vector_pc+4,8'h80); // RTI
        set_bytes('h0030,8'h00);
        irq=0; tirq=0; begin_reset();
        // Let CLI complete, then assert while the following NOP is in flight.
        // This makes both requests eligible at the NOP's 0202 boundary and
        // keeps the manual's 44-CEN service observer anchored there.
        watchdog=0;
        while(!(cen && uut.u_ctrl.ni && addr==='h0200 && uut.md[7:0]===8'h9a) && watchdog<300) begin
            @(posedge clk); watchdog=watchdog+1;
        end
        if(watchdog>=300) fail("interrupt setup did not reach CLI after reset");
        watchdog=0;
        while(uut.u_regs.i!==0 && watchdog<300) begin
            @(posedge clk); watchdog=watchdog+1;
        end
        if(watchdog>=300) fail("interrupt setup did not complete CLI");
        @(negedge clk);
        if(timer_source) tirq=1; else irq=1;
        watchdog=0; got_handler=0;
        while(!got_handler && watchdog<600) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni) begin
                if(edge0<0 && addr==='h0202 && uut.md[7:0]===8'h9d) edge0=ticks;
                else if(edge0>=0 && addr===vector_pc && uut.md[7:0]===8'ha6) begin
                    edge1=ticks; got_handler=1;
                end
            end
        end
        if(!got_handler) fail($sformatf("%s interrupt did not vector",timer_source ? "TIRQ" : "IRQ"));
        if(got_handler && edge1-edge0!=44) begin
            service_timing_deviations=service_timing_deviations+1;
            fail($sformatf("%s accepted-opcode to handler boundary measured %0d CEN edges (%0d E), manual expects 44 CEN edges (11 E)",timer_source ? "TIRQ" : "IRQ",edge1-edge0,(edge1-edge0)/4));
        end
        // Wait for handler's RTI to restore the stack and resume mainline.
        if(timer_source) tirq=0; else irq=0;
        return_watchdog=0;
        while(!(uut.u_regs.s===5'h1f && uut.u_regs.i===0 && u_mem.mem['h30]===8'ha5) && return_watchdog<1200) begin
            @(posedge clk); return_watchdog=return_watchdog+1;
        end
        if(return_watchdog>=1200) fail($sformatf("%s handler/RTI did not restore stack and marker",timer_source ? "TIRQ" : "IRQ"));
        if(write_edges-writes0<6) fail($sformatf("%s expected five interrupt stack writes plus handler store, observed %0d",timer_source ? "TIRQ" : "IRQ",write_edges-writes0));
        if(u_mem.mem['h7f]!==8'h02 || u_mem.mem['h7d]!==8'h00 || u_mem.mem['h7c]!==8'h00 || u_mem.mem['h7b][4:0]!==5'h00)
            fail($sformatf("%s stack PCL/X/A/CCR-low mismatch PCL=%02x X=%02x A=%02x CC=%02x",timer_source ? "TIRQ" : "IRQ",u_mem.mem['h7f],u_mem.mem['h7d],u_mem.mem['h7c],u_mem.mem['h7b]));
        if(u_mem.mem['h7e]!==8'hfa)
            fail($sformatf("%s stacked PCH=%02x expected FA",timer_source ? "TIRQ" : "IRQ",u_mem.mem['h7e]));
        if(u_mem.mem['h7b]!==8'he0)
            fail($sformatf("%s stacked CCR=%02x expected E0",timer_source ? "TIRQ" : "IRQ",u_mem.mem['h7b]));
        $fwrite(service_fd,"%s,%04x,11,44,%0d,%0d,1,%02x,%0d,%0d\n",timer_source ? "TIRQ" : "IRQ",vector_pc,edge1-edge0,write_edges-writes0-1,uut.u_regs.s,uut.u_regs.i,got_handler);
        $display("SERVICE: %s vector=%04x entry=%0d CEN edges (manual 44), stack_writes=%0d handler_writes=1, RTI restored S=%02x I=%0d",
            timer_source ? "TIRQ" : "IRQ",vector_pc,edge1-edge0,write_edges-writes0-1,uut.u_regs.s,uut.u_regs.i);
    end
endtask

// P3/P5 stack pointers use the five-bit ring $60-$7F. Start at $60, run JSR
// through the $7F wrap, then RTS back through $60 to prove push and pull.
task assess_legal_stack_wrap;
    integer watchdog, writes0;
    reg reached_call, reached_target, returned;
    begin
        for(k=0;k<16;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h0201,8'hbd); set_bytes('h0202,8'h30); // JSR direct $30
        set_bytes('h0030,8'h81); // RTS
        // Poison both the normative wrapped destination and the old-core
        // underflow destination so either wrong write is observable.
        set_bytes('h0060,8'hc6); set_bytes('h007f,8'hd7); set_bytes('h005f,8'hb5);
        irq=0; tirq=0; begin_reset(); case_id=16'h1bd; case_writes=0;
        watchdog=0; reached_call=0;
        while(!reached_call && watchdog<400) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0201 && uut.md[7:0]===8'hbd) begin
                uut.u_regs.s=5'h00;
                reached_call=1;
            end
        end
        if(!reached_call) fail("P3 legal-stack-wrap fixture did not reach JSR opcode");
        watchdog=0; reached_target=0;
        while(!reached_target && watchdog<600) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0030 && uut.md[7:0]===8'h81)
                reached_target=1;
        end
        returned=0; watchdog=0;
        while(!returned && watchdog<800) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0203 && uut.md[7:0]===8'h9d)
                returned=1;
        end
        #2;
        if(!reached_target) fail("P3/P5 legal-stack-wrap JSR did not reach RTS callee");
        if(!returned) fail("P3/P5 RTS did not pull through $60 and restore 0203");
        else begin
            // Return PC is $0203. PCL is written at $60, PCH wraps to $7F,
            // and RTS pulls PCH/PCL back across $7F->$60.
            if(u_mem.mem['h60]!==8'h03)
                fail($sformatf("P3/P5 legal-wrap PCL actual=%02x expected=03",u_mem.mem['h60]));
            if(u_mem.mem['h7f]!==8'hfa || u_mem.mem['h5f]!==8'hb5 ||
           uut.u_regs.s!==5'h00 || uut.u_regs.pc!==11'h203)
                fail($sformatf("P3/P5 legal wrap tuple PCH@7f=%02x poison@5f=%02x S=%02x PC=%04x",
                    u_mem.mem['h7f],u_mem.mem['h5f],uut.u_regs.s,uut.u_regs.pc));
            else $display("STACK-WRAP: P3/P5 JSR/RTS wrapped push and pull across $60-$7F; restored PC=0203 SP=$60");
            $fwrite(detail_fd,"legal-stack-wrap,p3-p5-pass,60:%02x;5f:%02x;7f:%02x;S:%02x;PC:%04x\n",
                u_mem.mem['h60],u_mem.mem['h5f],u_mem.mem['h7f],uut.u_regs.s,uut.u_regs.pc);
        end
    end
endtask

// App. G2 states simultaneous pending external/timer requests service IRQ
// first, with timer still pending after the external handler returns.
task assess_interrupt_priority;
    integer watchdog;
    reg [12:0] first_vector, second_vector;
    begin
        for(k=0;k<24;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h0200,8'h9a); // CLI
        set_bytes('h0201,8'h9d); set_bytes('h0202,8'h9d);
        set_bytes('h1ffa,8'h03); set_bytes('h1ffb,8'h00);
        set_bytes('h1ff8,8'h03); set_bytes('h1ff9,8'h10);
        set_bytes('h0300,8'h80); set_bytes('h0310,8'h80);
        irq=0; tirq=0; begin_reset(); first_vector=13'h1fff; second_vector=13'h1fff;
        watchdog=0;
        while(!(cen && uut.u_ctrl.ni && addr==='h0201 && uut.md[7:0]===8'h9d) && watchdog<400) begin
            @(posedge clk); watchdog=watchdog+1;
        end
        if(watchdog>=400) fail("IRQ priority fixture did not reach enabled NOP");
        @(negedge clk); irq=1; tirq=1; watchdog=0;
        while(first_vector===13'h1fff && watchdog<600) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && (addr==='h0300 || addr==='h0310)) first_vector=addr;
        end
        if(first_vector===13'h1fff) fail("simultaneous IRQ/TIRQ fixture did not reach a vector");
        else begin
            irq=0;
            watchdog=0;
            while(second_vector===13'h1fff && watchdog<1200) begin
                @(posedge clk); watchdog=watchdog+1;
                if(cen && uut.u_ctrl.ni && (addr==='h0300 || addr==='h0310) && addr!==first_vector)
                    second_vector=addr;
            end
            if(second_vector===13'h1fff) fail("pending second interrupt did not vector after RTI");
            if(first_vector!==13'h0300 || second_vector!==13'h0310) begin
                priority_deviations=priority_deviations+1;
                fail($sformatf("simultaneous IRQ/TIRQ priority expected IRQ 0300 then TIRQ 0310; observed %04x then %04x",first_vector,second_vector));
            end else $display("INTERRUPT-PRIORITY: simultaneous IRQ/TIRQ serviced IRQ 0300 then pending TIRQ 0310");
            $fwrite(detail_fd,"priority,0300/0310,%04x/%04x,%s\n",first_vector,second_vector,
                priority_deviations ? "mismatch" : "match");
        end
        irq=0; tirq=0;
    end
endtask

// Interrupt framing uses the same legal stack ring. Seed SP=$60 so PCL is
// written at $60, PCH wraps to $7F, and RTI pulls back across the boundary.
task assess_irq_stack_wrap;
    integer watchdog, pulse_edges, vectors, writes0, idle_edges;
    reg returned;
    begin
        for(k=0;k<16;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h0200,8'h9a); // CLI
        set_bytes('h0300,8'h80); // RTI
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffa,8'h03); set_bytes('h1ffb,8'h00);
        set_bytes('h005f,8'hb5);
        irq=0; tirq=0; begin_reset(); watchdog=0;
        while(!(cen && uut.u_ctrl.ni && addr==='h0200 && uut.md[7:0]===8'h9a) && watchdog<400) begin
            @(posedge clk); watchdog=watchdog+1;
        end
        if(watchdog>=400) fail("IRQ stack-wrap fixture did not reach CLI");
        watchdog=0;
        while(uut.u_regs.i!==0 && watchdog<400) begin
            @(posedge clk); watchdog=watchdog+1;
        end
        if(watchdog>=400) fail("IRQ stack-wrap fixture did not complete CLI");
        @(negedge clk); uut.u_regs.s=5'h00; irq=1;
        pulse_edges=0; vectors=0; writes0=write_edges;
        returned=0; watchdog=0;
        while(!returned && watchdog<1200) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                vectors=vectors+1;
            if(cen) pulse_edges=pulse_edges+1;
            if(pulse_edges==8 && irq) begin @(negedge clk); irq=0; end
            if(cen && uut.u_ctrl.ni && addr==='h0202 && uut.md[7:0]===8'h9d &&
               uut.u_regs.i===0 && uut.u_regs.s===5'h00)
                returned=1;
        end
        if(!returned) fail("IRQ/RTI stack-wrap fixture did not restore 0202 and SP=$60");
        #2;
        if(vectors!=1) fail($sformatf("IRQ/RTI stack-wrap expected one handler entry, got %0d",vectors));
        if(write_edges-writes0!=5) fail($sformatf("IRQ/RTI stack-wrap expected five frame writes, got %0d",write_edges-writes0));
        if(u_mem.mem['h60]!==8'h02 || u_mem.mem['h7f]!==8'hfa ||
           u_mem.mem['h7e]!==8'h00 || u_mem.mem['h7d]!==8'h00 || u_mem.mem['h7c]!==8'he0 ||
           u_mem.mem['h5f]!==8'hb5)
            fail($sformatf("IRQ/RTI wrapped frame PCL@60=%02x PCH@7F=%02x X@7E=%02x A@7D=%02x CC@7C=%02x poison@5F=%02x",
                u_mem.mem['h60],u_mem.mem['h7f],u_mem.mem['h7e],u_mem.mem['h7d],u_mem.mem['h7c],u_mem.mem['h5f]));
        if(uut.u_regs.pc!==11'h202 || uut.u_regs.s!==5'h00 || uut.u_regs.i!==0)
            fail($sformatf("IRQ/RTI wrapped return PC=%04x SP=%02x I=%0d",uut.u_regs.pc,uut.u_regs.s,uut.u_regs.i));
        idle_edges=0;
        while(idle_edges<80) begin
            @(posedge clk);
            if(cen) begin
                idle_edges=idle_edges+1;
                if(uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                    fail("IRQ/RTI stack-wrap fixture duplicated service after return");
            end
        end
        $display("STACK-WRAP: P3/P5 IRQ/RTI wrapped frame and return across $60-$7F; restored PC=0202 SP=$60");
        $fwrite(detail_fd,"irq-rti-stack-wrap,pass,60:%02x;7f:%02x;7e:%02x;7d:%02x;7c:%02x;5f:%02x;PC:%04x;S:%02x\n",
            u_mem.mem['h60],u_mem.mem['h7f],u_mem.mem['h7e],u_mem.mem['h7d],u_mem.mem['h7c],u_mem.mem['h5f],uut.u_regs.pc,uut.u_regs.s);
        irq=0;
    end
endtask

// The manual says a request arriving while I=1 is internally latched until
// I clears. Exercise both CLI and RTI unmasking with edge pulses longer than
// the P5 tcyc+250ns minimum, expressed here as two and three E cycles.
task assess_masked_irq_latch(input integer via_rti, input integer pulse_cen);
    integer watchdog, pulse_edges, eligible_boundaries;
    reg [12:0] expected_boundary;
    reg reached_vector;
    reg [12:0] observed_vector, first_eligible_addr, first_eligible_pc;
    begin
        for(k=0;k<24;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffa,8'h03); set_bytes('h1ffb,8'h00);
        set_bytes('h0300,8'h80);
        if(via_rti) begin
            set_bytes('h0200,8'h9d); set_bytes('h0201,8'h80); set_bytes('h0202,8'h9d);
            set_bytes('h007b,8'h00); set_bytes('h007c,8'h00);
            set_bytes('h007d,8'h00); set_bytes('h007e,8'h02); set_bytes('h007f,8'h02);
            expected_boundary=13'h0202;
        end else begin
            set_bytes('h0200,8'h9d); set_bytes('h0201,8'h9a); set_bytes('h0202,8'h9d);
            // A pending IRQ is checked as CLI completes. The I0 micro-op and
            // NI share this edge, so the return PC is the following byte.
            expected_boundary=13'h0202;
        end
        irq=0; tirq=0; begin_reset(); watchdog=0;
        while(!(cen && uut.u_ctrl.ni && addr==='h0200 && uut.md[7:0]===8'h9d) && watchdog<400) begin
            @(posedge clk); watchdog=watchdog+1;
        end
        if(watchdog>=400) fail("masked IRQ latch fixture did not reach masked NOP");
        if(via_rti) begin
            // Seed the valid return frame after reset has completed.
            uut.u_regs.s=5'h1a;
        end
        @(negedge clk); irq=1; pulse_edges=0;
        while(pulse_edges<pulse_cen) begin
            @(posedge clk);
            if(cen) begin
                pulse_edges=pulse_edges+1;
                if(uut.u_regs.i!==1)
                    fail($sformatf("IRQ pulse was not fully masked: I=%b at asserted edge %0d",uut.u_regs.i,pulse_edges));
            end
        end
        @(negedge clk); irq=0;
        // Observe the actual completion edge. CLI's final micro-op clears I
        // on NI; RTI has already restored I before its final NI. In either
        // case the first eligible boundary must accept this released pulse.
        watchdog=0; reached_vector=0; observed_vector=13'h1fff;
        eligible_boundaries=0; first_eligible_addr=13'h1fff; first_eligible_pc=13'h1fff;
        while(!reached_vector && watchdog<400) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni &&
               (uut.u_regs.i===0 || uut.u_ctrl.cc_sel==4'd5)) begin
                eligible_boundaries=eligible_boundaries+1;
                if(eligible_boundaries==1) begin
                    first_eligible_addr=addr;
                    first_eligible_pc=uut.u_regs.pc;
                end
                if(addr!==expected_boundary)
                    fail($sformatf("masked IRQ first unmasked boundary was %04x, expected %04x",addr,expected_boundary));
            end
            if(cen && uut.u_ctrl.ni && addr>=13'h0300 && addr<13'h0400) begin
                observed_vector=addr;
                reached_vector=1;
            end
        end
        if(reached_vector && observed_vector!==13'h0300)
            fail($sformatf("latched IRQ reached wrong handler boundary %04x, expected 0300",observed_vector));
        else if(!reached_vector) begin
            pending_irq_deviations=pending_irq_deviations+1;
            $display("FAIL: IRQ pulse masked with I=1 (%0d enabled edges), released before %s; manual requires latched service",pulse_edges,via_rti ? "RTI" : "CLI");
            fail("masked IRQ edge was not retained until unmask");
        end else begin
            if(eligible_boundaries!=1 || first_eligible_addr!==expected_boundary)
                fail($sformatf("masked IRQ service missed first eligible boundary; count=%0d first=%04x",eligible_boundaries,first_eligible_addr));
            if(first_eligible_pc!==expected_boundary)
                fail($sformatf("masked IRQ full return PC=%04x at first boundary, expected %04x",first_eligible_pc,expected_boundary));
            if(u_mem.mem['h7f]!==expected_boundary[7:0])
                fail($sformatf("masked IRQ saved return PCL=%02x, expected %02x at first eligible boundary",u_mem.mem['h7f],expected_boundary[7:0]));
            $display("MASKED-IRQ: %0d-CEN pulse serviced at first %s boundary %04x; saved PCL=%02x",pulse_edges,via_rti ? "RTI-unmasked" : "CLI-unmasked",expected_boundary,u_mem.mem['h7f]);
        end
        $fwrite(detail_fd,"masked-irq-%s,0300,%s,%0d,boundaries=%0d,first=%04x,pcl=%02x\n",via_rti ? "rti" : "cli",reached_vector ? "match" : "mismatch",pulse_edges,eligible_boundaries,first_eligible_addr,u_mem.mem['h7f]);
        irq=0;
    end
endtask

// A request arriving during SEI remains pending but masked on SEI's
// same-boundary I1 write. A later CLI must release it immediately.
task assess_sei_edge_mask;
    integer watchdog, pulse_edges, masked_edges;
    reg reached_sei, reached_nop, early_vector, reached_vector;
    begin
        for(k=0;k<24;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffa,8'h03); set_bytes('h1ffb,8'h00);
        set_bytes('h0200,8'h9a); // CLI
        set_bytes('h0201,8'h9b); // SEI
        set_bytes('h0202,8'h9d);
        set_bytes('h0203,8'h9a); // CLI releases the retained request
        set_bytes('h0204,8'h9d);
        set_bytes('h0300,8'h80);
        irq=0; tirq=0; begin_reset(); watchdog=0; reached_sei=0;
        while(!reached_sei && watchdog<500) begin
            @(negedge clk); watchdog=watchdog+1;
            // This is SEI's final fetch, one CEN before its I1+NI write.
            // The edge is latched before the same-boundary mask decision.
            if(cen && uut.fetch && addr==='h0202 && din===8'h9d)
                reached_sei=1;
        end
        if(!reached_sei) fail("SEI IRQ-mask fixture did not reach its final fetch");
        @(negedge clk); irq=1; pulse_edges=0;
        watchdog=0; early_vector=0; reached_nop=0; masked_edges=0;
        // Prove the first instruction after SEI executes before service.
        while(pulse_edges<8) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen) begin
                pulse_edges=pulse_edges+1;
                if(uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                    early_vector=1;
                if(uut.u_ctrl.ni && addr==='h0202 && uut.md[7:0]===8'h9d)
                    reached_nop=1;
            end
        end
        @(negedge clk); irq=0;
        while(!reached_nop && !early_vector && watchdog<500) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                early_vector=1;
            if(cen && uut.u_ctrl.ni && addr==='h0202 && uut.md[7:0]===8'h9d)
                reached_nop=1;
        end
        if(!reached_nop && !early_vector) fail("SEI fixture did not reach the post-SEI NOP boundary");
        if(early_vector) fail("IRQ accepted at SEI completion after I was set");
        if(uut.u_regs.i!==1) fail("SEI did not leave I set while IRQ remained masked");
        watchdog=0; reached_vector=0;
        while(!reached_vector && watchdog<600) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                reached_vector=1;
        end
        if(!reached_vector) fail("IRQ request was lost between SEI masking and later CLI");
        else if(u_mem.mem['h7f]!==8'h04)
            fail($sformatf("SEI/CLI retained IRQ saved PCL=%02x, expected 04",u_mem.mem['h7f]));
        else $display("MASKED-IRQ-SEI: %0d-CEN edge remained masked through SEI and pending until CLI; saved PCL=04",pulse_edges);
        $fwrite(detail_fd,"masked-irq-sei,0300,%s,%0d,masked=%0d,pcl=%02x\n",reached_vector ? "match" : "mismatch",pulse_edges,masked_edges,u_mem.mem['h7f]);
        irq=0;
    end
endtask

// A held asserted input produces only one edge request. Returning from the
// first ISR must not retrigger until the pin has gone inactive and active
// again. This also checks that the latch clears on IRQ acceptance.
task assess_irq_edge_rearm;
    integer watchdog, pulse_edges;
    reg reached_first, returned, reached_second;
    begin
        for(k=0;k<20;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffa,8'h03); set_bytes('h1ffb,8'h00);
        set_bytes('h0200,8'h9a); // CLI
        set_bytes('h0201,8'h9d);
        set_bytes('h0300,8'h80); // RTI
        irq=0; tirq=0; begin_reset(); watchdog=0;
        while(!(cen && uut.u_ctrl.ni && addr==='h0201 && uut.md[7:0]===8'h9d) && watchdog<400) begin
            @(posedge clk); watchdog=watchdog+1;
        end
        if(watchdog>=400) fail("IRQ edge-rearm fixture did not reach unmasked NOP");
        @(negedge clk); irq=1;
        watchdog=0; reached_first=0;
        while(!reached_first && watchdog<600) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                reached_first=1;
        end
        if(!reached_first) fail("first edge-triggered IRQ did not reach handler");
        watchdog=0; returned=0; reached_second=0;
        while(!returned && watchdog<800) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                reached_second=1;
            if(cen && uut.u_ctrl.ni && addr==='h0202 && uut.md[7:0]===8'h9d && uut.u_regs.i===0)
                returned=1;
        end
        if(reached_second) fail("held IRQ level retriggered without a new edge");
        if(!returned) fail("edge-triggered IRQ handler did not return while input remained asserted");
        watchdog=0;
        while(watchdog<40) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                fail("held IRQ level retriggered after RTI");
        end
        @(negedge clk); irq=0; pulse_edges=0;
        while(pulse_edges<8) begin
            @(posedge clk);
            if(cen) pulse_edges=pulse_edges+1;
        end
        @(negedge clk); irq=1; pulse_edges=0;
        while(pulse_edges<8) begin
            @(posedge clk);
            if(cen) pulse_edges=pulse_edges+1;
        end
        @(negedge clk); irq=0;
        watchdog=0; reached_second=0;
        while(!reached_second && watchdog<600) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                reached_second=1;
        end
        if(!reached_second) fail("IRQ did not rearm after inactive-to-active transition");
        else $display("IRQ-EDGE: held level serviced once; inactive-to-active edge serviced again");
        $fwrite(detail_fd,"irq-edge-rearm,2-service-edges,%s,%0d\n",reached_second ? "match" : "mismatch",pulse_edges);
        irq=0;
    end
endtask

// Reset discards an unaccepted masked request. The next CLI after reset must
// not service the old edge once the input is inactive.
task assess_irq_reset_clear;
    integer watchdog, pulse_edges;
    reg reached_masked, reached_vector;
    begin
        for(k=0;k<16;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffa,8'h03); set_bytes('h1ffb,8'h00);
        set_bytes('h0200,8'h9d); set_bytes('h0201,8'h9a); set_bytes('h0202,8'h9d);
        set_bytes('h0300,8'h9d);
        irq=0; tirq=0; begin_reset(); watchdog=0; reached_masked=0;
        while(!reached_masked && watchdog<400) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0200 && uut.md[7:0]===8'h9d)
                reached_masked=1;
        end
        if(!reached_masked) fail("IRQ reset-clear fixture did not reach masked NOP");
        @(negedge clk); irq=1; pulse_edges=0;
        while(pulse_edges<8) begin
            @(posedge clk);
            if(cen) pulse_edges=pulse_edges+1;
        end
        @(negedge clk); irq=0;
        begin_reset();
        watchdog=0; reached_vector=0;
        while(watchdog<600) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h9d)
                reached_vector=1;
        end
        if(reached_vector) fail("masked IRQ pending request survived reset");
        else $display("IRQ-RESET: reset cleared the unaccepted masked request");
        $fwrite(detail_fd,"irq-reset-clear,no-post-reset-vector,%s,%0d\n",reached_vector ? "mismatch" : "match",pulse_edges);
    end
endtask

// Capture IRQ while CEN is paused, either entirely inside the gap or across
// resume. The `clk` periods here are normalized to the established 4 CEN/E
// CPU model; no literal simulation nanoseconds are claimed as part timing.
task assess_irq_pause_capture(input integer spanning);
    integer watchdog, pause_edges, resumed_edges, eligible_boundaries, post_edges;
    integer writes_before;
    reg reached_pause, reached_vector, second_vector;
    reg [12:0] pause_addr, expected_boundary, first_eligible_addr, first_eligible_pc;
    reg [5:0] pause_sp;
    begin
        for(k=0;k<24;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffa,8'h03); set_bytes('h1ffb,8'h00);
        set_bytes('h0300,8'h80);
        if(spanning) begin
            set_bytes('h0200,8'h9d); set_bytes('h0201,8'h9a); set_bytes('h0202,8'h9d);
            expected_boundary=13'h0202;
        end else begin
            set_bytes('h0200,8'h9a); set_bytes('h0201,8'h9d); set_bytes('h0202,8'h9d);
            expected_boundary=13'h0202;
        end
        irq=0; tirq=0; pause_cen=0; begin_reset(); watchdog=0; reached_pause=0;
        while(!reached_pause && watchdog<500) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr===(spanning ? 13'h0200 : 13'h0201) &&
               uut.md[7:0]===8'h9d)
                reached_pause=1;
        end
        if(!reached_pause) fail($sformatf("IRQ CEN-pause fixture %0d did not reach its pre-pause NOP",spanning));
        @(negedge clk); pause_cen=1;
        pause_addr=addr; pause_sp=uut.u_regs.s; writes_before=write_edges;
        @(negedge clk); irq=1; pause_edges=0;
        while(pause_edges<(spanning ? 16 : 32)) begin
            @(posedge clk); pause_edges=pause_edges+1;
        end
        if(!spanning) begin @(negedge clk); irq=0; end
        repeat(4) @(negedge clk);
        if(addr!==pause_addr || uut.u_regs.s!==pause_sp || write_edges!=writes_before || wr)
            fail($sformatf("IRQ CEN-pause fixture %0d advanced CPU/bus during pause",spanning));
        if(!uut.u_ctrl.irq_pending)
            fail($sformatf("IRQ CEN-pause fixture %0d lost edge before resume",spanning));
        @(negedge clk); pause_cen=0;
        watchdog=0; reached_vector=0; second_vector=0;
        eligible_boundaries=0; first_eligible_addr=13'h1fff; first_eligible_pc=13'h1fff; resumed_edges=0;
        // Resuming at a CEN phase where the first eligible edge is imminent
        // can put that boundary on this same negedge; sample it before the
        // next posedge instead of skipping to the following negedge.
        if(cen && uut.u_ctrl.ni &&
           (uut.u_regs.i===0 || uut.u_ctrl.cc_sel==4'd5)) begin
            eligible_boundaries=eligible_boundaries+1;
            first_eligible_addr=addr;
            first_eligible_pc=uut.u_regs.pc;
            if(addr!==expected_boundary)
                fail($sformatf("IRQ pause fixture %0d first eligible boundary %04x expected %04x",spanning,addr,expected_boundary));
        end
        while(!reached_vector && watchdog<1000) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen && irq) resumed_edges=resumed_edges+1;
            if(spanning && !uut.u_regs.i && irq) irq=0;
            if(cen && uut.u_ctrl.ni &&
               (uut.u_regs.i===0 || uut.u_ctrl.cc_sel==4'd5)) begin
                eligible_boundaries=eligible_boundaries+1;
                if(eligible_boundaries==1) begin
                    first_eligible_addr=addr;
                    first_eligible_pc=uut.u_regs.pc;
                end
                if(addr!==expected_boundary)
                    fail($sformatf("IRQ pause fixture %0d first eligible boundary %04x expected %04x",spanning,addr,expected_boundary));
            end
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                reached_vector=1;
        end
        if(!reached_vector) fail($sformatf("IRQ CEN-pause fixture %0d did not vector after resume",spanning));
        if(eligible_boundaries!=1 || first_eligible_addr!==expected_boundary)
            fail($sformatf("IRQ CEN-pause fixture %0d missed first eligible boundary count=%0d first=%04x",spanning,eligible_boundaries,first_eligible_addr));
        if(first_eligible_pc!==expected_boundary)
            fail($sformatf("IRQ CEN-pause fixture %0d full return PC=%04x expected %04x",spanning,first_eligible_pc,expected_boundary));
        if(u_mem.mem['h7f]!==expected_boundary[7:0])
            fail($sformatf("IRQ CEN-pause fixture %0d saved PCL=%02x expected %02x",spanning,u_mem.mem['h7f],expected_boundary[7:0]));
        if(spanning && resumed_edges<8)
            fail($sformatf("IRQ pause-spanning assertion lasted only %0d resumed CEN edges, expected >=8",resumed_edges));
        if(!spanning && resumed_edges!=0)
            fail($sformatf("IRQ pause-only pulse remained active for %0d CEN edges after resume",resumed_edges));
        post_edges=0;
        while(post_edges<80) begin
            @(negedge clk);
            if(cen) begin
                post_edges=post_edges+1;
                if(uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80) begin
                    second_vector=1;
                    fail($sformatf("IRQ CEN-pause fixture %0d duplicated service after RTI",spanning));
                end
            end
        end
        if(!second_vector)
            $display("IRQ-CEN-PAUSE: %s pulse (%0d paused clk edges) retained, accepted once at %04x after resume; no paused bus writes",
                spanning ? "pause-spanning" : "pause-contained",pause_edges,expected_boundary);
        $fwrite(detail_fd,"irq-cen-pause-%s,%04x,%s,pause_clk=%0d,resume_cen=%0d,pcl=%02x\n",
            spanning ? "span" : "inside",expected_boundary,reached_vector ? "match" : "mismatch",pause_edges,resumed_edges,u_mem.mem['h7f]);
        irq=0; pause_cen=0;
    end
endtask

// An IRQ edge first observed on the same master edge as an eligible NI is
// captured for the following boundary: arbitration sees the old pending bit.
// Keep that phase behavior separate from requests captured before NI.
task assess_irq_ni_phase;
    integer watchdog, pulse_edges, eligible_boundaries;
    reg found_target, reached_vector;
    reg [12:0] first_boundary;
    begin
        for(k=0;k<20;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffa,8'h03); set_bytes('h1ffb,8'h00);
        set_bytes('h0200,8'h9a); set_bytes('h0201,8'h9d);
        set_bytes('h0202,8'h9d); set_bytes('h0203,8'h9d);
        set_bytes('h0300,8'h80);
        irq=0; tirq=0; begin_reset(); watchdog=0; found_target=0;
        while(!found_target && watchdog<600) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && uut.u_regs.i===0 &&
               addr==='h0202 && uut.md[7:0]===8'h9d)
                found_target=1;
        end
        if(!found_target) fail("NI-phase IRQ fixture did not reach eligible NOP 0202");
        // This rising edge is sampled at the same posedge which consumes the
        // current NI boundary. The old pending register is still clear here.
        eligible_boundaries=1; first_boundary=addr; irq=1;
        pulse_edges=0;
        watchdog=0; reached_vector=0;
        while(!reached_vector && watchdog<800) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && uut.u_regs.i===0 && addr<13'h0300) begin
                eligible_boundaries=eligible_boundaries+1;
                if(eligible_boundaries==1) first_boundary=addr;
            end
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                reached_vector=1;
            if(cen && pulse_edges<8) pulse_edges=pulse_edges+1;
            if(pulse_edges==8 && irq) irq=0;
        end
        if(!reached_vector) fail("NI-phase IRQ edge was not serviced after capture");
        if(eligible_boundaries!=2 || first_boundary!==13'h0202)
            fail($sformatf("NI-edge phase expected current boundary 0202 then service boundary 0203; observed count=%0d first=%04x",eligible_boundaries,first_boundary));
        if(u_mem.mem['h7f]!==8'h03)
            fail($sformatf("NI-edge phase saved PCL=%02x expected 03 after one same-edge opcode",u_mem.mem['h7f]));
        else $display("IRQ-NI-PHASE: edge sampled on NI queued for next boundary; one intervening opcode, saved PCL=03");
        $fwrite(detail_fd,"irq-ni-phase,next-boundary,eligible=%0d,first=%04x,pcl=%02x\n",eligible_boundaries,first_boundary,u_mem.mem['h7f]);
        irq=0;
    end
endtask

// A fresh edge coincident with acknowledgement must survive set-vs-clear
// priority and produce exactly one later service.
task assess_irq_edge_at_ack;
    integer watchdog, pulse_edges, handler_hits, post_edges;
    reg found_masked, found_ack, third_vector;
    begin
        for(k=0;k<24;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffa,8'h03); set_bytes('h1ffb,8'h00);
        set_bytes('h0200,8'h9d); set_bytes('h0201,8'h9a);
        set_bytes('h0202,8'h9d); set_bytes('h0203,8'h9d);
        set_bytes('h0300,8'h80);
        irq=0; tirq=0; begin_reset(); watchdog=0; found_masked=0;
        while(!found_masked && watchdog<500) begin
            @(posedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0200 && uut.md[7:0]===8'h9d)
                found_masked=1;
        end
        if(!found_masked) fail("IRQ ack-edge fixture did not reach masked NOP");
        @(negedge clk); irq=1; pulse_edges=0;
        while(pulse_edges<8) begin
            @(posedge clk); if(cen) pulse_edges=pulse_edges+1;
        end
        @(negedge clk); irq=0;
        watchdog=0;
        watchdog=0; found_ack=0;
        while(!found_ack && watchdog<500) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni &&
               (uut.u_regs.i===0 || uut.u_ctrl.cc_sel==4'd5) && addr==='h0202)
                found_ack=1;
        end
        if(!found_ack) fail("IRQ ack-edge fixture missed the first eligible boundary");
        // Existing pending request is accepted on the next posedge while a
        // second inactive-to-active event is sampled on that same edge.
        irq=1; handler_hits=0; watchdog=0;
        while(handler_hits<2 && watchdog<1600) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80) begin
                handler_hits=handler_hits+1;
                if(handler_hits==1 && !uut.u_ctrl.irq_pending)
                    fail("fresh IRQ edge coincident with acknowledgement was not retained");
            end
        end
        if(handler_hits!=2) fail($sformatf("IRQ ack-edge expected two services, observed %0d",handler_hits));
        if(u_mem.mem['h7f]!==8'h02)
            fail($sformatf("IRQ ack-edge saved PCL=%02x expected 02",u_mem.mem['h7f]));
        post_edges=0; third_vector=0;
        while(post_edges<100) begin
            @(negedge clk);
            if(cen) post_edges=post_edges+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                third_vector=1;
        end
        if(third_vector) fail("IRQ ack-edge held level duplicated service after the second edge was consumed");
        else $display("IRQ-ACK-EDGE: simultaneous fresh edge survived first ack; exactly two services");
        $fwrite(detail_fd,"irq-edge-at-ack,expected-2-services,%s,pulse=%0d\n",third_vector ? "mismatch" : "match",pulse_edges);
        irq=0;
    end
endtask

// A logical IRQ level held active across reset release is not a new edge.
// A later opposite level held for 2E rearms the input before the next 2E pulse.
task assess_irq_held_reset;
    integer watchdog, low_edges, high_edges, post_edges;
    reg unexpected_vector, reached_vector, second_vector;
    begin
        for(k=0;k<24;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h1ffa,8'h03); set_bytes('h1ffb,8'h00);
        set_bytes('h0200,8'h9a); set_bytes('h0201,8'h9d); set_bytes('h0202,8'h9d);
        set_bytes('h0300,8'h80);
        irq=1; tirq=0; begin_reset(); watchdog=0; unexpected_vector=0;
        while(watchdog<600) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                unexpected_vector=1;
        end
        if(unexpected_vector) fail("active IRQ held across reset release synthesized a new edge");
        else $display("IRQ-RESET-LEVEL: active pin through reset release did not create a request");
        @(negedge clk); irq=0; low_edges=0;
        while(low_edges<8) begin @(posedge clk); if(cen) low_edges=low_edges+1; end
        @(negedge clk); irq=1; high_edges=0;
        while(high_edges<8) begin @(posedge clk); if(cen) high_edges=high_edges+1; end
        @(negedge clk); irq=0;
        watchdog=0; reached_vector=0;
        while(!reached_vector && watchdog<800) begin
            @(negedge clk); watchdog=watchdog+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                reached_vector=1;
        end
        if(!reached_vector) fail("qualified rearm and IRQ pulse after reset did not service");
        post_edges=0; second_vector=0;
        while(post_edges<80) begin
            @(negedge clk);
            if(cen) post_edges=post_edges+1;
            if(cen && uut.u_ctrl.ni && addr==='h0300 && uut.md[7:0]===8'h80)
                second_vector=1;
        end
        if(second_vector) fail("reset-level rearm pulse caused duplicate IRQ service");
        else $display("IRQ-RESET-LEVEL: 2E inactive and active intervals rearmed one service");
        $fwrite(detail_fd,"irq-held-reset,rearm-2e,unexpected=%0d,served=%0d,low=%0d,high=%0d\n",unexpected_vector,reached_vector,low_edges,high_edges);
        irq=0;
    end
endtask

task assess_cen_pause;
    integer watchdog, start_ticks, wall_edges, old_edges, k;
    reg [12:0] held_addr;
    reg [7:0] held_dout;
    reg held_wr;
    begin
        for(k=0;k<32;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h0200,8'h9a); // CLI
        set_bytes('h0201,8'ha6); set_bytes('h0202,8'h5a);
        set_bytes('h0203,8'hb7); set_bytes('h0204,8'h30);
        set_bytes('h0205,8'h9d); set_bytes('h0030,0);
        pause_cen=0; irq=0; tirq=0; begin_reset();
        watchdog=0;
        while(!(cen && uut.u_ctrl.ni && addr==='h0203 && uut.md[7:0]===8'hb7) && watchdog<400) begin
            @(posedge clk); watchdog=watchdog+1;
        end
        if(watchdog>=400) fail("CEN pause fixture did not reach STA");
        held_addr=addr; held_dout=dout; held_wr=wr; start_ticks=write_edges;
        pause_cen=1; wall_edges=0;
        @(negedge clk); old_edges=ticks;
        repeat(12) begin
            @(posedge clk); wall_edges=wall_edges+1;
            #1;
            if(addr!==held_addr || dout!==held_dout || wr!==held_wr)
                fail("public bus changed while CEN was held low");
            if(ticks!==old_edges) fail("enabled-edge counter advanced while CEN was held low");
        end
        pause_cen=0;
        watchdog=0;
        while(write_edges==start_ticks && watchdog<300) begin @(posedge clk); watchdog=watchdog+1; end
        repeat(8) @(posedge clk);
        #2;
        if(watchdog>=300 || u_mem.mem['h30]!==8'h5a) fail($sformatf("STA did not commit after CEN resumed (wait=%0d writes=%0d mem=%02x)",watchdog,write_edges-start_ticks,u_mem.mem['h30]));
        $display("CEN-HOLD: %0d master edges held; public bus stable, enabled-edge count held, STA resumed",wall_edges);
    end
endtask

// Three semantic-only address probes supplement the fixed 237-case timing
// baseline. They check nonzero X arithmetic for IX1/IX2 and the P3 wrapper's
// physical 11-bit alias. The manual specifies X as an 8-bit addend; the P3
// sheet limits the physical program/data address pins to A10:A0.
task assess_addressed_load(input integer probe_id, input [7:0] opcode,
                           input [7:0] x_seed, input [7:0] off_hi,
                           input [7:0] off_lo, input [12:0] effective_addr,
                           input [12:0] poison_addr, input [7:0] expected_data,
                           input integer operand_bytes);
    integer watchdog, drain_edges;
    reg [12:0] sampled_addr;
    reg sampled_wr, sampled_ni, sampled_cen;
    reg [7:0] sampled_md;
    reg read_seen, endpoint_seen;
    begin
        case_id=300+probe_id; case_writes=0;
        for(k=0;k<16;k=k+1) set_bytes('h0200+k,8'h9d);
        set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
        set_bytes('h0200,8'h9d); // reset warmup
        set_bytes('h0201,opcode);
        if(operand_bytes==1) begin
            set_bytes('h0202,off_lo); set_bytes('h0203,8'h9d);
        end else begin
            set_bytes('h0202,off_hi); set_bytes('h0203,off_lo); set_bytes('h0204,8'h9d);
        end
        set_bytes(effective_addr,expected_data);
        set_bytes(poison_addr,expected_data ^ 8'hff);
        irq=0; tirq=0; begin_reset(); watchdog=0;
        while(!(uut.fetch && addr==='h0201 && din===opcode) && watchdog<400) begin
            @(negedge clk); watchdog=watchdog+1;
        end
        if(watchdog>=400) fail($sformatf("address effect %0d did not reach opcode fetch",probe_id));
        uut.u_regs.x=x_seed;
        read_seen=0; endpoint_seen=0; watchdog=0;
        while(!endpoint_seen && watchdog<500) begin
            @(posedge clk); watchdog=watchdog+1;
            sampled_addr=addr; sampled_wr=wr; sampled_ni=uut.u_ctrl.ni;
            sampled_cen=cen;
            sampled_md=uut.md[7:0];
            #1;
            if(sampled_cen && !sampled_wr && sampled_addr===effective_addr && din===expected_data)
                read_seen=1;
            if(sampled_cen && sampled_ni && sampled_addr===((operand_bytes==1) ? 13'h0203 : 13'h0204) && sampled_md===8'h9d)
                endpoint_seen=1;
        end
        if(!endpoint_seen) fail($sformatf("address effect %0d did not reach successor opcode",probe_id));
        drain_edges=0;
        while(drain_edges<4) begin
            @(posedge clk); if(cen) drain_edges=drain_edges+1;
        end
        #2;
        if(!read_seen || uut.u_regs.a!==expected_data)
            fail($sformatf("address effect %0d op=%02x read=%b bus=%04x A=%02x expected EA=%04x data=%02x poison=%04x",
                probe_id,opcode,read_seen,sampled_addr,uut.u_regs.a,effective_addr,expected_data,poison_addr));
        else begin
            address_effect_cases=address_effect_cases+1;
            $display("ADDRESS-EFFECT probe=%0d op=%02x X=%02x offset=%02x%02x public_EA=%04x physical_EA=%04x A=%02x poison=%04x distinct",
                probe_id,opcode,x_seed,off_hi,off_lo,effective_addr,effective_addr[10:0],uut.u_regs.a,poison_addr);
            $fwrite(detail_fd,"address-effect-%0d,EA=%04x;physical=%04x;data=%02x;poison=%04x,match\n",
                probe_id,effective_addr,effective_addr[10:0],expected_data,poison_addr);
        end
    end
endtask

task assess_addressing_effects;
    begin
        // LDA IX1: X=$30 plus unsigned offset $F0 carries into EA=$0120.
        // Poison at $0020 catches an implementation that drops the carry.
        assess_addressed_load(1,8'he6,8'h30,8'h00,8'hf0,13'h0120,13'h0020,8'ha6,1);
        // LDA IX2: X=$20 plus 16-bit offset $0150 gives EA=$0170. Poison at
        // $0070 catches ignoring the high operand byte.
        assess_addressed_load(2,8'hd6,8'h20,8'h01,8'h50,13'h0170,13'h0070,8'hb7,2);
        // P3 has only A10:A0 physically decoded. Public EA=$0800 must read
        // physical $0000; adjacent physical $0001 is a distinct poison.
        assess_addressed_load(3,8'hc6,8'h00,8'h08,8'h00,13'h0800,13'h0001,8'hc8,2);
        if(address_effect_cases!=3)
            fail($sformatf("address effect probes passed %0d/3",address_effect_cases));
    end
endtask

integer code, length, hmos, cmos_exp, extension;
integer elapsed, j;
initial begin
    $readmemh("manual_cases.hex",manual_cases);
    #1;
    for(i=0;i<2048;i=i+1) u_mem.mem[i]=8'h00;
    trace_fd=$fopen("bus_trace.csv","w");
    write_fd=$fopen("write_trace.csv","w");
    result_fd=$fopen("timing_results.csv","w");
    service_fd=$fopen("service_results.csv","w");
    detail_fd=$fopen("service_details.csv","w");
    $fwrite(trace_fd,"case,cen_edge,addr,din,dout,wr,stop,irq,tirq,fetch,uaddr,h,i,n,z,c\n");
    $fwrite(write_fd,"case,cen_edge,addr,dout\n");
    $fwrite(result_fd,"opcode,bytes,hmos,cmos,observed,path,class\n");
    $fwrite(service_fd,"source,vector,manual_cycles,manual_cen_edges,observed_cen_edges,stack_writes,handler_writes,sp_after_rti,i_after_rti,handler_reached\n");
    $fwrite(detail_fd,"case,expected,observed,status_or_edges\n");
    $dumpfile("test.lxt"); $dumpvars(0,clk,rst,cen,irq,tirq,addr,din,dout,wr,stop);

    // Public-bus calibration: reset path is excluded; three steady NOPs
    // independently establish exactly four enabled clocks per E cycle.
    set_bytes('h1ffe,8'h02); set_bytes('h1fff,8'h00);
    set_bytes('h0200,8'h9d); set_bytes('h0201,8'h9d); set_bytes('h0202,8'h9d);
    set_bytes('h0203,8'h9d); set_bytes('h0204,8'h9d);
    begin_reset();
    wait_bus_case('h0201,8'h9d,'h0202,300,elapsed);
    if(elapsed!=2) fail($sformatf("steady NOP 1 observed %0d, expected 2",elapsed));
    wait_bus_case('h0202,8'h9d,'h0203,300,elapsed);
    if(elapsed!=2) fail($sformatf("steady NOP 2 observed %0d, expected 2",elapsed));
    wait_bus_case('h0203,8'h9d,'h0204,300,elapsed);
    if(elapsed!=2) fail($sformatf("steady NOP 3 observed %0d, expected 2",elapsed));
    $display("CALIBRATION: three steady opcode-acceptance NOP intervals = 2 E each, 4 CEN/E; reset entry excluded");

    for(j=0;j<209;j=j+1) begin
        code=manual_cases[j][31:24]; length=manual_cases[j][23:20];
        hmos=manual_cases[j][19:16]; cmos_exp=manual_cases[j][15:12]; extension=manual_cases[j][11:8];
        if(!extension) begin
            assess_one(code[7:0],length,hmos,cmos_exp,-1);
            inventory_rows=inventory_rows+1;
            if(code<=8'h0f) assess_one(code[7:0],length,hmos,cmos_exp,code[0] ? 0 : 1);
            else if(code>=8'h22 && code<=8'h2f) begin
                case(code[3:0])
                    4'h2,4'h4,4'h6,4'h8,4'ha,4'hd,4'hf: assess_one(code[7:0],length,hmos,cmos_exp,0);
                    default: assess_one(code[7:0],length,hmos,cmos_exp,1);
                endcase
            end
        end
    end
    assess_interrupt(0);
    assess_interrupt(1);
    assess_legal_stack_wrap();
    assess_irq_stack_wrap();
    assess_interrupt_priority();
    assess_masked_irq_latch(0,8);
    assess_masked_irq_latch(1,12);
    assess_sei_edge_mask();
    assess_irq_edge_rearm();
    assess_irq_reset_clear();
    assess_irq_pause_capture(0);
    assess_irq_pause_capture(1);
    assess_irq_ni_phase();
    assess_irq_edge_at_ack();
    assess_irq_held_reset();
    assess_cen_pause();
    assess_addressing_effects();
    $fclose(trace_fd); $fclose(write_fd); $fclose(result_fd); $fclose(service_fd);
    $fclose(detail_fd);
    $display("RESULTS: cases=%0d rows=%0d HMOS-matches=%0d CMOS-matches=%0d overlap=%0d CMOS-only=%0d effects_checked=%0d neither=%0d harness_failures=%0d",
        executed,inventory_rows,hmos_match,cmos_match,both_match,cmos_only,effects_checked,neither_match,failures);
    $display("SERVICE-RESULTS: timing deviations=%0d known masked-IRQ XFAILs=%0d priority deviations=%0d",service_timing_deviations,pending_irq_deviations,priority_deviations);
    $display("ADDRESS-EFFECT-RESULTS: focused indexed/address-alias cases=%0d expected=3 (outside 237 timing baseline)",address_effect_cases);
    if(inventory_rows!=207) fail($sformatf("expected 207 normative encoding rows, exercised %0d",inventory_rows));
    if(executed!=237) fail($sformatf("expected 237 normative instruction/outcome cases, executed %0d",executed));
    if(failures==0 && executed==237 && inventory_rows==207 && hmos_match==237 && neither_match==0)
        $display("PASS: all 237 runtime outcomes match the independent HMOS manual oracle; fixtures and observer are clean");
    else $fatal(1,"assessment harness failure: observer=%0d cases=%0d rows=%0d HMOS-matches=%0d expected=237 neither=%0d",failures,executed,inventory_rows,hmos_match,neither_match);
    $finish;
end

initial begin #200000000; $display("FAIL: bounded simulation timeout"); $finish; end
endmodule
