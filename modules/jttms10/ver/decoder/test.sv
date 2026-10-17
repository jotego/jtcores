`timescale 1ns/1ps
`default_nettype none

// Recognition audit only: architectural execution is checked by the programs.
module test;
    import tms34010_pkg::*;
    reg [15:0] opcode;
    reg clk=0;
    decoded_instr_t decoded;
    wire reserved;
    tms34010_decode u_reference(.instr(opcode), .decoded(decoded));
    jttms10_ctrl u_new(.rst(1'b1), .clk(clk), .md(opcode),
                       .reserved_opcode(reserved));
    jttms10_ctrl_old u_old(.rst(1'b1), .clk(clk), .md(opcode));
    integer index, missing=0, reserved_diff=0, entry_diff=0, recognized=0;
    initial begin
        for(index=0;index<65536;index=index+1) begin
            opcode=index[15:0];
            #1; clk=1; #1;
            if(u_new.entry!==u_old.entry) begin
                $display("entry difference opcode=%h new=%h old=%h",
                         opcode,u_new.entry,u_old.entry);
                entry_diff=entry_diff+1;
            end
            if(!decoded.illegal && !decoded.illegal_trap) begin
                recognized=recognized+1;
                if(u_new.entry==u_new.ILLEGAL_SEQA) begin
                    $display("missing opcode=%h class=%0d",opcode,decoded.iclass);
                    missing=missing+1;
                end
            end
            if(reserved!==decoded.illegal_trap) begin
                $display("reserved difference opcode=%h new=%b reference=%b",
                         opcode,reserved,decoded.illegal_trap);
                reserved_diff=reserved_diff+1;
            end
            clk=0; #1;
        end
        if(missing!=0 || reserved_diff!=0 || entry_diff!=0)
            $fatal(1,"decode audit missing=%0d reserved differences=%0d entry differences=%0d",
                   missing,reserved_diff,entry_diff);
        $display("decode PASS: 65536 words, %0d defined-reference words",recognized);
        $finish;
    end
endmodule
`default_nettype wire
