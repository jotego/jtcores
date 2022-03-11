`timescale 1ns/1ps

module mist_dump(
    input           VGA_VS,
    input           led,
    input   [31:0]  frame_cnt
);

`ifdef DUMP
`ifndef NCVERILOG // iVerilog:
    initial begin
        // #(200*100*1000*1000);
        $display("DUMP enabled");
        $dumpfile("test.lxt");
    `ifdef LOADROM
        $display("DUMP starts");
        $dumpvars(0,mist_test.UUT.u_game.u_sdram);
        $dumpon;
    `endif
    end
    `ifndef LOADROM
        `ifdef DUMP_START
        always @(negedge VGA_VS) if( frame_cnt==`DUMP_START ) begin
        `else
            initial begin
        `endif
            $display("DUMP starts");
            `ifdef DEEPDUMP
                $dumpvars(0,mist_test);
            `else
                $dumpvars(1,mist_test.UUT.u_game.u_sdram);
                $dumpvars(1,mist_test.UUT.u_game.u_sdram.u_obj32);
                $dumpvars(1,mist_test.UUT.u_game.u_sdram.u_dwnld);
                $dumpvars(1,mist_test.frame_cnt);
            `endif
            $dumpon;
        end
    `endif
`else // NCVERILOG
    `ifdef DUMP_START
    always @(negedge VGA_VS) if( frame_cnt==`DUMP_START ) begin
    `else
    initial begin
    `endif
        $shm_open("test.shm");
        `ifdef DEEPDUMP
            $display("NC Verilog: will dump all signals");
            $shm_probe(mist_test,"AS");
        `else
            $display("NC Verilog: will dump selected signals");
            $shm_probe(frame_cnt);
            $shm_probe(UUT.u_game.u_main,"A");
            $shm_probe(UUT.u_game,"A");
            $shm_probe(UUT.u_game.u_video,"AS");
            //$shm_probe(UUT.u_game.u_video.u_colmix,"A");
            //$shm_probe(UUT.u_game.u_sdram,"A");
            `ifdef LOADROM
                $shm_probe(UUT.u_frame.u_board.u_sdram,"AS");
                $shm_probe(UUT.u_game.u_sdram,"AS");
                $shm_probe(u_harness.u_sdram,"A");
            `endif
            `ifdef DUMP_SDRAM
                $shm_probe(UUT.u_game.u_sdram, "AS");
                $shm_probe(UUT.u_frame.u_board.u_sdram, "AS");
                $shm_probe(UUT.u_game.u_main, "A");
                $shm_probe(u_harness.u_sdram, "A");
            `endif
        `endif
    end
`endif
`endif

endmodule // mist_dump