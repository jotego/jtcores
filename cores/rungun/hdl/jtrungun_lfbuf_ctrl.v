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
    output            ln_done,
    input             ln_hs,
    input      [ 7:0] ln_v,
    output            ln_we,

    input             scr_ok, obj_ok, fix_ok,
                      hflip, vflip,
    // virtual screen
    output            cen,
    output reg        hs,
    output reg [ 8:0] hdump,
    output     [ 8:0] hdumpf,
    output     [ 7:0] vdump, vdumpf
);

reg [10:0] nx_hdump;
reg        lnhs_l;

assign vdump    = ln_v;
assign nx_hdump = {1'b0,hdump}+10'd1;
assign cen      = &{fix_ok,scr_ok,obj_ok};
assign ln_we    = ~ln_done;
assign ln_addr  = hdump;
assign hs_edge  = ln_hs & ~lnhs_l;
assign hdumpf = {9{hflip}}^hdump,
       vdumpf = {8{vflip}}^vdump;

always @(posedge clk) begin
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