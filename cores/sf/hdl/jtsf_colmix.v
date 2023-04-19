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
    Date: 19-8-2020 */

module jtsf_colmix #(
    parameter CHRPW     = 6,
              SCRPW     = 6,
              OBJPW     = 8,
              BLANK_DLY = 3

) (
    input            rst,
    input            clk,
    input            pxl_cen,
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
    // CPU inteface
    input [10:1]     AB,
    input            col_uw,
    input            col_lw,
    input [15:0]     DB,

    output     [3:0] red,
    output     [3:0] green,
    output     [3:0] blue,
    // Debug
    input      [3:0] gfx_en
);

localparam [1:0] SCR2=2'd0,SCR1=2'd1,OBJ=2'd2,CHAR=2'd3;

reg  [ 9:0] pixel_mux;
reg  [ 1:0] prio;
wire [11:0] pal_rgb;

wire enable_char = gfx_en[0];
wire enable_scr1 = gfx_en[1];
wire enable_scr2 = gfx_en[2];
wire enable_obj  = gfx_en[3];
wire obj_blank  = &obj_pxl[3:0];
wire char_blank = &char_pxl[1:0];
wire scr1_blank = &scr1_pxl[3:0];
wire preLBL;

always @(*) begin
    if( !char_blank && enable_char)
        prio = CHAR;
    else if( !obj_blank && enable_obj)
        prio = OBJ;
    else if( !scr1_blank && enable_scr1 )
        prio = SCR1;
    else
        prio = SCR2;
end

always @(posedge clk) if(pxl_cen) begin
    pixel_mux[9:8] <= prio;
    case( prio )
        CHAR: pixel_mux[7:0] <= { 2'b0, char_pxl };
        OBJ:  pixel_mux[7:0] <= obj_pxl; // 2301
        SCR1: pixel_mux[7:0] <= scr1_pxl;
        SCR2: pixel_mux[7:0] <= enable_scr2 ? scr2_pxl : 8'h00;
    endcase
end


// Palette is in RAM
`ifdef GRAY
assign pal_rgb = {3{pixel_mux[3:0]}};
`else
wire [3:0] nc;

jtframe_dual_ram16 #(.AW(10)) u_pal (
    .clk0   ( clk       ),
    .clk1   ( clk       ),
    // Port 0 - CPU
    .data0  ( DB        ),
    .addr0  ( AB        ),
    .we0    ( {col_uw,col_lw}    ),
    .q0     (           ),
    // Port 1 - Palette
    .data1  (           ),
    .addr1  ( pixel_mux ),
    .we1    ( 2'b0      ),
    .q1     ( { nc, pal_rgb } )
);
`endif

jtframe_blank #(.DLY(BLANK_DLY),.DW(12)) u_dly(
    .clk        ( clk                 ),
    .pxl_cen    ( pxl_cen             ),
    .preLHBL    ( preLHBL             ),
    .preLVBL    ( preLVBL             ),
    .LHBL       ( LHBL                ),
    .LVBL       ( LVBL                ),
    .preLBL     ( preLBL              ),
    .rgb_in     ( pal_rgb             ),
    .rgb_out    ( {red, green, blue } )
);

endmodule