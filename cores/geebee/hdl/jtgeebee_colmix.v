/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 06-11-2026 */

module jtgeebee_colmix(
    input            [8:0] h,
    input            [8:0] v,
    input                  overlay,
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
wire [7:0] level = !(lhbl && lvbl) ? 0 :
    ball_pxl || (pixel && char_gate) ? {`JTFRAME_COLORW{1'b1}} :
    pixel ? {1'b0, {(`JTFRAME_COLORW-1){1'b1}}} : 0;
reg [2:0] tint;
reg [7:0] r, g, b;

always @* begin
    tint = 0;
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

always @* begin
    r = level;
    g = level;
    b = level;
    if (overlay && level != 0) begin
        case (tint)
            1: begin
                r = level == 8'hff ? 8'd160 : 8'd80;
                g = 0;
                b = level == 8'hff ? 8'd224 : 8'd112;
            end
            2: begin
                r = level == 8'hff ? 8'd224 : 8'd112;
                g = 0;
                b = level == 8'hff ? 8'd160 : 8'd80;
            end
            3: begin
                r = level;
                g = level == 8'hff ? 8'd208 : 8'd104;
                b = 0;
            end
            4: begin
                r = 0;
                g = level == 8'hff ? 8'd85 : 8'd42;
                b = level;
            end
            default:;
        endcase
    end
end

assign red   = r;
assign green = g;
assign blue  = b;

endmodule
