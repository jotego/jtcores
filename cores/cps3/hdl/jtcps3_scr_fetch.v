/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 18-4-2026 */

module jtcps3_scr_fetch #(
    parameter CMDW=96
)(
    input               rst,
    input               clk,
    input               draw,
    input       [CMDW-1:0] cmd,
    input       [ 8:0]  draw_v,

    input       [15:0]  tmap0_scrx,
    input       [15:0]  tmap0_scry,
    input       [ 5:0]  tmap0_ctrl,
    input       [ 6:0]  tmap0_lscr_base,
    input       [ 6:0]  tmap0_tile_base,

    input       [15:0]  tmap1_scrx,
    input       [15:0]  tmap1_scry,
    input       [ 5:0]  tmap1_ctrl,
    input       [ 6:0]  tmap1_lscr_base,
    input       [ 6:0]  tmap1_tile_base,

    input       [15:0]  tmap2_scrx,
    input       [15:0]  tmap2_scry,
    input       [ 5:0]  tmap2_ctrl,
    input       [ 6:0]  tmap2_lscr_base,
    input       [ 6:0]  tmap2_tile_base,

    input       [15:0]  tmap3_scrx,
    input       [15:0]  tmap3_scry,
    input       [ 5:0]  tmap3_ctrl,
    input       [ 6:0]  tmap3_lscr_base,
    input       [ 6:0]  tmap3_tile_base,

    output reg          fetch_done,
    output reg          seg_valid,
    output reg  [ 9:0]  seg_screen_x,
    output reg  [ 4:0]  seg_left,
    output reg  [ 3:0]  seg_xoff,
    output reg  [ 8:0]  seg_pal,
    output reg          seg_tile_hflip,
    output reg          seg_alpha,
    output reg          seg_bpp,
    output reg  [31:0]  seg_row_data0,
    output reg  [31:0]  seg_row_data1,
    output reg  [31:0]  seg_row_data2,
    output reg  [31:0]  seg_row_data3,
    input               seg_take,

    output reg          tiles_rd,
    output reg  [22:4]  tiles_addr,
    input       [127:0] tiles_data,
    input               tiles_ok,

    output reg          scrmap_rd,
    output reg  [18:2]  scrmap_addr,
    input       [31:0]  scrmap_data,
    input               scrmap_ok
);

localparam FST_IDLE        = 4'd0,
           FST_SETUP       = 4'd1,
           FST_SCROLL_REQ  = 4'd2,
           FST_SCROLL_WAIT = 4'd3,
           FST_PREP_SEG    = 4'd4,
           FST_MAP_REQ     = 4'd5,
           FST_MAP_WAIT    = 4'd6,
           FST_TILE_REQ    = 4'd7,
           FST_TILE_WAIT   = 4'd8,
           FST_SEG_WAIT    = 4'd9;

localparam [9:0] SCR_H_OFFSET = 10'd63;

reg  [ 3:0] fetch_st;
reg  [15:0] sel_scrx, sel_scry;
reg  [ 5:0] sel_ctrl;
reg  [ 6:0] sel_lscr_base, sel_tile_base;
reg  [ 9:0] eff_line, scrollx;
reg  [10:0] fetch_screen_x;
reg  [ 5:0] fetch_src_tilecol;
reg  [ 4:0] fetch_seg_left;
reg  [ 3:0] fetch_seg_xoff, fetch_tile_row;
reg  [14:0] fetch_tile;
reg  [ 8:0] fetch_pal;
reg         global_flip_x;
reg         fetch_tile_hflip, fetch_alpha, fetch_bpp;
reg  [31:0] fetch_row_data0, fetch_row_data1, fetch_row_data2, fetch_row_data3;

wire [ 9:0] fetch_xpos;
wire [ 9:0] fetch_screen_x_pos;
wire [ 4:0] fetch_seg_base_len;
wire [10:0] fetch_remaining;
wire [ 4:0] fetch_seg_len_cur;
wire [ 9:0] fetch_eff_line_p16;
wire [ 9:0] fetch_line_scroll_x;
wire [ 6:0] fetch_tileline;
wire [ 5:0] fetch_map_row, fetch_map_col;
wire [10:0] fetch_screen_x_next;
wire        seg_slot_free;
wire [31:0] cmd_w2;

assign fetch_screen_x_pos  = fetch_screen_x[9:0];
assign fetch_xpos          = fetch_screen_x_pos + scrollx - SCR_H_OFFSET;
assign fetch_seg_base_len  = fetch_xpos[3:0] == 4'd0 ? 5'd16 :
                             (5'd16 - fetch_xpos[3:0]);
assign fetch_remaining     = 11'd1024 - fetch_screen_x;
assign fetch_seg_len_cur   = fetch_remaining < { 6'd0, fetch_seg_base_len } ?
                             fetch_remaining[4:0] : fetch_seg_base_len;
assign fetch_eff_line_p16  = eff_line + 10'd16;
assign fetch_line_scroll_x = scrmap_data[25:16];
assign fetch_tileline      = eff_line[9:4] + 7'd1;
assign fetch_map_row       = fetch_tileline[5:0];
assign fetch_map_col       = global_flip_x ? (6'd63 - fetch_src_tilecol) :
                                             fetch_src_tilecol;
assign fetch_screen_x_next = fetch_screen_x + { 6'd0, fetch_seg_left };
assign seg_slot_free       = !seg_valid || seg_take;
assign cmd_w2              = cmd[95:64];

function [9:0] line_for;
    input [8:0] dv;
    input [15:0] scry;
    input        vflip;
    reg   [10:0] sum;
begin
    sum = { 2'd0, dv } + { 1'b0, scry[9:0] } + 11'd4;
    line_for = sum[9:0] ^ {10{vflip}};
end
endfunction

task select_tmap;
    input [1:0] sel;
begin
    case( sel )
        2'd0: begin
            sel_scrx      <= tmap0_scrx;
            sel_scry      <= tmap0_scry;
            sel_ctrl      <= tmap0_ctrl;
            sel_lscr_base <= tmap0_lscr_base;
            sel_tile_base <= tmap0_tile_base;
        end
        2'd1: begin
            sel_scrx      <= tmap1_scrx;
            sel_scry      <= tmap1_scry;
            sel_ctrl      <= tmap1_ctrl;
            sel_lscr_base <= tmap1_lscr_base;
            sel_tile_base <= tmap1_tile_base;
        end
        2'd2: begin
            sel_scrx      <= tmap2_scrx;
            sel_scry      <= tmap2_scry;
            sel_ctrl      <= tmap2_ctrl;
            sel_lscr_base <= tmap2_lscr_base;
            sel_tile_base <= tmap2_tile_base;
        end
        default: begin
            sel_scrx      <= tmap3_scrx;
            sel_scry      <= tmap3_scry;
            sel_ctrl      <= tmap3_ctrl;
            sel_lscr_base <= tmap3_lscr_base;
            sel_tile_base <= tmap3_tile_base;
        end
    endcase
end
endtask

wire enabled = sel_ctrl[5];
wire linescroll_enable = sel_ctrl[4];

always @(posedge clk) begin
    if( rst ) begin
        fetch_st          <= FST_IDLE;
        fetch_done        <= 1'b0;
        seg_valid         <= 1'b0;
        seg_screen_x      <= 10'd0;
        seg_left          <= 5'd0;
        seg_xoff          <= 4'd0;
        seg_pal           <= 9'd0;
        seg_tile_hflip    <= 1'b0;
        seg_alpha         <= 1'b0;
        seg_bpp           <= 1'b0;
        seg_row_data0     <= 32'd0;
        seg_row_data1     <= 32'd0;
        seg_row_data2     <= 32'd0;
        seg_row_data3     <= 32'd0;
        tiles_rd          <= 1'b0;
        tiles_addr        <= 19'd0;
        scrmap_rd         <= 1'b0;
        scrmap_addr       <= 17'd0;
        sel_scrx          <= 16'd0;
        sel_scry          <= 16'd0;
        sel_ctrl          <= 6'd0;
        sel_lscr_base     <= 7'd0;
        sel_tile_base     <= 7'd0;
        eff_line          <= 10'd0;
        scrollx           <= 10'd0;
        fetch_screen_x    <= 11'd0;
        fetch_src_tilecol <= 6'd0;
        fetch_seg_left    <= 5'd0;
        fetch_seg_xoff    <= 4'd0;
        fetch_tile_row    <= 4'd0;
        fetch_tile        <= 15'd0;
        fetch_pal         <= 9'd0;
        global_flip_x     <= 1'b0;
        fetch_tile_hflip  <= 1'b0;
        fetch_alpha       <= 1'b0;
        fetch_bpp         <= 1'b0;
        fetch_row_data0   <= 32'd0;
        fetch_row_data1   <= 32'd0;
        fetch_row_data2   <= 32'd0;
        fetch_row_data3   <= 32'd0;
    end else begin
        tiles_rd  <= 1'b0;
        scrmap_rd <= 1'b0;

        if( seg_take ) begin
            seg_valid <= 1'b0;
        end

        case( fetch_st )
            FST_IDLE: begin
                if( draw ) begin
                    select_tmap( cmd_w2[5:4] );
                    fetch_done <= 1'b0;
                    fetch_st   <= FST_SETUP;
                    seg_valid  <= 1'b0;
                end
            end

            FST_SETUP: begin
                global_flip_x     <= sel_ctrl[1];
                eff_line          <= line_for(draw_v, sel_scry, sel_ctrl[0]);
                scrollx           <= sel_scrx[9:0];
                fetch_screen_x    <= 11'd0;
                fetch_src_tilecol <= 6'd0;
                fetch_seg_left    <= 5'd0;
                fetch_seg_xoff    <= 4'd0;
                fetch_tile_row    <= 4'd0;
                fetch_tile        <= 15'd0;
                fetch_pal         <= 9'd0;
                fetch_tile_hflip  <= 1'b0;
                fetch_alpha       <= 1'b0;
                fetch_bpp         <= 1'b0;
                fetch_row_data0   <= 32'd0;
                fetch_row_data1   <= 32'd0;
                fetch_row_data2   <= 32'd0;
                fetch_row_data3   <= 32'd0;
                if( !enabled ) begin
                    fetch_done <= 1'b1;
                    fetch_st   <= FST_IDLE;
                end else if( linescroll_enable ) begin
                    fetch_st   <= FST_SCROLL_REQ;
                end else begin
                    fetch_st   <= FST_PREP_SEG;
                end
            end

            FST_SCROLL_REQ: begin
                scrmap_rd   <= 1'b1;
                scrmap_addr <= { sel_lscr_base, 10'd0 } + { 7'd0, fetch_eff_line_p16 };
                fetch_st    <= FST_SCROLL_WAIT;
            end

            FST_SCROLL_WAIT: begin
                if( scrmap_ok ) begin
                    scrollx  <= sel_scrx[9:0] + fetch_line_scroll_x;
                    fetch_st <= FST_PREP_SEG;
                end
            end

            FST_PREP_SEG: begin
                if( fetch_screen_x >= 11'd1024 ) begin
                    fetch_done <= 1'b1;
                    fetch_st   <= FST_IDLE;
                end else begin
                    fetch_src_tilecol <= fetch_xpos[9:4];
                    fetch_seg_xoff    <= fetch_xpos[3:0];
                    fetch_seg_left    <= fetch_seg_len_cur;
                    fetch_st          <= FST_MAP_REQ;
                end
            end

            FST_MAP_REQ: begin
                scrmap_rd   <= 1'b1;
                scrmap_addr <= { sel_tile_base, 10'd0 } +
                               { 5'd0, fetch_map_row, fetch_map_col };
                fetch_st    <= FST_MAP_WAIT;
            end

            FST_MAP_WAIT: begin
                if( scrmap_ok ) begin
                    fetch_tile       <= scrmap_data[31:17];
                    fetch_tile_hflip <= scrmap_data[12] ^ global_flip_x;
                    fetch_alpha      <= scrmap_data[10];
                    fetch_bpp        <= scrmap_data[9];
                    fetch_pal        <= scrmap_data[8:0];
                    fetch_tile_row   <= scrmap_data[11] ? (4'd15 - eff_line[3:0]) :
                                                          eff_line[3:0];
                    fetch_st         <= FST_TILE_REQ;
                end
            end

            FST_TILE_REQ: begin
                tiles_rd   <= 1'b1;
                tiles_addr <= { fetch_tile, fetch_tile_row };
                fetch_st   <= FST_TILE_WAIT;
            end

            FST_TILE_WAIT: begin
                if( tiles_ok ) begin
                    if( seg_slot_free ) begin
                        seg_valid      <= 1'b1;
                        seg_screen_x   <= fetch_screen_x[9:0];
                        seg_left       <= fetch_seg_left;
                        seg_xoff       <= fetch_seg_xoff;
                        seg_pal        <= fetch_pal;
                        seg_tile_hflip <= fetch_tile_hflip;
                        seg_alpha      <= fetch_alpha;
                        seg_bpp        <= fetch_bpp;
                        seg_row_data0  <= tiles_data[31:0];
                        seg_row_data1  <= tiles_data[63:32];
                        seg_row_data2  <= tiles_data[95:64];
                        seg_row_data3  <= tiles_data[127:96];
                        fetch_screen_x <= fetch_screen_x_next;
                        if( fetch_screen_x_next >= 11'd1024 ) begin
                            fetch_done <= 1'b1;
                            fetch_st   <= FST_IDLE;
                        end else begin
                            fetch_st   <= FST_PREP_SEG;
                        end
                    end else begin
                        fetch_row_data0 <= tiles_data[31:0];
                        fetch_row_data1 <= tiles_data[63:32];
                        fetch_row_data2 <= tiles_data[95:64];
                        fetch_row_data3 <= tiles_data[127:96];
                        fetch_st        <= FST_SEG_WAIT;
                    end
                end
            end

            FST_SEG_WAIT: begin
                if( seg_slot_free ) begin
                    seg_valid      <= 1'b1;
                    seg_screen_x   <= fetch_screen_x[9:0];
                    seg_left       <= fetch_seg_left;
                    seg_xoff       <= fetch_seg_xoff;
                    seg_pal        <= fetch_pal;
                    seg_tile_hflip <= fetch_tile_hflip;
                    seg_alpha      <= fetch_alpha;
                    seg_bpp        <= fetch_bpp;
                    seg_row_data0  <= fetch_row_data0;
                    seg_row_data1  <= fetch_row_data1;
                    seg_row_data2  <= fetch_row_data2;
                    seg_row_data3  <= fetch_row_data3;
                    fetch_screen_x <= fetch_screen_x_next;
                    if( fetch_screen_x_next >= 11'd1024 ) begin
                        fetch_done <= 1'b1;
                        fetch_st   <= FST_IDLE;
                    end else begin
                        fetch_st   <= FST_PREP_SEG;
                    end
                end
            end

            default: fetch_st <= FST_IDLE;
        endcase
    end
end

endmodule
