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

module jts18_vdp_pri_test #( parameter VBLs = 180)(
    input            clk, rst,
    input      [7:0] debug_bus,
    input      [2:0] vdp_prio,
    input      [1:0] obj_prio, buttons,
    input            sa, sb, fix, s1_pri, s2_pri, obj,
    input            LVBL,
    // input            i3, i6, // Obj0, Obj1
    // input            i4, i5, i7, i8, i9, //Tilemap 3, 2, 1, 0, 4 
    output reg       vdp_sel,
    output     [7:0] st_show
);

reg  [6:0] lyr_cnt=0;
reg  [4:0] obj_cnt=0;
reg  [4:0] lyr_bus, lyr_bus_out;
reg  [3:0] obj_bus, obj_bus_out;
reg  [1:0] buttons_l, objs;
reg        LVBL_l, go, gof;
reg  [7:0] scnt;
wire [7:0] fin = VBLs;
wire [6:0] acond, acond_s;
// assign obj_bus = {~obj_prio, obj_prio};        
// assign lyr_bus = {sa, sb, fix, s1_pri, s2_pri};
assign st_show = debug_bus[7] ? {vdp_prio, obj_cnt} : (debug_bus[0]? {2'b0, acond_s} : {1'b0, lyr_cnt}) ;

always @( posedge clk ) begin
    obj_bus   <= { obj_prio, ~obj_prio};
    lyr_bus   <= { !obj, !sb, !fix, s1_pri, s2_pri};
    LVBL_l    <= LVBL;
    buttons_l <= buttons;
    acond_s <= acond;
end

always @( posedge clk, posedge rst) begin
    if( rst ) begin
        obj_cnt <= 5'b0;
        lyr_cnt <= 7'b0;
        go      <= 1'b0;
        gof     <= 1'b0;
        scnt    <= 8'b0;
    end else begin
        obj_cnt <= obj_cnt /*+ debug_bus[3:0]*/;
        if( buttons_l[1] & !buttons[1] ) go  <= ~go;
        if( buttons_l[0] & !buttons[0] ) gof <= ~gof;
        if( !LVBL_l && LVBL ) scnt <= scnt + 1'b1;
        if( scnt==fin ) begin
            scnt <= 0;
            if( go  ) obj_cnt <= obj_cnt +1'b1 /*+ debug_bus[3:0]*/;
            if( gof ) lyr_cnt <= lyr_cnt +1'b1;
            if( obj_cnt == 5'h17 ) obj_cnt <= 5'b0;
            if( lyr_cnt == 7'h77 ) lyr_cnt <= 7'b0;
        end
        if( !buttons ) begin
            obj_cnt <= 5'b0;
            lyr_cnt <= 7'b0;
            go      <= 1'b0;
            gof     <= 1'b0;
            scnt    <= 8'b0;
        end
    end
end
// always @( posedge clk ) begin
    // vdp_sel <= c01 || c2 || c3 || c4 || c5 || c6 || c7;
// end

jtframe_sort u_sortobj(
    .debug_bus( obj_cnt     ),
    .busin    ( obj_bus     ),
    .busout   ( obj_bus_out )
);

jtframe_sort5 u_sortlyr(
    .debug_bus( lyr_cnt     ),
    .busin    ( lyr_bus     ),
    .busout   ( lyr_bus_out )
);

always @* begin
    objs = debug_bus[5] ? lyr_bus_out[3:2] : obj_bus_out[3:2];
end

jts18_vdp_pri u_eq(
    .clk      ( clk            ),
    .debug_bus( debug_bus      ),
    .vdp_prio ( vdp_prio       ),
    .i6       ( objs[1]        ), // Obj1
    .i7       ( objs[0]        ), // Obj0
    .i3       ( lyr_bus_out[2]^debug_bus[2] ), // Tilemap0'
    .i4       ( lyr_bus_out[3]^debug_bus[3] ), // Tilemap1'
    .i5       ( !sa            ), // Tilemap2'
    .i8       ( lyr_bus_out[0]^debug_bus[1] ), // Tilemap3'
    .i9       ( lyr_bus_out[4]^debug_bus[4] ), // Tilemap4'
    .vdp_sel  ( vdp_sel        ),
    .acond    ( acond          )
);

endmodule