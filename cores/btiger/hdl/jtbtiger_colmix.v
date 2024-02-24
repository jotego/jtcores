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

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-11-2019 */

// bd02.9j is probably the priority PROM. It isn't really worth using
// as the content is quite plain


module jtbtiger_colmix(
    input            rst,
    input            clk,
    input            cen12,
    input            cen6 /* synthesis direct_enable = 1 */,

    // pixel input from generator modules
    input [6:0]      char_pxl,        // character color code
    input [7:0]      scr_pxl,
    input [6:0]      obj_pxl,
    input            preLVBL,
    input            preLHBL,
    output           LHBL,
    output           LVBL,

    // CPU inteface
    input [9:0]      AB,
    input            blue_cs,
    input            redgreen_cs,
    input [7:0]      DB,

    output     [3:0] red,
    output     [3:0] green,
    output     [3:0] blue,
    // Priority PROMs bd01.8j
    input [7:0]     prog_addr,
    input           prom_prior_we,
    input [3:0]     prom_din
);

reg  [9:0] pixel_mux;

wire char_blank  = &char_pxl[1:0];
wire obj_blank   = &obj_pxl [3:0];

reg  [2:0] obj_sel; // signals whether an object pixel is selected

reg  [7:0] seladdr;
wire [3:0] selbus;

reg  [7:0] scr0;
reg  [6:0] char0, obj0;

wire [1:0] scr_prio = scr_pxl[6:5] + 2'b01;

always @(posedge clk) if(cen6) begin
    seladdr <= { ~char_blank, ~obj_blank,
        scr_pxl[7] ? 2'b00 : {scr_prio}, scr_pxl[3:0] };
    scr0  <= scr_pxl;
    char0 <= char_pxl;
    obj0  <= obj_pxl;

    obj_sel[2] <= obj_sel[1];
    obj_sel[1] <= obj_sel[0];
    obj_sel[0] <= 1'b0;

    pixel_mux[9:8] <= selbus[3:2];
    case( selbus[1:0] )
        2'b11: pixel_mux[7:0] <= { 1'b0, char0 };
        2'b10: pixel_mux[7:0] <= scr0;
        2'b01: begin
            pixel_mux[7:0] <= { 1'b0, obj0 };
            obj_sel[0] <= 1'b1;
        end
        2'b00: pixel_mux[7:0] <= 8'd0; // this value is a guess
    endcase
end

wire [3:0] pal_red, pal_green, pal_blue;

// Palette is in RAM
wire we_rg = /* !LVBL && */ redgreen_cs;
wire we_b  = /* !LVBL && */ blue_cs;

jtgng_dual_ram #(.AW(10),.SIMFILE("rg_ram.bin")) u_redgreen(
    .clk        ( clk         ),
    .clk_en     ( cen6        ), // clock enable only applies to write operation
    .data       ( DB          ),
    .rd_addr    ( pixel_mux   ),
    .wr_addr    ( AB          ),
    .we         ( we_rg       ),
    .q          ( {pal_red, pal_green}     )
);

jtgng_dual_ram #(.AW(10),.DW(4),.SIMFILE("b_ram.bin")) u_blue(
    .clk        ( clk         ),
    .clk_en     ( cen6        ), // clock enable only applies to write operation
    .data       ( DB[3:0]     ),
    .rd_addr    ( pixel_mux   ),
    .wr_addr    ( AB          ),
    .we         ( we_b        ),
    .q          ( pal_blue    )
);

// Clock must be faster than 6MHz so selbus is ready for the next
// 6MHz clock cycle:
jtframe_prom #(.AW(8),.DW(4),.SIMFILE("../../../rom/btiger/bd01.8j")) u_selbus(
    .clk    ( clk           ),
    .cen    ( cen12         ),
    .data   ( prom_din      ),
    .rd_addr( seladdr       ),
    .wr_addr( prog_addr     ),
    .we     ( prom_prior_we ),
    .q      ( selbus        )
);

jtframe_blank #(.DLY(8),.DW(12)) u_dly(
    .clk        ( clk                 ),
    .pxl_cen    ( cen6                ),
    .preLHBL    ( preLHBL             ),
    .preLVBL    ( preLVBL             ),
    .LHBL       ( LHBL                ),
    .LVBL       ( LVBL                ),
    .rgb_in     ( {pal_red, pal_green, pal_blue} ),
    .preLBL     (                     ),
    .rgb_out    ( {red, green, blue } )
);

endmodule // jtgng_colmix