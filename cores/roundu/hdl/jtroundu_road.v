/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-10-2026 */

module jtroundu_road(
    input             rst,
    input             clk,
    input             pxl_cen,
    input       [8:0] h,
    input       [8:0] v,
    input             enable,
    input       [7:0] top,
    input      [15:0] yclip,
    input             bank,
    output reg [11:1] ctrl_addr,
    input      [15:0] ctrl_data,
    output reg [11:1] pixel_addr,
    input      [15:0] pixel_data,
    output reg [11:1] color_addr,
    input      [15:0] color_data,
    output reg  [8:0] pxl,
    output reg        solid
);

reg [3:0] fetch;
reg [2:0] phase;
reg [15:0] shift1, step, shift2;
reg signed [24:0] start1, start2;
reg signed [26:0] pos1, pos2, origin1, origin2;
reg signed [24:0] div_num1, div_num2;
reg [23:0] div_q1, div_q2;
reg [16:0] div_rem1, div_rem2;
reg [4:0] div_count;
reg div_finish;
reg line_valid, line_palette, pixel_bank;
reg [2:0] color_bit;
wire [8:0] next_y = v == 271 ? 9'd0 : v+9'd1;
wire signed [17:0] first_y = 18'sd256 - $signed({10'd0,top}) - $signed({2'd0,yclip});
wire signed [17:0] local_y = $signed({9'd0,next_y}) - first_y;
wire [15:0] shift_sum = shift1+shift2;
wire signed [24:0] numerator1 = -$signed({shift1[15],shift1,8'd0}) + 25'sd128;
wire signed [24:0] numerator2 = -$signed({shift_sum[15],shift_sum,8'd0}) + 25'sd128;
wire [24:0] magnitude1 = numerator1 < 0 ? -numerator1 : numerator1;
wire [24:0] magnitude2 = numerator2 < 0 ? -numerator2 : numerator2;
wire signed [24:0] x = $signed({16'd0,h});
wire [16:0] div_trial1 = {div_rem1[15:0],div_q1[23]};
wire [16:0] div_trial2 = {div_rem2[15:0],div_q2[23]};
wire [17:0] div_diff1 = {1'b0,div_trial1} - {2'b0,step};
wire [17:0] div_diff2 = {1'b0,div_trial2} - {2'b0,step};
wire div_take1 = !div_diff1[17];
wire div_take2 = !div_diff2[17];
wire [16:0] div_next_rem1 = div_take1 ? div_diff1[16:0] : div_trial1;
wire [16:0] div_next_rem2 = div_take2 ? div_diff2[16:0] : div_trial2;
wire [23:0] div_next_q1 = {div_q1[22:0],div_take1};
wire [23:0] div_next_q2 = {div_q2[22:0],div_take2};
reg [10:0] next_pixel;
reg next_bank;

always @* begin
    next_pixel = 11'h080;
    next_bank = 1;
    if (pos1 >= 0 && pos1 < 262144) begin
        next_pixel = {4'd0,pos1[17:11]};
        next_bank = 0;
    end else if (pos2 >= 0 && pos2 < 262144) begin
        next_pixel = {4'b0100,pos2[17:11]};
    end else if (x < start1 && x < start2) begin
        next_pixel = start2 < start1 ? 11'h200 : 11'h000;
        next_bank = start2 < start1;
    end else if (x >= start1 && x >= start2) begin
        next_pixel = start2 < start1 ? 11'h07f : 11'h27f;
        next_bank = !(start2 < start1);
    end
end

always @(posedge clk) begin
    if (rst) begin
        fetch <= 0;
        phase <= 0;
        ctrl_addr <= 0;
        pixel_addr <= 0;
        color_addr <= 0;
        shift1 <= 0;
        shift2 <= 0;
        step <= 0;
        start1 <= 65536;
        start2 <= 65536;
        pos1 <= 0;
        pos2 <= 0;
        origin1 <= 0;
        origin2 <= 0;
        div_count <= 0;
        div_finish <= 0;
        div_num1 <= 0;
        div_num2 <= 0;
        div_q1 <= 0;
        div_q2 <= 0;
        div_rem1 <= 0;
        div_rem2 <= 0;
        line_valid <= 0;
        line_palette <= 0;
        color_bit <= 0;
        pixel_bank <= 0;
        pxl <= 0;
        solid <= 0;
    end else begin
        if (pxl_cen && h == 320) begin
            fetch <= 1;
            ctrl_addr <= {bank,next_y[7:0],2'd0};
            color_addr <= {11{local_y >= 0}} & local_y[13:3];
            color_bit <= local_y[2:0];
            line_valid <= enable && local_y >= 0 && next_y < 240;
        end else if (fetch != 0) begin
            fetch <= fetch+1'd1;
            case (fetch)
                2: begin
                    shift1 <= ctrl_data;
                    ctrl_addr <= ctrl_addr+1'd1;
                    line_palette <= color_data[{1'b0,color_bit}];
                end
                4: begin
                    step <= {ctrl_data[7:0],ctrl_data[15:8]};
                    ctrl_addr <= ctrl_addr+1'd1;
                end
                6: shift2 <= ctrl_data;
                7: begin
                    if (step == 0) begin
                        start1 <= 25'sd65536;
                        start2 <= 25'sd65536;
                        origin1 <= 0;
                        origin2 <= 0;
                        div_count <= 0;
                    end else begin
                        div_num1 <= numerator1;
                        div_num2 <= numerator2;
                        div_q1 <= magnitude1[23:0];
                        div_q2 <= magnitude2[23:0];
                        div_rem1 <= 0;
                        div_rem2 <= 0;
                        div_count <= 24;
                    end
                    fetch <= 0;
                end
                default: ;
            endcase
        end
        if (div_count != 0) begin
            div_q1 <= div_next_q1;
            div_q2 <= div_next_q2;
            div_rem1 <= div_next_rem1;
            div_rem2 <= div_next_rem2;
            div_count <= div_count-1'd1;
            if (div_count == 1) div_finish <= 1;
        end
        if (div_finish) begin
            div_finish <= 0;
            start1 <= div_num1 < 0 ? -$signed({1'b0,div_q1}) : $signed({1'b0,div_q1});
            start2 <= div_num2 < 0 ? -$signed({1'b0,div_q2}) : $signed({1'b0,div_q2});
            origin1 <= (div_num1 < 0 ? -$signed({10'd0,div_rem1}) : $signed({10'd0,div_rem1})) - $signed({{2{div_num1[24]}},div_num1});
            origin2 <= (div_num2 < 0 ? -$signed({10'd0,div_rem2}) : $signed({10'd0,div_rem2})) - $signed({{2{div_num2[24]}},div_num2});
        end
        if (pxl_cen) begin
            if (h == 399) begin
                pos1 <= origin1;
                pos2 <= origin2;
            end else begin
                pos1 <= pos1 + $signed({11'd0,step});
                pos2 <= pos2 + $signed({11'd0,step});
            end
            pixel_addr <= next_pixel;
            pixel_bank <= next_bank;
            solid <= line_valid;
            phase <= 1;
        end else if (phase != 0) begin
            phase <= phase+1'd1;
            if (phase == 2) begin
                pxl <= 9'd320 + {3'd0,pixel_bank,line_palette,4'd0} + {5'd0,pixel_data[3:0]};
                phase <= 0;
            end
        end
    end
end

endmodule
