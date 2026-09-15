/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Layer priority and palette lookup. The colour lags hdump by two pixels.
 */
module jtwardner_colmix(
    input             clk,
    input             pxl_cen,
    input             LVBL,
    input             LHBL,
    input             video_on,
    input      [ 3:0] gfx_en,

    input      [ 7:0] bg_pxl,
    input      [ 7:0] fg_pxl,
    input      [ 8:0] tx_pxl,
    input      [11:0] obj_pxl,

    output     [11:1] pal_vaddr,
    input      [15:0] pal_vq,

    // palette readback through the OSD
    input             ioctl_ram,
    input      [11:0] ioctl_addr,
    output     [ 7:0] ioctl_din,

    output reg [ 4:0] red,
    output reg [ 4:0] green,
    output reg [ 4:0] blue
);

wire [ 1:0] obj_prio = obj_pxl[11:10];
wire        fg_hit   = fg_pxl[3:0]  != 4'd0 && gfx_en[2];
wire        tx_hit   = tx_pxl[2:0]  != 3'd0 && gfx_en[0];
wire        obj_hit  = obj_pxl[3:0] != 4'd0 && gfx_en[3];
reg  [10:0] pal_addr;
reg         blank_l;

// priority 1 is hidden by the foreground or text, 2 by text, 3 never
wire obj_show = obj_hit && ( obj_prio == 2'd3 ||
                            (obj_prio == 2'd2 && !tx_hit) ||
                            (obj_prio == 2'd1 && !tx_hit && !fg_hit) );

assign pal_vaddr = ioctl_ram ? ioctl_addr[11:1] : pal_addr;
assign ioctl_din = ioctl_addr[0] ? pal_vq[15:8] : pal_vq[7:0];

// palette bases: sprites 0, background 1024, foreground 1280, text 1536
always @(posedge clk) if( pxl_cen ) begin
    pal_addr <= obj_show ? {1'b0, obj_pxl[9:0]} :
                tx_hit   ? {3'b110, tx_pxl[8:4], tx_pxl[2:0]} :
                fg_hit   ? {3'b101, fg_pxl} :
                           {3'b100, gfx_en[1] ? bg_pxl : 8'd0};
    blank_l  <= ~(LVBL & LHBL) | ~video_on;
    {blue, green, red} <= blank_l ? 15'd0 : pal_vq[14:0];
end

endmodule
