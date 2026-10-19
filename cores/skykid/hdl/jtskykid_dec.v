/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 23-9-2026 */

module jtskykid_dec(
    input          rst, clk,
                   rnw, lvbl,
    input   [15:0] addr,
    output  reg    vram0_cs, vram1_cs, oram_cs, c30_cs,
                   rom_cs,   banked_cs, wdog_cs,
                   scrx_cs,  scry_cs,  bank_cs, pri_cs, srst,
    output         int_n
);

reg irq_ctl, irq_ack, srst_cs;

always @(posedge clk) begin
    if( rst ) begin
        irq_ack <= 0;
        srst    <= 1;
    end else begin
        if(srst_cs) srst    <= addr[11];
        if(irq_ctl) irq_ack <= addr[11];
    end
end

jtframe_edge #(.QSET(0)) u_irq(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .edgeof ( ~lvbl     ),
    .clr    ( irq_ack   ),
    .q      ( int_n     )
);

always @* begin
    vram0_cs  = 0; vram1_cs = 0; oram_cs = 0; c30_cs  = 0;
    wdog_cs   = 0; scrx_cs  = 0; scry_cs = 0; irq_ctl = 0;
    bank_cs   = 0; pri_cs   = 0; srst_cs = 0; banked_cs = 0;
    casez(addr[15:12])
        4'b000?: banked_cs = rnw;                  // 0000~1FFF
        4'b0010: vram1_cs  = 1;                    // 2000~2FFF
        4'b0100: begin
            vram0_cs = ~addr[11];                  // 4000~47FF
            oram_cs  =  addr[11];                  // 4800~4FFF
        end
        4'b0101: oram_cs = 1;                      // 5000~5FFF
        4'b0110: begin
            if(!rnw) begin
                scry_cs = addr[11:8]==4'h0;        // 6000~60FF
                scrx_cs = addr[11:9]==3'b001;      // 6200~63FF
            end
            c30_cs = addr[11:8]>=4'h8 && addr[11:8]<=4'hb; // 6800~6BFF
        end
        4'b0111: begin
            if(!rnw             ) irq_ctl = 1;     // 7xxx
            if( rnw && addr[11] ) wdog_cs = 1;     // 78xx
        end
        4'b1000: if(!rnw) srst_cs = 1;             // 8xxx
        4'b1001: if(!rnw) bank_cs = 1;             // 9xxx
        4'b1010: if(!rnw) pri_cs  = 1;             // A000~A001
        default:;
    endcase
    rom_cs = (addr[15] && rnw) || banked_cs;
end

endmodule
