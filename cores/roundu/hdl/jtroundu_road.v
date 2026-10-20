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
reg signed [31:0] start1, start2;
reg line_valid, line_palette, pixel_bank;
reg [2:0] color_bit;
wire [8:0] next_y = v == 271 ? 9'd0 : v+9'd1;
wire signed [17:0] first_y = 18'sd256 - $signed({10'd0,top}) - $signed({2'd0,yclip});
wire signed [17:0] local_y = $signed({9'd0,next_y}) - first_y;
wire [15:0] shift_sum = shift1+shift2;
wire signed [31:0] numerator1 = -($signed({{16{shift1[15]}},shift1}) * 32'sd256) + 32'sd128;
wire signed [31:0] numerator2 = -($signed({{16{shift_sum[15]}},shift_sum}) * 32'sd256) + 32'sd128;
wire signed [31:0] x = $signed({23'd0,h});
wire signed [31:0] delta1 = x-start1;
wire signed [31:0] delta2 = x-start2;
wire signed [63:0] pos1 = delta1 * $signed({1'b0,step});
wire signed [63:0] pos2 = delta2 * $signed({1'b0,step});
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
                    start1 <= step == 0 ? 32'sd65536 : numerator1 / $signed({16'd0,step});
                    start2 <= step == 0 ? 32'sd65536 : numerator2 / $signed({16'd0,step});
                    fetch <= 0;
                end
                default: ;
            endcase
        end
        if (pxl_cen) begin
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
