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
`ifdef IVERILOG
        $dumpfile("test.lxt");
`else
        $dumpfile("test.vcd");
`endif
    end
    `ifdef LOADROM
    //always @(negedge led) if( $time > 20000 ) begin // led = downloading signal
    initial begin
        $display("iverilog: DUMP starts");
        $dumpvars(1,mist_test.UUT.u_game);
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
                $dumpvars(0,mist_test.UUT.u_game.u_main.u_mapper);
                $dumpvars(1,mist_test.UUT.u_game.u_sub);
                // $dumpvars(1,mist_test.UUT.u_game.u_sdram);
                // $dumpvars(1,mist_test.UUT.u_game.u_sdram.u_dwnld);
                //$dumpvars(1,mist_test.UUT.u_game.u_sound);
                $dumpvars(1,mist_test.UUT.u_game.u_video);
                $dumpvars(1,mist_test.UUT.u_game.u_video.u_obj);
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
            //$shm_probe(UUT.u_game,"A");
            $shm_probe(UUT.u_game.u_main,"A");
            $shm_probe(UUT.u_game.u_main.u_mapper,"A");
            $shm_probe(UUT.u_game.u_sub,"A");
            $shm_probe(UUT.u_game.u_sub.u_dma,"A");
            $shm_probe(UUT.u_game.u_sub.u_dtack,"A");
            $shm_probe(UUT.u_game.u_sdram,"A");
            //$shm_probe(UUT.u_game.u_sdram.u_bank1,"AS");
            `ifndef NOSOUND
                $shm_probe(UUT.u_game.u_sound,"A");
                $shm_probe(UUT.u_game.u_sound.u_pcm,"A");
                $shm_probe(UUT.u_game.u_sound.u_jt51.u_mmr,"A");
                $shm_probe(UUT.u_game.u_sound.u_jt51.u_timers,"AS");
            `endif
            //$shm_probe(UUT.u_game.u_video,"A");
            $shm_probe(UUT.u_game.u_video.u_road,"A");
            //$shm_probe(UUT.u_game.u_video.u_colmix,"A");
        `endif
    end
`endif
`endif

endmodule // mist_dump