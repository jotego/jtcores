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
    Date: 19-2-2019 */

// 1943 Colour Mixer
// Schematics page 8/9

module jt1943_colmix(
    input           rst,
    input           clk,    // 24 MHz
    input           cen6 /* synthesis direct_enable = 1 */,
    // Synchronization
    //input [2:0]       H,
    // pixel input from generator modules
    input [3:0]     char_pxl,        // character color code
    input [5:0]     scr1_pxl,
    input [5:0]     scr2_pxl,
    input [7:0]     obj_pxl,
    // Palette PROMs 12A, 13A, 14A, 12C
    input   [7:0]   prog_addr,
    input           prom_12a_we,
    input           prom_13a_we,
    input           prom_14a_we,
    input           prom_12c_we,
    input   [3:0]   prom_din,

    input           LVBL,
    input           LHBL,

    output  [3:0]   red,
    output  [3:0]   green,
    output  [3:0]   blue
);

wire [7:0] dout_rg;
wire [3:0] dout_b;

reg [7:0] pixel_mux;

reg [7:0] prom_addr;
wire [3:0] selbus;

wire char_blank = |(~char_pxl);
wire obj_blank  = |(~obj_pxl[3:0]);
wire scr1_blank = |(~scr1_pxl[3:0]);
wire [7:0] seladdr = { 3'b0, char_blank, obj_blank, obj_pxl[7:6], scr1_blank };

reg [3:0] char_pxl_1;
reg [5:0] scr1_pxl_1;
reg [5:0] scr2_pxl_1;
reg [7:0] obj_pxl_1;

// latch for one clock cycle to wait for the selbus signal
always @(posedge clk) if(cen6) begin
    char_pxl_1  <= char_pxl;
    scr1_pxl_1  <= scr1_pxl;
    scr2_pxl_1  <= scr2_pxl;
    obj_pxl_1   <= obj_pxl;
end

always @(*) begin
    case( selbus[1:0] )
        2'b00: pixel_mux[5:0] = scr2_pxl_1;
        2'b01: pixel_mux[5:0] = scr1_pxl_1;
        2'b10: pixel_mux[5:0] =  obj_pxl_1[5:0];
        2'b11: pixel_mux[5:0] = { 2'b0, char_pxl_1 };
    endcase // selbus[1:0]
    pixel_mux[7:6] = selbus[3:2];
end

always @(posedge clk) if(cen6) begin
    prom_addr <= (LVBL&&LHBL) ? pixel_mux : 8'd0;
end


// palette ROM
jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/1943/bm1.12a")) u_red(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( prom_din    ),
    .rd_addr( prom_addr   ),
    .wr_addr( prog_addr   ),
    .we     ( prom_12a_we  ),
    .q      ( red         )
);

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/1943/bm2.13a")) u_green(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( prom_din    ),
    .rd_addr( prom_addr   ),
    .wr_addr( prog_addr   ),
    .we     ( prom_13a_we  ),
    .q      ( green       )
);

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/1943/bm3.14a")) u_blue(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( prom_din    ),
    .rd_addr( prom_addr   ),
    .wr_addr( prog_addr   ),
    .we     ( prom_14a_we ),
    .q      ( blue        )
);

// Clock must be faster than 6MHz so selbus is ready for the next
// 6MHz clock cycle:
jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/1943/bm4.12c"),.cen_rd(1)) u_selbus(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( prom_din    ),
    .rd_addr( seladdr     ),
    .wr_addr( prog_addr   ),
    .we     ( prom_12c_we ),
    .q      ( selbus      )
);

endmodule // jtgng_colmix