/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 15-3-2025 */

// memory address decoder for CPU 2 (11A on PCB)
module jtcus41(
    input          rst, clk,
                   rnw, lvbl, roishtar, genpeitd, wndrmomo,
    input   [15:0] addr,
    output  reg    scr0_cs,   scr1_cs,   oram_cs, rom_cs, banked_cs,
                   latch0_cs, latch1_cs,
                   mbank_cs,  sbank_cs,
                   wdog_cs,
    output         int_n
);

reg irq_ack;

jtframe_edge #(.QSET(0))u_irq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~lvbl     ),
    .clr    ( irq_ack   ),
    .q      ( int_n     )
);

localparam [2:0] ROISHTAR=3'b100, WNDRMOMO=3'b010, GENPEITD=3'b001;

always @* begin
    oram_cs   = 0;
    scr0_cs   = 0;
    scr1_cs   = 0;
    banked_cs = 0;
    wdog_cs   = 0;
    irq_ack   = 0;
    latch0_cs = 0;
    latch1_cs = 0;
    case({roishtar,wndrmomo,genpeitd})
        ROISHTAR:
            casez(addr[15:12])
                4'b000?: oram_cs   = 1; // 0000~1FFF
                4'b010?: scr1_cs   = 1; // 4000~5FFF 8kB tilemap RAM
                4'b011?: scr0_cs   = 1; // 6000~7FFF
                4'b1010: if(!rnw) wdog_cs = 1;
                4'b1011: if(!rnw) irq_ack = 1;
                default:;
            endcase
        WNDRMOMO:
            casez(addr[15:12])
                4'b001?: oram_cs   = 1; // 2000~3FFF
                4'b010?: scr0_cs   = 1; // 4000~5FFF 8kB tilemap RAM
                4'b011?: scr1_cs   = 1; // 6000~7FFF
                4'b1100: if(!rnw) casez(addr[11])
                    0: wdog_cs = 1; // C000
                    1: irq_ack = 1; // C800
                endcase
                default:;
            endcase
        GENPEITD:
            casez(addr[15:12])
                4'b000?: scr0_cs   = 1; // 0000~1FFF 8kB tilemap RAM
                4'b001?: scr1_cs   = 1; // 2000~3FFF
                4'b010?: oram_cs   = 1; // 4000~5FFF
                4'b1000: if(!rnw && addr[11]) irq_ack = 1;
                4'b1011: if(!rnw) wdog_cs = 1;
                default:;
            endcase
        default:
            casez(addr[15:12])
                4'b000?: oram_cs   = 1; // 0000~1FFF
                4'b001?: scr0_cs   = 1; // 2000~3FFF 8kB tilemap RAM
                4'b010?: scr1_cs   = 1; // 4000~5FFF
                4'b011?: banked_cs = 1; // 6000~7FFF ROM (banked)
                4'b1000: if(!rnw) casez(addr[11])
                    0: wdog_cs = 1; // 8000
                    1: irq_ack = 1; // 8800
                endcase
                4'b1101: if(!rnw) case(addr[11])
                    0: latch0_cs = 1; // D000 LATCH0 in schematics
                    1: latch1_cs = 1; // D800 LATCH1
                endcase
                default:;
            endcase
    endcase
    rom_cs   = (addr[15] && rnw) || banked_cs; // 8000~FFFF
    mbank_cs =  latch0_cs && addr[1:0]==3;
    sbank_cs =  latch1_cs && addr[1:0]==3;
end

endmodule
