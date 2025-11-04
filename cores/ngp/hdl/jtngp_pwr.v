/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 04-11-2025 */

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