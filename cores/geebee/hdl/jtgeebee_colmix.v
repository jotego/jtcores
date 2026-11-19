/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_colmix(
    input            [8:0] h,
    input            [8:0] v,
    input            [1:0] overlay,
    input                  char_pxl,
    input                  char_gate,
    input                  ball_pxl,
    input                  bgw,
    input                  lhbl,
    input                  lvbl,
    output [`JTFRAME_COLORW-1:0] red,
    output [`JTFRAME_COLORW-1:0] green,
    output [`JTFRAME_COLORW-1:0] blue
);

// Sheet 9: 7486 4M mixes BGW with 2A pixels; 3W adds the ball branch.
wire pixel = bgw ^ char_pxl;
wire [8:0] x = v - 9'd16;
wire [8:0] y = 9'd271 - h;
wire [8:0] edge_h = h < 9'd136 ? h : y;
wire [8:0] edge_v = x < 9'd112 ? x : 9'd223 - x;
wire       lower_bumper = x >= 9'd129;
wire [8:0] bumper_row = x - (lower_bumper ? 9'd129 : 9'd58);
wire [8:0] bumper_last = lower_bumper ? 9'd37 : 9'd36;
wire [8:0] bumper_bevel = bumper_row <= 9'd18 ? bumper_row : bumper_last - bumper_row;
wire       bumper = (lower_bumper || x >= 9'd58) && bumper_row <= bumper_last &&
    h >= (lower_bumper ? 9'd178 : 9'd179) && h <= 9'd212 &&
    h + bumper_bevel >= 9'd187 && h <= (lower_bumper ? 9'd202 : 9'd203) + bumper_bevel;
wire [7:0] level = !(lhbl && lvbl) ? 0 :
    ball_pxl || (pixel && char_gate) ? {`JTFRAME_COLORW{1'b1}} :
    pixel ? {1'b0, {(`JTFRAME_COLORW-1){1'b1}}} : 0;
reg [2:0] tint;
reg [23:0] color;

always @* begin
    tint = 0;
    case (overlay)
        2'd1: begin
            if (y >= 9'd8 && y <= 9'd40 && (x <= 9'd32 || x >= 9'd192)) tint = 1;
            if (y >= 9'd8 && y <= 9'd32 && x >= 9'd24 && x <= 9'd200) tint = 2;
            if (y >= 9'd33 && y <= 9'd40 && x >= 9'd33 && x <= 9'd191) tint = 3;
            if (y >= 9'd41 && y <= 9'd223 && (x <= 9'd8 || x >= 9'd216)) tint = 1;
            if (y >= 9'd41 && y <= 9'd223 &&
                ((x >= 9'd9 && x <= 9'd32) || (x >= 9'd192 && x <= 9'd215))) tint = 4;
            if ((y >= 9'd96 && y <= 9'd104 && x >= 9'd104 && x <= 9'd120) ||
                (y >= 9'd168 && y <= 9'd183 &&
                 ((x >= 9'd80 && x <= 9'd95) || (x >= 9'd128 && x <= 9'd143)))) tint = 4;
            if (y >= 9'd224 && y <= 9'd232) tint = 2;
            if (y >= 9'd233 && y <= 9'd255) tint = 1;
        end
        2'd2: begin
            if (edge_h >= 9'd8 && edge_h < 9'd16) tint = 1;
            if (edge_h >= 9'd16 && edge_h < 9'd32) tint = 5;
            if (edge_h >= 9'd32) begin
                if (edge_v < 9'd16) tint = 4;
                else if (edge_v < 9'd32) begin
                    tint = edge_v >= 9'd24 && edge_h <= edge_v + 9'd8 ? 3 : 6;
                end else if (edge_h < 9'd40) tint = 3;
            end
        end
        2'd3: begin
            if (h >= 9'd32 && h < 9'd55 && (x < 9'd32 || x >= 9'd191)) tint = 5;
            if (edge_v < 9'd24 && h >= 9'd55 && h < 9'd240)
                tint = edge_v >= 9'd8 && h >= 9'd72 ? 6 : 4;
            if (edge_v >= 9'd24) begin
                if ((h >= 9'd10 && h < 9'd17) || (h >= 9'd121 && h < 9'd128)) tint = 6;
                if (h >= 9'd231 && h < 9'd240) tint = 7;
                if (h >= 9'd240 && h < 9'd255) tint = 3;
                if (h >= 9'd255 && h < 9'd264) tint = 5;
            end else if (edge_v >= 9'd16 && h < 9'd240 && h + edge_v >= 9'd255) tint = 7;
            if (h >= 9'd164 && h < 9'd179 && x >= 9'd93 && x < 9'd131) tint = 6;
            if (bumper) tint = 7;
        end
        default:;
    endcase
end

always @* begin
    case (tint)
        1: color = 24'ha000e0;
        2: color = 24'he000a0;
        3: color = 24'hffd000;
        4: color = 24'h0055ff;
        5: color = 24'hff2224;
        6: color = 24'h20ff26;
        7: color = 24'hfeff26;
        default: color = 24'hffffff;
    endcase
end

assign {red, green, blue} = level == 8'hff ? color :
    level == 0 ? 24'd0 : {1'b0, color[23:17], 1'b0, color[15:9], 1'b0, color[7:1]};

endmodule
