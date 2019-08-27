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
    Date: 18-2-2019 */

// 1943 Character Generation
module jtgng_charmsg(
    input            clk,
    input            cen6,  /* synthesis direct_enable = 1 */

    input      [3:0] avatar_idx,
    input      [9:0] scan,
    output reg [7:0] msg_low,
    output     [7:0] msg_high
);

wire [7:0] mem_msg, mem_msg_av;

jtgng_ram #(.aw(10),.synfile("msg.hex"),.simfile("msg.bin")) u_char_msg(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( 8'd0        ),
    .addr   ( scan        ),
    .we     ( 1'b0        ),
    .q      ( mem_msg     )
);

`ifdef AVATARS
wire [8:0] av_scan = { avatar_idx, scan[9:5] };

jtgng_ram #(.aw(9),.synfile("msg_av.hex")) u_ram_msg_av(
    .clk    ( clk         ),
    .cen    ( cen6        ),
    .data   ( 8'd0        ),
    .addr   ( av_scan     ),
    .we     ( 1'b0        ),
    .q      ( mem_msg_av  )
);

reg av_col;

always @(*) begin
    av_col  = scan[4:0] == 5'd9;
    msg_low = av_col ? mem_msg_av : mem_msg;
end
`else 
always @(*) msg_low = mem_msg;
`endif

assign msg_high = 8'h2;

endmodule