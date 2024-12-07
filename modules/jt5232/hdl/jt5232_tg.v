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
    input             en,
    output reg [ 2:0] organ
);

reg  [ 8:0] cnt=0;
wire [ 8:0] nxc;
reg  [ 3:0] pipes=0;
reg  [ 7:0] harmonics=0;
wire        carry;

assign { carry, nxc } = {1'b0,cnt}+{1'b0,step};

always @(posedge clk) if(cen) begin
    cnt <= nxc;
    if(carry) harmonics <= harmonics+8'd1;
    case(bsel)
        0: pipes <= {{3{harmonics[7]}},harmonics[6]};
        1: pipes <= {{2{harmonics[7]}},harmonics[5+:2]};
        2: pipes <= {harmonics[7],harmonics[4+:3]};
        3: pipes <= harmonics[4+:4];
        4: pipes <= harmonics[3+:4];
        5: pipes <= harmonics[2+:4];
        6: pipes <= harmonics[1+:4];
        7: pipes <= harmonics[0+:4];
    endcase
    if(!en) {cnt,pipes,harmonics} <= 0;
    organ <= {2'd0,pipes[0]}+{2'd0,pipes[1]}+{2'd0,pipes[2]}+{2'd0,pipes[3]};
end

endmodule