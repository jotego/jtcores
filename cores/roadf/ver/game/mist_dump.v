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
        $display("iverilog: DUMP enabled");
        $dumpfile("test.lxt");
    end
    `ifdef DUMP_START
    always @(negedge VGA_VS) if( frame_cnt==`DUMP_START ) begin
    `else
        initial begin
    `endif
        $display("DUMP starts");
        `ifdef DEEPDUMP
            $dumpvars(0,mist_test);
        `else
            $dumpvars(1,mist_test.UUT.u_game);
            //$dumpvars(1,mist_test.UUT.u_game.u_sound);
            $dumpvars(1,mist_test.UUT.u_game.u_video);
            $dumpvars(1,mist_test.UUT.u_game.u_video.u_scroll);
            $dumpvars(1,mist_test.frame_cnt);
        `endif
        $dumpon;
    end
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
            $shm_probe(UUT.u_game,"A");
            $shm_probe(UUT.u_game.u_main,"A");
            $shm_probe(UUT.u_game.u_sdram,"A");
            $shm_probe(UUT.u_game.u_sdram.u_dwnld,"A");
            // $shm_probe(UUT.u_game.u_sound,"A");
            // $shm_probe(UUT.u_game.u_video,"A");
        `endif
    end
`endif
`endif

endmodule // mist_dump