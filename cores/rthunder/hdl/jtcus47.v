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

// memory address decoder for CPU1 (connected to CUS30)
module jtcus47(
    input          rst, clk,
                   rnw, lvbl,
    input   [15:0] addr,
    output  reg    bank=0,   // SCR0 ROM bank
                   scr0_cs,   scr1_cs,   oram_cs, rom_cs, banked_cs,
                   latch0_cs, latch1_cs, latch2_cs, snd_cs,
                   mbank_cs,  sbank_cs,  c115_cs,
                   wdog_cs,
    output         int_n
);

reg scrbank_cs, irq_ack;

always @(posedge clk) begin
    if(scrbank_cs) bank <= addr[10];
end

jtframe_edge #(.QSET(0))u_irq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~lvbl     ),
    .clr    ( irq_ack   ),
    .q      ( int_n     )
);

always @* begin
    scr0_cs    = 0;
    scr1_cs    = 0;
    oram_cs    = 0;
    latch0_cs  = 0;
    latch1_cs  = 0;
    latch2_cs  = 0;
    wdog_cs    = 0;
    irq_ack    = 0;
    banked_cs  = 0;
    scrbank_cs = 0;
    c115_cs    = 0;
    casez(addr[15:12])
        // shared with sub CPU
        4'b000?: scr0_cs = 1; // 0000~1FFF 8kB tilemap RAM
        4'b001?: scr1_cs = 1; // 2000~3FFF
        4'b010?: oram_cs = 1; // 4000~5FFF
        // shared with MCU (via CUS30)
        4'b011?: begin
            banked_cs = rnw; // 6000~7FFF ROM (banked)
            c115_cs   =!rnw; // 6000~7FFF control of 63701X
        end
        4'b1000: if(!rnw) casez(addr[11:10]) // only writes
            2'b00: wdog_cs = 1;     // 8000
            2'b01: irq_ack = 1;     // 8400
            2'b1?: scrbank_cs = 1;  // 8800~8FFF
        endcase
        4'b1001: if(!rnw) case(addr[10])
            0: latch0_cs = 1; // 9000 LATCH0 in schematics
            1: latch1_cs = 1; // 9400 LATCH1
        endcase
        4'b1010: latch2_cs = !rnw; // Back color
        default:;
    endcase
    snd_cs   = addr[15:12]==4'h4 && addr[11:10]==0; // 4000~43FF CUS30
    rom_cs   = (addr[15] && rnw) || banked_cs;
    mbank_cs = latch0_cs && addr[1:0]==3;
    sbank_cs = latch1_cs && addr[1:0]==3;
end

endmodule
