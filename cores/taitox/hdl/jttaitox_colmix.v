/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
            Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 15-8-2026 */

/*  X1-003 / X1-006 colour stage. */

module jttaitox_colmix(
    input             clk,
    input             pxl_cen,
    input             LHBL,
    input             LVBL,
    input      [ 8:0] scr_pxl,      // X1-001 background column layer
    input      [ 8:0] obj_pxl,      // X1-001 foreground sprites
    output reg [ 9:1] pal_addr,
    input      [15:0] pal_data,
    input      [ 3:0] gfx_en,
    output     [ 4:0] red,
    output     [ 4:0] green,
    output     [ 4:0] blue
);

// palette index where the bg color is stored.
// this is part of seta xi-002(1?) but for now we don't have a model for it.
// this is part of the seta investigation.
localparam [8:0] BACKDROP = 9'h1f0;

reg  [ 8:0] col;
reg  [14:0] rgb;
wire        blank, obj_op, scr_op;

assign blank = ~(LVBL & LHBL);
assign { red, green, blue } = blank ? 15'd0 : rgb;
// pen 0 is transparent on both layers
assign obj_op = obj_pxl[3:0]!=0 && gfx_en[3];
assign scr_op = scr_pxl[3:0]!=0 && gfx_en[0];

always @* begin
    col = obj_op ? obj_pxl : scr_op ? scr_pxl : BACKDROP;
end

always @(posedge clk) if( pxl_cen ) begin
    pal_addr <= col;
    rgb      <= pal_data[14:0];
end

endmodule
