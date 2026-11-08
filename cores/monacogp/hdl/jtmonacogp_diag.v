// SPDX-License-Identifier: GPL-3.0-or-later
// Development display only. Raw PROM bits do not reproduce sprite wiring.
module jtmonacogp_diag(
    input clk, rst,
    input [8:0] x, y,
    input active, grid,
    input next_n, prev_n,
    input loaded, load_error,
    output reg [4:0] selected,
    output [179:0] prom_addr,
    input [159:0] prom_q,
    output reg [3:0] red, green, blue
);
    reg next_d, prev_d;
    always @(posedge clk) begin
        if (rst) begin
            selected <= 0;
            next_d <= 1;
            prev_d <= 1;
        end else begin
            next_d <= next_n;
            prev_d <= prev_n;
            if (next_d && !next_n) selected <= selected == 19 ? 0 : selected+5'd1;
            else if (prev_d && !prev_n) selected <= selected == 0 ? 19 : selected-5'd1;
        end
    end
    wire [8:0] bx = x - 9'd116, by = y - 9'd64;
    wire in_bitmap = x >= 116 && x < 244 && y >= 64 && y < 192;
    wire [8:0] address = {by[6:1],bx[6:4]};
    assign prom_addr = {20{address}};
    wire [7:0] data = prom_q[selected*8+:8];
    wire bitmap = data[3'd7-bx[3:1]];
    wire address_used = selected < 17 || address < 32;
    wire [8:0] marker_x = x - 9'd20;
    wire [4:0] marker = marker_x[8:4];
    wire [8:0] tx = x - 9'd92;
    wire [8:0] fx = x - 9'd92;
    // 22 characters each; 8-pixel cells, 5x7 ink.
    localparam [22*8-1:0] TITLE = "MONACO GP: DIAGNOSTIC ";
    localparam [22*8-1:0] FOOT = "NO GAME LOGIC OR SOUND";
    reg [7:0] ch;
    reg [2:0] text_col, text_row;
    reg text_area;
    reg [34:0] glyph;
    reg [5:0] glyph_index;
    function [34:0] font;
        input [7:0] c;
        begin
            case(c)
                "A": font=35'b01110_10001_10001_11111_10001_10001_10001;
                "C": font=35'b01111_10000_10000_10000_10000_10000_01111;
                "D": font=35'b11110_10001_10001_10001_10001_10001_11110;
                "E": font=35'b11111_10000_10000_11110_10000_10000_11111;
                "G": font=35'b01111_10000_10000_10111_10001_10001_01111;
                "I": font=35'b11111_00100_00100_00100_00100_00100_11111;
                "L": font=35'b10000_10000_10000_10000_10000_10000_11111;
                "M": font=35'b10001_11011_10101_10101_10001_10001_10001;
                "N": font=35'b10001_11001_11001_10101_10011_10011_10001;
                "O": font=35'b01110_10001_10001_10001_10001_10001_01110;
                "P": font=35'b11110_10001_10001_11110_10000_10000_10000;
                "R": font=35'b11110_10001_10001_11110_10100_10010_10001;
                "S": font=35'b01111_10000_10000_01110_00001_00001_11110;
                "T": font=35'b11111_00100_00100_00100_00100_00100_00100;
                "U": font=35'b10001_10001_10001_10001_10001_10001_01110;
                ":": font=35'b00000_00100_00100_00000_00100_00100_00000;
                default: font=0;
            endcase
        end
    endfunction
    always @* begin
        ch=0; text_col=0; text_row=0; text_area=0;
        if (x>=92 && x<268 && y>=8 && y<15) begin
            ch=TITLE[(21-tx[8:3])*8+:8];
            text_col=tx[2:0]; text_row=y[2:0]; text_area=1;
        end else if (x>=92 && x<268 && y>=208 && y<215) begin
            ch=FOOT[(21-fx[8:3])*8+:8];
            text_col=fx[2:0]; text_row=y[2:0]; text_area=1;
        end
        glyph_index=6'd34 - {3'b0,text_row}*6'd5 - {3'b0,text_col};
        glyph=font(ch);
        red=0; green=0; blue=0;
        if (active) begin
            blue=1;
            if (grid) begin
                red={4{x[7]}}; green={4{x[6]}}; blue={4{x[5]}};
                if (x[4:0]==0 || y[4:0]==0 || x==359 || y==239) begin
                    red=15; green=15; blue=15;
                end
            end else begin
                if (y>=36 && y<44 && x>=20 && x<340 && marker_x[3:0]<14) begin
                    red=marker==selected ? 15 : 2;
                    green=marker==selected ? 12 : 3;
                    blue=marker==selected ? 2 : 5;
                end
                if (in_bitmap) begin
                    if (loaded && address_used) begin
                        red={4{bitmap}}; green={4{bitmap}}; blue={4{bitmap}};
                    end else begin
                        red=loaded ? 2 : 5;
                        green=0; blue=loaded ? 2 : 0;
                    end
                end
                if (text_area && text_col<5 && glyph[glyph_index]) begin
                    red=12; green=13; blue=15;
                end
            end
            // Completion indicator remains visible on either diagnostic page.
            if (y>=228 && y<232 && x>=20 && x<340) begin
                red=loaded ? 0 : 12;
                green=loaded ? 12 : 0;
                blue=load_error ? 12 : 0;
            end
        end
    end
endmodule
