/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 28-02-2025 */

module jtframe_crosshair_draw(
    input            clk,
    input      [8:0] hcnt,
    input      [8:0] vcnt,
    input      [8:0] x,
    input      [8:0] y,
    output reg [1:0] crosshair
);

wire [8:0] x_diff, y_diff;
reg  [5:0] cord;
reg  [1:0] pxl [63:0];
wire [1:0] cross_pre;
reg        inzone;

assign x_diff = hcnt - x;
assign y_diff = vcnt - y;
assign cross_pre = inzone ? pxl[cord] : 2'b0;

always @(posedge clk) begin
    inzone    <= ( ( ~|x_diff[8:3] && ~&x_diff[2:1] )  || ( &x_diff[8:3]  &&  |x_diff[2:1] ) ) &&
                 ( ( ~|y_diff[8:3] && ~&y_diff[2:1] )  || ( &y_diff[8:3]  &&  |y_diff[2:1] ) );
    cord      <=   {  ~y_diff[2],       y_diff[1:0],        ~x_diff[2],        x_diff[1:0] };
    crosshair <= cross_pre;
end

initial pxl ='{
// X    0  1  2  3  4  5  6  7  //  Y
        0, 0, 3, 1, 1, 3, 0, 0, //  0
        0, 0, 3, 1, 1, 3, 0, 0, //  1
        3, 3, 3, 1, 1, 3, 3, 3, //  2
        1, 1, 1, 3, 3, 1, 1, 1, //  3
        1, 1, 1, 3, 3, 1, 1, 1, //  4
        3, 3, 3, 1, 1, 3, 3, 3, //  5
        0, 0, 3, 1, 1, 3, 0, 0, //  6
        0, 0, 3, 1, 1, 3, 0, 0  //  7
};

endmodule
