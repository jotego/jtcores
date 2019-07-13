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
    Date: 29-6-2019 */

// Commando Colour Mixer
// Schematics page 8/8

`timescale 1ns/1ps

module jtcommando_colmix(
    input           rst,
    input           clk,
    input           cen12,
    input           cen6 /* synthesis direct_enable = 1 */,

    // pixel input from generator modules
    input [5:0]     char_pxl,        // character color code
    input [6:0]     scr_pxl,
    input [5:0]     obj_pxl,
    // Palette PROMs and object priority
    input   [7:0]   prog_addr,
    input           prom_1d_we,
    input           prom_2d_we,
    input           prom_3d_we,
    input   [3:0]   prom_din,

    input           LVBL,
    input           LHBL,
    input           pause,

    output reg [3:0] red,
    output reg [3:0] green,
    output reg [3:0] blue,
    // Debug
    input      [3:0] gfx_en
);

wire [7:0] dout_rg;
wire [3:0] dout_b;

reg [7:0] pixel_mux;

reg [7:0] prom_addr;
wire [3:0] selbus;

wire char_blank_b = gfx_en[0] & |(~char_pxl[1:0]);
wire obj_blank_b  = gfx_en[3] & |(~obj_pxl[3:0]);

always @(posedge clk) if(cen12) begin
    casez( {char_blank_b, obj_blank_b} )
        2'b00: pixel_mux <= { 1'b0, scr_pxl[6:0] }; // background
        2'b01: pixel_mux <= { 2'd1, obj_pxl      }; // objects
        2'b1?: pixel_mux <= { 2'd3, char_pxl     }; // characters
    endcase
end

always @(posedge clk) if(cen6) begin
    prom_addr <= (LVBL&&LHBL) ? pixel_mux : 8'd0;
end

// palette ROM
wire [3:0] pal_red, pal_green, pal_blue;

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/commando/vtb1.1d")) u_red(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( prom_din    ),
    .rd_addr( prom_addr   ),
    .wr_addr( prog_addr   ),
    .we     ( prom_1d_we  ),
    .q      ( pal_red     )
);

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/commando/vtb2.2d")) u_green(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( prom_din    ),
    .rd_addr( prom_addr   ),
    .wr_addr( prog_addr   ),
    .we     ( prom_2d_we  ),
    .q      ( pal_green   )
);

jtgng_prom #(.aw(8),.dw(4),.simfile("../../../rom/commando/vtb3.3d")) u_blue(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( prom_din    ),
    .rd_addr( prom_addr   ),
    .wr_addr( prog_addr   ),
    .we     ( prom_3d_we  ),
    .q      ( pal_blue    )
);

`ifdef AVATARS
// Objects have their own palette during pause
wire [11:0] avatar_pal;
reg [1:0] avatar_msb[0:2];
wire [7:0] avatar_addr = { avatar_msb[2], prom_addr[5:0] };

jtgng_ram #(.dw(12),.aw(8), .synfile("avatar_pal.hex"),.cen_rd(1))u_avatars(
    .clk    ( clk           ),
    .cen    ( pause         ),  // tiny power saving when not in pause
    .data   ( 12'd0         ),
    .addr   ( avatar_addr   ),
    .we     ( 1'b0          ),
    .q      ( avatar_pal    )
);

reg [1:0] obj_sel;

always @(posedge clk) if(cen6) begin
    obj_sel[0] <= selbus[1:0]==2'b10;
    obj_sel[1] <= obj_sel[0];
    // copy the OBJ palette address
    avatar_msb[0] <= obj_pxl[7:6];
    avatar_msb[1] <= avatar_msb[0];
    avatar_msb[2] <= avatar_msb[1];
end

always @(posedge clk) if(cen12) begin
    { red, green, blue } <= pause && obj_sel[1] ? avatar_pal : {pal_red, pal_green, pal_blue};
end
`else
always @(*) begin
    red   = pal_red;
    blue  = pal_blue;
    green = pal_green;
end
`endif

endmodule // jtcommando_colmix