/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
module jtapach3_objbounds(
    input                    rst,
    input                    clk,
    input                    start,
    input       signed [31:0] origin_x,
    input       signed [31:0] origin_y,
    input       signed [9:0] slope,
    input             [24:0] shrink,
    input                    flip_x,
    input                    flip_y,
    input             [31:0] top,
    input             [31:0] bottom,
    input             [31:0] width,
    output reg               done,
    output reg               reject,
    output reg        [31:0] extent
);
reg [2:0] state;
reg [1:0] corner;
reg signed [33:0] dx, dy, mx, my;
reg signed [43:0] tx, ty;
reg signed [59:0] sx, sy;
reg signed [31:0] max_x, min_y, max_y;
reg signed [33:0] cx, cy;
reg signed [31:0] px, py;
always @(posedge clk) begin
    done <= 0;
    if (rst) begin
        state <= 0;
        corner <= 0;
        reject <= 0;
        extent <= 0;
    end else case (state)
        0: if (start) begin
            corner <= 0;
            max_x <= -32'sh7fffffff;
            min_y <= 32'sh7fffffff;
            max_y <= -32'sh7fffffff;
            state <= 1;
        end
        1: begin
            cx=(corner[0] ? 34'sd320 : 34'sd0)-$signed({{2{origin_x[31]}},origin_x});
            cy=(corner[1] ? 34'sd240 : 34'sd0)-$signed({{2{origin_y[31]}},origin_y});
            dx <= cx <<< 16;
            dy <= cy <<< 16;
            state <= 2;
        end
        2: begin
            tx <= slope*dy;
            ty <= slope*dx;
            state <= 3;
        end
        3: begin
            mx <= dx+$signed(tx[41:8]);
            my <= dy-$signed(ty[41:8]);
            state <= 4;
        end
        4: begin
            sx <= mx*$signed({1'b0,shrink});
            sy <= my*$signed({1'b0,shrink});
            state <= 5;
        end
        5: begin
            px={{12{sx[59]}},sx[59:40]};
            py={{12{sy[59]}},sy[59:40]};
            if (flip_x) px=-px-1;
            if (flip_y) py=-py-1;
            if (px>max_x) max_x <= px;
            if (py<min_y) min_y <= py;
            if (py>max_y) max_y <= py;
            corner <= corner+1'b1;
            state <= &corner ? 3'd6 : 3'd1;
        end
        6: begin
            reject <= max_x<0 || max_y<$signed(top) || min_y>=$signed(bottom);
            extent <= $signed(width)>max_x+2 ? width : max_x+32'd2;
            done <= 1;
            state <= 0;
        end
        default: state <= 0;
    endcase
end
endmodule
