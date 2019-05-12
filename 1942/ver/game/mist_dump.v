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
    `ifdef XXLOADROM
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
    `ifndef VIDEO_START
    initial begin
    `else
    always @(negedge VGA_VS) if( frame_cnt==`VIDEO_START ) begin
    `endif
        $display("NC Verilog: will dump all signals");
        $shm_open("test.shm");
        `ifdef DEEPDUMP
            $shm_probe(mist_test,"AS");
        `else
            $shm_probe(UUT.u_game.u_prom_we,"AS");
            $shm_probe(UUT.u_base.u_sdram,"AS");
        `endif
    end
`endif
`endif

endmodule // mist_dump