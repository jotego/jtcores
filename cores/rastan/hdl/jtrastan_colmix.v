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
    Date: 2-4-2022 */

module jtrastan_colmix(
    input           rst,
    input           clk,
    input           pxl_cen,

    input    [11:1] main_addr,
    input    [15:0] main_dout,
    output   [15:0] main_din,
    input    [ 1:0] main_dsn,
    input           main_rnw,
    input           pal_cs,        // selection from address decoder

    input           preLHBL,
    input           preLVBL,
    output          LHBL,
    output          LVBL,

    input    [10:0] scr0_pxl,
    input    [10:0] scr1_pxl,
    input    [ 7:0] obj_pxl,
    input    [ 2:0] obj_pal,

    output    [4:0] red,
    output    [4:0] green,
    output    [4:0] blue,

    input     [3:0] gfx_en
);

wire [15:0] pal_dout;
reg  [10:0] pal_addr;
wire        scr1_blank, obj_blank;
wire [ 1:0] cpu_we;

assign scr1_blank = scr1_pxl[3:0]==0 || !gfx_en[0];
assign obj_blank  =  obj_pxl[3:0]==0 || !gfx_en[3];
assign cpu_we     = ~main_dsn & {2{pal_cs & ~main_rnw}};

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pal_addr <= 0;
    end else if(pxl_cen) begin
        if( !obj_blank )
            pal_addr <= { obj_pal, obj_pxl };
        else if( !scr1_blank )
            pal_addr <= scr1_pxl;
        else
            pal_addr <= gfx_en[1] ? scr0_pxl : 11'd0;
    end
end

// The CPU has priority access in the original
// So it could break the output unless it access
// only during blankings.
`ifndef GRAY
jtframe_dual_ram16 #(
    .AW         (           11  ),
    .SIMFILE_LO ( "pal_lo.bin"  ),
    .SIMFILE_HI ( "pal_hi.bin"  )
) u_palram(
    // Port 0: CPU
    .clk0   ( clk       ),
    .data0  ( main_dout ),
    .we0    ( cpu_we    ),
    .addr0  ( main_addr ),
    .q0     ( main_din  ),
    // Port 1
    .clk1   ( clk       ),
    .data1  ( 16'd0     ),
    .addr1  ( pal_addr  ),
    .we1    ( 2'd0      ),
    .q1     ( pal_dout  )
);
`else
assign pal_dout = { 1'b0, {3{ pal_addr[3:0],1'b0 }}};
`endif

jtframe_blank #(
    .DLY( 4),
    .DW (15)
) u_dly(
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),
    .preLHBL    ( preLHBL           ),
    .preLVBL    ( preLVBL           ),
    .LHBL       ( LHBL              ),
    .LVBL       ( LVBL              ),
    .preLBL     (                   ),
    .rgb_in     ( pal_dout[14:0]    ),
    .rgb_out    ( {blue,green,red}  )
);

endmodule