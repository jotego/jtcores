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
    Date: 22-9-2019 */

`timescale 1ns/1ps

// Resistor values measured on PCB by Caius (Twitter @Caius63417737)
// Pin number    7    6    5  4  3   2    1
// R2R ladders: 4.7k-2.2K-1K-470-220-100  common net
// R9  470, R10 470, R11 470, R12 1K, R14 1K, R16 1K, R13 220, R15 220, R17 220

// Table of colours (voltages)
//                      Brightnes
//       0      1    2     3     4     5     6     7
// Colour
// 0   0.000 0.194 0.412 0.606 0.881 1.075 1.293 1.487 
// 1   0.088 0.282 0.500 0.694 0.969 1.163 1.381 1.575 
// 2   0.194 0.388 0.606 0.800 1.075 1.268 1.487 1.681 
// 3   0.282 0.476 0.694 0.888 1.163 1.357 1.575 1.769 
// 4   0.412 0.606 0.825 1.018 1.293 1.487 1.706 1.899 
// 5   0.500 0.694 0.913 1.107 1.381 1.575 1.794 1.987 
// 6   0.606 0.800 1.018 1.212 1.487 1.681 1.899 2.093 
// 7   0.694 0.888 1.107 1.300 1.575 1.769 1.987 2.181 
// 8   0.881 1.075 1.293 1.487 1.762 1.956 2.174 2.368 
// 9   0.969 1.163 1.381 1.575 1.850 2.044 2.262 2.456 
// 10  1.075 1.268 1.487 1.681 1.956 2.149 2.368 2.562 
// 11  1.163 1.357 1.575 1.769 2.044 2.237 2.456 2.650 
// 12  1.293 1.487 1.706 1.899 2.174 2.368 2.586 2.780 
// 13  1.381 1.575 1.794 1.987 2.262 2.456 2.674 2.868 
// 14  1.487 1.681 1.899 2.093 2.368 2.562 2.780 2.974 
// 15  1.575 1.769 1.987 2.181 2.456 2.650 2.868 3.062 

module jtbiocom_colmix(
    input            rst,
    input            clk,
    input            cen6 /* synthesis direct_enable = 1 */,
    input            cpu_cen,
    // pixel input from generator modules
    input [5:0]      char_pxl,        // character color code
    input [7:0]      scr1_pxl,
    input [7:0]      scr2_pxl,
    input [7:0]      obj_pxl,
    input            LVBL,
    input            LHBL,
    output  reg      LHBL_dly,
    output  reg      LVBL_dly,
    // Priority PROM
    input [7:0]      prog_addr,
    input            prom_prio_we,
    input [3:0]      prom_din,
    // Avatars
    // input [3:0]      avatar_idx,
    // input            pause,
    // CPU inteface
    input [10:1]     AB,
    input            col_uw,
    input            col_lw,
    input [15:0]     DB,

    output reg [4:0] red,
    output reg [4:0] green,
    output reg [4:0] blue,
    // Debug
    input      [3:0] gfx_en
);

parameter SIM_PRIO = "../../../rom/biocom/63s141.18f";

reg [9:0] pixel_mux;

wire enable_char = gfx_en[0];
wire enable_scr1 = gfx_en[1];
wire enable_scr2 = gfx_en[2];
wire enable_obj  = gfx_en[3];

//reg  [2:0] obj_sel; // signals whether an object pixel is selected
wire [1:0] pre_prio;
reg  [7:0] seladdr;
reg  [1:0] prio, presel;
wire       char_blank_n = |(~char_pxl[1:0]);

always @(*) begin
    seladdr[0]   = enable_scr2 ? (|(~scr2_pxl[3:0])) : 1'b0;
    seladdr[6:1] = enable_scr1 ? ({ scr1_pxl[7:6], scr1_pxl[3:0] }) : 6'h3f;
    seladdr[7]   = enable_obj  ? (|(~obj_pxl[3:0])) : 1'b0;
    prio         = pre_prio | ( enable_char ? {2{char_blank_n}} : 2'b0 );
end

always @(posedge clk) if(cen6) begin
    case( prio )
        2'b11: pixel_mux[7:0] <= { 2'b0, char_pxl };
        2'b10: pixel_mux[7:0] <= obj_pxl;
        2'b01: pixel_mux[7:0] <= { 2'b0, scr1_pxl[5:0] };
        2'b00: pixel_mux[7:0] <= { 1'b0, scr2_pxl[6:0] };
    endcase
    pixel_mux[9:8] <= prio;
end

// Blanking delay
wire [1:0] pre_BL;

jtgng_sh #(.width(2),.stages(5)) u_blank_dly(
    .clk    ( clk      ),
    .clk_en ( cen6     ),
    .din    ( {LHBL, LVBL}     ),
    .drop   ( pre_BL   )
);

// Address mux
reg  [9:0] pal_addr;
reg        pal_uwe, pal_lwe;
reg        coloff; // colour off
wire [3:0] pal_red, pal_green, pal_blue, pal_bright;

always @(*) begin
    if( pre_BL!=2'b11 ) begin
        pal_addr = AB;
        pal_uwe   = col_uw;
        pal_lwe   = col_lw;
    end else begin
        pal_addr = pixel_mux;
        pal_uwe  = 1'b0;
        pal_lwe  = 1'b0;
    end
end

always @(posedge clk) if(cen6) begin
    coloff <= pre_BL!=2'b11;
    {LHBL_dly, LVBL_dly} <= pre_BL;
end


// Palette is in RAM

jtgng_ram #(.aw(10),.dw(8),.simhexfile("palrg.hex")) u_upal(
    .clk        ( clk         ),
    .cen        ( cpu_cen     ), // clock enable only applies to write operation
    .data       ( DB[15:8]    ),
    .addr       ( pal_addr    ),
    .we         ( pal_uwe     ),
    .q          ( {pal_red, pal_green } )
);

jtgng_ram #(.aw(10),.dw(8),.simhexfile("palbb.hex")) u_lpal(
    .clk        ( clk         ),
    .cen        ( cpu_cen     ), // clock enable only applies to write operation
    .data       ( DB[7:0]     ),
    .addr       ( pal_addr    ),
    .we         ( pal_lwe     ),
    .q          ( { pal_blue, pal_bright } )
);



// `ifdef AVATARS
// `ifdef MISTER
// `define AVATAR_PAL
// `endif
// `endif
// 
// `ifdef AVATAR_PAL
// wire [11:0] avatar_pal;
// // Objects have their own palette during pause
// wire [ 7:0] avatar_addr = { avatar_idx, obj_pxl[0], obj_pxl[1], obj_pxl[2], obj_pxl[3] };
// 
// jtgng_ram #(.dw(12),.aw(8), .synfile("avatar_pal.hex"),.cen_rd(1))u_avatars(
//     .clk    ( clk           ),
//     .cen    ( pause         ),  // tiny power saving when not in pause
//     .data   ( 12'd0         ),
//     .addr   ( avatar_addr   ),
//     .we     ( 1'b0          ),
//     .q      ( avatar_pal    )
// );
// // Select the avatar palette output if we are on avatar mode
// wire [11:0] avatar_mux = (pause&&obj_sel[1]) ? avatar_pal : { pal_red, pal_green, pal_blue };
// `else 
// wire [11:0] avatar_mux = {pal_red, pal_green, pal_blue};
// `endif

// Clock must be faster than 6MHz so pre_prio is ready for the next
// 6MHz clock cycle:
jtgng_prom #(.aw(8),.dw(2),.simfile(SIM_PRIO)) u_pre_prio(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prom_din[1:0] ),
    .rd_addr( seladdr       ),
    .wr_addr( prog_addr     ),
    .we     ( prom_prio_we  ),
    .q      ( pre_prio      )
);

reg [4:0] pre_r, pre_g, pre_b;
reg [3:0] pre_bright;
reg [7:0] step;

always @(posedge clk,posedge rst) begin
    if( rst ) begin
        step <= 8'd1;
    end else begin
        step <= { step[6:0], step[7] };
        if( step[0] ) begin
            pre_bright <= pal_bright;
            if( coloff ) begin
                pre_r <= 5'd0;
                pre_g <= 5'd0;
                pre_b <= 5'd0;
            end else begin
                pre_r <= { pal_red,  pal_red[3]   } >> ~pal_bright[3];
                pre_g <= { pal_green,pal_green[3] } >> ~pal_bright[3];
                pre_b <= { pal_blue, pal_blue[3]  } >> ~pal_bright[3];
            end
        end
        else begin
            if( !pre_bright[3] && pre_bright[2:0]!=3'd0 ) begin
                pre_r <= pre_r + 5'd2;
                pre_g <= pre_g + 5'd2;
                pre_b <= pre_b + 5'd2;
                pre_bright[2:0] <= pre_bright[2:0] - 3'd1;
            end
        end
    end
end

always @(posedge clk) if(cen6) begin
    red   <= pre_r;
    green <= pre_g;
    blue  <= pre_b;
end

endmodule // jtgng_colmix