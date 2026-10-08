/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 10-07-2024 */

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
