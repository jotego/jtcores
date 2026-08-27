/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-02-2025 */

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
