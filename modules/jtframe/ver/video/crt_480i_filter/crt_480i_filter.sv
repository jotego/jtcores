/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-11-2026 */

`ifndef CRT_480I_FILTER_TEST
`define CRT_480I_FILTER_TEST

// Valid NARC configuration for simunit's standalone lint pass.
module crt_480i_filter(
    input clk,
    input [1:0] level
);

jtframe_crt_480i #(
    .CLK_HZ   ( 48000000 ),
    .CLK_DIV  ( 4        ),
    .CLK_FRAC ( 1        ),
    .RING     ( 128      ),
    .PW       ( 15       ),
    .LUT_EXT  ( 0        )
) u_crt_480i(
    .clk       ( clk    ),
    .ce_in     ( 1'b0   ),
    .pix_in    ( 15'd0  ),
    .vs_in     ( 1'b0   ),
    .de_in     ( 1'b0   ),
    .hoffset   ( 7'sd0  ),
    .voffset   ( 7'sd0  ),
    .deflicker ( level  ),
    .vheight   ( 3'd0   ),
    .lut_addr  (        ),
    .lut_rgb   ( 24'd0  ),
    .ce_out    (        ),
    .r_out     (        ),
    .g_out     (        ),
    .b_out     (        ),
    .hs_out    (        ),
    .vs_out    (        ),
    .de_out    (        ),
    .hb_out    (        ),
    .vb_out    (        ),
    .field     (        ),
    .locked    (        )
);

endmodule

`endif
