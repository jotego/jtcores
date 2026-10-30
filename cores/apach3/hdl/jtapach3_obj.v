/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

module jtapach3_obj(
    input              rst,
    input              clk,
    input              pxl_cen,
    input        [8:0] h,
    input        [8:0] v,
    output reg  [13:1] ram_addr,
    input       [15:0] ram_data,
    output       [8:1] ctrl_addr,
    input       [15:0] ctrl_data,
    output      [20:3] rom_addr,
    output             rom_cs,
    input       [63:0] rom_data,
    input              rom_ok,
    output       [9:0] pxl,
    output reg         overflow
);

localparam IDLE=0, CLUT_L=1, CLUT_L_DONE=2, CLUT_H=3, CLUT_H_DONE=4,
    WAIT0=5, WAIT1=6, ATTR_WAIT=7, ATTR=8, NEXT=10,
    HEADER=11, DESC=12, PREP=13, PIXEL=14, TILE=15, GFX=16,
    SNAP_WAIT=17, SNAP_ATTR=18, WALK_INIT=19, WALK_WAIT=20,
    WALK_LOAD=21, WALK_FETCH=22, WALK_HEADER=23, WALK_DESC=24,
    WALK_STORE=25, WALK_NEXT=26, FAST=27, FAST_DONE=28,
    PREP_COORD=29, FAST_MUL=30, FAST_CHECK=31, FAST_MOD_MUL=32,
    FAST_MOD_CHECK=33, FAST_MOD_END=34, HEADER_MUL=35, HEADER_CHECK=36,
    HEADER_DONE=37, FAST_REM=38, BOUNDS_ROT=39, BOUNDS_FINAL=40,
    COORD_MIX=41, COORD_FINAL=42, PIXEL_MUL=43, PIXEL_CHECK=44,
    PIXEL_LOOKUP=45, PIXEL_WRAP_MUL=46, PIXEL_WRAP_CHECK=47,
    PIXEL_TILE=48, BOUNDS_REDUCE=49, COORD_TILT=50, PIXEL_WRAP_END=51,
    BOUNDS_SCREEN=52, BOUNDS_CLIP=53, BOUNDS_DONE=54,
    PIPE_START=55, PIPE_RUN=56, PIPE_GFX=57, REPEAT_WAIT=58, CTRL_WAIT=59, CTRL_SELECT=60;
reg [5:0] state, return_state;
localparam DR_IDLE=0, DR_RUN=1, DR_DRAIN=2;
reg [1:0] dr_state;
reg dr_cnt;
reg [17:0] request_addr;
reg request_bank;
reg [31:0] fetched;
reg [63:0] pair_data;
reg [17:0] pair_addr;
reg pair_valid;
reg [8:0] clut_load;
reg loaded;
reg [31:0] clut_l [0:511];
reg [31:0] clut_h [0:511];
reg [31:0] clut_l_q, clut_h_q;
reg [32:0] inverse [0:511];
reg [24:0] shrink_table [0:256];
reg [32:0] scale_inverse_rom, scale_inverse;
reg [24:0] shrink;
reg [15:0] attr [0:5];
reg [2:0] attr_step;
reg [12:0] list_base;
reg [10:0] offset;
reg [8:0] snap_index, walk_index, object_index, object_count, shadow_count;
reg ctrl_select, shadow_base, separate_lists, build_shadow, shadow_pass;
wire [8:0] walk_count = build_shadow ? shadow_count : object_count;
wire first_shadow = object_count == 0 && separate_lists;
wire [8:0] first_count = first_shadow ? shadow_count : object_count;
reg [9:0] frame_wr_addr, frame_rd_addr;
reg [207:0] frame_wr_data;
wire [207:0] frame_q, list_data;
wire [9:0] list_addr;
wire [8:0] list_index;
wire list_valid, list_busy;
reg list_start;
wire [207:0] frame_data;
wire [7:0] first_line = frame_data[135:128];
wire [7:0] end_line = frame_data[143:136];
reg frame_we, frame_ready, frame_valid, walk_valid;
reg [31:0] frame_header;
reg [8:0] target_y;
reg [6:0] rows;
reg [8:0] top_line;
reg [9:0] bottom_line;
reg repeat_line;
reg [5:0] row;
reg [11:0] last_left;
reg [12:0] last_right;
reg [17:0] last_base;
reg [12:0] object_width;
reg [11:0] object_left;
reg [4:0] draw_page, walk_page, page_count;
reg page_hit;
reg [30:0] page_valid;
reg [13:0] page_id [0:30];
reg [12:0] page_width [0:30];
reg [11:0] page_left [0:30];
reg [4:0] lookup_page;
integer pc;
always @* begin
    lookup_page=0;
    for (pc=0;pc<31;pc=pc+1)
        if (page_valid[pc] && page_id[pc]==attr[0][13:0]) lookup_page=pc[4:0]+5'd1;
end
reg [31:0] pixel_x_min, pixel_x_max;
reg [8:0] draw_x, last_x;
reg signed [59:0] source_x, source_y, step_x, step_y;
reg [17:0] tile_addr, cached_addr;
reg cache_valid;
reg [63:0] cached_data;
reg [19:0] fast_col, fast_next_col;
reg [19:0] prep_dist;
reg [8:0] prep_count;
reg [32:0] prep_inverse;
reg [59:0] prep_col_product, prep_step_product;
reg [31:0] prep_col, prep_delta;
reg [26:0] prep_col_quotient, prep_step_quotient;
reg [26:0] prep_raw_col, prep_raw_step;
reg bounds_walk;
reg signed [31:0] bound_left, bound_right, bound_top, bound_bottom, bound_width;
reg signed [31:0] bound_rx [0:3], bound_ry [0:3];
reg signed [31:0] bound_minx [0:1], bound_maxx [0:1];
reg signed [31:0] bound_miny [0:1], bound_maxy [0:1];
reg signed [33:0] coord_dx, coord_dy, coord_mixed_x, coord_mixed_y;
reg signed [43:0] coord_tilt_x, coord_tilt_y;
reg [31:0] pixel_y_min, pixel_y_max;
reg [8:0] fast_rem, fast_next_rem, fast_step, fast_step_rem;
reg [12:0] fast_span;
reg [2:0] fast_line;
reg [17:0] fast_addr [0:1];
reg [63:0] fast_data [0:1];
reg [1:0] fast_valid;
reg fast_pending, fast_wait, fast_slot, fast_replace;
reg [17:0] fast_request;
wire fast_pair_hit = pair_valid && pair_addr == fast_request;
reg [19:0] r_next_col;
reg r_next_vld;
reg [17:0] fast_tile_addr, fast_ahead_tile;
wire [17:0] fast_ahead_addr;
reg fast_ahead_ready;
reg fast_tile_bank;
integer fast_delta, fast_r, fast_c, fast_tile, fast_ahead;
wire fast_hit0 = fast_valid[0] && fast_addr[0] == fast_tile_addr;
wire fast_hit1 = fast_valid[1] && fast_addr[1] == fast_tile_addr;
wire fast_hit = fast_hit0 || fast_hit1;
wire fast_ahead_hit = (fast_valid[0] && fast_addr[0] == fast_ahead_addr) ||
                      (fast_valid[1] && fast_addr[1] == fast_ahead_addr);
wire [63:0] fast_word = fast_data[fast_hit1];
reg [19:0] d_col;
wire [5:0] fast_nibble = {fast_tile_bank,d_col[2:0] ^ 3'd3,2'b00};
wire fast_free_slot = !fast_valid[0] ? 1'b0 : !fast_valid[1] ? 1'b1 : fast_replace;
reg [319:0] covmap;
reg span_covered;
integer cb;
always @* begin
    span_covered=1;
    for (cb=0;cb<40;cb=cb+1)
        if (cb>=({23'd0,frame_data[190:182]}>>3) && cb<=({23'd0,frame_data[199:191]}>>3) &&
            !(&covmap[cb*8+:8])) span_covered=0;
end
reg [8:0] cover_cnt;
wire line_full = cover_cnt == 9'd320;
reg [7:0] cov_chunk;
reg [8:0] d_rem, d_step, d_step_rem, d_scale;
reg [12:0] d_span;
reg [2:0] d_line;
reg [8:0] d_x, d_lastx;
reg d_flip, d_repeat;
reg [17:0] d_base;
reg [7:0] d_color;
reg [2:0] nibble;
reg [3:0] pen;
reg [7:0] pipe_palette;
reg [8:0] read_x, write_x;
reg [9:0] write_data;
reg write_enable;
reg [1:0] color_valid;
reg [8:0] color_x0, color_x1;
reg [2:0] color_select;
wire [8:0] scale = attr[4][8:0];
wire flip_x = attr[1][15];
wire flip_y = attr[1][14];
wire signed [9:0] rotation = {attr[5][8],attr[5][8:0]};
wire signed [9:0] slope = flip_x ? -rotation : rotation;
wire [9:0] slope_magnitude = slope < 0 ? -slope : slope;
wire [8:0] slope_abs = slope_magnitude[8:0];
wire signed [31:0] origin_x = {{16{attr[2][15]}},attr[2]};
wire signed [31:0] origin_y = {{16{attr[3][15]}},attr[3]};
wire signed [31:0] line_y = {23'd0,target_y};
reg closing, drawing, launch_pending;
assign frame_data = drawing ? list_data : frame_q;
reg pipe_start;
wire pipe_pop;
wire pipe_busy, pipe_valid, pipe_ahead_valid;
wire [47:0] pipe_pixel;
wire [17:0] pipe_ahead_addr;
wire pipe_flush = closing || (drawing && h == 397);
wire pipe_hit0 = fast_valid[0] && fast_addr[0] == pipe_pixel[21:4];
wire pipe_hit1 = fast_valid[1] && fast_addr[1] == pipe_pixel[21:4];
wire pipe_pair_hit = pair_valid && pair_addr == pipe_pixel[21:4];
wire tex_hit;
wire [63:0] tex_data;
wire pipe_hit = tex_hit || pipe_hit0 || pipe_hit1 || pipe_pair_hit ||
                (cache_valid && cached_addr == pipe_pixel[21:4]);
wire [63:0] pipe_word = pipe_pair_hit ? pair_data : pipe_hit0 ? fast_data[0] :
                        pipe_hit1 ? fast_data[1] : tex_hit ? tex_data : cached_data;
wire pipe_ahead_hit = (fast_valid[0] && fast_addr[0] == pipe_ahead_addr) ||
                      (fast_valid[1] && fast_addr[1] == pipe_ahead_addr) ||
                      (cache_valid && cached_addr == pipe_ahead_addr) ||
                      (pair_valid && pair_addr == pipe_ahead_addr);

wire [11:0] color_index = {dr_state != DR_IDLE ? d_color : (state == PIPE_RUN || state == PIPE_GFX || pipe_pop) ? pipe_palette : attr[1][10:3],pen};
wire [31:0] clut_word = color_select[2] ? clut_h_q : clut_l_q;
wire [4:0] clut_shift = {color_select[1:0] ^ 2'b01,3'b000};
wire [7:0] clut_color = clut_word[clut_shift+:8];
wire line_start = pxl_cen && h == 0;
reg [8:0] launch_v;
wire [8:0] launch_y = launch_v == 279 ? 9'd0 : launch_v + 9'd1;
integer i, dy, source_line, source_col, source_row, dist_x, dist_y;
integer left_edge, right_edge, first_x, end_x, tile_number, tile_count, tile_delta;
integer st, sb, sr, cx, cy, rx, ry, minx, maxx, miny, maxy;
wire bounds_empty = !walk_valid || miny >= maxy || miny >= 240 || maxy <= 0;
reg signed [33:0] dx_fixed, dy_fixed;
reg signed [35:0] slope_scale;
reg [40:0] init_shrink;
reg [26:0] quotient;

function [17:0] graphics_addr;
    input [17:0] tile;
    input [2:0] line;
    begin
        graphics_addr = {tile[15:1],line};
    end
endfunction

assign fast_ahead_addr = graphics_addr(fast_ahead_tile,d_line);

wire [17:0] fast_start_tile = last_base + {1'b0,fast_col[19:3]};
wire [17:0] fast_start_addr = graphics_addr(fast_start_tile,fast_line);
wire fast_start_hit = (fast_valid[0] && fast_addr[0] == fast_start_addr) ||
                      (fast_valid[1] && fast_addr[1] == fast_start_addr);

reg [19:0] jump_col;
reg [8:0] jump_rem;
reg [3:0] jump_k;
reg [11:0] jump_kstep, jump_krem;
reg [11:0] jump_steps [0:7], jump_remainders [0:7];
reg [12:0] jump_m [0:8];
reg [13:0] jump_tot, jump_u;
reg [7:0] jump_ge;
reg [3:0] jump_c;
integer jm;
always @* begin
    jump_k = 4'd8 - {1'b0,d_x[2:0]};
    jump_kstep = jump_steps[d_x[2:0]];
    jump_krem = jump_remainders[d_x[2:0]];
    jump_m[0] = 0;
    jump_m[1] = {4'd0,d_scale};
    jump_m[2] = {3'd0,d_scale,1'd0};
    jump_m[3] = {3'd0,d_scale,1'd0} + {4'd0,d_scale};
    jump_m[4] = {2'd0,d_scale,2'd0};
    jump_m[5] = {2'd0,d_scale,2'd0} + {4'd0,d_scale};
    jump_m[6] = {2'd0,d_scale,2'd0} + {3'd0,d_scale,1'd0};
    jump_m[7] = {1'd0,d_scale,3'd0} - {4'd0,d_scale};
    jump_m[8] = {1'd0,d_scale,3'd0};
    jump_u = {2'd0,jump_krem};
    jump_tot = {5'd0,d_rem} + {2'd0,jump_krem};
    if (d_flip) begin
        for (jm=0; jm<8; jm=jm+1)
            jump_ge[jm] = jump_u > {1'd0,jump_m[jm]} + {5'd0,d_rem};
    end else begin
        for (jm=0; jm<8; jm=jm+1)
            jump_ge[jm] = jump_tot >= {1'd0,jump_m[jm+1]};
    end
    jump_c = ({2'd0,jump_ge[0]} + {2'd0,jump_ge[1]} + {2'd0,jump_ge[2]} + {2'd0,jump_ge[3]})
           + ({2'd0,jump_ge[4]} + {2'd0,jump_ge[5]} + {2'd0,jump_ge[6]} + {2'd0,jump_ge[7]});
    if (d_flip) begin
        jump_rem = d_rem + jump_m[jump_c][8:0] - jump_krem[8:0];
        jump_col = d_col - {8'd0,jump_kstep} - {16'd0,jump_c};
    end else begin
        jump_rem = jump_tot[8:0] - jump_m[jump_c][8:0];
        jump_col = d_col + {8'd0,jump_kstep} + {16'd0,jump_c};
    end
end

always @* begin
    fast_delta = {23'd0,d_step};
    fast_r = {23'd0,d_rem};
    if (d_flip) begin
        fast_r = fast_r - {23'd0,d_step_rem};
        if (fast_r < 0) begin
            fast_r = fast_r + {23'd0,d_scale};
            fast_delta = fast_delta + 1;
        end
        fast_c = {12'd0,d_col} - fast_delta;
    end else begin
        fast_r = fast_r + {23'd0,d_step_rem};
        if (fast_r >= {23'd0,d_scale}) begin
            fast_r = fast_r - {23'd0,d_scale};
            fast_delta = fast_delta + 1;
        end
        fast_c = {12'd0,d_col} + fast_delta;
    end
    if (d_repeat) begin
        if (fast_c < 0) fast_c = fast_c + {19'd0,d_span};
        else if (fast_c >= {19'd0,d_span}) fast_c = fast_c - {19'd0,d_span};
    end
    fast_next_col = fast_c[19:0];
    fast_next_rem = fast_r[8:0];
    fast_tile = {14'd0,d_base} + ({12'd0,d_col} >> 3);
    fast_tile_bank = fast_tile[0];
    fast_tile_addr = graphics_addr(fast_tile[17:0],d_line);
    fast_ahead = d_flip ? ({12'd0,d_col} & -8) - (fast_tile_bank ? 16 : 8) :
                         ({12'd0,d_col} & -8) + (fast_tile_bank ? 8 : 16);
    if (d_scale < 16) fast_ahead = {12'd0,r_next_col};
    if (d_repeat) begin
        if (fast_ahead < 0) fast_ahead = fast_ahead + {19'd0,d_span};
        else if (fast_ahead >= {19'd0,d_span}) fast_ahead = fast_ahead - {19'd0,d_span};
        if (fast_ahead < 0) fast_ahead = fast_ahead + {19'd0,d_span};
        else if (fast_ahead >= {19'd0,d_span}) fast_ahead = fast_ahead - {19'd0,d_span};
    end
    fast_tile = {14'd0,d_base} + (fast_ahead >> 3);
end

task request;
    input bank;
    input [17:0] address;
    input [5:0] destination;
    begin
`ifdef SIMULATION
`ifdef APACH3_OBJ_TRAFFIC
        if (drawing && destination != PIPE_GFX) $display("OBJ_ACCESS kind=M addr=%0d bank=%0d",address,bank);
`endif
`endif
        request_bank <= bank;
        request_addr <= address;
        return_state <= destination;
        if (pair_valid && pair_addr == address) begin
            fetched <= bank ? pair_data[63:32] : pair_data[31:0];
            state <= destination;
        end else state <= WAIT0;
    end
endtask


assign ctrl_addr = ctrl_select ? 8'he0 : 8'h20;
wire fsm_req = state == WAIT0 || state == WAIT1;
reg rom_owner;
assign rom_addr = rom_owner ? fast_request : request_addr;
assign rom_cs = rom_owner ? fast_pending && !fast_pair_hit : fsm_req;

initial begin
    inverse[0] = 0;
    for (i=1;i<512;i=i+1) inverse[i] = (33'h100000000 + {1'b0,i[31:0]} - 1'b1) / {1'b0,i[31:0]};
    for (i=0;i<257;i=i+1) begin
        init_shrink = 41'h10000000000 / (41'd65536 + {9'd0,i[31:0]}*{9'd0,i[31:0]});
        shrink_table[i] = init_shrink[24:0];
    end
end

always @(posedge clk) begin
    if (state == ATTR && list_valid) scale_inverse_rom <= inverse[frame_data[72:64]];
    scale_inverse <= scale_inverse_rom;
    shrink <= shrink_table[slope_abs];
    clut_l_q <= clut_l[color_index[11:3]];
    clut_h_q <= clut_h[color_index[11:3]];
    color_select <= color_index[2:0];
    if (rst) read_x <= 0;
    else if (pxl_cen) read_x <= h >= 398 ? h-9'd398 : h+9'd2;
end


assign pipe_pop = !pipe_flush &&
    ((state == PIPE_RUN && pipe_valid &&
      (pipe_pixel[47:39] != target_y || covmap[pipe_pixel[30:22]] || line_full ||
       pipe_hit)) ||
     state == PIPE_GFX);

wire [17:0] tex_next_addr = !pipe_valid ? 18'd0 :
                           pipe_pop && pipe_ahead_valid ? pipe_ahead_addr : pipe_pixel[21:4];
wire tex_fill = (state == WAIT1 && !rom_owner && rom_ok) ||
                (fast_wait && rom_owner && rom_ok && fast_pending);
jtapach3_objcache u_texcache (
    .rst       ( rst              ),
    .clk       ( clk              ),
    .addr      ( pipe_pixel[21:4] ),
    .next_addr ( tex_next_addr    ),
    .fill      ( tex_fill         ),
    .fill_addr ( rom_addr         ),
    .fill_data ( rom_data         ),
    .hit       ( tex_hit          ),
    .data      ( tex_data         )
);

reg bounds_start;
wire bounds_done, repeat_reject;
wire [31:0] repeat_extent;

jtapach3_objbounds u_repeat_bounds (
    .rst      ( rst           ),
    .clk      ( clk           ),
    .start    ( bounds_start  ),
    .origin_x ( origin_x      ),
    .origin_y ( origin_y      ),
    .slope    ( slope         ),
    .shrink   ( shrink        ),
    .flip_x   ( flip_x        ),
    .flip_y   ( flip_y        ),
    .top      ( bound_top     ),
    .bottom   ( bound_bottom  ),
    .width    ( bound_width   ),
    .done     ( bounds_done   ),
    .reject   ( repeat_reject ),
    .extent   ( repeat_extent )
);

wire desc_write = state == DESC || (state == WALK_DESC && walk_page != 0);
wire [10:0] desc_write_addr = {state == WALK_DESC ? walk_page : 5'd0,row};
jtapach3_objpipe u_pipe (
    .rst         ( rst                       ),
    .clk         ( clk                       ),
    .flush       ( pipe_flush                ),
    .start       ( pipe_start                ),
    .occupied    ( covmap                    ),
    .source_x    ( source_x                  ),
    .source_y    ( source_y                  ),
    .step_x      ( step_x                    ),
    .step_y      ( step_y                    ),
    .first_x     ( draw_x                    ),
    .last_x      ( last_x                    ),
    .target_y    ( target_y                  ),
    .palette     ( attr[1][10:3]             ),
    .scale       ( scale                     ),
    .reciprocal  ( scale_inverse             ),
    .flip_x      ( flip_x                    ),
    .flip_y      ( flip_y                    ),
    .repeat_line ( repeat_line               ),
    .top_line    ( top_line                  ),
    .bottom_line ( bottom_line               ),
    .x_min       ( pixel_x_min               ),
    .x_max       ( pixel_x_max               ),
    .y_min       ( pixel_y_min               ),
    .y_max       ( pixel_y_max               ),
    .desc_we     ( desc_write                ),
    .desc_addr   ( desc_write_addr           ),
    .desc_page   ( draw_page                 ),
    .desc_left   ( {1'b0,fetched[15:8],3'd0} ),
    .desc_right  ( (({5'd0,fetched[15:8]} + {5'd0,fetched[7:0]} + 13'd1) << 3) ),
    .desc_base   ( {1'b0,fetched[31:16],1'b0} ),
    .busy        ( pipe_busy                 ),
    .valid       ( pipe_valid                ),
    .pop         ( pipe_pop                  ),
    .pixel       ( pipe_pixel                ),
    .ahead_valid ( pipe_ahead_valid          ),
    .ahead_addr  ( pipe_ahead_addr           )
);

jtframe_obj_buffer #(
    .DW         ( 10     ),
    .AW         ( 9      ),
    .ALPHAW     ( 9      ),
    .ALPHA      ( 0      ),
    .BLANK      ( 0      ),
    .SHADOW     ( 1      ),
    .SHADOW_PEN ( 9'h1ff )
) u_buffer (
    .clk     ( clk          ),
    .LHBL    ( h != 398     ),
    .flip    ( 1'b0         ),
    .wr_data ( write_data   ),
    .wr_addr ( write_x      ),
    .we      ( write_enable ),
    .rd_addr ( read_x       ),
    .rd      ( pxl_cen      ),
    .rd_data ( pxl          )
);

wire [8:0] list_length = shadow_pass ? shadow_count : object_count;
wire list_pop = state == ATTR && list_valid && !line_full && !pipe_flush;
wire [9:0] frame_read_addr = drawing ? list_addr : frame_rd_addr;
jtapach3_objlist u_list (
    .rst      ( rst         ),
    .clk      ( clk         ),
    .flush    ( pipe_flush  ),
    .start    ( list_start  ),
    .bank     ( shadow_pass ),
    .length   ( list_length ),
    .target_y ( target_y    ),
    .ram_addr ( list_addr   ),
    .ram_data ( frame_q     ),
    .busy     ( list_busy   ),
    .valid    ( list_valid  ),
    .data     ( list_data   ),
    .index    ( list_index  ),
    .pop      ( list_pop    )
);

jtframe_dual_ram #(
    .AW ( 10  ),
    .DW ( 208 )
) u_frame_list (
    .clk0  ( clk             ),
    .data0 ( frame_wr_data   ),
    .addr0 ( frame_wr_addr   ),
    .we0   ( frame_we        ),
    .q0    (                 ),
    .clk1  ( clk             ),
    .data1 ( 208'd0          ),
    .addr1 ( frame_read_addr ),
    .we1   ( 1'b0            ),
    .q1    ( frame_q         )
);

always @(posedge clk) begin
    frame_we <= 0;
    bounds_start <= 0;
    pipe_start <= 0;
    list_start <= 0;
    write_enable <= 0;
    color_valid <= {color_valid[0],1'b0};
    color_x1 <= color_x0;
    if (color_valid[1] && !covmap[color_x1]) begin
        write_x <= color_x1;
        write_data <= {clut_color == 8'hff,1'b1,clut_color};
        write_enable <= shadow_pass ? clut_color == 8'hff : clut_color != 8'hff || !separate_lists;
        if (shadow_pass || clut_color != 8'hff) begin
            covmap[color_x1] <= 1;
            cover_cnt <= cover_cnt + 1'b1;
        end
    end
    if (rst) begin
        state <= CLUT_L;
        return_state <= IDLE;
        request_addr <= 0;
        request_bank <= 0;
        pair_data <= 0;
        pair_addr <= 0;
        pair_valid <= 0;
        clut_load <= 0;
        loaded <= 0;
        pipe_start <= 0;
        pipe_palette <= 0;
        list_start <= 0;
        bounds_start <= 0;
        closing <= 0;
        drawing <= 0;
        launch_pending <= 0;
        launch_v <= 0;
        ram_addr <= 0;
        attr_step <= 0;
        list_base <= 0;
        offset <= 0;
        snap_index <= 0;
        walk_index <= 0;
        object_index <= 0;
        object_count <= 0;
        shadow_count <= 0;
        ctrl_select <= 0;
        shadow_base <= 0;
        separate_lists <= 0;
        build_shadow <= 0;
        shadow_pass <= 0;
        frame_wr_addr <= 0;
        frame_rd_addr <= 0;
        frame_wr_data <= 0;
        frame_we <= 0;
        frame_ready <= 0;
        frame_valid <= 0;
        walk_valid <= 0;
        frame_header <= 0;
        target_y <= 0;
        rows <= 0;
        top_line <= 0;
        bottom_line <= 0;
        repeat_line <= 0;
        row <= 0;
        object_width <= 0;
        object_left <= 0;
        draw_page <= 0;
        walk_page <= 0;
        page_count <= 0;
        page_hit <= 0;
        page_valid <= 0;
        pixel_x_min <= 0;
        pixel_x_max <= 0;
        draw_x <= 0;
        last_x <= 0;
        source_x <= 0;
        source_y <= 0;
        step_x <= 0;
        step_y <= 0;
        tile_addr <= 0;
        cached_addr <= 0;
        cached_data <= 0;
        cache_valid <= 0;
        fast_col <= 0;
        fast_rem <= 0;
        fast_step <= 0;
        fast_step_rem <= 0;
        fast_span <= 0;
        fast_line <= 0;
        fast_valid <= 0;
        fast_pending <= 0;
        fast_wait <= 0;
        fast_slot <= 0;
        fast_replace <= 0;
        fast_request <= 0;
        rom_owner <= 0;
        r_next_col <= 0;
        r_next_vld <= 0;
        fast_ahead_tile <= 0;
        fast_ahead_ready <= 0;
        for (i=0;i<2;i=i+1) begin
            fast_addr[i] <= 0;
            fast_data[i] <= 0;
        end
        nibble <= 0;
        pen <= 0;
        color_valid <= 0;
        color_x0 <= 0;
        color_x1 <= 0;
        write_x <= 0;
        write_data <= 0;
        overflow <= 0;
        covmap <= 0;
        cover_cnt <= 0;
        cov_chunk <= 0;
        dr_state <= DR_IDLE;
        dr_cnt <= 0;
        d_col <= 0; d_rem <= 0; d_step <= 0; d_step_rem <= 0; d_scale <= 0;
        d_span <= 0; d_line <= 0; d_x <= 0; d_lastx <= 0;
        d_flip <= 0; d_repeat <= 0; d_base <= 0; d_color <= 0;
        for (i=0;i<6;i=i+1) attr[i] <= 0;
    end else begin
        rom_owner <= rom_owner ? fast_pending : !fsm_req && fast_pending;
        r_next_col <= fast_next_col;
        r_next_vld <= dr_state == DR_RUN;
        fast_ahead_tile <= fast_tile[17:0];
        fast_ahead_ready <= dr_state == DR_RUN && r_next_vld
                        && (d_repeat || (fast_ahead >= 0 && fast_ahead < {19'd0,d_span}));
        if (fast_pending) begin
            fast_wait <= rom_owner;
            if (fast_pair_hit) begin
                fast_addr[fast_slot] <= fast_request;
                fast_data[fast_slot] <= pair_data;
                fast_valid[fast_slot] <= 1;
                fast_pending <= 0;
            end else if (fast_wait && rom_owner && rom_ok) begin
                fast_addr[fast_slot] <= fast_request;
                fast_data[fast_slot] <= rom_data;
                fast_valid[fast_slot] <= 1;
                fast_pending <= 0;
                pair_data <= rom_data;
                pair_addr <= fast_request;
                pair_valid <= 1;
            end
        end
        case (dr_state)
            DR_RUN: begin
                if (line_full) begin
                    dr_cnt <= 0;
                    dr_state <= DR_DRAIN;
                end else if (cov_chunk[d_x[2:0]]) begin
                    if (d_x == d_lastx) begin
                        dr_cnt <= 0;
                        dr_state <= DR_DRAIN;
                    end else if ((&cov_chunk) && !d_repeat
                              && {1'b0,d_x} + {6'd0,jump_k} <= {1'b0,d_lastx}) begin
                        d_x <= d_x + {5'd0,jump_k};
                        d_col <= jump_col;
                        d_rem <= jump_rem;
                        cov_chunk <= covmap[{d_x[8:3]+5'd1,3'd0}+:8];
                    end else begin
                        d_x <= d_x + 1'b1;
                        d_col <= fast_next_col;
                        d_rem <= fast_next_rem;
                        if (d_x[2:0] == 3'd7) cov_chunk <= covmap[{d_x[8:3]+5'd1,3'd0}+:8];
                    end
                end else if (fast_hit) begin
                    fast_replace <= !fast_hit1;
                    pen <= fast_word[fast_nibble+:4];
                    color_valid[0] <= fast_word[fast_nibble+:4] != 0;
                    color_x0 <= d_x;
                    if (d_x == d_lastx) begin
                        dr_cnt <= 0;
                        dr_state <= DR_DRAIN;
                    end else begin
                        d_x <= d_x + 1'b1;
                        d_col <= fast_next_col;
                        d_rem <= fast_next_rem;
                        if (d_x[2:0] == 3'd7) cov_chunk <= covmap[{d_x[8:3]+5'd1,3'd0}+:8];
                        if (!fast_pending && fast_ahead_ready && fast_ahead_addr != fast_tile_addr && !fast_ahead_hit) begin
                            fast_slot <= !fast_hit1;
                            fast_request <= fast_ahead_addr;
                            fast_pending <= 1;
                            fast_wait <= 0;
                        end
                    end
                end else if (!fast_pending) begin
                    fast_slot <= fast_free_slot;
                    fast_request <= fast_tile_addr;
                    fast_pending <= 1;
                    fast_wait <= 0;
                end
            end
            DR_DRAIN: begin
                dr_cnt <= 1;
                if (dr_cnt) dr_state <= DR_IDLE;
            end
            default: ;
        endcase
        case (state)
            IDLE: ;
            CLUT_L: request(0,18'h3fe00 + {9'd0,clut_load},CLUT_L_DONE);
            CLUT_L_DONE: begin
                clut_l[clut_load] <= fetched;
                state <= CLUT_H;
            end
            CLUT_H: request(1,18'h3fe00 + {9'd0,clut_load},CLUT_H_DONE);
            CLUT_H_DONE: begin
                clut_h[clut_load] <= fetched;
                clut_load <= clut_load + 1'b1;
                if (&clut_load) begin
                    loaded <= 1;
                    state <= IDLE;
                end else state <= CLUT_L;
            end
            WAIT0: state <= WAIT1;
            WAIT1: if (!rom_owner && rom_ok) begin
                fetched <= request_bank ? rom_data[63:32] : rom_data[31:0];
                pair_data <= rom_data;
                pair_addr <= request_addr;
                pair_valid <= 1;
                state <= return_state;
            end
            ATTR_WAIT: begin
                if (list_valid) state <= ATTR;
                else if (!list_busy && !list_start) begin
                    object_index <= 0;
                    state <= NEXT;
                end
            end
            ATTR: if (line_full) state <= NEXT;
            else if (!list_valid && !list_busy && !list_start) begin
                object_index <= 0;
                state <= NEXT;
            end else if (list_valid) begin
                object_index <= list_index;
                for (i=0;i<6;i=i+1) attr[i] <= frame_data[i*16+:16];
                object_width <= frame_data[156:144];
                object_left <= frame_data[171:160];
                draw_page <= frame_data[180:176];
                draw_x <= frame_data[190:182];
                last_x <= frame_data[199:191];
                if (object_index != 0) frame_rd_addr <= {shadow_pass,object_index - 9'd1};
                if (target_y < {1'b0,first_line} || target_y >= {1'b0,end_line} ||
                    (frame_data[88:80] != 0 && span_covered)) state <= list_index == 0 ? NEXT : ATTR;
                else begin
                    fetched <= frame_data[127:96];
                    state <= HEADER;
                end
            end
            NEXT: begin
                if (object_index == 0 || line_full || (!list_busy && !list_start)) begin
                    if (dr_state != DR_IDLE || color_valid != 0 || write_enable) begin end
                    else if (!line_full && separate_lists && !shadow_pass && shadow_count != 0) begin
                        shadow_pass <= 1;
                        list_start <= 1;
                        object_index <= shadow_count - 1'b1;
                        frame_rd_addr <= {1'b1,shadow_count - 9'd1};
                        state <= ATTR_WAIT;
                    end else state <= IDLE;
                end
                else begin
                    object_index <= object_index - 1'b1;
                    state <= ATTR;
                end
            end
            HEADER: begin
                st = {24'd0,fetched[7:0]} & 32'hf8;
                sb = {23'd0,fetched[24],fetched[23:16]};
                sr = (sb - st + 7) >>> 3;
                top_line <= st[8:0];
                sb = st + sr*8;
                bottom_line <= sb[9:0];
                rows <= sr[6:0];
                repeat_line <= fetched[31];
                if (sr <= 0 || sr > 64) state <= NEXT;
                else if (rotation == 0) begin
                    dy = line_y - origin_y;
                    if (flip_y) dy = -dy - 1;
                    prep_dist <= dy[19:0];
                    state <= HEADER_MUL;
                end else if (draw_page != 0) state <= PREP;
                else begin
                    row <= 0;
                    request(1,{2'd0,attr[0]},DESC);
                end
            end
            HEADER_MUL: begin
                prep_col_product <= {prep_dist,7'd0} * scale_inverse;
                state <= HEADER_CHECK;
            end
            HEADER_CHECK: begin
                quotient = prep_col_product[58:32];
                if (quotient * scale > {9'd0,prep_dist,7'd0}) quotient = quotient - 1'b1;
                prep_raw_col <= quotient;
                state <= HEADER_DONE;
            end
            HEADER_DONE: begin
                source_line = {5'd0,prep_raw_col};
                source_row = (source_line - {23'd0,top_line}) >>> 3;
                if (source_line < top_line || source_line >= bottom_line) state <= NEXT;
                else begin
                    row <= source_row[5:0];
                    fast_line <= source_line[2:0];
                    request(!source_row[0],{2'd0,attr[0]} + {12'd0,source_row[6:1]} + {17'd0,source_row[0]},DESC);
                end
            end
            DESC: begin
                last_left <= {1'b0,fetched[15:8],3'd0};
                last_right <= ({5'd0,fetched[15:8]} + {5'd0,fetched[7:0]} + 13'd1) << 3;
                last_base <= {1'b0,fetched[31:16],1'b0};
                sr = ({24'd0,fetched[15:8]} + {24'd0,fetched[7:0]} + 1) * 8;
                if (sr > object_width) object_width <= sr[12:0];
                if (rotation == 0 || {1'b0,row} + 1'b1 == rows) state <= PREP;
                else begin
                    row <= row + 1'b1;
                    request(row[0],{2'd0,attr[0]} + {13'd0,row[5:1]} + 18'd1,DESC);
                end
            end
            PREP: begin
                bounds_walk <= 0;
                bound_left <= (last_left*scale + 127) >> 7;
                bound_right <= (last_right*scale + 127) >> 7;
                bound_top <= (top_line*scale) >> 7;
                bound_bottom <= (bottom_line*scale + 127) >> 7;
                bound_width <= (object_width*scale + 127) >> 7;
                pixel_x_min <= (object_left*scale + 127) >> 7;
                pixel_x_max <= (object_width*scale + 127) >> 7;
                pixel_y_min <= (top_line*scale + 127) >> 7;
                pixel_y_max <= (bottom_line*scale + 127) >> 7;
                state <= rotation != 0 && draw_page != 0 ? PREP_COORD : rotation == 0 || repeat_line ? BOUNDS_SCREEN : BOUNDS_ROT;
            end
            BOUNDS_ROT: begin
                for (i=0;i<4;i=i+1) begin
                    cx = i[0] ? bound_width : 0;
                    cy = i[1] ? bound_bottom : bound_top;
                    if (flip_x) cx = -cx;
                    if (flip_y) cy = -cy;
                    bound_rx[i] <= (cx <<< 8) - $signed(slope)*cy;
                    bound_ry[i] <= $signed(slope)*cx + (cy <<< 8);
                end
                state <= BOUNDS_REDUCE;
            end
            BOUNDS_REDUCE: begin
                for (i=0;i<2;i=i+1) begin
                    bound_minx[i] <= bound_rx[i*2] < bound_rx[i*2+1] ? bound_rx[i*2] : bound_rx[i*2+1];
                    bound_maxx[i] <= bound_rx[i*2] > bound_rx[i*2+1] ? bound_rx[i*2] : bound_rx[i*2+1];
                    bound_miny[i] <= bound_ry[i*2] < bound_ry[i*2+1] ? bound_ry[i*2] : bound_ry[i*2+1];
                    bound_maxy[i] <= bound_ry[i*2] > bound_ry[i*2+1] ? bound_ry[i*2] : bound_ry[i*2+1];
                end
                state <= BOUNDS_FINAL;
            end
            BOUNDS_FINAL: begin
                minx <= bound_minx[0] < bound_minx[1] ? bound_minx[0] : bound_minx[1];
                maxx <= bound_maxx[0] > bound_maxx[1] ? bound_maxx[0] : bound_maxx[1];
                miny <= bound_miny[0] < bound_miny[1] ? bound_miny[0] : bound_miny[1];
                maxy <= bound_maxy[0] > bound_maxy[1] ? bound_maxy[0] : bound_maxy[1];
                state <= BOUNDS_SCREEN;
            end
            BOUNDS_SCREEN: begin
                if (bounds_walk) begin
                    first_x <= 0;
                    end_x <= 319;
                    if (!walk_valid) begin miny <= 0; maxy <= 0; end
                    else if (rotation == 0) begin
                        miny <= flip_y ? origin_y - bound_bottom : origin_y + bound_top;
                        maxy <= flip_y ? origin_y - bound_top : origin_y + bound_bottom;
                    end
                    else begin
                        first_x <= origin_x + (minx >>> 8) - 1;
                        end_x <= origin_x - ((-maxx) >>> 8) + 1;
                        miny <= origin_y + (miny >>> 8) - 1;
                        maxy <= origin_y - ((-maxy) >>> 8) + 2;
                    end
                end else begin
                    first_x <= 0;
                    end_x <= 319;
                    if (rotation == 0) begin
                        if (flip_x) begin
                            first_x <= repeat_line ? 0 : origin_x - bound_right;
                            end_x <= origin_x - bound_left - 1;
                        end else begin
                            first_x <= origin_x + bound_left;
                            end_x <= repeat_line ? 319 : origin_x + bound_right - 1;
                        end
                    end else if (!repeat_line) begin
                        first_x <= origin_x + (minx >>> 8) - 1;
                        end_x <= origin_x - ((-maxx) >>> 8) + 1;
                        miny <= origin_y + (miny >>> 8) - 1;
                        maxy <= origin_y - ((-maxy) >>> 8) + 1;
                    end
                end
                state <= BOUNDS_CLIP;
            end
            BOUNDS_CLIP: begin
                if (bounds_walk) begin
                    if (miny < 0) miny <= 0;
                    if (maxy > 240) maxy <= 240;
                    if (first_x < 0) first_x <= 0;
                    if (end_x > 319) end_x <= 319;
                    if (first_x > end_x || end_x < 0 || first_x > 319) walk_valid <= 0;
                end else begin
                    if (first_x < 0) first_x <= 0;
                    if (rotation != 0 && !repeat_line && (line_y < miny || line_y > maxy)) end_x <= -1;
                    else if (end_x > 319) end_x <= 319;
                end
                state <= BOUNDS_DONE;
            end
            BOUNDS_DONE: begin
                if (bounds_walk) begin
                    frame_we <= 1;
                    frame_wr_addr <= {build_shadow,walk_index};
                    frame_wr_data <= {8'd0,end_x[8:0],first_x[8:0],1'b0,walk_page,4'd0,object_left,3'd0,object_width,
                        bounds_empty ? 8'd0 : maxy[7:0],bounds_empty ? 8'd0 : miny[7:0],
                        frame_header,frame_data[95:0]};
                    state <= WALK_NEXT;
                end else begin
                    if (first_x > end_x || end_x < 0 || first_x > 319) state <= NEXT;
                    else begin
                        draw_x <= first_x[8:0];
                        last_x <= end_x[8:0];
                        state <= PREP_COORD;
                    end
                end
            end
            PREP_COORD: begin
                if (rotation != 0 && dr_state != DR_IDLE) begin
                end else if (rotation != 0) begin
                    dx_fixed = $signed({25'd0,draw_x}) - $signed({{2{origin_x[31]}},origin_x});
                    dx_fixed = (dx_fixed <<< 16) + 34'sh8000;
                    dy_fixed = $signed({25'd0,target_y}) - $signed({{2{origin_y[31]}},origin_y});
                    dy_fixed = (dy_fixed <<< 16) + 34'sh8000;
                    coord_dx <= dx_fixed;
                    coord_dy <= dy_fixed;
                    state <= COORD_TILT;
                end else begin
                    dist_x = flip_x ? origin_x - {23'd0,draw_x} - 1 : {23'd0,draw_x} - origin_x;
                    prep_dist <= dist_x[19:0];
                    tile_count = ({19'd0,last_right} - {20'd0,last_left}) >> 3;
                    prep_count <= tile_count[8:0];
                    prep_inverse <= inverse[tile_count];
                    fast_span <= last_right - {1'b0,last_left};
                    state <= FAST_MUL;
                end
            end
            COORD_TILT: begin
                coord_tilt_x <= $signed(slope)*coord_dy;
                coord_tilt_y <= $signed(slope)*coord_dx;
                state <= COORD_MIX;
            end
            COORD_MIX: begin
                coord_mixed_x <= coord_dx + $signed(coord_tilt_x[41:8]);
                coord_mixed_y <= coord_dy - $signed(coord_tilt_y[41:8]);
                slope_scale = $signed(slope)*$signed({1'b0,shrink});
                step_y <= -$signed({{16{slope_scale[35]}},slope_scale,8'd0});
                step_x <= $signed({19'd0,shrink,16'd0});
                state <= COORD_FINAL;
            end
            COORD_FINAL: begin
                source_x <= coord_mixed_x * $signed({1'b0,shrink});
                source_y <= coord_mixed_y * $signed({1'b0,shrink});
                state <= PIPE_START;
            end
            FAST_MUL: begin
                prep_col_product <= {prep_dist,7'd0} * scale_inverse;
                prep_step_product <= 27'd128 * scale_inverse;
                state <= FAST_CHECK;
            end
            FAST_CHECK: begin
                quotient = prep_col_product[58:32];
                if (quotient * scale > {9'd0,prep_dist,7'd0}) quotient = quotient - 1'b1;
                source_col = {5'd0,quotient};
                quotient = prep_step_product[58:32];
                if (quotient * scale > 36'd128) quotient = quotient - 1'b1;
                tile_delta = {5'd0,quotient};
                prep_raw_col <= source_col[26:0];
                prep_raw_step <= tile_delta[26:0];
                prep_delta <= tile_delta;
                state <= FAST_REM;
            end
            FAST_REM: begin
                prep_col <= {5'd0,prep_raw_col} - {20'd0,last_left};
                cx = {12'd0,prep_dist}*128 - {5'd0,prep_raw_col}*scale;
                fast_rem <= cx[8:0];
                cx = 128 - {5'd0,prep_raw_step}*scale;
                fast_step_rem <= cx[8:0];
                state <= FAST_MOD_MUL;
            end
            FAST_MOD_MUL: begin
                if (repeat_line) begin
                    prep_col_product <= prep_col[29:3] * prep_inverse;
                    prep_step_product <= prep_delta[29:3] * prep_inverse;
                    state <= FAST_MOD_CHECK;
                end else begin
                    fast_col <= prep_col[19:0];
                    fast_step <= prep_delta[8:0];
                    state <= FAST;
                end
            end
            FAST_MOD_CHECK: begin
                quotient = prep_col_product[58:32];
                prep_col_quotient <= quotient * prep_count > {9'd0,prep_col[29:3]} ? quotient - 1'b1 : quotient;
                quotient = prep_step_product[58:32];
                prep_step_quotient <= quotient * prep_count > {9'd0,prep_delta[29:3]} ? quotient - 1'b1 : quotient;
                state <= FAST_MOD_END;
            end
            FAST_MOD_END: begin
                source_col = prep_col - ((prep_col_quotient * prep_count) << 3);
                tile_delta = prep_delta - ((prep_step_quotient * prep_count) << 3);
                fast_col <= source_col[19:0];
                fast_step <= tile_delta[8:0];
                state <= FAST;
            end
            FAST: if (dr_state == DR_IDLE) begin
                if (!fast_pending && !fast_start_hit) begin
                    fast_slot <= fast_free_slot;
                    fast_request <= fast_start_addr;
                    fast_pending <= 1;
                    fast_wait <= 0;
                end
                d_col <= fast_col;
                d_rem <= fast_rem;
                d_step <= fast_step;
                d_step_rem <= fast_step_rem;
                for (i=0;i<8;i=i+1) begin
                    jump_steps[i] <= {3'd0,fast_step} * (12'd8 - {8'd0,i[3:0]});
                    jump_remainders[i] <= {3'd0,fast_step_rem} * (12'd8 - {8'd0,i[3:0]});
                end
                d_span <= fast_span;
                d_line <= fast_line;
                d_x <= draw_x;
                d_lastx <= last_x;
                d_scale <= scale;
                d_flip <= flip_x;
                d_repeat <= repeat_line;
                d_base <= last_base;
                d_color <= attr[1][10:3];
                cov_chunk <= covmap[{draw_x[8:3],3'd0}+:8];
                dr_state <= DR_RUN;
                state <= NEXT;
            end
            PIPE_START: begin
                pipe_start <= 1;
                state <= PIPE_RUN;
            end
            PIPE_RUN: begin
                if (pipe_valid) begin
                    if (pipe_pixel[47:39] != target_y || covmap[pipe_pixel[30:22]] || line_full) begin end
                    else if (pipe_hit) begin
                        pen <= pipe_word[{pipe_pixel[3:0],2'b00}+:4];
                        color_valid[0] <= pipe_word[{pipe_pixel[3:0],2'b00}+:4] != 0;
                        color_x0 <= pipe_pixel[30:22];
                        pipe_palette <= pipe_pixel[38:31];
                    end else begin
                        tile_addr <= pipe_pixel[21:4];
                        nibble <= pipe_pixel[2:0];
                        draw_x <= pipe_pixel[30:22];
                        request(pipe_pixel[3],pipe_pixel[21:4],PIPE_GFX);
                    end
                    if (!fast_pending && pipe_ahead_valid && pipe_ahead_addr != pipe_pixel[21:4] &&
                        !pipe_ahead_hit) begin
                        fast_request <= pipe_ahead_addr;
                        fast_slot <= fast_free_slot;
                        fast_pending <= 1;
                        fast_wait <= 0;
                    end
                end else if (!pipe_busy && !pipe_start) state <= NEXT;
            end
            PIPE_GFX: begin
                cached_addr <= tile_addr;
                cached_data <= pair_data;
                cache_valid <= 1;
                pen <= fetched[{nibble,2'b00}+:4];
                color_valid[0] <= fetched[{nibble,2'b00}+:4] != 0;
                color_x0 <= draw_x;
                pipe_palette <= pipe_pixel[38:31];
                state <= PIPE_RUN;
            end
            SNAP_WAIT: begin
                ram_addr <= list_base + {2'd0,offset} + 1'b1;
                attr_step <= 0;
                state <= SNAP_ATTR;
            end
            SNAP_ATTR: begin
                attr[attr_step] <= ram_data;
                ram_addr <= ram_addr + 1'b1;
                attr_step <= attr_step + 1'b1;
                if (attr_step == 5) begin
                    frame_we <= 1;
                    frame_wr_addr <= {build_shadow,snap_index};
                    frame_wr_data <= {112'd0,ram_data,attr[4],attr[3],attr[2],attr[1],attr[0]};
                    if (attr[0] == 16'hffff || attr[4] == 16'hffff) begin
                        if (build_shadow) shadow_count <= snap_index;
                        else object_count <= snap_index;
                        state <= WALK_INIT;
                    end else if (snap_index == 341) begin
                        if (build_shadow) shadow_count <= 342;
                        else object_count <= 342;
                        state <= WALK_INIT;
                    end else begin
                        snap_index <= snap_index + 1'b1;
                        offset <= offset + 11'd6;
                        ram_addr <= list_base + {2'd0,offset} + 13'd6;
                        state <= SNAP_WAIT;
                    end
                end
            end
            WALK_INIT: begin
                walk_index <= 0;
                frame_rd_addr <= {build_shadow,9'd0};
                state <= WALK_WAIT;
            end
            WALK_WAIT: begin
                if (walk_count == 0) state <= WALK_NEXT;
                else state <= WALK_LOAD;
            end
            WALK_LOAD: begin
                for (i=0;i<6;i=i+1) attr[i] <= frame_data[i*16+:16];
                frame_header <= 0;
                object_width <= 0;
                object_left <= 12'hfff;
                walk_valid <= 0;
                state <= WALK_FETCH;
            end
            WALK_FETCH: begin
                page_hit <= lookup_page != 0;
                walk_page <= 0;
                if (rotation != 0 && scale != 0 && attr[0] < 16'h4000) begin
                    if (lookup_page != 0) walk_page <= lookup_page;
                    else if (page_count < 31) begin
                        walk_page <= page_count+1'b1;
                        page_id[page_count] <= attr[0][13:0];
                        page_count <= page_count+1'b1;
                    end
                end
                if (attr[0] >= 16'h4000 || scale == 0) state <= WALK_STORE;
                else request(0,{2'd0,attr[0]},WALK_HEADER);
            end
            WALK_HEADER: begin
                st = {24'd0,fetched[7:0]} & 32'hf8;
                sb = {23'd0,fetched[24],fetched[23:16]};
                sr = (sb - st + 7) >>> 3;
                frame_header <= fetched;
                top_line <= st[8:0];
                sb = st + sr*8;
                bottom_line <= sb[9:0];
                rows <= sr[6:0];
                repeat_line <= fetched[31];
                walk_valid <= sr > 0 && sr <= 64;
                if (sr <= 0 || sr > 64 || rotation == 0) begin
                    walk_page <= 0;
                    state <= WALK_STORE;
                end else if (page_hit) begin
                    object_width <= page_width[walk_page-1'b1];
                    object_left <= page_left[walk_page-1'b1];
                    state <= WALK_STORE;
                end else begin
                    row <= 0;
                    request(1,{2'd0,attr[0]},WALK_DESC);
                end
            end
            WALK_DESC: begin
                if ({1'b0,fetched[15:8],3'd0}<object_left) object_left <= {1'b0,fetched[15:8],3'd0};
                sr = ({24'd0,fetched[15:8]} + {24'd0,fetched[7:0]} + 1) * 8;
                if (sr > object_width) object_width <= sr[12:0];
                if ({1'b0,row} + 1'b1 == rows) state <= WALK_STORE;
                else begin
                    row <= row + 1'b1;
                    request(row[0],{2'd0,attr[0]} + {13'd0,row[5:1]} + 18'd1,WALK_DESC);
                end
            end
            WALK_STORE: begin
                if (walk_page != 0 && !page_hit && walk_valid) begin
                    page_valid[walk_page-1'b1] <= 1;
                    page_width[walk_page-1'b1] <= object_width;
                    page_left[walk_page-1'b1] <= object_left;
                end
                bounds_walk <= 1;
                bound_left <= 0;
                bound_right <= 0;
                bound_top <= (top_line*scale + (rotation == 0 ? 127 : 0)) >> 7;
                bound_bottom <= (bottom_line*scale + 127) >> 7;
                bound_width <= (object_width*scale + 127) >> 7;
                if (walk_valid && repeat_line) begin
                    bounds_start <= 1;
                    state <= REPEAT_WAIT;
                end else state <= !walk_valid || rotation == 0 ? BOUNDS_SCREEN : BOUNDS_ROT;
            end
            REPEAT_WAIT: if (bounds_done) begin
                if (repeat_reject) begin
                    walk_valid <= 0;
                    state <= BOUNDS_SCREEN;
                end else begin
                    bound_width <= repeat_extent;
                    state <= rotation == 0 ? BOUNDS_SCREEN : BOUNDS_ROT;
                end
            end
            WALK_NEXT: begin
                if (walk_count == 0 || walk_index + 9'd1 == walk_count) begin
                    if (separate_lists && !build_shadow) begin
                        build_shadow <= 1;
                        snap_index <= 0;
                        offset <= 0;
                        list_base <= {shadow_base,12'd0};
                        ram_addr <= {shadow_base,12'd0};
                        state <= SNAP_WAIT;
                    end else begin
                        frame_ready <= 1;
                        state <= IDLE;
                    end
                end else begin
                    walk_index <= walk_index + 1'b1;
                    frame_rd_addr <= {build_shadow,walk_index + 9'd1};
                    state <= WALK_WAIT;
                end
            end
            CTRL_WAIT: state <= CTRL_SELECT;
            CTRL_SELECT: begin
                separate_lists <= ctrl_data[12] != list_base[12];
                shadow_base <= ctrl_data[12];
                ctrl_select <= 0;
                state <= SNAP_WAIT;
            end
            default: state <= IDLE;
        endcase
        if (drawing && h == 397) begin
            if (state != IDLE || dr_state != DR_IDLE) overflow <= 1;
            drawing <= 0;
            closing <= 1;
        end
        if (closing || (drawing && h == 397)) begin
            dr_state <= DR_IDLE;
            pipe_start <= 0;
            color_valid[0] <= 0;
            return_state <= IDLE;
            state <= fsm_req && !(state == WAIT1 && !rom_owner && rom_ok) ? WAIT1 : IDLE;
        end
        if (line_start && loaded) begin
            launch_pending <= v == 240 || v == 279 || v < 240;
            launch_v <= v;
        end
        if (launch_pending && !fsm_req && !fast_pending && !rom_owner) begin
            launch_pending <= 0;
            closing <= 0;
            dr_state <= DR_IDLE;
            if (launch_v == 240) begin
                frame_ready <= 0;
                frame_valid <= 0;
                snap_index <= 0;
                offset <= 0;
                list_base <= {ctrl_data[12],12'd0};
                ram_addr <= {ctrl_data[12],12'd0};
                build_shadow <= 0;
                page_valid <= 0;
                page_count <= 0;
                ctrl_select <= 1;
                state <= CTRL_WAIT;
            end else begin
                shadow_pass <= first_shadow;
                list_start <= 1;
                if (launch_v == 279) begin
                    frame_valid <= frame_ready;
                    overflow <= !frame_ready;
                end
                covmap <= 0;
                cover_cnt <= 0;
                target_y <= launch_y;
                object_index <= first_count - 1'b1;
                frame_rd_addr <= {first_shadow,first_count - 9'd1};
                drawing <= launch_y < 240 && first_count != 0 && (launch_v == 279 ? frame_ready : frame_valid);
                state <= launch_y < 240 && first_count != 0 && (launch_v == 279 ? frame_ready : frame_valid) ? ATTR_WAIT : IDLE;
            end
        end
    end
end

`ifdef SIMULATION
`ifdef APACH3_OBJ_PROFILE
integer prof_color_missed=0;
integer prof_lines=0, prof_missed=0, prof_busy=0, prof_pixels=0, prof_wait=0, prof_responses=0;
always @(posedge clk) begin
    if (rst) begin
        prof_lines <= 0;
        prof_color_missed <= 0;
        prof_missed <= 0;
        prof_busy <= 0;
        prof_pixels <= 0;
        prof_wait <= 0;
        prof_responses <= 0;
    end else begin
        if (drawing && (state != IDLE || dr_state != DR_IDLE)) prof_busy <= prof_busy+1;
        if (write_enable) prof_pixels <= prof_pixels+1;
        if (rom_cs && !rom_ok) prof_wait <= prof_wait+1;
        if ((state == WAIT1 && !rom_owner && rom_ok) || (fast_wait && rom_owner && rom_ok && fast_pending)) prof_responses <= prof_responses+1;
        if (drawing && h == 397) begin
            prof_lines <= prof_lines+1;
            if (!shadow_pass && (state != IDLE || dr_state != DR_IDLE)) prof_color_missed <= prof_color_missed+1;
            if (state != IDLE || dr_state != DR_IDLE) prof_missed <= prof_missed+1;
        end
        if (line_start && v == 240) begin
            $display("OBJ_COLOR_MISSED %0d",prof_color_missed);
            $display("OBJ_PROFILE lines=%0d missed=%0d busy=%0d pixels=%0d rom_wait=%0d responses=%0d",prof_lines,prof_missed,prof_busy,prof_pixels,prof_wait,prof_responses);
            prof_lines <= 0;
            prof_color_missed <= 0;
            prof_missed <= 0;
            prof_busy <= 0;
            prof_pixels <= 0;
            prof_wait <= 0;
            prof_responses <= 0;
        end
    end
end
`endif
`endif

`ifdef SIMULATION
`ifdef APACH3_OBJ_DETAIL
integer detail_frame=0, detail_k;
integer detail_states [0:63];
integer detail_cycles [0:341];
integer detail_desc [0:341];
integer detail_tex [0:341];
integer detail_left [0:341];
integer detail_right [0:341];
integer detail_visits [0:341];
integer detail_launches [0:341];
reg [95:0] detail_attrs [0:341];
integer detail_line_cycles=0, detail_line_left=0, detail_line_right=0;
integer detail_meta=0, detail_texture=0, detail_empty=0, detail_hit=0, detail_issue=0, detail_covered=0;
always @(posedge clk) begin
    if (rst) begin
        detail_frame <= 0;
        detail_line_cycles <= 0;
        detail_line_left <= 0;
        detail_line_right <= 0;
        detail_meta <= 0;
        detail_texture <= 0;
        detail_empty <= 0;
        detail_hit <= 0;
        detail_issue <= 0;
        detail_covered <= 0;
        for (detail_k=0;detail_k<64;detail_k=detail_k+1) detail_states[detail_k]=0;
        for (detail_k=0;detail_k<342;detail_k=detail_k+1) begin
            detail_cycles[detail_k]=0;
            detail_desc[detail_k]=0;
            detail_tex[detail_k]=0;
            detail_left[detail_k]=0;
            detail_right[detail_k]=0;
            detail_visits[detail_k]=0;
            detail_launches[detail_k]=0;
            detail_attrs[detail_k]=0;
        end
    end else begin
        if (drawing) begin
            detail_line_cycles <= detail_line_cycles+1;
            detail_states[state]=detail_states[state]+1;
            if (object_index<342) detail_cycles[object_index]=detail_cycles[object_index]+1;
            if (state==ATTR && list_valid && list_index<342) detail_visits[list_index]=detail_visits[list_index]+1;
            if (state==HEADER && object_index<342) begin
                detail_attrs[object_index]={attr[5],attr[4],attr[3],attr[2],attr[1],attr[0]};
            end
            if ((state==PIPE_START || state==FAST) && object_index<342) detail_launches[object_index]=detail_launches[object_index]+1;
            if (fsm_req) begin
                if (return_state==PIPE_GFX) begin
                    detail_texture <= detail_texture+1;
                    if (object_index<342) detail_tex[object_index]=detail_tex[object_index]+1;
                end else begin
                    detail_meta <= detail_meta+1;
                    if (object_index<342) detail_desc[object_index]=detail_desc[object_index]+1;
                end
            end
            if (state==PIPE_RUN) begin
                if (!pipe_valid && pipe_busy) detail_empty <= detail_empty+1;
                else if (pipe_pop) begin
                    if (covmap[pipe_pixel[30:22]] || line_full) detail_covered <= detail_covered+1;
                    else detail_hit <= detail_hit+1;
                end else if (pipe_valid) detail_issue <= detail_issue+1;
            end
            if (write_enable) begin
                if (write_x<160) begin
                    detail_line_left <= detail_line_left+1;
                    if (object_index<342) detail_left[object_index]=detail_left[object_index]+1;
                end else begin
                    detail_line_right <= detail_line_right+1;
                    if (object_index<342) detail_right[object_index]=detail_right[object_index]+1;
                end
            end
            if (h==397) begin
                $display("OBJ_LINE f=%0d y=%0d cycles=%0d left=%0d right=%0d stop_i=%0d attr=%h state=%0d head_x=%0d fifo=%0d producer_x=%0d",detail_frame,target_y,detail_line_cycles,detail_line_left,detail_line_right,object_index,attr[0],state,pipe_pixel[30:22],u_pipe.count,u_pipe.x);
                detail_line_cycles <= 0;
                detail_line_left <= 0;
                detail_line_right <= 0;
            end
        end
        if (line_start && v==240) begin
            $display("OBJ_TOTAL f=%0d meta=%0d texture=%0d empty=%0d hit=%0d miss_issue=%0d covered=%0d",detail_frame,detail_meta,detail_texture,detail_empty,detail_hit,detail_issue,detail_covered);
            for (detail_k=0;detail_k<64;detail_k=detail_k+1) begin
                if (detail_states[detail_k]!=0) $display("OBJ_STATE f=%0d s=%0d clocks=%0d",detail_frame,detail_k,detail_states[detail_k]);
                detail_states[detail_k]=0;
            end
            for (detail_k=0;detail_k<342;detail_k=detail_k+1) begin
                if (detail_cycles[detail_k]!=0) $display("OBJ_JOB f=%0d i=%0d clocks=%0d meta=%0d texture=%0d visits=%0d launches=%0d left=%0d right=%0d attrs=%h",detail_frame,detail_k,detail_cycles[detail_k],detail_desc[detail_k],detail_tex[detail_k],detail_visits[detail_k],detail_launches[detail_k],detail_left[detail_k],detail_right[detail_k],detail_attrs[detail_k]);
                detail_cycles[detail_k]=0;
                detail_desc[detail_k]=0;
                detail_tex[detail_k]=0;
                detail_left[detail_k]=0;
                detail_right[detail_k]=0;
                detail_visits[detail_k]=0;
                detail_launches[detail_k]=0;
            end
            detail_frame <= detail_frame+1;
            detail_meta <= 0;
            detail_texture <= 0;
            detail_empty <= 0;
            detail_hit <= 0;
            detail_issue <= 0;
            detail_covered <= 0;
        end
    end
end
`endif
`endif

`ifdef SIMULATION
`ifdef APACH3_OBJ_TRAFFIC
integer trace_frame=0, trace_x;
reg [8:0] trace_color;
reg trace_shadow;
reg [8:0] trace_h;
always @(posedge clk) begin
    trace_h <= h;
    if (line_start && v == 240) trace_frame <= trace_frame+1;
    if (dr_state == DR_RUN && !line_full && !cov_chunk[d_x[2:0]] && fast_hit)
        $display("OBJ_ACCESS kind=T addr=%0d part=%0d nibble=%0d pass=%0d",fast_tile_addr,fast_nibble[5:4],fast_nibble[5:2],shadow_pass);
    if (pipe_pop && pipe_valid && pipe_pixel[47:39] == target_y && !covmap[pipe_pixel[30:22]]) begin
        $display("OBJ_ACCESS kind=T addr=%0d part=%0d nibble=%0d pass=%0d",pipe_pixel[21:4],pipe_pixel[3:2],pipe_pixel[3:0],shadow_pass);
    end
    if (h == 398 && trace_h != 398 && target_y < 240 && (v < 239 || v == 279)) begin
        for (trace_x=0;trace_x<320;trace_x=trace_x+1) begin
            trace_color=u_buffer.u_line.u_ram.mem[{u_buffer.line,trace_x[8:0]}];
            trace_shadow=u_buffer.line ? u_buffer.genblk1.u_shadow0.u_ram.mem[trace_x] : u_buffer.genblk1.u_shadow1.u_ram.mem[trace_x];
            if (trace_color[8] || trace_shadow)
                $display("OBJ_OUT f=%0d y=%0d x=%0d c=%0d s=%0d",trace_frame,target_y,trace_x,trace_color,trace_shadow);
        end
    end
end
`endif
`endif

`ifdef SIMULATION
`ifdef APACH3_OBJ_SDRAM_STATS
integer board_fills=0, board_ground=0, board_cpu=0, board_sound=0;
always @(posedge clk) begin
    if ($root.game_test.ba_ack[0]) board_cpu <= board_cpu+1;
    if ($root.game_test.ba_ack[1]) board_fills <= board_fills+1;
    if ($root.game_test.ba_ack[2]) board_ground <= board_ground+1;
    if ($root.game_test.ba_ack[3]) board_sound <= board_sound+1;
    if (line_start && v == 240) begin
        $display("OBJ_SDRAM sprite=%0d ground=%0d cpu=%0d sound=%0d",board_fills,board_ground,board_cpu,board_sound);
        board_fills <= 0;
        board_ground <= 0;
        board_cpu <= 0;
        board_sound <= 0;
    end
end
`endif
`endif

endmodule
