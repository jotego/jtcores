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
    Date: 1-7-2025 */

module jttoki_obj(
    input                 clk,
    input                 rst,
    input                 pxl_cen,
    input                 cabal,
    input                 hs,

    input           [8:0] hdump,
    input           [8:0] vrender,

    output         [10:1] lut_addr,
    input          [15:0] lut_dout,

    input          [15:0] gfx_data,
    input                 gfx_ok,
    output reg     [19:1] gfx_addr,
    output reg            gfx_cs,

    output          [7:0] pxl
);

localparam [3:0] ST_START          = 4'd0,
                 ST_FETCH_LUT_WORD = 4'd1,
                 ST_START_DECODING = 4'd2,
                 ST_WAIT_DRAW      = 4'd3,
                 ST_NEXT           = 4'd4,
                 ST_FINISHED       = 4'd5;

localparam [1:0] ROM_IDLE   = 2'd0,
                 ROM_FIRST  = 2'd1,
                 ROM_SECOND = 2'd2;

reg  [15:0] lut_words [3:0];
reg  [ 8:0] vrender_l;
reg  [ 7:0] index;
reg  [ 3:0] state = ST_START;
reg  [ 1:0] rom_state = ROM_IDLE;
reg  [ 1:0] lut_addr_index, lut_words_index;
reg         last_group;
reg         lut_read_valid;

reg  [12:0] dr_code;
reg  [ 8:0] dr_xpos;
reg  [ 3:0] dr_ysub;
reg  [ 3:0] dr_pal;
reg         draw;
reg         dr_hflip;

reg  [31:0] dr_rom_data;
reg  [17:0] rom_req_addr;
reg  [15:0] rom_word0;
reg         dr_rom_ok;
reg         rom_req_cabal;

wire [31:0] sorted_data;
wire [19:2] dr_rom_addr;
wire [18:0] first_word_addr;
wire [18:0] second_word_addr;
wire [10:1] fetch_lut_addr, next_lut_addr;
wire [12:0] code;
wire [ 8:0] render_line = vrender - 9'd1;
wire [ 8:0] toki_x_offset;
wire [ 8:0] y_offset, xpos, ypos;
wire [ 8:0] line_delta;
wire [ 7:0] next_index;
wire [ 5:0] hzoom;
wire [ 3:0] pal;
wire        dr_busy;
wire        dr_rom_cs;
wire        hflip, flip, hz_keep, vflip;
wire        enabled, line_hit, x_hits_screen;

assign hzoom           = 6'd0;
assign flip            = 1'b0;
assign hz_keep         = 1'b0;
assign vflip           = 1'b0;
assign toki_x_offset   = {1'b0, lut_words[0][7:4], 4'd0};
assign xpos            = lut_words[2][8:0] + 9'd1 + (cabal ? 9'd0 : toki_x_offset);
assign y_offset        = {1'b0, lut_words[0][3:0], 4'd0};
assign ypos            = cabal ? {1'b0, lut_words[0][7:0]} : lut_words[3][8:0] + y_offset;
assign line_delta      = render_line - ypos;
assign code            = cabal ? {1'b0, lut_words[1][11:0]} : {lut_words[2][15], lut_words[1][11:0]};
assign pal             = cabal ? lut_words[2][14:11] : lut_words[1][15:12];
assign hflip           = cabal ? lut_words[2][10] : lut_words[0][8];
assign enabled         = cabal ? (lut_words[0][8] && lut_words[1][11:0] != 12'd0) :
                                  ((lut_words[2] != 16'hf000) && (lut_words[0] != 16'hffff) &&
                                   (code != 13'd0));
assign line_hit        = render_line >= ypos && render_line <= ypos + 9'd15;
assign x_hits_screen   = xpos < 9'd256 || xpos > 9'd497;
assign first_word_addr = rom_word_addr(rom_req_cabal, rom_req_addr);
assign second_word_addr = first_word_addr + 19'd1;
assign next_index      = index + 8'd1;
assign fetch_lut_addr  = {index, lut_addr_index};
assign next_lut_addr   = {next_index, 2'd0};
assign sorted_data     = {
    {gfx_data[15:12], rom_word0[15:12]},
    {gfx_data[11: 8], rom_word0[11: 8]},
    {gfx_data[ 7: 4], rom_word0[ 7: 4]},
    {gfx_data[ 3: 0], rom_word0[ 3: 0]}
};
assign lut_addr        = state == ST_FETCH_LUT_WORD         ? fetch_lut_addr :
                         state == ST_NEXT && !last_group    ? next_lut_addr  :
                         10'd0;

function [18:0] rom_word_addr;
    input        is_cabal;
    input [17:0] addr;
    reg   [12:0] tile;
    reg          half;
    reg    [3:0] row;
    begin
        tile = addr[17:5];
        half = addr[4];
        row  = addr[3:0];
        if (is_cabal)
            rom_word_addr = {1'b0, tile[11:0], 6'd0} +
                            {13'd0, row, 2'd0} +
                            {17'd0, half, 1'b0};
        else
            rom_word_addr = {tile, 6'd0} +
                            {14'd0, row, 1'b0} +
                            {13'd0, half, 5'd0};
    end
endfunction

always @(posedge clk) begin
    if (rst) begin
        vrender_l        <= 9'd0;
        lut_addr_index   <= 2'b0;
        lut_words_index  <= 2'b0;
        last_group       <= 1'b0;
        lut_read_valid   <= 1'b0;
        index            <= 8'd0;
        draw             <= 1'b0;
        dr_code          <= 13'd0;
        dr_xpos          <= 9'd0;
        dr_ysub          <= 4'd0;
        dr_hflip         <= 1'b0;
        dr_pal           <= 4'd0;
        state            <= ST_START;
    end else begin
        draw <= 1'b0;

        case (state)
            ST_START: begin
                vrender_l        <= vrender;
                index            <= 8'd0;
                lut_addr_index   <= 2'd1;
                lut_words_index  <= 2'd0;
                lut_read_valid   <= 1'b1;
                state            <= ST_FETCH_LUT_WORD;
            end

            ST_FETCH_LUT_WORD: begin
                if (lut_read_valid) begin
                    lut_words[lut_words_index] <= lut_dout;
                    if (lut_words_index == 2'd3) begin
                        lut_read_valid <= 1'b0;
                        last_group     <= index == 8'hff;
                        state          <= ST_START_DECODING;
                    end else begin
                        lut_words_index <= lut_words_index + 2'd1;
                        if (lut_addr_index != 2'd3)
                            lut_addr_index <= lut_addr_index + 2'd1;
                    end
                end
            end

            ST_START_DECODING: begin
                if (enabled && line_hit && x_hits_screen) begin
                    dr_code  <= code;
                    dr_xpos  <= xpos + 9'h8;
                    dr_ysub  <= cabal ? 4'd15 - line_delta[3:0] : line_delta[3:0];
                    dr_hflip <= hflip;
                    dr_pal   <= pal;
                    state    <= ST_WAIT_DRAW;
                end else begin
                    state <= ST_NEXT;
                end
            end

            ST_WAIT_DRAW: begin
                if (!dr_busy) begin
                    draw  <= 1'b1;
                    state <= ST_NEXT;
                end
            end

            ST_NEXT: begin
                if (last_group) begin
                    state <= ST_FINISHED;
                end else begin
                    index           <= next_index;
                    lut_addr_index  <= 2'd1;
                    lut_words_index <= 2'd0;
                    lut_read_valid  <= 1'b1;
                    state           <= ST_FETCH_LUT_WORD;
                end
            end

            ST_FINISHED: begin
                if (vrender_l != vrender) begin
                    state <= ST_START;
                end
                vrender_l <= vrender;
            end

            default: begin
                state <= ST_START;
            end
        endcase
    end
end

always @(posedge clk) begin
    if (rst) begin
        rom_state     <= ROM_IDLE;
        rom_req_addr  <= 18'd0;
        rom_req_cabal <= 1'b0;
        rom_word0     <= 16'd0;
        dr_rom_ok     <= 1'b0;
        dr_rom_data   <= 32'd0;
        gfx_addr      <= 19'd0;
        gfx_cs        <= 1'b0;
    end else begin
        dr_rom_ok <= 1'b0;

        case (rom_state)
            ROM_IDLE: begin
                gfx_cs <= 1'b0;
                if (dr_rom_cs) begin
                    rom_req_addr  <= dr_rom_addr;
                    rom_req_cabal <= cabal;
                    gfx_addr      <= rom_word_addr(cabal, dr_rom_addr);
                    gfx_cs        <= 1'b1;
                    rom_state     <= ROM_FIRST;
                end
            end

            ROM_FIRST: begin
                if (gfx_ok) begin
                    rom_word0 <= gfx_data;
                    gfx_addr  <= second_word_addr;
                    gfx_cs    <= 1'b1;
                    rom_state <= ROM_SECOND;
                end
            end

            ROM_SECOND: begin
                if (gfx_ok) begin
                    dr_rom_data <= sorted_data;
                    dr_rom_ok   <= 1'b1;
                    gfx_cs      <= 1'b0;
                    rom_state   <= ROM_IDLE;
                end
            end

            default: begin
                gfx_cs    <= 1'b0;
                rom_state <= ROM_IDLE;
            end
        endcase
    end
end

jtframe_objdraw #(
    .AW       ( 9    ),
    .CW       ( 13   ),
    .PW       ( 8    ),
    .HJUMP    ( 1    ),
    .HFIX     ( 0    ),
    .LATCH    ( 1    ),
    .KEEP_OLD ( 1    ),
    .ALPHA    ( 8'h0f )
) u_draw(
    .rst      ( rst           ),
    .clk      ( clk           ),
    .pxl_cen  ( pxl_cen       ),
    .hs       ( hs            ),
    .flip     ( flip          ),
    .hdump    ( hdump         ),

    .draw     ( draw          ),
    .busy     ( dr_busy       ),
    .code     ( dr_code       ),
    .xpos     ( dr_xpos       ),
    .ysub     ( dr_ysub       ),
    .hzoom    ( hzoom         ),
    .hz_keep  ( hz_keep       ),
    .hflip    ( dr_hflip      ),
    .vflip    ( vflip         ),
    .pal      ( dr_pal        ),

    .rom_addr ( dr_rom_addr   ),
    .rom_cs   ( dr_rom_cs     ),
    .rom_ok   ( dr_rom_ok     ),
    .rom_data ( dr_rom_data   ),

    .pxl      ( pxl           )
);

endmodule
