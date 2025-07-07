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
    Date: 18-5-2025 */

module jtpaclan_colmix(
    input             clk,
    input             pxl_cen, pxl2_cen, fixed,
    input      [ 1:0] palbank,

    input      [ 9:0] scr0_pxl, scr1_pxl,
    input      [ 7:0] obj_pxl,
    input             scr0_prio,

    output     [ 9:0] scr0pal_addr, scr1pal_addr,
    input      [ 7:0] scr0pal_data, scr1pal_data,

    output reg [ 9:0] rgb_addr,
    input      [ 7:0] rg_data,
    input      [ 3:0] b_data,

    input      [ 3:0] gfx_en,
    output reg [ 3:0] red, green, blue
);

// background (scr1)
// sprites 00~7F
// foreground low prio (scr0)
// sprites, all but 7F (lantern), FF (no sprite)
// foreground high prio (scr0)
// sprites F0~FE

localparam [6:0] ALPHA=7'h7f;

reg  [7:0] scr_pal, cus29;
reg        scrwin, scr1win;
wire       scr0_op, obj0_op, obj1_op, obj2_op, obj3_op;

assign scr0pal_addr = scr0_pxl;
assign scr1pal_addr = scr1_pxl;

assign scr0_op = scr0pal_data[6:0]!=ALPHA && gfx_en[0]; // foreground
assign obj0_op = obj_pxl<8'h80;
assign obj1_op = obj_pxl[6:0]!=ALPHA;
assign obj2_op = obj_pxl>=8'hf0 && obj_pxl!=8'hff;
assign obj3_op = obj0_op & ~obj1_op;

always @(posedge clk) begin
    scr_pal <= (scr1win ? scr1pal_data : scr0pal_data);
end

always @* begin
    scrwin  = obj_pxl[7] ? 0 : scr0_prio;
    cus29   = scrwin ? scr0pal_data : obj_pxl;
    scr1win =&cus29[6:0];
    // scr1win = ~scr0_op && gfx_en[1];
    // scrwin = 1;
    // if(gfx_en[3]) begin
    //     if(obj0_op && scr1win) scrwin=0;
    //     if(obj1_op && (scr1win || !scr0_prio)) scrwin = 0;
    //     if(obj2_op) scrwin = 0;
    //     if(obj3_op) {scr1win,scrwin} = {scr0_op,1'b1};
    // end
end

always @(posedge clk) if(pxl_cen) begin
    rgb_addr[9:8] <= palbank;
    rgb_addr[7:0] <= scr1win ? scr1pal_data : cus29;
    {green,red,blue} <= {rg_data,b_data[3:0]};
end

endmodule    