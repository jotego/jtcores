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
    Date: 3-9-2022 */

module jtkchamp_colmix(
    input              clk,
    input              pxl_cen,
    input              LVBL,
    input              LHBL,

    input        [5:0] obj_pxl,
    input        [6:0] char_pxl,

    input        [9:0] prog_addr,
    input        [3:0] prog_data,
    input              prog_en,

    output reg   [3:0] red,
    output reg   [3:0] green,
    output reg   [3:0] blue,
    input        [3:0] gfx_en,
    input        [7:0] debug_bus
);

wire [9:0] pal_addr;
wire [3:0] pal_dout;
reg  [1:0] cnt;
reg  [3:0] pr,pg,pb;
reg  [7:0] mux;
wire       mux_sel;

assign mux_sel  = obj_pxl[1:0]==0;
assign pal_addr = { cnt, mux };

always @(posedge clk) begin
    if( pxl_cen ) begin
        cnt <= 0;
        { red, green, blue } <= (LVBL && LHBL) ? {pr,pg,pb} : 12'd0;
        mux <= { mux_sel, mux_sel ? char_pxl : {1'b0, obj_pxl} };
    end else begin
        cnt <= cnt+1;
        if(cnt==1) pr <= pal_dout;
        if(cnt==2) pg <= pal_dout;
        if(cnt==3) pb <= pal_dout;
    end
end

jtframe_prom #(.DW(4)) u_prom (
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .wr_addr( prog_addr ),
    .we     ( prog_en   ),

    .rd_addr( pal_addr  ),
    .q      ( pal_dout  )
);


endmodule