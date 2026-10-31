/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtslap_wait(
    input       rst,
    input       clk,
    input       pxl_cen,
    input [8:0] hdump, scrx,
    input       flip,
    input       fix_cs, scr_cs,
    output      wait_n
);
reg  [1:0] fix_wait, scr_wait;
reg        fg_clk, bg_clk, fg_clk_l, bg_clk_l;
wire [8:0] hscroll;
assign hscroll = hdump + scrx;
assign wait_n = (!fix_cs || !fix_wait[1]) && (!scr_cs || !scr_wait[1]);

// Sheets 5/6: the graphics clocks come from latched pixel bit 2.
always @(posedge clk) if(pxl_cen) begin
    fg_clk <= ~hdump[2] ^ flip;
    bg_clk <= ~hscroll[2] ^ flip;
end
always @(posedge clk) begin
    fg_clk_l <= fg_clk;
    bg_clk_l <= bg_clk;
end
// Sheet 8 U2A/U1A: inactive chip selects preset both LS74s. An access
// releases WAIT after two falling graphics-clock edges.
always @(posedge clk) begin
    if(rst || !fix_cs) fix_wait <= 2'b11;
    else if(fg_clk_l && !fg_clk) fix_wait <= {fix_wait[0],1'b0};
    if(rst || !scr_cs) scr_wait <= 2'b11;
    else if(bg_clk_l && !bg_clk) scr_wait <= {scr_wait[0],1'b0};
end
endmodule
