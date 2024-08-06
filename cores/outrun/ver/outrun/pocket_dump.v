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
            $display("Verilog sim will dump all signals");
            $dumpvars(0,test);
        `else
            $display("Verilog sim will dump selected signals");
            // $dumpvars(frame_cnt);
            // $dumpvars(2,UUT.u_frame.u_base.u_lf_buf);
            $dumpvars(1,UUT.u_game.u_game.u_video);
            $dumpvars(2,UUT.u_game.u_game.u_video.u_obj);
            // $dumpvars(0,u_harness.u_cram0);
            $dumpvars(2,UUT);

            `ifndef NOMAIN
                $dumpvars(1,UUT.u_game.u_main);
            `endif
        `endif
    end
`endif

endmodule // pocket_dump