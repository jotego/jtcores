/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-8-2020 */

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
`ifdef DUMP_START
    initial $display("Dumping will start at frame %0d", `DUMP_START);
    always @(negedge VGA_VS) if( frame_cnt==`DUMP_START ) begin
`else
    initial begin
`endif
        `ifdef DEEPDUMP
            $display("Dumping all signals");
            $dumpvars(0,mist_test);
        `else
            $display("Dumping selected signals");
            `ifndef NOMAIN
                $dumpvars(1,mist_test.UUT.u_game.u_game.u_main);
            `endif
            `ifndef NOSOUND
                $dumpvars(1,mist_test.UUT.u_game.u_game.u_sound);
            `endif
            `ifndef NOVIDEO
                $dumpvars(1,mist_test.UUT.u_game.u_game.u_video);
            `endif
            $dumpvars(1,mist_test.frame_cnt);
        `endif
        $dumpon;
    end
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
            $shm_probe(UUT.u_game.u_game,"A");
            $shm_probe(UUT.u_game.u_game.u_main,"A");
            // $shm_probe(UUT.u_game.u_game.u_sound,"A");
            // $shm_probe(UUT.u_game.u_game.u_video,"A");
        `endif
    end
`endif
`endif

endmodule // mist_dump