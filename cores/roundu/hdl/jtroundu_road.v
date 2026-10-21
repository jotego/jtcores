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

reg  [3:0] fetch;
reg  [2:0] phase;
reg [15:0] shift1, step, shift2;
// strip accumulators in x.11 fixed point: texel index = pos[17:11], in-strip while 0 <= pos < 'h40000
reg signed [26:0] pos1, pos2;
reg        line_valid, line_palette, pixel_bank, set2_left, overlap, strip2_en;
reg  [2:0] color_bit;
reg [10:0] pixel2;
reg  [3:0] col1;
wire [8:0] next_y = v == 271 ? 9'd0 : v+9'd1;
wire signed [17:0] first_y = 18'sd256 - $signed({10'd0,top}) - $signed({2'd0,yclip});
wire signed [17:0] local_y = $signed({9'd0,next_y}) - first_y;
wire [15:0] shift_sum = shift1+shift2;
wire in1    = pos1[26:18]==0;
wire in2    = pos2[26:18]==0 && strip2_en;
wire left1  = pos1[26];
wire left2  = pos2[26] || !strip2_en;
wire right1 = !pos1[26] && pos1[25:18]!=0;
wire right2 = (!pos2[26] && pos2[25:18]!=0) || !strip2_en;
wire s2l    = set2_left && strip2_en;
wire [3:0] col2 = pixel_data[3:0];
reg [10:0] next_pixel;
reg next_bank;

always @* begin
    next_pixel = 11'h080;
    next_bank = 1;
    if (in1) begin
        next_pixel = {4'd0,pos1[17:11]};
        next_bank = 0;
    end else if (in2) begin
        next_pixel = {4'b0100,pos2[17:11]};
    end else if (left1 && left2) begin
        next_pixel = s2l ? 11'h200 : 11'h000;
        next_bank = s2l;
    end else if (right1 && right2) begin
        next_pixel = s2l ? 11'h07f : 11'h27f;
        next_bank = !s2l && strip2_en;
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
        pos1 <= 0;
        pos2 <= 0;
        line_valid <= 0;
        line_palette <= 0;
        color_bit <= 0;
        pixel_bank <= 0;
        set2_left <= 0;
        strip2_en <= 0;
        overlap <= 0;
        pixel2 <= 0;
        col1 <= 0;
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
                6: begin
                    shift2 <= ctrl_data;
                    ctrl_addr <= ctrl_addr+1'd1;
                end
                8: begin
                    strip2_en <= ctrl_data[15];
                    fetch <= 0;
                end
                default: ;
            endcase
        end
        if (pxl_cen) begin
            if (h == 399) begin
                pos1 <= {{3{shift1[15]}},shift1,8'd0};
                pos2 <= {{3{shift_sum[15]}},shift_sum,8'd0};
                set2_left <= $signed(shift_sum) > $signed(shift1);
            end else begin
                pos1 <= pos1 + $signed({11'd0,step});
                pos2 <= pos2 + $signed({11'd0,step});
            end
            pixel_addr <= next_pixel;
            pixel_bank <= next_bank;
            pixel2 <= {4'b0100,pos2[17:11]};
            overlap <= in1 && in2;
            solid <= line_valid;
            phase <= 1;
        end else if (phase != 0) begin
            phase <= phase+1'd1;
            if (phase == 2) begin
                if (overlap) begin
                    col1 <= pixel_data[3:0];
                    pixel_addr <= pixel2;
                end else begin
                    pxl <= 9'd320 + {3'd0,pixel_bank,line_palette,4'd0} + {5'd0,pixel_data[3:0]};
                    phase <= 0;
                end
            end else if (phase == 4) begin
                pxl <= col2 > col1 ?
                    9'd320 + {3'd0,1'b1,line_palette,4'd0} + {5'd0,col2} :
                    9'd320 + {3'd0,1'b0,line_palette,4'd0} + {5'd0,col1};
                phase <= 0;
            end
        end
    end
end

endmodule
