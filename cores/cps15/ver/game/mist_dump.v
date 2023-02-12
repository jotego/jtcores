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
                $dumpvars(1,mist_test.UUT.u_game);
                $dumpvars(0,mist_test.UUT.u_game.u_sdram_mux);
                $dumpvars(1,mist_test.UUT.u_game.u_video.u_mmr);
                $dumpvars(0,mist_test.UUT.u_frame.u_board.u_sdram);
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
            `ifdef PUNISHER_SIM
                $shm_probe(UUT.u_game.u_sound, "A");
                $shm_probe(UUT.u_game.u_sound.u_dsp16, "A");
                $shm_probe(UUT.u_game.u_sound.u_dsp16.u_sio, "A");
                $shm_probe(UUT.u_game.u_sound.u_dsp16.u_pio, "A");
            `endif
            //$shm_probe(UUT.u_game.u_sound.u_adpcm, "AS");
            //$shm_probe(UUT.u_game.u_sdram_mux, "A");
            //$shm_probe(UUT.u_game.u_sdram_mux.u_slot0, "AS");
            //$shm_probe(UUT.u_game.u_sdram_mux.u_slot1, "AS");
            //$shm_probe(UUT.u_game.u_sdram_mux.u_slot9, "AS");
            //$shm_probe(UUT.u_game,"A");
            //$shm_probe(UUT.u_game.u_sdram_mux,"A");

            //$shm_probe(UUT.u_game, "A");
            `ifdef LOADROM
                $shm_probe(UUT.u_game.u_sdram, "A");
                $shm_probe(UUT.u_game.u_sdram.u_prom_we, "A");
                `ifndef NODSP
                    $shm_probe(UUT.u_game.u_sound.u_dsp16.u_rom, "A");
                `endif
            `endif
            `ifdef JTFRAME_SDRAM_STATS
                $shm_probe(UUT.u_frame.u_board.u_sdram.u_stats, "A");
            `endif
            //$shm_probe(UUT.u_frame.u_board.u_sdram, "A");
            //$shm_probe(UUT.u_game.u_sound, "A");
            `ifndef NOMAIN
                //$shm_probe(UUT.u_game.u_sound.u_dsp16, "A");
                $shm_probe(UUT.u_game.u_sound.cpu2dsp_s);
                //$shm_probe(UUT.u_game.u_sound.sample_cnt);
                //$shm_probe(UUT.u_game.u_sound.uprate.period);
                $shm_probe(UUT.u_game.u_sound.left );
                $shm_probe(UUT.u_game.u_sound.right);
                $shm_probe(UUT.u_game.u_sound.sample);
                //$shm_probe(UUT.u_game.u_sound.dsp_irq);
                //$shm_probe(UUT.u_game.u_sound.dsp_rst);
                //$shm_probe(UUT.u_game.u_sound.cpu2dsp);
                //$shm_probe(UUT.u_game.u_eeprom,"A");
                //$shm_probe(UUT.u_game.u_sound.u_buslock, "A");
            `else
                //$shm_probe(UUT.u_game.u_main, "A" );
                $shm_probe(UUT.u_game.u_main.u_dtack, "A" );
            `endif
            //$shm_probe(UUT.u_game.u_video, "A");
            //$shm_probe(UUT.u_game.u_video.u_colmix, "A");

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
            //$shm_probe(UUT.u_game.u_video, "A");
            //$shm_probe(UUT.u_game.u_video.u_obj, "AS");
            //$shm_probe(UUT.u_game.u_video.u_colmix, "AS");

        `endif
    end
`endif
`endif

endmodule // mist_dump