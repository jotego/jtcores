/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-4-2026 */

module jtcps3_scr_draw(
    input               rst,
    input               clk,

    input               seg_valid,
    input       [ 9:0]  seg_screen_x,
    input       [ 4:0]  seg_left,
    input       [ 3:0]  seg_xoff,
    input       [ 8:0]  seg_pal,
    input               seg_tile_hflip,
    input               seg_alpha,
    input               seg_bpp,
    input       [31:0]  seg_row_data0,
    input       [31:0]  seg_row_data1,
    input       [31:0]  seg_row_data2,
    input       [31:0]  seg_row_data3,

    output              seg_take,
    output              active,

    input       [16:0]  buf_dout,
    output reg          wr_en,
    output reg  [ 9:0]  wr_addr,
    output reg  [16:0]  wr_pxl
);

localparam DST_IDLE       = 2'd0,
           DST_DRAW       = 2'd1,
           DST_BLEND_WAIT = 2'd2,
           DST_BLEND_WR   = 2'd3;

reg  [ 1:0] draw_st;
reg  [ 9:0] draw_screen_x;
reg  [ 4:0] draw_seg_left, draw_seg_pos;
reg  [ 3:0] draw_seg_xoff;
reg  [ 8:0] draw_pal;
reg         draw_tile_hflip, draw_alpha, draw_bpp, draw_blend_6bpp;
reg  [ 7:0] draw_blend_pxl;
reg  [31:0] draw_row_data0, draw_row_data1, draw_row_data2, draw_row_data3;

wire [ 4:0] draw_pixel_idx;
wire [ 4:0] draw_pixel_in_tile_rev;
wire [ 3:0] draw_pixel_in_tile;
wire [ 7:0] raw_pxl;
wire        is_opaque;
wire [16:0] norm_pxl;
wire [16:0] blended;

assign seg_take = seg_valid && draw_st == DST_IDLE;
assign active   = draw_st != DST_IDLE;

assign draw_pixel_idx         = draw_seg_xoff + draw_seg_pos;
assign draw_pixel_in_tile_rev = 5'd15 - draw_pixel_idx;
assign draw_pixel_in_tile     = draw_tile_hflip ? draw_pixel_in_tile_rev[3:0] :
                                                  draw_pixel_idx[3:0];
assign is_opaque              = raw_pxl != 8'd0;
assign norm_pxl               = draw_bpp ? { 2'd0, draw_pal, raw_pxl[5:0] } :
                                             { draw_pal, raw_pxl };
assign blended = draw_blend_6bpp ?
    (buf_dout | { 1'b0, draw_blend_pxl[3:0], 12'd0 }) :
    (buf_dout | { draw_pal[0], draw_blend_pxl[0], 15'd0 });

jtcps3_pixel u_pixel(
    .w0         ( draw_row_data0     ),
    .w1         ( draw_row_data1     ),
    .w2         ( draw_row_data2     ),
    .w3         ( draw_row_data3     ),
    .px         ( draw_pixel_in_tile ),
    .pxl        ( raw_pxl            )
);

always @(posedge clk) begin
    if( rst ) begin
        draw_st         <= DST_IDLE;
        wr_en           <= 1'b0;
        wr_addr         <= 10'd0;
        wr_pxl          <= 17'd0;
        draw_screen_x   <= 10'd0;
        draw_seg_left   <= 5'd0;
        draw_seg_pos    <= 5'd0;
        draw_seg_xoff   <= 4'd0;
        draw_pal        <= 9'd0;
        draw_tile_hflip <= 1'b0;
        draw_alpha      <= 1'b0;
        draw_bpp        <= 1'b0;
        draw_blend_6bpp <= 1'b0;
        draw_blend_pxl  <= 8'd0;
        draw_row_data0  <= 32'd0;
        draw_row_data1  <= 32'd0;
        draw_row_data2  <= 32'd0;
        draw_row_data3  <= 32'd0;
    end else begin
        wr_en <= 1'b0;

        case( draw_st )
            DST_IDLE: begin
                if( seg_take ) begin
                    draw_screen_x   <= seg_screen_x;
                    draw_seg_left   <= seg_left;
                    draw_seg_pos    <= 5'd0;
                    draw_seg_xoff   <= seg_xoff;
                    draw_pal        <= seg_pal;
                    draw_tile_hflip <= seg_tile_hflip;
                    draw_alpha      <= seg_alpha;
                    draw_bpp        <= seg_bpp;
                    draw_blend_6bpp <= 1'b0;
                    draw_blend_pxl  <= 8'd0;
                    draw_row_data0  <= seg_row_data0;
                    draw_row_data1  <= seg_row_data1;
                    draw_row_data2  <= seg_row_data2;
                    draw_row_data3  <= seg_row_data3;
                    draw_st         <= DST_DRAW;
                end
            end

            DST_DRAW: begin
                if( draw_seg_pos >= draw_seg_left ) begin
                    draw_st <= DST_IDLE;
                end else begin
                    wr_addr <= draw_screen_x;
                    if( is_opaque ) begin
                        if( draw_alpha ) begin
                            draw_blend_pxl  <= raw_pxl;
                            draw_blend_6bpp <= draw_bpp;
                            draw_st         <= DST_BLEND_WAIT;
                        end else begin
                            wr_pxl        <= norm_pxl;
                            wr_en         <= 1'b1;
                            draw_screen_x <= draw_screen_x + 10'd1;
                            draw_seg_pos  <= draw_seg_pos + 5'd1;
                            if( draw_seg_pos + 5'd1 >= draw_seg_left ) begin
                                draw_st <= DST_IDLE;
                            end
                        end
                    end else begin
                        draw_screen_x <= draw_screen_x + 10'd1;
                        draw_seg_pos  <= draw_seg_pos + 5'd1;
                        if( draw_seg_pos + 5'd1 >= draw_seg_left ) begin
                            draw_st <= DST_IDLE;
                        end
                    end
                end
            end

            DST_BLEND_WAIT: begin
                draw_st <= DST_BLEND_WR;
            end

            DST_BLEND_WR: begin
                wr_en         <= 1'b1;
                wr_pxl        <= blended;
                draw_screen_x <= draw_screen_x + 10'd1;
                draw_seg_pos  <= draw_seg_pos + 5'd1;
                if( draw_seg_pos + 5'd1 >= draw_seg_left ) begin
                    draw_st <= DST_IDLE;
                end else begin
                    draw_st <= DST_DRAW;
                end
            end

            default: draw_st <= DST_IDLE;
        endcase
    end
end

endmodule
