`timescale 1ns/1ps

module mist_dump(
    input           VGA_VS,
    input           led,
    input   [31:0]  frame_cnt
);

`ifdef DUMP
initial begin
    $display("DUMP enabled");
    `ifdef IVERILOG
        $dumpfile("test.lxt");
    `else
        $dumpfile("test.vcd");
    `endif
end
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
        $dumpvars(1,mist_test.UUT.u_game.u_rom);
        $dumpvars(1,mist_test.UUT.u_game);
        $dumpvars(0,mist_test.UUT.u_game.u_dwnld);
        $dumpvars(0,mist_test.UUT.u_frame.u_board.u_sdram);
    `endif
    $dumpon;
end
`endif

endmodule // mist_dump