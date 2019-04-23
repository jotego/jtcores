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
    Date: 1-13-2019 */

`timescale 1ns/1ps

module jt1943_obj(
    input              rst,
    input              clk,
    input              cen6,
    input              OBJON,
    // screen
    input              HINIT,
    input              LHBL,
    input              LVBL,
    input              LVBL_obj,
    input   [ 7:0]     V,
    input   [ 8:0]     H,
    input              flip,
    // Pause screen
    input              pause,
    output  [ 2:0]     avatar_idx,
    // shared bus
    output      [12:0] AB,
    input        [7:0] DB,
    input              OKOUT,
    output             bus_req,        // Request bus
    input              bus_ack,    // bus acknowledge
    output             blen,   // bus line counter enable
    // Palette PROM
    input   [7:0]      prog_addr,
    input              prom_7c_we,
    input              prom_8c_we,
    input   [3:0]      prog_din,
    // SDRAM interface
    output      [16:0] obj_addr,
    input       [15:0] objrom_data,
    // pixel output
    output       [7:0] obj_pxl
);

wire [8:0] pre_scan;
wire [7:0] ram_dout;

wire line, fill, line_obj_we;
wire [4:0] post_scan;
wire [7:0] VF;
wire [7:0] objbuf_data;

reg [4:0] objcnt;
reg [3:0] pxlcnt;

always @(posedge clk) if(cen6) begin
    if( HINIT )
        { objcnt, pxlcnt } <= {5'd8,4'd0};
    else
        if( objcnt != 5'd0 )  { objcnt, pxlcnt } <=  { objcnt, pxlcnt } + 1'd1;
end

// DMA to 6809 RAM memory to copy the sprite data
jtgng_objdma #(.OBJMAX(9'h1FF)) u_dma(
    .rst        ( rst        ),
    .clk        ( clk        ),
    .cen6       ( cen6       ),    //  6 MHz
    // screen
    .LVBL       ( LVBL       ),
    .pause      ( pause      ),
    .avatar_idx ( avatar_idx ),
    // shared bus
    .AB         ( {AB[11:5], AB[1:0]} ), // 9bits
    .DB         ( DB         ),
    .OKOUT      ( OKOUT      ),
    .bus_req    ( bus_req    ),  // Request bus
    .bus_ack    ( bus_ack    ),  // bus acknowledge
    .blen       ( blen       ),  // bus line counter enable
    // output data
    .pre_scan   ( pre_scan   ),
    .ram_dout   ( ram_dout   )
);

assign AB[ 12] = 1'b1;
assign AB[4:2] = 3'b0;


// Parse sprite data per line
jtgng_objbuf #(.OBJMAX(10'h1FF),.OBJMAX_LINE(5'd31)) u_buf(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    // screen
    .HINIT          ( HINIT         ),
    .LVBL           ( LVBL_obj      ),
    .V              ( V             ),
    .VF             ( VF            ),
    .flip           ( flip          ),
    // sprite data scan
    .pre_scan       ( pre_scan      ),
    .ram_dout       ( ram_dout      ),
    // sprite data buffer
    .objbuf_data    ( objbuf_data   ),
    .objcnt         ( objcnt        ),
    .pxlcnt         ( pxlcnt        ),
    .line           ( line          )
);

wire [8:0] posx;
wire [7:0] new_pxl;

// draw the sprite
jt1943_objdraw u_draw(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
`ifndef OBJTEST
    .OBJON          ( OBJON         ),
`else 
    .OBJON          ( 1'b1          ),
`endif
    // screen
    .VF             ( VF            ),
    .pxlcnt         ( pxlcnt        ),
    .pause          ( pause         ),
    // per-line sprite data
    .objcnt         ( objcnt        ),
    .objbuf_data    ( objbuf_data   ),
    // SDRAM interface
    .obj_addr       ( obj_addr      ),
    .objrom_data    ( objrom_data   ),
    // PROMs
    .prog_addr      ( prog_addr     ),
    .prom_7c_we     ( prom_7c_we    ),
    .prom_8c_we     ( prom_8c_we    ),
    .prog_din       ( prog_din      ),
    // pixel data
    .posx           ( posx          ),
    .new_pxl        ( new_pxl       )
);

// line buffers for pixel data
jtgng_objpxl #(.dw(8),.obj_dly(5'hf),.palw(4)) u_pxlbuf(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    .DISPTM_b       ( 1'b0          ),
    // screen
    .LHBL           ( LHBL          ),
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