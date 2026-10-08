/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-02-2025 */

module jtframe_crosshair_disable #(parameter CNTW=8)(
    input        rst,
    input        clk,
    input        vs,
    input  [1:0] strobe,
    output       pulse,
    output [1:0] en_b
);

jtframe_countup #(.W(CNTW)
)crosshair_left(
    .rst( strobe[0] ),
    .clk( clk       ),
    .cen( pulse     ),
    .v  ( en_b[0]   )
);

jtframe_countup #(.W(CNTW)
)crosshair_rigth(
    .rst( strobe[1] ),
    .clk( clk       ),
    .cen( pulse     ),
    .v  ( en_b[1]   )
);

jtframe_edge cnt_pulse(
    .rst   ( rst    ),
    .clk   ( clk    ),
    .edgeof( vs     ),
    .clr   ( pulse  ),
    .q     ( pulse  )
);

endmodule
