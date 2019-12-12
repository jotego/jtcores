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
    Date: 20-11-2019 */

// bd02.9j is probably the priority PROM. It isn't really worth using
// as the content is quite plain

`timescale 1ns/1ps

module jtbtiger_colmix(
    input            rst,
    input            clk,
    input            cen6 /* synthesis direct_enable = 1 */,

    // pixel input from generator modules
    input [6:0]      char_pxl,        // character color code
    input [7:0]      scr_pxl,
    input [6:0]      obj_pxl,
    input            LVBL,
    input            LHBL,
    output  reg      LHBL_dly,
    output  reg      LVBL_dly,
    // Avatars
    input [3:0]      avatar_idx,
    input            pause,
    // CPU inteface
    input [9:0]      AB,
    input            blue_cs,
    input            redgreen_cs,
    input [7:0]      DB,

    output reg [3:0] red,
    output reg [3:0] green,
    output reg [3:0] blue,
    // control
    input            CHRON,
    input            SCRON,
    input            OBJON,
    // Debug
    input      [3:0] gfx_en
);

reg [9:0] pixel_mux;

wire enable_char = gfx_en[0] && CHRON;
wire enable_scr  = gfx_en[1] && SCRON;
wire obj_blank   = &obj_pxl[3:0] || !OBJON;
wire char_blank  = &char_pxl[1:0];
wire enable_obj  = gfx_en[3];

reg  [2:0] obj_sel; // signals whether an object pixel is selected

////////////////////////////////////
// Priority - scroll overlapping
// PROM bd02.9j seems to be driven by scr_pxl[7:4] to obtain a 0,1,2,3 value
// This value comes into bd01.8j. Address 0x40-0x7F seem to contain whether
// scr or obj are selected. bit 0 selects obj, bit 1 scr.
// Paul Leaman's visually derived transparent table in MAME source code
// fits this interpretation of the PROM too
// I am not reading the PROMs here as it will take less area to do it
// directly in code

reg       scr_win;

always @(*) begin
    case( scr_pxl[7:5] )
        3'd0:    scr_win = scr_pxl[3:2]<2'd3;
        3'd1:    scr_win = scr_pxl[3:2]<2'd2;
        3'd2:    scr_win = scr_pxl[3:2]<2'd1;
        default: scr_win = 1'b0;
    endcase
end

always @(posedge clk) if(cen6) begin
    obj_sel[2] <= obj_sel[1];
    obj_sel[1] <= obj_sel[0];
    obj_sel[0] <= 1'b0;
    if( char_blank || !enable_char ) begin
        // Object or scroll
        if( obj_blank || !enable_obj || scr_win)
            pixel_mux <= enable_scr ? { 2'b0, scr_pxl } : ~10'h0; // scroll wins
        else begin
            obj_sel[0] <= 1'b1;
            pixel_mux <= {3'b100, obj_pxl }; // object wins
        end
    end
    else begin // characters
        pixel_mux <= { 3'b110, char_pxl };
    end
end

reg [1:0] pre_BL;

//jtframe_sh #(.width(2),.stages(5)) u_hb_dly(
//    .clk    ( clk      ),
//    .clk_en ( cen6     ),
//    .din    ( {LHBL, LVBL}     ),
//    .drop   ( pre_BL   )
//);

always @(posedge clk) if(cen6) begin
    {LHBL_dly, LVBL_dly} <= pre_BL;
    pre_BL <= {LHBL, LVBL};
end

wire [3:0] pal_red, pal_green, pal_blue;

// Palette is in RAM
wire we_rg = /* !LVBL && */ redgreen_cs;
wire we_b  = /* !LVBL && */ blue_cs;

jtgng_dual_ram #(.aw(10),.simfile("rg_ram.bin")) u_redgreen(
    .clk        ( clk         ),
    .clk_en     ( cen6        ), // clock enable only applies to write operation
    .data       ( DB          ),
    .rd_addr    ( pixel_mux   ),
    .wr_addr    ( AB          ),
    .we         ( we_rg       ),
    .q          ( {pal_red, pal_green}     )
);

jtgng_dual_ram #(.aw(10),.dw(4),.simfile("b_ram.bin")) u_blue(
    .clk        ( clk         ),
    .clk_en     ( cen6        ), // clock enable only applies to write operation
    .data       ( DB[3:0]     ),
    .rd_addr    ( pixel_mux   ),
    .wr_addr    ( AB          ),
    .we         ( we_b        ),
    .q          ( pal_blue    )
);

`ifdef AVATARS
`ifdef MISTER
`define AVATAR_PAL
`endif
`endif

`ifdef AVATAR_PAL
wire [11:0] avatar_pal;
// Objects have their own palette during pause
wire [ 7:0] avatar_addr = { avatar_idx, obj_pxl[0], obj_pxl[1], obj_pxl[2], obj_pxl[3] };

jtframe_ram #(.dw(12),.aw(8), .synfile("avatar_pal.hex"),.cen_rd(1))u_avatars(
    .clk    ( clk           ),
    .cen    ( pause         ),  // tiny power saving when not in pause
    .data   ( 12'd0         ),
    .addr   ( avatar_addr   ),
    .we     ( 1'b0          ),
    .q      ( avatar_pal    )
);
// Select the avatar palette output if we are on avatar mode
wire [11:0] avatar_mux = (pause&&obj_sel[1]) ? avatar_pal : { pal_red, pal_green, pal_blue };
`else 
wire [11:0] avatar_mux = {pal_red, pal_green, pal_blue};
`endif


always @(posedge clk) if (cen6)
    {red, green, blue } <= pre_BL==2'b11 ? avatar_mux : 12'd0;

endmodule // jtgng_colmix