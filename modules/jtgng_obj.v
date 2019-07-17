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
    Date: 27-10-2017 */

module jtgng_obj(
    input              rst,
    input              clk,     // 24 MHz
    input              cen6,    //  6 MHz
    // screen
    input              HINIT,
    input              LHBL,
    input              LVBL,
    input              LVBL_obj,
    input   [ 7:0]     V,
    input   [ 8:0]     H,
    input              flip,
    // shared bus
    output       [8:0] AB,
    input        [7:0] DB,
    input              OKOUT,
    output             bus_req,        // Request bus
    input              bus_ack,    // bus acknowledge
    output             blen,   // bus line counter enable
    // SDRAM interface
    output      [15:0] obj_addr,
    input       [15:0] objrom_data,
    // pixel output
    output       [5:0] obj_pxl
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
jtgng_objdma u_dma(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen6       ( cen6      ),    //  6 MHz
    // screen
    .LVBL       ( LVBL      ),
    // shared bus
    .AB         ( AB        ),
    .DB         ( DB        ),
    .OKOUT      ( OKOUT     ),
    .bus_req    ( bus_req   ),  // Request bus
    .bus_ack    ( bus_ack   ),  // bus acknowledge
    .blen       ( blen      ),  // bus line counter enable
    // output data
    .pre_scan   ( pre_scan  ),
    .ram_dout   ( ram_dout  )
);

// Parse sprite data per line
jtgng_objbuf u_buf(
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
wire [1:0] pospal;
wire [3:0] new_pxl;

// draw the sprite
jtgng_objdraw u_draw(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen6           ( cen6          ),    //  6 MHz
    // screen
    .VF             ( VF            ),
    .pxlcnt         ( pxlcnt        ),
    // per-line sprite data
    .objcnt         ( objcnt        ),
    .objbuf_data    ( objbuf_data   ),
    // SDRAM interface
    .obj_addr       ( obj_addr      ),
    .objrom_data    ( objrom_data   ),
    // pixel data
    .posx           ( posx          ),
    .pospal         ( pospal        ),
    .new_pxl        ( new_pxl       )
);

// line buffers for pixel data
jtgng_objpxl #(.dw(6),.obj_dly(5'hf),.palw(2)) u_pxlbuf(
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
    // .pospal         ( pospal        ),
    .new_pxl        ( {pospal, new_pxl}       ),
    .obj_pxl        ( obj_pxl       )
);

endmodule