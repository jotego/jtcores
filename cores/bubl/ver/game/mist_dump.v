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
                $dumpvars(0,mist_test.UUT.u_game.u_main);
                $dumpvars(0,mist_test.UUT.u_game.u_main.u_mcu);
                //$dumpvars(0,mist_test.UUT.u_frame.u_board);
                // $dumpvars(0,mist_test.UUT.u_game.u_sdram);
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
            //$shm_probe(UUT.u_game.u_video,"AS");
            $shm_probe(UUT.u_game,"A");
            //$shm_probe(UUT.u_game.u_dwnld,"A");
            $shm_probe(UUT.u_game.u_main,"A");
            $shm_probe(UUT.u_game.u_main.u_subwait,"AS");
            $shm_probe(UUT.u_game.u_main.u_mainwait,"AS");
            $shm_probe(UUT.u_game.u_main.u_mcu,"A");
            `ifndef NOSOUND
                $shm_probe(UUT.u_game.u_sound,"A");
                $shm_probe(UUT.u_game.u_sound.u_cpu,"AS");
                //$shm_probe(UUT.u_game.u_sound.u_2203,"AS");
                //$shm_probe(UUT.u_game.u_sound.u_opl,"AS");
            `endif
            //$shm_probe(UUT.u_game.u_video,"A");
            //$shm_probe(UUT.u_game.u_main.u_mcu,"A");
            //$shm_probe(UUT.u_game.u_main.u_mcu.u_gatecen,"A");
            //$shm_probe(UUT.u_game.u_video.u_colmix.col_addr);
            //$shm_probe(UUT.u_game.u_main.u_maincpu,"A");
            //$shm_probe(UUT.u_game.u_main.u_subcpu,"A");
            //$shm_probe(UUT.u_game.u_rom,"AS");
        `endif
    end
`endif
`endif

endmodule // mist_dump