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

            `ifdef LOADROM
                $shm_probe(UUT.u_game.u_dwnld,"A");
                $shm_probe(UUT.u_frame.u_board.u_sdram,"AS");
            `else
                `ifndef NOSOUND
                    $shm_probe(UUT.u_game.u_sound,"A");
                    $shm_probe(UUT.u_game.u_sound.u_fmcpu,"A");
                    $shm_probe(UUT.u_game.u_sound.u_adpcmcpu,"A");
                `endif
                `ifdef OBJLOAD
                    $shm_probe(UUT.u_game.u_objload,"A");
                `else
                //$shm_probe(UUT.u_game,"A");
                $shm_probe(UUT.u_game.u_main,"A");
                $shm_probe(UUT.u_game.u_main.u_dtack,"A");
                $shm_probe(UUT.u_game.u_mcu,"A");
                $shm_probe(UUT.u_game.u_mcu.u_mcu,"A");
                //$shm_probe(UUT.u_game.u_bank0,"AS");
                //$shm_probe(UUT.u_frame.u_board.u_sdram,"AS");
                //$shm_probe(UUT.u_game.u_video,"A");
                `endif
            `endif
            //$shm_probe(UUT.u_game.u_video,"A");
            //$shm_probe(UUT.u_game.u_video.u_obj,"AS");
        `endif
    end
`endif
`endif

endmodule // mist_dump