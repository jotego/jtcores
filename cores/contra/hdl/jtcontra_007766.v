/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 27-6-2020 */

// This is the custom address decoder
// It originally split the bus depending on the E/Q phases
// That is not needed here

// I don't understand how the 007452 (divider chip) is selected
// without selecting the GFX chip

module jtcontra_007766(
    input      [15:0]  cpu_addr, // only bits 15-10 and 6-5 were used
    output reg [ 1:0]  gfx_cs,
    output reg [13:0]  gfx_addr
);

reg cfg_cs;

always @(*) begin
    cfg_cs = cpu_addr[15:10]==6'd0;
    gfx_cs[0] = cpu_addr[15:13]==3'b001 || ( cfg_cs && cpu_addr[6:5]==2'b00); // 2000-3FFF and 0000-001F
    gfx_cs[1] = cpu_addr[15:13]==3'b010 || ( cfg_cs && cpu_addr[6:5]==2'b11); // 4000-5FFF and 0060-007F

    gfx_addr[13:0] = cpu_addr[13:0];
    if( gfx_cs[1] ) begin
        gfx_addr[ 13] = ~cfg_cs;
        //gfx_addr[ 12] = ~gfx_addr[12];
        if(cfg_cs) gfx_addr[6:5] = 2'b0;
    end
end

endmodule