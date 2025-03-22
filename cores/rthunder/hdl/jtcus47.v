/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-3-2025 */

// memory address decoder for main CPU (cpu1 in MAME)
module jtcus47(
    input               rst,
    input               clk,
    input        [15:0] addr,
);

always @* begin
    casez(addr[15:12])
    // shared with sub CPU
    4'b000?: scr0_cs = 1; // 8kB tilemap RAM
    4'b001?: scr1_cs = 1;
    // shared with MCU (via CUS30)
    4'b0100: snd_cs  = 1;
    4'b011?: begin rom_cs = 1; banked_cs = 1; end
    4'b1???: rom_cs = 1;
    4'b1000: casez(addr[11:10])
        2'b00: wdog_cs = 1;
        2'b01: irq_ack = 1;
        2'b1?: scrbank_cs = 1;
    endcase
    5'b1001: case(addr[11:10])
        0: casez(addr[1:0])
            2'b0?: scr0x_cs = 1;
            2'b10: scr0y_cs = 1;
            2'b11: bank_cs  = 1;
        endcase
        1: casez(addr[1:0])
            2'b0?: scr1x_cs = 1;
            2'b10: scr1y_cs = 1;
            2'b11: bank_cs  = 1;
        endcase
    endcase
end

endmodule
