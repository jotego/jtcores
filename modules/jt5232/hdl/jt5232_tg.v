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
    Date: 6-12-2024 */

// the ' means feet in an organ pipe length
// output  2' = 4*f
// output  4' = 2*f
// output  8' is the base pitch = f
// output 16' = f/2

module jt5232_tg(
    input             rst,
    input             clk,
    input             cen,
    input      [ 8:0] step,
    input      [ 2:0] bsel, // bit selection
    input      [ 3:0] pipe_en,
    output reg [ 2:0] organ
);

reg  [ 8:0] cnt=0;
wire [ 8:0] nxc;
reg  [ 3:0] pipes=0;
reg  [ 7:0] h=0;    // harmonics
wire [ 7:0] hnx;
reg         hl;
wire        over, over2;

assign over  = cnt==step;
assign over2 = cnt==(step>>1);
assign hnx   = h+8'd1;

always @(posedge clk) if(cen) begin
    cnt <= over ? 9'd0 : cnt+9'd1;
    // counts twice, at the middle and at the end
    if(over2 && !hl) begin hl<=1; h <= hnx; end
    if(over        ) begin hl<=0; h <= hnx; end
    case(bsel)
        1: pipes <= {h[0],h[0],h[0],h[1]};
        2: pipes <= {h[0],h[0],h[1],h[2]};
        3: pipes <= {h[0],h[1],h[2],h[3]};
        4: pipes <= {h[1],h[2],h[3],h[4]};
        5: pipes <= {h[2],h[3],h[4],h[5]};
        6: pipes <= {h[3],h[4],h[5],h[6]};
        7: pipes <= {h[4],h[5],h[6],h[7]};
    endcase
    if(!pipe_en[0]) pipes[0] <= 0;
    if(!pipe_en[1]) pipes[1] <= 0;
    if(!pipe_en[2]) pipes[2] <= 0;
    if(!pipe_en[3]) pipes[3] <= 0;
    organ <= {2'd0,pipes[0]}+{2'd0,pipes[1]}+{2'd0,pipes[2]}+{2'd0,pipes[3]};
end

endmodule