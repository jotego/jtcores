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

module jt5232_acc(
    input             clk,
    input             cen,
    input  [12*8-1:0] eg,
    input  [ 3*8-1:0] organ,
    output [    14:0] snd1, snd2,
    output reg        clip
);

integer i;
reg [14:0] mul[0:7];
reg [15:0] acc0,acc1,acc2,acc3;
reg [16:0] acc4,acc5;

function [14:0] clipsnd(input [16:0] s);
    clipsnd = s[16:15]!=0 ? ~15'h0 : s[14:0];
endfunction

assign snd1=clipsnd(acc4);
assign snd2=clipsnd(acc5);

always @(posedge clk) begin
    clip <= |{acc4[16:14],acc5[16:14]}; // these are expected to always be zero
    for(i=0;i<8;i=i+1) mul[i]<=eg[12*i+:12]*organ[3*i+:3];
    acc0 <= {1'b0,mul[0]}+{1'b0,mul[1]};
    acc1 <= {1'b0,mul[2]}+{1'b0,mul[3]};
    acc2 <= {1'b0,mul[4]}+{1'b0,mul[5]};
    acc3 <= {1'b0,mul[7]}+{1'b0,mul[7]};
    if(cen) begin
        acc4 <= {1'b0,acc0}+{1'b0,acc1};
        acc5 <= {1'b0,acc2}+{1'b0,acc3};
    end
end

endmodule