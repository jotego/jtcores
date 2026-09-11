/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Priority mixer and palette lookup. Picks one layer per pixel, reads the
 * palette entry it selects and registers the colour, so red/green/blue lag
 * hdump by two pixel enables.
 */

module jtwardner_colmix(
    input             clk,
    input             pxl_cen,
    input             LVBL, LHBL, video_on,
    input      [ 3:0] gfx_en,

    input      [ 7:0] bg_pxl, fg_pxl,
    input      [ 8:0] tx_pxl,
    input      [12:0] obj_pxl,          // {multi, prio[1:0], colour[5:0], pen[3:0]}

    output reg [10:0] pal_vaddr, input [15:0] pal_vq,
    output reg [ 4:0] red, green, blue
);

//
// gfx_en comes from JTFRAME's OSD debug menu and switches a layer off without
// changing anything else, which is the only way to tell the layers apart on
// real hardware. jtframe's convention is 0 char/text, 1 first scroll, 2 second
// scroll, 3 objects. A disabled layer reports "no pixel here", so the mixer
// falls through to whatever is behind it exactly as it would if the layer were
// blank.
wire fg_hit  = fg_pxl[3:0]  != 4'd0 && gfx_en[2];
wire tx_hit  = tx_pxl[2:0]  != 3'd0 && gfx_en[0];   // characters have three planes
wire obj_hit = obj_pxl[3:0] != 4'd0 && gfx_en[3];
wire [1:0] obj_prio  = obj_pxl[11:10];
wire       obj_multi = obj_pxl[12];

// MAME pmasks: prio 1 hidden by fg or text, 2 by text, 3 never; a pixel a
// previous sprite touched is never hidden
wire obj_show = obj_hit && (
        obj_multi || obj_prio == 2'd3 ||
        (obj_prio == 2'd2 && !tx_hit) ||
        (obj_prio == 2'd1 && !tx_hit && !fg_hit) );

reg blank_l;

always @(posedge clk) if( pxl_cen ) begin
    // palette bases: sprites 0, bg 1024, fg 1280, text 1536
    // the background is opaque, so switching it off shows palette entry 0 of
    // its bank rather than falling through to anything
    pal_vaddr <= obj_show ? {1'b0, obj_pxl[9:0]} :
                 tx_hit   ? {3'b110, tx_pxl[8:4], tx_pxl[2:0]} :
                 fg_hit   ? {3'b101, fg_pxl}     :
                            {3'b100, gfx_en[1] ? bg_pxl : 8'd0};
    blank_l   <= ~(LVBL & LHBL) | ~video_on;
    // the palette read is one clock, so pal_vq now belongs to the pixel
    // registered at the previous enable
    {blue, green, red} <= blank_l ? 15'd0 : pal_vq[14:0];   // xBGR_555
end

endmodule
