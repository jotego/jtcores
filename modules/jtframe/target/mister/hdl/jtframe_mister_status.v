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
    Date: 14-03-2025 */
module jtframe_mister_status (
    input  [63:0] status,
    output        crop_en,
    output [ 3:0] vcopt,
    output [ 2:0] crop_scale,
    output [ 3:0] voffset,
    output [ 3:0] hoffset,
    output        hsize_enable,
    output [ 3:0] hsize_scale,
    output        gun_border_en,
    output        uart_en
);

// Vertical crop
assign crop_en    = status[41];
assign vcopt      = status[45:42];
assign crop_scale = {1'b0, status[47:46]};

// H-Pos & V-Pos for CRT
assign { voffset, hoffset } = status[60:53];

// Horizontal scaling for CRT
assign hsize_enable = status[48];
assign hsize_scale  = status[52:49];

assign uart_en  = status[38]; // It can be used by the cheat engine or the game

// Sinden Lightgun white borders
assign gun_border_en = status[8];

endmodule
