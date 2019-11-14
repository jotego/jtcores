/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-11-2019 */

module jtgng_avatar_pal #(parameter
    PALW = 4
) (
    input               clk,
    input               pause,
    input   [3:0]       avatar_idx,
    input               obj_sel,
    input   [3:0]       obj_pxl,
    input   [PALW-1:0]  pal_red,
    input   [PALW-1:0]  pal_green,
    input   [PALW-1:0]  pal_blue,
    output [3*PALW-1:0] avatar_mux
);


`ifdef AVATARS
`ifdef MISTER
    `define AVATAR_PAL
`endif
`endif


`ifdef AVATAR_PAL
wire [11:0] avatar_pal;
// Objects have their own palette during pause
wire [ 7:0] avatar_addr = { avatar_idx, obj_pxl[0], obj_pxl[1], obj_pxl[2], obj_pxl[3] };

jtgng_ram #(.dw(PALW*3),.aw(8), .synfile("avatar_pal.hex"),.cen_rd(1))u_avatars(
    .clk    ( clk           ),
    .cen    ( pause         ),  // tiny power saving when not in pause
    .data   ( {PALW{3'b0}} ),
    .addr   ( avatar_addr   ),
    .we     ( 1'b0          ),
    .q      ( avatar_pal    )
);
// Select the avatar palette output if we are on avatar mode
assign avatar_mux = (pause&&obj_sel) ? avatar_pal : { pal_red, pal_green, pal_blue };
`else
    assign avatar_mux = {pal_red, pal_green, pal_blue};
`endif

endmodule