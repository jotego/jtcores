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
    Date: 31-8-2024 */

module jtwwfss_colmix(
    input           clk,
    input           LHBL,
    input           LVBL,

    input    [ 9:1] cpu_addr,
    input    [15:0] cpu_dout,
    output   [15:0] cpu_din,
    input    [ 1:0] pal_wen,

    input    [ 6:0] char_pxl,
    input    [ 6:0] scr_pxl,
    input    [ 6:0] obj_pxl,

    output   [ 3:0] red, green, blue,

    input    [ 3:0] gfx_en
);

reg [ 9:1] pal_addr;

assign {blue,green,red} = LVBL && LHBL ? pal_dout[11:0] : 12'd0;
assign char_blank = !gfx_en[0] || char_pxl[3:0]==0;
assign obj_blank  = !gfx_en[3] ||  obj_pxl[3:0]==0;
assign pal_we     = ~pal_wen;
// assign scr_blank  = gfx_en[1] || char_pxl[3:0]==0;

always @* begin
    casez( {char_blank, obj_blank} )
        2'b0?: pal_addr = { 2'b00, char_pxl };
        2'b10: pal_addr = { 2'b01, obj_pxl  };
        2'b11: pal_addr = { 2'b10, scr_pxl  };
    endcase
end

jtframe_dual_ram16 #(.AW(10)) u_ram(
    // Port 0 - CPU
    .clk0       ( clk       ),
    .data0      ( cpu_dout  ),
    .addr0      ( cpu_addr  ),
    .we0        ( pal_we    ),
    .q0         ( cpu_din   ),
    // Port 1 - color reads
    .clk1       ( clk       ),
    .data1      ( 16'd0     ),
    .addr1      ( pal_addr  ),
    .we1        ( 2'd0      ),
    .q1         ( pal_dout  )
);

endmodule