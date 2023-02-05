`timescale 1ns/1ps

module pocket_dump(
    input        scal_vs,
    input [31:0] frame_cnt
);

`ifdef DUMP
    `ifdef DUMP_START
    always @(posedge scal_vs) if( frame_cnt==`DUMP_START ) begin
    `else
    initial begin
    `endif
        $dumpfile("test.lxt");
        `ifdef DEEPDUMP
            $display("NC Verilog: will dump all signals");
            $dumpvars(0,test);
        `else
            $display("NC Verilog: will dump selected signals");

            $dumpvars(1,UUT.ic.u_frame.u_base.u_cmd);
            $dumpvars(0,u_harness);

        `endif
    end
`endif

endmodule // pocket_dump