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
    input              obj_cs,
    input              wr_n,
    // SDRAM interface
    output      [14:0] obj_addr,
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
wire [7:0]  objbuf_data0, objbuf_data1, objbuf_data2, objbuf_data3;

wire [3:0] pxlcnt;
wire [4:0] objcnt;

wire SEATM_b, DISPTM_b;

jt1942_objtiming u_timing(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .cen6        ( cen6          ),    //  6 MHz
    // screen
    .HINIT       ( HINIT         ),
    .V           ( V             ),
    .H           ( H             ),    
    // Timings
    .SEATM_b     ( SEATM_b       ),
    .DISPTM_b    ( DISPTM_b      ),
    // Timing PROM
    .prog_addr   ( prog_addr     ),
    .prom_m11_we ( prom_m11_we   ),
    .prog_din    ( prog_din[1:0] ),
    .pxlcnt      ( pxlcnt        ),
    .objcnt      ( objcnt        ),
    .line        ( line          )
);


jt1942_objram u_ram(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    .cen3           ( cen3          ),    //  3 MHz
    // Timings
    .objcnt         ( objcnt        ),
    .pxlcnt         ( pxlcnt        ),
    .SEATM_b        ( SEATM_b       ),
    // CPU interface
    .DB             ( DB            ),
    .AB             ( AB            ),
    .wr_n           ( wr_n          ),
    .obj_cs         ( obj_cs        ),
    // memory output
    .objbuf_data0   ( objbuf_data0  ),
    .objbuf_data1   ( objbuf_data1  ),
    .objbuf_data2   ( objbuf_data2  ),
    .objbuf_data3   ( objbuf_data3  )
);

wire [8:0] posx;
wire [3:0] new_pxl;

`ifdef OBJ_TEST
    reg [15:0] test_data, td0, td1, td2;
    always @(*)
        case( obj_addr[14:8] )
            7'h3b: td0 = {2{~obj_addr[3:0],obj_addr[3:0]}};
            default: td0 = 16'd0;
        endcase
    always @(posedge clk) if(cen6) begin
        td1 <= td0;
        td2 <= td1;
        test_data <= td2;
    end
`endif

// draw the sprite
jt1942_objdraw u_draw(
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
    .objbuf_data0   ( objbuf_data0  ),
    .objbuf_data1   ( objbuf_data1  ),
    .objbuf_data2   ( objbuf_data2  ),
    .objbuf_data3   ( objbuf_data3  ),
    `ifdef OBJ_TEST
    .objrom_data    ( test_data     ),
    `else
    .objrom_data    ( objrom_data   ),
    `endif
    // SDRAM interface
    .obj_addr       ( obj_addr      ),
    // Palette PROM
    .prog_addr      ( prog_addr     ),
    .prom_k3_we     ( prom_k3_we    ),
    .prog_din       ( prog_din      ),
    // pixel data
    .new_pxl        ( new_pxl       )
);

// line buffers for pixel data
jt1942_objpxl #(.obj_dly(5'h1f))u_pxlbuf(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    // screen
    .LHBL           ( LHBL          ),    
    .DISPTM_b       ( DISPTM_b      ),
    .flip           ( flip          ),
    .objcnt         ( objcnt        ),
    .pxlcnt         ( pxlcnt        ),
    .posx           ( posx          ),
    .line           ( line          ),
    // pixel data
    .new_pxl        ( new_pxl       ),
    .obj_pxl        ( obj_pxl       )
);

endmodule // jtgng_char