/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

`timescale 1ns/1ps
module m6802_compare_tb;
parameter TRIALS=64;
parameter NSC=0;
reg started=0;
wire old_done, old_vma;
reg clk=0, rst=1;
reg [3:0] divider=0;
wire cen=divider==0;
reg old_finished=0, new_finished=0;
reg [7:0] old_din, new_din;
wire [7:0] old_dout, new_dout;
wire [15:0] old_addr, new_addr;
wire old_wr, old_ni, new_wr, new_done, new_vma, new_ni;
reg [7:0] old_memory[0:65535], new_memory[0:65535];
integer k, opcode, trial, old_boundaries=0, checked=0, timer=0;
integer observed_cycles=0, new_ticks=0, last_transfer=0;
reg [7:0] flags_mask;
reg [5:0] seed_cc;
string expected_pattern;
reg [7:0] expected_transfer;

always #5 clk=~clk;
always @(posedge clk) begin
    divider <= divider+4'd1;
    old_din <= old_memory[old_addr];
    new_din <= new_memory[new_addr];
    if(!rst) begin
        if(cen && !new_finished) new_ticks=new_ticks+1;
        if(new_done && !new_finished) begin
            if(last_transfer!=0 && new_ticks-last_transfer!=4)
                $fatal(1,"Opcode %h inserted an unrequested E cycle: %0d crystal ticks",opcode,new_ticks-last_transfer);
            last_transfer=new_ticks;
        end
        if(old_done && !old_finished) begin
            if(old_wr && old_vma) old_memory[old_addr]<=old_dout;
            if(old_ni) old_finished=1;
        end
        if(new_done && new_vma && new_wr) new_memory[new_addr]<=new_dout;
        if(new_done && (started || cpu.opcode_fetch) && !new_finished) begin
            started=1;
            expected_transfer=expected_pattern[observed_cycles];
            if(observed_cycles>=expected_pattern.len() ||
               new_vma!==(expected_transfer=="R" || expected_transfer=="W") ||
               new_wr!==(expected_transfer=="W" || expected_transfer=="X"))
                $fatal(1,"Opcode %h bus cycle%0d expected=%c actual VMA/WR=%b/%b",
                    opcode,observed_cycles+1,expected_transfer,new_vma,new_wr);
            observed_cycles=observed_cycles+1;
        end
        if(new_ni) new_finished=1;
    end
end

function valid;
    input [7:0] code;
    begin
        valid=0;
        if(code[7]) begin
            case(code[3:0])
                0,1,2,4,5,6,8,9,10,11,14: valid=1;
                12: valid=!code[6];
                7,15: valid=code[5:4]!=0;
                13: valid=code==8'h8d || code==8'h9d || code==8'had || code==8'hbd;
                default:;
            endcase
        end else if(code[7:4]>=4) begin
            case(code[3:0])
                0,3,4,6,7,8,9,10,12,13,15: valid=1;
                14: valid=code[7:4]>=6;
                default:;
            endcase
        end else if(code[7:4]==2) valid=1;
        else case(code)
            8'h01,8'h06,8'h07,8'h08,8'h09,8'h0a,8'h0b,8'h0c,8'h0d,8'h0e,8'h0f,
            8'h10,8'h11,8'h16,8'h17,8'h19,8'h1b,
            8'h30,8'h31,8'h32,8'h33,8'h34,8'h35,8'h36,8'h37,
            8'h39,8'h3b,8'h3e,8'h3f: valid=1;
            default:;
        endcase
    end
endfunction

function string bus_pattern;
    input [7:0] code;
    begin
        bus_pattern="RR";
        if(code[7]) begin
            case(code[5:4])
                0: bus_pattern=(code[3:0]==12 || code[3:0]==14) ? "RRR" : "RR";
                1: case(code[3:0])
                    7: bus_pattern="RRIW";
                    15: bus_pattern="RRIWW";
                    12,14: bus_pattern="RRRR";
                    default: bus_pattern="RRR";
                endcase
                2: case(code[3:0])
                    7: bus_pattern="RRIIIW";
                    15: bus_pattern="RRIIIWW";
                    12,14: bus_pattern="RRIIRR";
                    default: bus_pattern="RRIIR";
                endcase
                3: case(code[3:0])
                    7: bus_pattern="RRRIW";
                    15: bus_pattern="RRRIWW";
                    12,14: bus_pattern="RRRRR";
                    default: bus_pattern="RRRR";
                endcase
            endcase
        end
        if(code[7:4]==2) bus_pattern="RRII";
        if(code[7:4]==6) bus_pattern=code==8'h6d ? "RRIIRIX" : "RRIIRIW";
        if(code[7:4]==7) bus_pattern=code==8'h7d ? "RRRRIX" : "RRRRIW";
        case(code)
            8'h08,8'h09,8'h30,8'h31,8'h34,8'h35,8'h6e: bus_pattern="RRII";
            8'h36,8'h37: bus_pattern="RRWI";
            8'h32,8'h33: bus_pattern="RRIR";
            8'h39: bus_pattern="RRIRR";
            8'h3b: bus_pattern="RRIRRRRRRR";
            8'h3e: bus_pattern="RRWWWWWWW";
            8'h3f: bus_pattern="RRWWWWWWWIRR";
            8'h7e: bus_pattern="RRR";
            8'h8d,8'had: bus_pattern="RRIWWIII";
            8'h9d: bus_pattern="RRWWIR";
            8'hbd: bus_pattern="RRRRWWIIR";
            default:;
        endcase
    end
endfunction

task set_memory;
    input [15:0] location;
    input [7:0] value;
    begin old_memory[location]=value; new_memory[location]=value; end
endtask

task run_case;
    input [7:0] code;
    input integer seed;
    reg [7:0] initial_a, initial_b, initial_cc;
    begin
        @(negedge clk);
        rst=1;
        old_finished=0; new_finished=0; old_boundaries=0; started=0;
        observed_cycles=0; new_ticks=0; last_transfer=0;
        expected_pattern=bus_pattern(code);
        repeat(4) @(negedge clk);
        set_memory(16'h8000,code);
        if(NSC) new_memory[16'h8000]={code[6],code[7],code[5:2],code[0],code[1]};
        set_memory(16'h8001,8'h35);
        set_memory(16'h8002,8'h01);
        if(code[7] || code[7:5]==3'b011) begin
            case(code[5:4])
                0: begin set_memory(16'h8001,seed*47+8'h81); set_memory(16'h8002,seed*13+8'h27); end
                1: set_memory(16'h8001,8'h20);
                2: set_memory(16'h8001,8'h35);
                3: begin set_memory(16'h8001,8'h90); set_memory(16'h8002,8'h35); end
            endcase
        end
        for(k=0;k<2;k=k+1) begin
            set_memory(16'h0020+k,seed*53+k*21+8'h80);
            set_memory(16'h9035+k,seed*53+k*21+8'h80);
        end
        for(k=0;k<16;k=k+1) set_memory(16'hf878+k,seed*31+k*7);
        set_memory(16'hfffe,8'h80); set_memory(16'hffff,0);
        set_memory(16'hfffa,8'h90); set_memory(16'hfffb,0);
        set_memory(16'h9000,8'h01);
        initial_a=seed*37+8'h7f;
        initial_b=seed*79+8'h81;
        initial_cc={2'b11,seed[5:0]};
        seed_cc=initial_cc[5:0];
        rst=0;
        legacy.a=initial_a; cpu.u_regs.a=initial_a;
        legacy.b=initial_b; cpu.u_regs.b=initial_b;
        legacy.x=16'h9000; cpu.u_regs.x=16'h9000;
        legacy.s=16'hf87f; cpu.u_regs.s=16'hf87f;
        legacy.cc=initial_cc;
        {cpu.u_regs.h,cpu.u_regs.i,cpu.u_regs.n,cpu.u_regs.z,cpu.u_regs.v,cpu.u_regs.c}=initial_cc[5:0];
        timer=0;
        while(!(old_finished && new_finished) && timer<20000) begin
            @(negedge clk);
            timer=timer+1;
        end
        if(timer==20000 || cpu.illegal)
            $fatal(1,"Opcode %h seed%0d timeout old=%b new=%b illegal=%b",code,seed,old_finished,new_finished,cpu.illegal);
        if(observed_cycles!=expected_pattern.len())
            $fatal(1,"Opcode %h cycle count expected=%0d actual=%0d",code,expected_pattern.len(),observed_cycles);
        flags_mask=code==8'h19 ? 8'hfd : 8'hff;
        if({cpu.u_regs.a,cpu.u_regs.b,cpu.u_regs.x,cpu.u_regs.s,cpu.u_regs.pc}!={legacy.a,legacy.b,
            legacy.x,legacy.s,legacy.pc} ||
            (cpu.u_regs.cc & flags_mask)!==(legacy.cc & flags_mask))
            $fatal(1,"Opcode %h seed%0d new A/B/X/S/PC/CC=%h/%h/%h/%h/%h/%h old=%h/%h/%h/%h/%h/%h",
                code,seed,cpu.u_regs.a,cpu.u_regs.b,cpu.u_regs.x,cpu.u_regs.s,cpu.u_regs.pc,cpu.u_regs.cc,
                legacy.a,legacy.b,legacy.x,legacy.s,legacy.pc,
                legacy.cc);
        for(k=0;k<2;k=k+1) begin
            if(new_memory[16'h0020+k]!==old_memory[16'h0020+k] ||
               new_memory[16'h9035+k]!==old_memory[16'h9035+k])
                $fatal(1,"Opcode %h seed%0d memory result mismatch",code,seed);
        end
        for(k=0;k<16;k=k+1) begin
            flags_mask=8'hff;
            if((new_memory[16'hf878+k] & flags_mask)!==(old_memory[16'hf878+k] & flags_mask))
                $fatal(1,"Opcode %h seed%0d stack result mismatch %h new=%h old=%h",code,seed,16'hf878+k,new_memory[16'hf878+k],old_memory[16'hf878+k]);
        end
        if((code==8'h3e || code==8'h3f) && new_memory[16'hf879]!==initial_cc)
            $fatal(1,"WAI/SWI did not stack the pre-interrupt condition code");
        if(code==8'h3f && {new_memory[16'hf87e],new_memory[16'hf87f]}!==16'h8001)
            $fatal(1,"SWI did not stack the return PC");
        checked=checked+1;
    end
endtask

jt680x #(
    .FC_COMPAT       ( 1             )
) cpu(
    .irq             ( 1'b0          ),
    .nmi             ( 1'b0          ),
    .ext_halt        ( 1'b0          ),
    .irq_icf         ( 1'b0          ),
    .irq_ocf         ( 1'b0          ),
    .irq_tof         ( 1'b0          ),
    .irq_sci         ( 1'b0          ),
    .irq_cmf         ( 1'b0          ),
    .irq2            ( 1'b0          ),
    .ba              (               ),
    .nsc8105         ( NSC!=0        ),
    .opcode_fetch    (               ),
    .rst             ( rst           ),
    .cpu_rst         ( rst           ),
    .clk             ( clk           ),
    .cen             ( cen           ),
    .enable          ( !new_finished ),
    .ready           ( 1'b1          ),
    .mr_n            ( 1'b1          ),
    .din             ( new_din       ),
    .addr            ( new_addr      ),
    .dout            ( new_dout      ),
    .e               (               ),
    .vma             ( new_vma       ),
    .wr              ( new_wr        ),
    .done            ( new_done      ),
    .instruction_end ( new_ni        )
);

m6802_reference legacy(
    .rst             ( rst           ),
    .cpu_rst         ( rst           ),
    .clk             ( clk           ),
    .cen             ( cen           ),
    .enable          ( !old_finished ),
    .ready           ( 1'b1          ),
    .mr_n            ( 1'b1          ),
    .din             ( old_din       ),
    .addr            ( old_addr      ),
    .dout            ( old_dout      ),
    .e               (               ),
    .vma             ( old_vma       ),
    .wr              ( old_wr        ),
    .done            ( old_done      ),
    .instruction_end ( old_ni        )
);

initial begin
    for(k=0;k<65536;k=k+1) set_memory(k,8'h01);
    for(opcode=0;opcode<256;opcode=opcode+1) if(valid(opcode)) begin
        for(trial=0;trial<TRIALS;trial=trial+1) run_case(opcode,trial);
    end
    $display("PASS YAML MCU NSC=%0d: %0d opcode/register/flags/memory comparisons",NSC,checked);
    $finish;
end
endmodule
