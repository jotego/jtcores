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
    Date: 10-07-2024 */

module jts18_vdp_pri_test(
    input            clk, rst,
    input      [7:0] debug_bus,
    input      [2:0] vdp_prio,
    input      [1:0] obj_prio, buttons,
    input            sa, sb, fix, s1_pri, s2_pri, obj,
    input            LVBL,
    output reg       vdp_sel,
    output     [7:0] st_show
);
reg        i3, i4, i5, i8, i9, i6, i7;
wire [6:0] acond;

always @( posedge clk ) begin
    {i7, i6} <= obj_prio;
     i3 <= !fix;
     i4 <= !sa;
     i5 <=  obj&& s1_pri;
     i8 <=  s1_pri && s2_pri;
     i9 <= !sb && s2_pri;
 end

 assign st_show = 8'b0;

jts18_vdp_pri u_eq(
    .clk      ( clk         ),
    .debug_bus( debug_bus   ),
    .vdp_prio ( vdp_prio    ),
    .i6       ( i6          ), // Obj1
    .i7       ( i7          ), // Obj0
    .i3       ( i3          ), // Tilemap0'
    .i4       ( i4          ), // Tilemap1'
    .i5       ( i5          ), // Tilemap2'
    .i8       ( i8          ), // Tilemap3'
    .i9       ( i9          ), // Tilemap4'
    .vdp_sel  ( vdp_sel     ),
    .acond    ( acond       )
);

endmodule