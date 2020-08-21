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
    input [8:0]      scr1_pxl,
    input [7:0]      scr2_pxl,
    input [7:0]      obj_pxl,
    input            LVBL,
    input            LHBL,
    output           LHBL_dly,
    output           LVBL_dly,
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

// Address mux
reg  [ 9:0] pal_addr;
reg         pal_uwe, pal_lwe;
wire [ 3:0] pal_red, pal_green, pal_blue;
wire [11:0] pal_rgb;

wire enable_char = gfx_en[0];
wire enable_scr1 = gfx_en[1];
wire enable_scr2 = gfx_en[2];
wire enable_obj  = gfx_en[3];
wire obj_blank  = &obj_pxl[3:0];
wire char_blank = &char_pxl[1:0];
wire scr1_blank = &scr1_pxl[3:0];
wire preLBL;

`ifndef GRAY
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
`else
assign prio=SCR2;
`endif

always @(posedge clk) if(pxl_cen) begin
    pixel_mux[9:8] <= prio;
    case( prio )
        CHAR: pixel_mux[7:0] <= { 2'b0, char_pxl };
        OBJ:  pixel_mux[7:0] <= obj_pxl; // 2301
        SCR1: pixel_mux[7:0] <= scr1_pxl[7:0];
        SCR2: pixel_mux[7:0] <= enable_scr2 ? scr2_pxl[7:0] : 8'h00;
    endcase
end

assign pal_rgb = {pal_red, pal_green, pal_blue};

always @(*) begin
    if( !preLBL ) begin
        pal_addr = AB;
        pal_uwe   = col_uw;
        pal_lwe   = col_lw;
    end else begin
        pal_addr = pixel_mux;
        pal_uwe  = 1'b0;
        pal_lwe  = 1'b0;
    end
end

// Palette is in RAM
`ifdef GRAY
assign pal_red   = pal_addr[3:0];
assign pal_green = pal_addr[3:0];
assign pal_blue  = pal_addr[3:0];
`else
jtframe_ram #(.aw(10),.dw(4),.simhexfile("palr.hex")) u_upal(
    .clk        ( clk         ),
    .cen        ( cpu_cen     ), // clock enable only applies to write operation
    .data       ( DB[11:8]    ),
    .addr       ( pal_addr    ),
    .we         ( pal_uwe     ),
    .q          ( pal_red     )
);

jtframe_ram #(.aw(10),.dw(8),.simhexfile("palgb.hex")) u_lpal(
    .clk        ( clk         ),
    .cen        ( cpu_cen     ), // clock enable only applies to write operation
    .data       ( DB[7:0]     ),
    .addr       ( pal_addr    ),
    .we         ( pal_lwe     ),
    .q          ( { pal_green, pal_blue } )
);
`endif

jtframe_blank #(.DLY(BLANK_DLY),.DW(12)) u_dly(
    .clk        ( clk                 ),
    .pxl_cen    ( pxl_cen             ),
    .LHBL       ( LHBL                ),
    .LVBL       ( LVBL                ),
    .LHBL_dly   ( LHBL_dly            ),
    .LVBL_dly   ( LVBL_dly            ),
    .preLBL     ( preLBL              ),
    .rgb_in     ( pal_rgb             ),
    .rgb_out    ( {red, green, blue } )
);

endmodule