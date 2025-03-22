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
    Date: 15-3-2025 */

module jtrthunder_colmix(
    input             clk,
    input             pxl_cen, pxl2_cen,

    input      [10:0] scr0_pxl, scr1_pxl,
    input      [ 7:0] backcolor, obj_pxl,
    input      [ 2:0] obj_prio, scr0_prio, scr1_prio,

    output reg [10:0] scrpal_addr,
    input      [ 7:0] scrpal_data,

    output     [ 8:0] rgb_addr,
    input      [ 7:0] rg_data,
    input      [ 3:0] b_data,

    input      [ 3:0] gfx_en,
    output     [ 3:0] red, green, blue
);

localparam [2:0] ALPHA=0,BG_PXL=3'b111, BG_PRIO=3'b0;

reg  [2:0] bg_prio;
reg        scrwin, scr1win;
wire       scr1_op, scr0_op, obj_op;

assign scr1_op = scr1_pxl[2:0]!=ALPHA && gfx_en[1];
assign scr0_op = scr0_pxl[2:0]!=ALPHA && gfx_en[0];
assign obj_op  = ~&obj_pxl[3:0] & gfx_en[3];

always @* begin
    scr1win = scr1_op && scr1_prio > scr0_prio;
    scrwin  = bg_prio > obj_prio || !obj_op;
end

always @(posedge clk) if(pxl2_cen) begin
    { bg_prio, scrpal_addr } <=
        scr1win ? {scr1_prio,scr1_pxl} :
        scr0_op ? {scr0_prio,scr0_pxl} :
                  {BG_PRIO, backcolor,  BG_PXL} ;
end

always @(posedge clk) if(pxl_cen) begin
    rgb_addr[8]   <= scrwin;
    rgb_addr[7:0] <= scrwin ? scrpal_data : obj_pxl;
    {green,red,blue} <= {rg_data,b_data[3:0]};
end

endmodule    