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
    Date: 22-9-2019 */

// Resistor values measured on PCB by Caius (Twitter @Caius63417737)
// Pin number    7    6    5  4  3   2    1
// R2R ladders: 4.7k-2.2K-1K-470-220-100  common net
// R9  470, R10 470, R11 470, R12 1K, R14 1K, R16 1K, R13 220, R15 220, R17 220

// Table of colours (voltages)
//                      Brightness
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
//
// For a 5-bit value:
// Col    0   1   2   3   4   5   6   7
// 0      0   2   4   6   9   11  13  15
// 1      1   3   5   7   10  12  14  16
// 2      2   4   6   8   11  13  15  17
// 3      3   5   7   9   12  14  16  18
// 4      4   6   8   10  13  15  17  19
// 5      5   7   9   11  14  16  18  20
// 6      6   8   10  12  15  17  19  21
// 7      7   9   11  13  16  18  20  22
// 8      9   11  13  15  18  20  22  24
// 9      10  12  14  16  19  21  23  25
// 10     11  13  15  17  20  22  24  26
// 11     12  14  16  18  21  23  25  27
// 12     13  15  17  19  22  24  26  28
// 13     14  16  18  20  23  25  27  29
// 14     15  17  19  21  24  26  28  30
// 15     16  18  20  22  25  27  29  31

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
    input            preLVBL,
    input            preLHBL,
    output           LHBL,
    output           LVBL,
    // Priority PROM
    input [7:0]      prog_addr,
    input            prom_prio_we,
    input [3:0]      prom_din,
    // CPU inteface
    input [10:1]     AB,
    input            col_uw,
    input            col_lw,
    input [15:0]     DB,

    output     [4:0] red,
    output     [4:0] green,
    output     [4:0] blue,
    // Debug
    input      [3:0] gfx_en
);

parameter SIM_PRIO = "../../../rom/biocom/63s141.18f";
localparam BLANK_DLY=2;

reg [9:0] pxl_mux;

wire char_en = gfx_en[0];
wire scr1_en = gfx_en[1];
wire scr2_en = gfx_en[2];
wire obj_en  = gfx_en[3];

wire [1:0] pre_prio;
reg  [7:0] seladdr;
reg  [1:0] prio, presel;
wire       char_blank_n = ~&char_pxl[1:0];
wire       preLBL;

always @(*) begin
    seladdr[0]   = scr2_en ? ~&scr2_pxl[3:0] : 1'b0;
    seladdr[6:1] = scr1_en ? { scr1_pxl[7:6], scr1_pxl[3:0] } : 6'h3f;
    seladdr[7]   = obj_en  ? ~&obj_pxl[3:0] : 1'b0;
    prio         = pre_prio  | ( char_en ? {2{char_blank_n}} : 2'b0 );
end

always @(posedge clk) if(cen6) begin
    case( prio )
        2'b11: pxl_mux[7:0] <= { 2'b0, char_pxl };
        2'b10: pxl_mux[7:0] <= obj_pxl;
        2'b01: pxl_mux[7:0] <= { 2'b0, scr1_pxl[5:0] };
        2'b00: pxl_mux[7:0] <= { 1'b0, scr2_pxl[6:0] };
    endcase
    pxl_mux[9:8] <= prio;
end

// Address mux
wire [3:0] pal_red, pal_green, pal_blue, pal_bright;

jtframe_dual_ram16 #(
    .AW        (10          ),
    .SIMFILE_LO("pal_lo.bin"), // palrg.hex
    .SIMFILE_HI("pal_hi.bin")  // palbb.hex
) u_ram(
    .clk0   ( clk       ),
    .clk1   ( clk       ),

    // CPU writes
    .addr0  ( AB  ),
    .data0  ( DB        ),
    .we0    ( {col_uw, col_lw} ),
    .q0     (           ),

    // Video reads
    .addr1  ( pxl_mux ),
    .data1  (           ),
    .we1    ( 2'b0      ),
    .q1     ( {pal_red, pal_green, pal_blue, pal_bright } )
);

// Clock must be faster than 6MHz so pre_prio is ready for the next
// 6MHz clock cycle:
jtframe_prom #(.AW(8),.DW(2),.SIMFILE(SIM_PRIO)) u_pre_prio(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( prom_din[1:0] ),
    .rd_addr( seladdr       ),
    .wr_addr( prog_addr     ),
    .we     ( prom_prio_we  ),
    .q      ( pre_prio      )
);

reg [4:0] pre_r, pre_g, pre_b;

always @(posedge clk) begin
    if( ~preLBL ) begin
        pre_r <= 5'd0;
        pre_g <= 5'd0;
        pre_b <= 5'd0;
    end else begin
        pre_r <= pal_bright[3] ? { pal_red,  pal_red[3]   } : { 1'b0, pal_red   } + { 1'b0, pal_bright[2:0], pal_bright[2]};
        pre_g <= pal_bright[3] ? { pal_green,pal_green[3] } : { 1'b0, pal_green } + { 1'b0, pal_bright[2:0], pal_bright[2]};
        pre_b <= pal_bright[3] ? { pal_blue, pal_blue[3]  } : { 1'b0, pal_blue  } + { 1'b0, pal_bright[2:0], pal_bright[2]};
    end
end

jtframe_blank #(.DLY(BLANK_DLY),.DW(15)) u_dly(
    .clk        ( clk                 ),
    .pxl_cen    ( cen6                ),
    .preLHBL    ( preLHBL             ),
    .preLVBL    ( preLVBL             ),
    .LHBL       ( LHBL                ),
    .LVBL       ( LVBL                ),
    .preLBL     ( preLBL              ),
    .rgb_in     ( {pre_r, pre_g, pre_b}),
    .rgb_out    ( {red, green, blue }  )
);

endmodule