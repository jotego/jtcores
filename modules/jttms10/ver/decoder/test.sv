`timescale 1ns/1ps
`default_nettype none

// Recognition audit only: architectural execution is checked by the programs.
module test;
    import tms34010_pkg::*;
    reg [15:0] opcode;
    decoded_instr_t decoded;
    wire reserved;
    tms34010_decode u_reference(.instr(opcode), .decoded(decoded));
    // Only MD affects combinational entry/reserved decoding. Keep the ROM
    // clock stopped; the remaining sequencer ports are intentionally unused.
    jttms10_ctrl u_new(.rst(1'b1), .clk(1'b0), .md(opcode),
                       .reserved_opcode(reserved));
    integer index, missing=0, reserved_diff=0, recognized=0;
    initial begin
        for(index=0;index<65536;index=index+1) begin
            opcode=index[15:0];
            #1;
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
        end
        if(missing || reserved_diff)
            $fatal(1,"decode audit missing=%0d reserved differences=%0d",
                   missing,reserved_diff);
        $display("decode PASS: 65536 words, %0d defined-reference words",recognized);
        $finish;
    end
endmodule
`default_nettype wire
