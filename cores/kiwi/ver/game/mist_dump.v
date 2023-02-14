/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME. If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-8-2020 */

`timescale 1ns/1ps

module mist_dump(
    input           VGA_VS,
    input           led,
    input   [31:0]  frame_cnt
);

`ifdef DUMP
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
            $dumpvars(1,UUT.u_game.u_game.u_main);
            $dumpvars(1,UUT.u_game.u_game.u_sound);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.PC);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.ACC);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.Ap);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.SP);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.F);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.Fp);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.Alternate);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.B);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.C);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.D);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.E);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.H);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.L);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.IX);
            $dumpvars(1,UUT.u_game.u_game.u_main.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.IY);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.PC);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.ACC);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.Ap);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.SP);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.F);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.Fp);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.Alternate);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.B);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.C);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.D);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.E);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.H);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.L);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.IX);
            $dumpvars(1,UUT.u_game.u_game.u_sound.u_gamecpu.u_cpu.u_cpu.i_tv80_core.i_reg.IY);

            $dumpvars(1,mist_test.frame_cnt);
        `endif
        $dumpon;
    end
`endif

endmodule // mist_dump