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
    Date: 8-2026 */

/*  X1-003 / X1-006 colour stage.

    The X1-001 sprite colour is 5 bits (seta001.cpp draw_foreground:
    color = (color_pointer[i] & 0xf8) >> 3) and the pen is 4 bits, so the
    palette index is 9 bits even though the palette RAM holds 2048 words.
    taito_x's colorbase is 0, so sprites reach entries 0..511 only.

    screen_update fills the bitmap with pen 0x1f0 before drawing, so that
    is the backdrop wherever neither layer is opaque.

    Palette format is xRGB-555 (palette_device::xRGB_555): R=[14:10],
    G=[9:5], B=[4:0]. NOT the xBGR-555 most jt cores use.

    Pen extraction from the gfx ROM is taken STRAIGHT here. If the planes
    come out permuted the fix belongs in cfg/mame2mra.toml, not in a
    scramble added below - see the gfx1 comment there.    */

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

localparam [8:0] BACKDROP = 9'h1f0;   // screen_update bitmap.fill(0x1f0)

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
