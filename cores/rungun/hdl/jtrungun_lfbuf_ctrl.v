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
    Date: 13-8-2025 */

module jtrungun_lfbuf_ctrl(
    input             clk,
    output     [ 8:0] ln_addr,
    output reg        ln_done,
    input             ln_hs,
    input      [ 7:0] ln_v,
    output            ln_we,

    input             scr_cs, obj_cs, fix_cs,
                      scr_ok, obj_ok, fix_ok,
                      hflip, vflip,
    // virtual screen
    output reg        cen,
    output reg        hs,
    output reg [ 8:0] hdump,
    output     [ 8:0] hdumpf,
    output     [ 7:0] vdump, vdumpf
);

wire [9:0] nx_hdump;
reg        lnhs_l;
reg  [1:0] cencnt;
wire       hs_edge;

assign vdump    = ln_v;
assign nx_hdump = {1'b0,hdump}+10'd1;
assign ln_we    = ~ln_done & cen;
assign ln_addr  = hdump;
assign hs_edge  = ln_hs & ~lnhs_l;
assign hdumpf = {9{hflip}}^hdump,
       vdumpf = {8{vflip}}^vdump;

always @(posedge clk) begin
    cencnt <= cencnt==2 ? 2'd0 : cencnt+1'd1;
    cen <= &{fix_ok|~fix_cs,scr_ok|~scr_cs,obj_ok|~obj_cs,~ln_done,cencnt==0};
    lnhs_l <= ln_hs;
    if(cen && !ln_done) begin
        hs <= 0;
        {ln_done,hdump} <= nx_hdump;
    end
    if( hs_edge ) begin
        hs      <= 1;
        hdump   <= 0;
        ln_done <= 0;
    end
end

endmodule