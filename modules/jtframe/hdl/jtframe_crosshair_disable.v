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
    Date: 28-02-2025 */

module jtframe_crosshair_disable #(parameter CNTW=8)(
    input        rst,
    input        clk,
    input        vs,
    input  [1:0] strobe,
    output [1:0] en_b
);

wire pulse;

jtframe_countdown #(.W(CNTW)
)crosshair_left(
    .rst( strobe[0] ),
    .clk( clk       ),
    .cen( pulse     ),
    .v  ( en_b[0]   )
);

jtframe_countdown #(.W(CNTW)
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