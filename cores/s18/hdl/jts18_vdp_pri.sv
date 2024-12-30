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

module jts18_vdp_pri(
    input            clk,
    input      [7:0] debug_bus,
    input      [2:0] vdp_prio,
    input            i7, i6, // Obj0, Obj1
    input            i3, i4, i5, i8, i9, //Tilemap 0, 1, 2, 3, 4
    output reg       vdp_sel,
    output     [6:0] acond
);

reg c01, c2, c3, c4, c5, c6, c7;
wire p2, p1, p0;
assign {p2,p1,p0} = vdp_prio;
assign acond = {c01, c2, c3, c4, c5, c6, c7};


always @* begin
    c7  =                                                     p2 && p1 && p0;
    c6  =                    (  !i6  || !i7  || i8 || i9 ) && p2 && p1;
    c5  =  i3             &&    !i6                        && p2       && p0;
    c4  =  i3             && (          !i7  || i8 || i9 ) && p2;
    c3  =  i3 && i4                  && !i7                      && p1 && p0;
    c2  =  i3 && i4       && ( (!i6  && !i7) || i8 || i9 )       && p1;
    c01 = !i3 && i4 && i5 && ( (!i6  && !i7) || i8 || i9 );
end

always @( posedge clk ) begin
    vdp_sel <= c01 || c2 || c3 || c4 || c5 || c6 || c7;
end
endmodule