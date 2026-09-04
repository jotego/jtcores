/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 04-11-2025 */

// This module generates a pulse when button (active low) is pressed for a number of frames determined by CNTW
// Use for replicating real-life console power button needing long-pressing to work

module jtngp_pwr #(parameter CNTW=7)(
    input      rst,
    input      clk,
    input      vs,
    input      button,
    output reg pwr_press
);

wire pressed, vs_edge;
reg  pressed_l;

always @(posedge clk) begin
    pressed_l <=   ~pressed;
    pwr_press <= ~&{pressed,pressed_l};
end

jtframe_countup #(.W(CNTW)
)u_pressed(
    .rst   ( button  ),
    .clk   ( clk     ),
    .cen   ( vs_edge ),
    .v     ( pressed )
);

jtframe_edge cnt_pulse(
    .rst   ( rst     ),
    .clk   ( clk     ),
    .edgeof( vs      ),
    .clr   ( vs_edge ),
    .q     ( vs_edge )
);

endmodule
