/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-9-2026 */

module jtskykid_dec(
    input      [15:0] addr,
    input             rnw,
    output reg        vram0_cs, vram1_cs, oram_cs, banked_cs,
                      scrx_cs,  scry_cs,  bank_cs, pri_cs
);

always @* begin
    vram0_cs = 0; vram1_cs = 0; oram_cs = 0; banked_cs = 0;
    scrx_cs  = 0; scry_cs  = 0; bank_cs = 0; pri_cs    = 0;
    casez(addr[15:12])
        4'b000?: banked_cs = rnw;                  // 0000~1FFF
        4'b0010: vram1_cs  = 1;                    // 2000~2FFF
        4'b0100: begin
            vram0_cs = ~addr[11];                  // 4000~47FF
            oram_cs  =  addr[11];                  // 4800~4FFF
        end
        4'b0101: oram_cs = 1;                      // 5000~5FFF
        4'b0110: if(!rnw) begin
            scry_cs = addr[11:8]==4'h0;            // 6000~60FF
            scrx_cs = addr[11:9]==3'b001;          // 6200~63FF
        end
        4'b1001: bank_cs = !rnw;                   // 9xxx
        4'b1010: pri_cs  = !rnw;                   // A000~A001
        default:;
    endcase
end

endmodule
