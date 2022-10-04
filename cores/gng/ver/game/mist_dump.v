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
    initial begin
        $display("DUMP starts");
        `ifdef DEEPDUMP
            $dumpvars(0,mist_test);
        `else
            $dumpvars(1,mist_test.UUT.u_game.u_main);
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
            $shm_probe(UUT.u_game.u_sound,"A");
            $shm_probe(UUT.u_game.u_sound.u_fm0,"A");
            $shm_probe(UUT.u_game.u_sound.u_fm1,"A");
            $shm_probe(UUT.u_game.u_sound.u_fm0.u_jt12.u_mmr,"AS");
            $shm_probe(UUT.u_game.u_sound.u_fm1.u_jt12.u_mmr,"AS");
        `endif
    end
`endif
`endif

endmodule // mist_dump