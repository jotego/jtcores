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
    Date: 16-4-2020 */

`timescale 1ns/1ps

module jtsectionz_colmix #(
    parameter CHARW = 6
) (
    input            rst,
    input            clk,
    input            cen12,
    input            cen6 /* synthesis direct_enable = 1 */,

    // pixel input from generator modules
    input [CHARW-1:0]char_pxl,        // character color code
    input [6:0]      scr_pxl,
    input [6:0]      obj_pxl,
    input            LVBL,
    input            LHBL,
    output           LHBL_dly,
    output           LVBL_dly,
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
    // Priority PROMs bd01.8j
    // input [7:0]     prog_addr,
    // input           prom_prior_we,
    // input [3:0]     prom_din,
    // Debug
    input      [3:0] gfx_en
);

reg [9:0] pixel_mux;

wire enable_char = gfx_en[0];
wire enable_scr  = gfx_en[1];
wire enable_obj  = gfx_en[3];

wire char_blank  = (&char_pxl[1:0]) | ~enable_char;
wire obj_blank   = (&obj_pxl[3:0])  | ~enable_obj;
wire scr_blank   = &scr_pxl[3:0];

reg  [2:0] obj_sel; // signals whether an object pixel is selected

reg  [7:0] seladdr;
reg  [1:0] selbus;

reg [6:0] scr0, obj0;
reg [CHARW-1:0] char0;

wire [1:0] scr_prio = scr_pxl[6:5] + 2'b01;

always @(posedge clk) if(cen6) begin
    seladdr <= { ~char_blank, ~obj_blank, 
        !enable_scr ? 2'b00 : {scr_prio}, scr_pxl[3:0] };
    scr0 <= scr_pxl;
    char0 <= char_pxl;
    obj0 <= obj_pxl;

    obj_sel[2] <= obj_sel[1];
    obj_sel[1] <= obj_sel[0];
    obj_sel[0] <= 1'b0;

    pixel_mux[9:8] <= selbus;
    case( selbus )
        2'b10: pixel_mux[7:0] <= { {(8-CHARW){1'b0}}, char0 };
        2'b00: pixel_mux[7:0] <= { 1'b0, scr0 };
        2'b01: begin
            pixel_mux[7:0] <= { 1'b1, obj0 };
            obj_sel[0] <= 1'b1;
        end
        default: pixel_mux[7:0] <= 8'd0; // this value is a guess
    endcase
end

always @(posedge clk) if(cen12) begin
    selbus <= seladdr[7] ? 2'b10 : ( // char
        seladdr[6] ? 2'b01 : // obj
        2'b00); // scr
end

jtframe_sh #(.width(2),.stages(8)) u_hb_dly(
    .clk    ( clk      ),
    .clk_en ( cen6     ),
    .din    ( {LHBL, LVBL}    ),
    .drop   ( {LHBL_dly, LVBL_dly}   )
);

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
    .data       ( DB[7:4]     ),
    .rd_addr    ( pixel_mux   ),
    .wr_addr    ( AB          ),
    .we         ( we_b        ),
    .q          ( pal_blue    )
);
/*
// Clock must be faster than 6MHz so selbus is ready for the next
// 6MHz clock cycle:
jtframe_prom #(.aw(8),.dw(4),.simfile("../../../rom/btiger/bd01.8j")) u_selbus(
    .clk    ( clk           ),
    .cen    ( cen12         ),
    .data   ( prom_din      ),
    .rd_addr( seladdr       ),
    .wr_addr( prog_addr     ),
    .we     ( prom_prior_we ),
    .q      ( selbus        )
);
*/

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

wire blanking = !LVBL_dly || (/*!LHBL &&*/ !LHBL_dly);

always @(posedge clk) if (cen6)
    {red, green, blue } <= !blanking ? avatar_mux : 12'd0;


endmodule // jtgng_colmix