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
    end
    `ifdef LOADROM
    always @(negedge led) if( $time > 20000 ) begin // led = downloading signal
        $display("DUMP starts");
        $dumpvars(0,mist_test);
        $dumpon;
    end
    `else
        `ifdef DUMP_START
        always @(negedge VGA_VS) if( frame_cnt==`DUMP_START ) begin
        `else
            initial begin
        `endif
            $display("DUMP starts");
            `ifdef DEEPDUMP
                $dumpvars(0,mist_test);
            `else
                $dumpvars(1,mist_test.UUT.u_game.u_main);
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
            //$shm_probe(UUT.u_game.u_dwnld,"A");
            //$shm_probe(UUT.u_game,"A");
            $shm_probe(UUT.u_game.u_main,"A");
            $shm_probe(UUT.u_game.u_video.u_gfx,"A");
            $shm_probe(UUT.u_game.u_video.u_colmix,"A");
            $shm_probe(UUT.u_game.u_video.u_gfx.u_obj,"A");
            $shm_probe(UUT.u_game.u_video.u_gfx.u_tilemap,"A");
            $shm_probe(UUT.u_frame.u_board.u_scan2x,"AS");
            $shm_probe(UUT.u_frame.u_board.u_wirebw,"AS");
            `ifdef NOSOUND
                $shm_probe(UUT.u_game.u_main.u_cpu.u_wait,"A");
            `else
                $shm_probe(UUT.u_game.u_main.u_fm0.u_jt12,"A");
                $shm_probe(UUT.u_game.u_main.u_fm0.u_jt12.u_mmr,"A");
                $shm_probe(UUT.u_game.u_main.u_fm0.u_jt12.u_timers,"AS");

                $shm_probe(UUT.u_game.u_main.u_fm1.u_jt12,"A");
                $shm_probe(UUT.u_game.u_main.u_fm1.u_jt12.u_mmr,"AS");
                $shm_probe(UUT.u_game.u_main.u_fm1.u_jt12.u_timers,"AS");
            `endif
            //$shm_probe(UUT.u_game.u_main.u_prot,"A");
            //$shm_probe(UUT.u_game.u_video,"A");
        `endif
    end
`endif
`endif

endmodule // mist_dump