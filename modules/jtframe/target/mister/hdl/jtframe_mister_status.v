/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 14-03-2025 */
module jtframe_mister_status (
    input  [63:0] status,
`ifdef JTFRAME_CRT480I
    input         crt_on,   // 480i analog output: it has its own position controls
`endif
    output        crop_en,
    output [ 3:0] vcopt,
    output [ 2:0] crop_scale,
    output [ 3:0] voffset,
    output [ 3:0] hoffset,
    output        hsize_enable,
    output [ 3:0] hsize_scale,
    output [ 1:0] ram_save,
    output        ram_load,
    output        gun_border_en,
    output        uart_en
);

// Vertical crop
assign crop_en    = status[41];
assign vcopt      = status[45:42];
assign crop_scale = {1'b0, status[47:46]};

`ifndef JTFRAME_CRT480I
wire crt_on = 0;
`endif
// H-Pos & V-Pos for CRT. With 480i on, crt_480i has its own controls and these stay at rest
// (the 480i and native MRAs share one settings file)
assign { voffset, hoffset } = crt_on ? 8'd0 : status[60:53];

// Horizontal scaling for CRT
assign hsize_enable = ~crt_on & status[48];
assign hsize_scale  = crt_on ? 4'd0 : status[52:49];

assign uart_en  = status[38]; // It can be used by the cheat engine or the game

// Sinden Lightgun white borders
assign gun_border_en = status[8];

// Save/Load
assign ram_save = status[21:20];
assign ram_load = status[22];

endmodule
