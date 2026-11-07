/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 3-1-2025 */

// blink output toggles every frame as long as en==1
// if en==0, blink=0
module jtframe_blink(
    input      clk,
    input      vs,
    input      en,      
    output reg blink=0
);

reg vs_l=0, odd=0;

always @(posedge clk) begin
    vs_l <= vs;
    if( vs & ~vs_l ) odd<=~odd;
    blink <= !en || odd;
end

endmodule