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

// memory address decoder for sound CPU (cpu2 in MAME)
module jtcus41(
    input          rst, clk,
                   rnw, lvbl,
    input   [15:0] addr,
    output  reg    scr0_cs,   scr1_cs,   oram_cs,
                   latch0_cs, latch1_cs,
                   mbank_cs,  sbank_cs,
                   wdog_cs,   int_n
);

reg irq_ack;

jtframe_edge #(.QSET(0))u_irq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~lvbl     ),
    .clr    ( irq_ack   ),
    .q      ( int_n     )
);

always @* begin
    casez(addr[15:12])
        4'b000?: oram_cs = 1; // 0000~1FFF
        4'b001?: scr0_cs = 1; // 2000~3FFF 8kB tilemap RAM
        4'b010?: scr1_cs = 1; // 4000~5FFF
        4'b011?: begin rom_cs = 1; banked_cs = 1; end // 6000~7FFF ROM (banked)
        4'b1???: rom_cs = rnw; // 8000~FFFF
        4'b1000: if(!rnw) casez(addr[11])
            0: wdog_cs = 1;
            1: irq_ack = 1;
        endcase
        4'b1101: if(!rnw) case(addr[11])
            0: latch0_cs = 1; // LATCH0 in schematics
            1: latch1_cs = 1; // LATCH1
        endcase
        mbank_cs = latch0_cs && addr[1:0]==3;
        sbank_cs = latch1_cs && addr[1:0]==3;
    endcase
end

endmodule
