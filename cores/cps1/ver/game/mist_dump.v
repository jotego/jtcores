`timescale 1ns/1ps

module mist_dump(
    input           VGA_VS,
    input           led,
    input   [31:0]  frame_cnt
);

`ifdef DUMP
`ifndef NCVERILOG // iVerilog:
    initial begin
        `ifdef IVERILOG
            $dumpfile("test.lxt");
        `else
            $dumpfile("test.vcd");
        `endif
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
                $dumpvars(1,mist_test.UUT.u_game);
                $dumpvars(1,mist_test.UUT.u_game.u_video.u_mmr);
                $dumpvars(1,mist_test.UUT.u_game.u_video.u_colmix);
                //$dumpvars(0,mist_test.UUT.u_frame.u_board.u_sdram);
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
            //$shm_probe(UUT.u_game.u_prom_we, "A");
            //$shm_probe(UUT.u_game.u_sound, "A");
            //$shm_probe(UUT.u_game.u_sound.u_adpcm, "AS");
            //$shm_probe(UUT.u_game.u_sdram_mux, "A");
            //$shm_probe(UUT.u_game.u_sdram_mux.u_slot0, "AS");
            //$shm_probe(UUT.u_game.u_sdram_mux.u_slot1, "AS");
            //$shm_probe(UUT.u_game.u_sdram_mux.u_slot9, "AS");
            //$shm_probe(UUT.u_game,"A");
            //$shm_probe(UUT.u_game.u_sdram_mux,"A");
            `ifdef LOADROM
                $shm_probe(UUT.u_game.u_sdram,"A");
                $shm_probe(UUT.u_game.u_sdram.u_prom_we,"A");
                $shm_probe(UUT.u_frame.u_board.u_sdram,"A");
                $shm_probe(UUT.u_game, "A");
                $shm_probe(UUT.u_game.u_main, "A");
            `else
                `ifdef JTFRAME_SDRAM_STATS
                $shm_probe(UUT.u_frame.u_board.u_stats, "A");
                `endif
            // No load ROM sim:
                `ifdef FAKE_LATCH
                    $shm_probe(UUT.u_game.u_sound, "A");
                    $shm_probe(UUT.u_game.u_sound.u_pole, "A");
                    $shm_probe(UUT.u_game.u_sound.u_adpcm, "AS");
                    $shm_probe(UUT.u_game.u_sound.u_adpcm.u_ctrl, "A");
                    $shm_probe(UUT.u_game.u_sound.u_adpcm.u_serial, "A");
                    //$shm_probe(UUT.u_game.u_sound.u_adpcm.u_acc, "A");
                    //$shm_probe(UUT.u_game.u_sound.u_adpcm.u_rom, "A");
                    //$shm_probe(UUT.u_game.u_sound.u_cpu, "A");
                    //$shm_probe(UUT.u_game.u_sound.u_cpu.u_wait, "AS");
                    //$shm_probe(UUT.u_game.u_sound.u_jt51.u_timers, "A");
                    //$shm_probe(UUT.u_game.u_sound.u_jt51.u_mmr, "AS");
                    //$shm_probe(UUT.u_game.u_sound.u_jt51, "AS");

                `else

                    //$shm_probe(UUT.u_frame.u_board.u_sdram, "A");
                    //$shm_probe(UUT.u_game, "A");
                    `ifdef JTFRAME_CHEAT
                        $shm_probe(UUT.u_frame.u_board.u_cheat, "AS");
                        $shm_probe(UUT.u_frame.u_board.u_cheat.u_rom, "A");
                        $shm_probe(UUT.u_frame.u_board.u_sdram,"A");
                    `endif
                    `ifdef LOADROM
                        $shm_probe(UUT.u_game.u_sdram, "A");
                        $shm_probe(UUT.u_game.u_sdram.u_prom_we, "A");
                        $shm_probe(UUT.u_frame.u_board.u_sdram, "AS");
                    `else
                        `ifndef NOMAIN
                            $shm_probe(UUT.u_game.u_main, "A");
                            $shm_probe(UUT.u_game.u_main.u_dtack, "A");
                            $shm_probe(UUT.u_game.u_sdram, "AS");
                            //$shm_probe(UUT.u_frame.u_board.u_sdram, "AS");
                            //$shm_probe(UUT.u_game.u_video,"A");
                            //$shm_probe(UUT.u_game.u_sound, "A");
                        `endif
                    `endif
                    `ifdef DUMP_SDRAM
                        $shm_probe(UUT.u_game.u_sdram, "AS");
                        $shm_probe(UUT.u_frame.u_board.u_sdram, "AS");
                        $shm_probe(UUT.u_game.u_video,"A");
                        $shm_probe(UUT.u_game.u_sound, "A");
                        $shm_probe(UUT.u_game.u_main, "A");
                        $shm_probe(u_harness.u_sdram, "A");
                    `endif
                    /*
                    $shm_probe(UUT.u_game.u_video.u_dma.step );
                    $shm_probe(UUT.u_game.u_video.u_dma.misses );
                    $shm_probe(UUT.u_game.u_video.u_dma.br  );
                    $shm_probe(UUT.u_game.u_video.u_dma.adv );
                    $shm_probe(UUT.u_game.u_video.u_dma.obj_end  );
                    $shm_probe(UUT.u_game.u_video.u_dma.obj_fill );
                    $shm_probe(UUT.u_game.u_video.u_dma.vram_ok );
                    $shm_probe(UUT.u_game.u_video.u_dma.on_scr1 );
                    $shm_probe(UUT.u_game.u_video.u_dma.on_scr2 );
                    $shm_probe(UUT.u_game.u_video.u_dma.on_scr3 );
                    $shm_probe(UUT.u_game.u_video.u_dma.on_row  );
                    $shm_probe(UUT.u_game.u_video.u_dma.on_obj  );
                    $shm_probe(UUT.u_game.u_video.u_dma.on_pal  );
                    */

                    //$shm_probe(UUT.u_game.u_video.VB );
                    //$shm_probe(UUT.u_game.u_video.HB );
                    //$shm_probe(UUT.u_game.u_main.vram_cs );
                    //$shm_probe(UUT.u_game.u_main, "A" );
                    //$shm_probe(UUT.u_game.u_video, "A");
                    //$shm_probe(UUT.u_game.u_video.u_obj, "AS");
                    //$shm_probe(UUT.u_game.u_video.u_colmix, "AS");
                `endif
            `endif
        `endif
    end
`endif
`endif

endmodule // mist_dump