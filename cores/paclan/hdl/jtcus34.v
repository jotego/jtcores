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
    Date: 18-5-2025 */

module jtcus34(
    input          rst, clk,
                   rnw, lvbl,
    input   [15:0] addr,
    output  reg    scr0pos_cs,scr1pos_cs, oram_cs, rom_cs, banked_cs,
                   scr0_cs,   scr1_cs,    srst,
                   c30_cs,    basel_cs,   wdog_cs, flip,
    output         int_n
);

reg irq_ctl, irq_ack, flip_cs, srst_cs;

always @(posedge clk) begin
    if( rst ) begin
        flip    <= 0;
        irq_ack <= 0;
        srst    <= 1;
    end else begin
        if(flip_cs) flip    <=~addr[11];
        if(srst_cs) srst    <= addr[11];
        if(irq_ctl) irq_ack <= addr[11];
    end
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
    scr0pos_cs = 0;
    scr1pos_cs = 0;
    oram_cs    = 0;
    wdog_cs    = 0;
    irq_ctl    = 0;
    banked_cs  = 0;
    basel_cs   = 0;
    srst_cs    = 0;
    flip_cs    = 0;
    c30_cs     = 0;
    casez(addr[15:12])
        // shared with sub CPU
        4'b0000: scr0_cs = 1;        // 0000~0FFF 4kB tilemap RAM
        4'b0001: scr1_cs = 1;        // 1000~1FFF
        4'b0010: oram_cs = 1;        // 2000~2FFF
        4'b0011: begin
            oram_cs =~addr[11]; // 3000~37FF
            if(addr[11]&&!rnw) case(addr[10:9])
                0: scr0pos_cs=1;
                1: scr1pos_cs=1;
                2: basel_cs=1;
                default:;
            endcase
        end
        4'b010?: banked_cs = rnw;    // 4000~5FFF ROM (banked)
        4'b0110: c30_cs  = addr[11:8]>=4'h8 && addr[11:8]<=4'hb; // 6800~6BFF CUS 30
        4'b0111: begin
            if(!rnw             ) irq_ctl = 1; // 7xxx
            if( rnw && addr[11] ) wdog_cs = 1; // 78xx
        end
        4'b1000: if(!rnw) srst_cs = 1;         // 8xxx
        4'b1001: if(!rnw) flip_cs = 1;         // 9xxx
        default:;
    endcase
    rom_cs   = (addr[15] && rnw) || banked_cs;
end

endmodule
