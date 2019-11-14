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
    //always @(negedge led) if( $time > 20000 ) begin // led = downloading signal
   initial begin 
        $display("DUMP starts");
        $dumpvars(1,mist_test.UUT.u_game.u_prom_we);            
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
                //$dumpvars(1,mist_test.UUT.u_game.u_main);
                $dumpvars(1,mist_test.UUT.u_game.u_sound);
                $dumpvars(2,mist_test);
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
        $display("NC Verilog: will dump all signals");
        $shm_open("test.shm");
        `ifdef DEEPDUMP
            $shm_probe(mist_test,"AS");
        `else
            $shm_probe(mist_test.UUT.u_game.u_sound,"A");
            $shm_probe(mist_test.UUT.u_game.u_mcu,"A");
            $shm_probe(mist_test.UUT.u_game.u_main,"A");
            $shm_probe(mist_test.UUT.u_game.u_sound.u_jt51,"A");
            $shm_probe(mist_test.UUT.u_game.u_sound.u_jt51.u_mmr,"AS");
            $shm_probe(mist_test.UUT,"A");
            $shm_probe(mist_test,"A");
        `endif
    end
`endif
`endif

endmodule // mist_dump
