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
            //$shm_probe(UUT.u_game, "A");
            `ifdef LOADROM
                $shm_probe(UUT.u_game.u_sdram, "A");
                $shm_probe(UUT.u_game.u_sdram.u_prom_we, "A");
            `endif
            //$shm_probe(UUT.u_frame.u_board.u_sdram, "A");
            //$shm_probe(UUT.u_game, "A");
            `ifdef NOMAIN
                $shm_probe(UUT.u_game.u_video, "AS");
            `else
                $shm_probe(UUT.u_game.u_main, "A");
                $shm_probe(UUT.u_game.u_main.FC);
                $shm_probe(UUT.u_game.u_main.raster);
                $shm_probe(UUT.u_game.u_main.int1);
                $shm_probe(UUT.u_game.u_main.int2);
                $shm_probe(UUT.u_game.u_main.inta_n);
                //$shm_probe(UUT.u_game.u_main.RnW);
                //$shm_probe(UUT.u_game.u_video.u_dma, "A");
                $shm_probe(UUT.u_game.u_main.u_dtack, "A");
            `endif

            //$shm_probe(UUT.u_game.u_sound, "A");
            //$shm_probe(UUT.u_game.u_sound.u_buslock, "A");
            `ifdef DUMP_MAIN
                $shm_probe(UUT.u_game.u_main, "A");
            `endif
            `ifdef DUMP_SND
                $shm_probe(UUT.u_game.u_main, "A");
                $shm_probe(UUT.u_game.u_sound, "A");
                //$shm_probe(UUT.u_game.u_sound.u_buslock, "A");
            `endif
            `ifdef DUMP_SDRAM
                $shm_probe(UUT.u_game.u_sdram, "AS");
                $shm_probe(UUT.u_frame.u_board.u_sdram, "AS");
                $shm_probe(UUT.u_frame.u_board.u_rdy_check, "AS");
                $shm_probe(UUT.u_game.u_video,"A");
                $shm_probe(UUT.u_game.u_sound, "A");
                $shm_probe(UUT.u_game.u_main, "A");
                $shm_probe(u_harness.u_sdram, "A");
            `endif
            //$shm_probe(UUT.u_game.u_video.u_obj.u_scan,"A");
            //$shm_probe(UUT.u_game.u_main.u_cpu.excUnit.regs68L);
            //$shm_probe(UUT.u_game.u_main.u_cpu.excUnit.regs68H);
            //$shm_probe(UUT.u_game.u_sdram, "A");
            //$shm_probe(UUT.u_game.u_video, "A");
            //$shm_probe(UUT.u_game.u_video.u_mmr, "A");
            //$shm_probe(UUT.u_game.u_video.u_obj, "AS");
            //$shm_probe(UUT.u_game.u_main.obank);
            //$shm_probe(UUT.u_game.LVBL);
            ////$shm_probe(UUT.u_game.LHBL);
            `ifdef DUMP_RASTER
                $shm_probe(UUT.u_game.u_video.u_mmr, "A");
                $shm_probe(UUT.u_game.u_video.u_timing,"A");
                $shm_probe(UUT.u_game.u_video.u_mmr.u_raster,"AS");
                $shm_probe(UUT.u_game.u_video.u_mmr.addr);
                $shm_probe(UUT.u_game.u_video.u_dma,"A");
                $shm_probe(UUT.u_game.u_video.u_mmr.dsn);
                $shm_probe(UUT.u_game.u_video.u_mmr.cpu_dout);
                $shm_probe(UUT.u_game.u_video.u_mmr.ppu2_cs);
            `endif
            // CPS2 colour mixer
            //$shm_probe(UUT.u_game.u_video.u_objmix,"A");
            //$shm_probe(UUT.u_game.u_video.u_mmr.layer_ctrl);
            //$shm_probe(UUT.u_game.u_video.u_mmr.prio0);
            //$shm_probe(UUT.u_game.u_video.u_mmr.prio1);
            //$shm_probe(UUT.u_game.u_video.u_mmr.prio2);
            //$shm_probe(UUT.u_game.u_video.u_mmr.prio3);
            //$shm_probe(UUT.u_game.u_video.u_mmr.pal_page_en);
            //$shm_probe(UUT.u_game.u_video.u_mmr.vram1_base);
            //$shm_probe(UUT.u_game.u_video.u_mmr.vram2_base);
            //$shm_probe(UUT.u_game.u_video.u_mmr.vram3_base);
            //$shm_probe(UUT.u_game.u_video.u_mmr.pal_base);

            //$shm_probe(UUT.u_game.u_video.VB );
            //$shm_probe(UUT.u_game.u_video.HB );
            //$shm_probe(UUT.u_game.u_main.vram_cs );
            //$shm_probe(UUT.u_game.u_main, "A" );
            //$shm_probe(UUT.u_game.u_video, "A");
            //$shm_probe(UUT.u_game.u_video.u_obj, "AS");
            //$shm_probe(UUT.u_game.u_video.u_colmix, "AS");

        `endif
    end
`endif
`endif

endmodule // mist_dump