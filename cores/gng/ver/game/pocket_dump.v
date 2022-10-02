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
            $dumpvars(frame_cnt);
            $dumpvars(1,UUT.u_game);

            `ifndef NOMAIN
                $dumpvars(1,UUT.u_game.u_main);
            `endif
            $dumpvars(1,UUT.u_game.u_sdram);
            //$dumpvars(1,UUT.u_game.u_sdram.u_dwnld);
            //$dumpvars(1,UUT.u_game.u_video);
            `ifndef NOSOUND
                $dumpvars(1,UUT.u_game.u_sound);
            `endif
        `endif
    end
`endif

endmodule // pocket_dump