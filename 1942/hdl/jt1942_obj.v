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
    Date: 20-1-2019 */

// 1942 Object Generation
    
module jt1942_obj(
    input              rst,
    input              clk,
    input              cen6,    //  6 MHz
    input              cen3,    //  3 MHz
    // screen
    input              HINIT,
    input              LHBL,
    input              LVBL,
    input   [ 7:0]     V,
    input   [ 8:0]     H,
    input              flip,
    // CPU bus
    input        [6:0] AB,
    input        [7:0] DB,
    input              wr_n,
    // SDRAM interface
    output      [13:0] obj_addr,
    input       [15:0] objrom_data,
    // PROMs
    input   [7:0]      prog_addr,
    input              prom_m11_we,
    input              prom_k3_we,
    input   [3:0]      prog_din,
    // pixel output
    output       [3:0] obj_pxl
);


wire line, fill, line_obj_we;
wire [7:0] objbuf_data;
wire [3:0]   pxlcnt;

jt1942_objtiming u_timing(
    .rst       ( rst       ),
    .clk       ( clk       ),
    .cen6      ( cen6      ),    //  6 MHz
    // screen
    .HINIT     ( HINIT     ),
    .pxlcnt    ( pxlcnt    ),
    .line      ( line      )
);


jt1942_objram u_ram(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    .cen3           ( cen3          ),    //  3 MHz
    .H              ( H             ),
    .V              ( V             ),
    // CPU interface
    .DB             ( DB            ),
    .AB             ( AB            ),
    .wr_n           ( wr_n          ),
    // memory output
    .objbuf_data    ( objbuf_data   ),
    // Timing PROM
    .prog_addr      ( prog_addr     ),
    .prom_m11_we    ( prom_m11_we   ),
    .prog_din       ( prog_din[1:0] )
);

wire [8:0] posx;
wire [3:0] new_pxl;

// draw the sprite
jtgng_objdraw u_draw(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    // screen
    .V              ( V             ),
    .H              ( H             ),
    .pxlcnt         ( pxlcnt        ),
    .posx           ( posx          ),
    .flip           ( flip          ),
    // per-line sprite data
    .objbuf_data    ( objbuf_data   ),
    // SDRAM interface
    .obj_addr       ( obj_addr      ),
    .objrom_data    ( objrom_data   ),
    // Palette PROM
    .prog_addr      ( prog_addr     ),
    .prom_k3_we     ( prom_k3_we    ),
    .prog_din       ( prog_din      ),
    // pixel data
    .new_pxl        ( new_pxl       )
);

// line buffers for pixel data
jt1942_objpxl u_pxlbuf(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    // screen
    .LHBL           ( LHBL          ),    
    .flip           ( flip          ),
    .pxlcnt         ( pxlcnt        ),
    .posx           ( posx          ),
    .line           ( line          ),
    // pixel data
    .new_pxl        ( new_pxl       ),
    .obj_pxl        ( obj_pxl       )
);

endmodule // jtgng_char