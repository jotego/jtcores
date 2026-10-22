/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 19-10-2026 */

module jtroundu_obj(
    input              rst,
    input              clk,
    input              pxl_cen,
    input        [8:0] h,
    input        [8:0] v,
    output reg  [13:1] ram_addr,
    input       [15:0] ram_data,
    output       [8:1] ctrl_addr,
    input       [15:0] ctrl_data,
    output      [19:2] rom_l_addr,
    output             rom_l_cs,
    input       [31:0] rom_l_data,
    input              rom_l_ok,
    output      [19:2] rom_h_addr,
    output             rom_h_cs,
    input       [31:0] rom_h_data,
    input              rom_h_ok,
    output       [9:0] pxl,
    output reg         overflow
);

localparam IDLE=0, CLUT_L=1, CLUT_L_DONE=2, CLUT_H=3, CLUT_H_DONE=4,
    WAIT0=5, WAIT1=6, ATTR_WAIT=7, ATTR=8, ATTR_DONE=9, NEXT=10,
    HEADER=11, DESC=12, PREP=13, PIXEL=14, TILE=15, GFX=16,
    SNAP_WAIT=17, SNAP_ATTR=18, WALK_INIT=19, WALK_WAIT=20,
    WALK_LOAD=21, WALK_FETCH=22, WALK_HEADER=23, WALK_DESC=24,
    WALK_STORE=25, WALK_NEXT=26, FAST=27, FAST_DONE=28,
    PREP_COORD=29, FAST_MUL=30, FAST_CHECK=31, FAST_MOD_MUL=32,
    FAST_MOD_CHECK=33, FAST_MOD_END=34, HEADER_MUL=35, HEADER_CHECK=36,
    HEADER_DONE=37, FAST_REM=38, BOUNDS_ROT=39, BOUNDS_FINAL=40,
    COORD_MIX=41, COORD_FINAL=42, PIXEL_MUL=43, PIXEL_CHECK=44,
    PIXEL_LOOKUP=45, PIXEL_WRAP_MUL=46, PIXEL_WRAP_CHECK=47,
    PIXEL_TILE=48, BOUNDS_REDUCE=49, COORD_TILT=50, PIXEL_WRAP_END=51;
reg [5:0] state, return_state;
localparam DR_IDLE=0, DR_RUN=1, DR_DRAIN=2;
reg [1:0] dr_state;
reg dr_cnt;
reg [17:0] request_addr;
reg request_bank;
reg [31:0] fetched;
reg [8:0] clut_load;
reg loaded;
reg [31:0] clut_l [0:511];
reg [31:0] clut_h [0:511];
reg [31:0] clut_l_q, clut_h_q;
reg [32:0] inverse [0:511];
reg [24:0] shrink_table [0:256];
reg [32:0] scale_inverse;
reg [24:0] shrink;
reg [15:0] attr [0:5];
reg [2:0] attr_step;
reg [12:0] list_base;
reg [10:0] offset;
reg [8:0] snap_index, walk_index, object_index, object_count;
reg [8:0] frame_wr_addr, frame_rd_addr;
reg [159:0] frame_wr_data;
wire [159:0] frame_data;
reg frame_we, frame_ready, frame_valid, walk_valid;
reg [31:0] frame_header;
reg [7:0] first_line, end_line;
reg [8:0] target_y;
reg [6:0] rows;
reg [8:0] top_line;
reg [9:0] bottom_line;
reg repeat_line;
reg [5:0] row;
reg [11:0] run_left [0:63];
reg [12:0] run_right [0:63];
reg [17:0] run_base [0:63];
reg [11:0] last_left, row_left;
reg [12:0] last_right, row_right;
reg [17:0] last_base, row_base;
reg [12:0] object_width;
reg [8:0] draw_x, last_x;
reg signed [59:0] source_x, source_y, step_x, step_y;
reg [17:0] tile_addr, cached_addr;
reg tile_bank, cached_bank, cache_valid;
reg [31:0] cached_data;
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
reg [19:0] pixel_dist_x, pixel_dist_y;
reg [31:0] pixel_y_min, pixel_y_max;
reg [26:0] pixel_line, pixel_col;
reg [17:0] pixel_base;
reg [8:0] pixel_count;
reg [32:0] pixel_inverse;
reg [26:0] pixel_delta, pixel_quotient, pixel_wrapped;
reg [8:0] fast_rem, fast_next_rem, fast_step, fast_step_rem;
reg [12:0] fast_span;
reg [2:0] fast_line;
reg [17:0] fast_addr [0:1];
reg [31:0] fast_data [0:1];
reg [1:0] fast_valid;
reg fast_pending, fast_wait, fast_bank;
reg [17:0] fast_request;
reg [17:0] fast_tile_addr, fast_ahead_addr;
reg fast_tile_bank, fast_ahead_bank;
integer fast_delta, fast_r, fast_c, fast_tile, fast_ahead;
wire fast_hit = fast_valid[fast_tile_bank] && fast_addr[fast_tile_bank] == fast_tile_addr;
wire fast_ahead_hit = fast_valid[fast_ahead_bank] && fast_addr[fast_ahead_bank] == fast_ahead_addr;
reg [319:0] covmap, shaded;
reg [8:0] cover_cnt;
wire line_full = cover_cnt == 9'd320;
reg [7:0] cov_chunk;
reg [19:0] d_col;
reg [8:0] d_rem, d_step, d_step_rem, d_scale;
reg [12:0] d_span;
reg [2:0] d_line;
reg [8:0] d_x, d_lastx;
reg d_flip, d_repeat;
reg [17:0] d_base;
reg [7:0] d_color;
reg [2:0] nibble;
reg [3:0] pen;
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
wire [11:0] color_index = {dr_state != DR_IDLE ? d_color : attr[1][10:3],pen};
wire [31:0] clut_word = color_select[2] ? clut_h_q : clut_l_q;
wire [4:0] clut_shift = {color_select[1:0] ^ 2'b01,3'b000};
wire [7:0] clut_color = clut_word[clut_shift+:8];
wire line_start = pxl_cen && h == 0;
wire [8:0] next_y = v == 271 ? 9'd0 : v + 9'd1;
integer i, dy, source_line, source_col, source_row, dist_x, dist_y;
integer left_edge, right_edge, first_x, end_x, tile_number, tile_count, tile_delta;
integer st, sb, sr, cx, cy, rx, ry, minx, maxx, miny, maxy;
reg signed [33:0] dx_fixed, dy_fixed;
reg signed [35:0] slope_scale;
reg [40:0] init_shrink;
reg [26:0] quotient;

function [17:0] graphics_addr;
    input [17:0] tile;
    input [2:0] line;
    reg [16:0] physical;
    begin
        physical = tile[17:1];
        if (physical >= 98304) physical = physical - 17'd98304;
        if (physical >= 49152) physical = physical - 17'd49152;
        if (physical >= 24576) physical = physical - 17'd24576;
        graphics_addr = {physical[14:0],line};
    end
endfunction

reg [19:0] jump_col;
reg [8:0] jump_rem;
reg [3:0] jump_k;
reg [11:0] jump_kstep, jump_krem;
reg [12:0] jump_m [0:8];
reg [13:0] jump_tot, jump_u;
reg [7:0] jump_ge;
reg [3:0] jump_c;
integer jm;
// parallel k-step advance: products by shift select, carries by parallel
// compares against scale multiples and a popcount, instead of a serial chain
always @* begin
    jump_k = 4'd8 - {1'b0,d_x[2:0]};
    jump_kstep = ({3'd0,d_step} & {12{jump_k[0]}})
               + (({2'd0,d_step} << 1) & {12{jump_k[1]}})
               + (({1'd0,d_step} << 2) & {12{jump_k[2]}})
               + (({3'd0,d_step} << 3) & {12{jump_k[3]}});
    jump_krem  = ({3'd0,d_step_rem} & {12{jump_k[0]}})
               + (({2'd0,d_step_rem} << 1) & {12{jump_k[1]}})
               + (({1'd0,d_step_rem} << 2) & {12{jump_k[2]}})
               + (({3'd0,d_step_rem} << 3) & {12{jump_k[3]}});
    jump_m[0] = 0;
    jump_m[1] = {4'd0,d_scale};
    jump_m[2] = {3'd0,d_scale,1'd0};
    jump_m[3] = {3'd0,d_scale,1'd0} + {4'd0,d_scale};
    jump_m[4] = {2'd0,d_scale,2'd0};
    jump_m[5] = {2'd0,d_scale,2'd0} + {4'd0,d_scale};
    jump_m[6] = {2'd0,d_scale,2'd0} + {3'd0,d_scale,1'd0};
    jump_m[7] = {1'd0,d_scale,3'd0} - {4'd0,d_scale};
    jump_m[8] = {1'd0,d_scale,3'd0};
    if (d_flip) begin
        jump_u = {2'd0,jump_krem};
        for (jm=0; jm<8; jm=jm+1)
            jump_ge[jm] = jump_u > {1'd0,jump_m[jm]} + {5'd0,d_rem};
    end else begin
        jump_tot = {5'd0,d_rem} + {2'd0,jump_krem};
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
    fast_ahead = d_flip ? ({12'd0,d_col} & -8) - 8 : ({12'd0,d_col} & -8) + 8;
    if (d_scale < 16) fast_ahead = {12'd0,fast_next_col};
    if (d_repeat) begin
        if (fast_ahead < 0) fast_ahead = fast_ahead + {19'd0,d_span};
        else if (fast_ahead >= {19'd0,d_span}) fast_ahead = fast_ahead - {19'd0,d_span};
    end
    fast_tile = {14'd0,d_base} + (fast_ahead >> 3);
    fast_ahead_bank = fast_tile[0];
    fast_ahead_addr = graphics_addr(fast_tile[17:0],d_line);
end

task request;
    input bank;
    input [17:0] address;
    input [5:0] destination;
    begin
        request_bank <= bank;
        request_addr <= address;
        return_state <= destination;
        state <= WAIT0;
    end
endtask

task advance_pixel;
    begin
        if (draw_x == last_x) state <= NEXT;
        else begin
            draw_x <= draw_x + 1'b1;
            source_x <= source_x + step_x;
            source_y <= source_y + step_y;
            state <= PIXEL;
        end
    end
endtask

assign ctrl_addr = 8'he0;
// the ROM address must hold until data_ok, so the bus only changes owner
// while the previous owner has no request in flight
wire fsm_req = state == WAIT0 || state == WAIT1;
reg rom_owner;
assign rom_l_addr = rom_owner ? fast_request : request_addr;
assign rom_h_addr = rom_owner ? fast_request : request_addr;
assign rom_l_cs = rom_owner ? fast_pending && !fast_bank : fsm_req && !request_bank;
assign rom_h_cs = rom_owner ? fast_pending && fast_bank : fsm_req && request_bank;

initial begin
    inverse[0] = 0;
    for (i=1;i<512;i=i+1) inverse[i] = (33'h100000000 + {1'b0,i[31:0]} - 1'b1) / {1'b0,i[31:0]};
    for (i=0;i<257;i=i+1) begin
        init_shrink = 41'h10000000000 / (41'd65536 + {9'd0,i[31:0]}*{9'd0,i[31:0]});
        shrink_table[i] = init_shrink[24:0];
    end
end

// row descriptor read issued during PIXEL_CHECK, same expression as pixel_line
wire [26:0] lookup_raw  = prep_step_product[58:32];
wire [26:0] lookup_line = lookup_raw*scale > {9'd0,pixel_dist_y,7'd0} ? lookup_raw - 1'b1 : lookup_raw;
wire [31:0] lookup_row  = ({5'd0,lookup_line} - {23'd0,top_line}) >> 3;

always @(posedge clk) begin
    scale_inverse <= inverse[scale];
    shrink <= shrink_table[slope_abs];
    clut_l_q <= clut_l[color_index[11:3]];
    clut_h_q <= clut_h[color_index[11:3]];
    color_select <= color_index[2:0];
    row_left  <= run_left [lookup_row[5:0]];
    row_right <= run_right[lookup_row[5:0]];
    row_base  <= run_base [lookup_row[5:0]];
    if (rst) read_x <= 0;
    else if (pxl_cen) read_x <= h;
end

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
    .LHBL    ( h != 0       ),
    .flip    ( 1'b0         ),
    .wr_data ( write_data   ),
    .wr_addr ( write_x      ),
    .we      ( write_enable ),
    .rd_addr ( read_x       ),
    .rd      ( pxl_cen      ),
    .rd_data ( pxl          )
);

jtframe_dual_ram #(
    .AW ( 9   ),
    .DW ( 160 )
) u_frame_list (
    .clk0  ( clk           ),
    .data0 ( frame_wr_data ),
    .addr0 ( frame_wr_addr ),
    .we0   ( frame_we      ),
    .q0    (               ),
    .clk1  ( clk           ),
    .data1 ( 160'd0        ),
    .addr1 ( frame_rd_addr ),
    .we1   ( 1'b0          ),
    .q1    ( frame_data    )
);

always @(posedge clk) begin
    frame_we <= 0;
    write_enable <= 0;
    color_valid <= {color_valid[0],1'b0};
    color_x1 <= color_x0;
    if (color_valid[1]) begin
        write_x <= color_x1;
        write_data <= {clut_color == 8'hff || shaded[color_x1],1'b1,clut_color};
        write_enable <= 1;
        if (clut_color == 8'hff) shaded[color_x1] <= 1;
        else begin
            covmap[color_x1] <= 1;
            cover_cnt <= cover_cnt + 1'b1;
        end
    end
    if (rst) begin
        state <= CLUT_L;
        return_state <= IDLE;
        request_addr <= 0;
        request_bank <= 0;
        clut_load <= 0;
        loaded <= 0;
        ram_addr <= 0;
        attr_step <= 0;
        list_base <= 0;
        offset <= 0;
        snap_index <= 0;
        walk_index <= 0;
        object_index <= 0;
        object_count <= 0;
        frame_wr_addr <= 0;
        frame_rd_addr <= 0;
        frame_wr_data <= 0;
        frame_we <= 0;
        frame_ready <= 0;
        frame_valid <= 0;
        walk_valid <= 0;
        frame_header <= 0;
        first_line <= 0;
        end_line <= 0;
        target_y <= 0;
        rows <= 0;
        top_line <= 0;
        bottom_line <= 0;
        repeat_line <= 0;
        row <= 0;
        object_width <= 0;
        draw_x <= 0;
        last_x <= 0;
        source_x <= 0;
        source_y <= 0;
        step_x <= 0;
        step_y <= 0;
        tile_addr <= 0;
        tile_bank <= 0;
        cached_addr <= 0;
        cached_bank <= 0;
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
        fast_bank <= 0;
        fast_request <= 0;
        rom_owner <= 0;
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
        shaded <= 0;
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
        if (fast_pending) begin
            fast_wait <= rom_owner;
            if (fast_wait && rom_owner && (fast_bank ? rom_h_ok : rom_l_ok)) begin
                fast_addr[fast_bank] <= fast_request;
                fast_data[fast_bank] <= fast_bank ? rom_h_data : rom_l_data;
                fast_valid[fast_bank] <= 1;
                fast_pending <= 0;
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
                    pen <= fast_data[fast_tile_bank][{d_col[2:0] ^ 3'd3,2'b00}+:4];
                    color_valid[0] <= fast_data[fast_tile_bank][{d_col[2:0] ^ 3'd3,2'b00}+:4] != 0;
                    color_x0 <= d_x;
                    if (d_x == d_lastx) begin
                        dr_cnt <= 0;
                        dr_state <= DR_DRAIN;
                    end else begin
                        d_x <= d_x + 1'b1;
                        d_col <= fast_next_col;
                        d_rem <= fast_next_rem;
                        if (d_x[2:0] == 3'd7) cov_chunk <= covmap[{d_x[8:3]+5'd1,3'd0}+:8];
                        if (!fast_pending && fast_ahead_bank != fast_tile_bank && !fast_ahead_hit
                         && (d_repeat || (fast_ahead >= 0 && fast_ahead < {19'd0,d_span}))) begin
                            fast_bank <= fast_ahead_bank;
                            fast_request <= fast_ahead_addr;
                            fast_pending <= 1;
                            fast_wait <= 0;
                        end
                    end
                end else if (!fast_pending) begin
                    fast_bank <= fast_tile_bank;
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
            CLUT_L: request(0,18'h2fe00 + {9'd0,clut_load},CLUT_L_DONE);
            CLUT_L_DONE: begin
                clut_l[clut_load] <= fetched;
                state <= CLUT_H;
            end
            CLUT_H: request(1,18'h2fe00 + {9'd0,clut_load},CLUT_H_DONE);
            CLUT_H_DONE: begin
                clut_h[clut_load] <= fetched;
                clut_load <= clut_load + 1'b1;
                if (&clut_load) begin
                    loaded <= 1;
                    state <= IDLE;
                end else state <= CLUT_L;
            end
            WAIT0: state <= WAIT1;
            WAIT1: if (!rom_owner && (request_bank ? rom_h_ok : rom_l_ok)) begin
                fetched <= request_bank ? rom_h_data : rom_l_data;
                state <= return_state;
            end
            ATTR_WAIT: begin
                state <= ATTR;
            end
            ATTR: begin
                for (i=0;i<6;i=i+1) attr[i] <= frame_data[i*16+:16];
                frame_header <= frame_data[127:96];
                first_line <= frame_data[135:128];
                end_line <= frame_data[143:136];
                object_width <= frame_data[156:144];
                state <= ATTR_DONE;
            end
            ATTR_DONE: begin
                if (target_y < {1'b0,first_line} || target_y >= {1'b0,end_line}) state <= NEXT;
                else begin
                    fetched <= frame_header;
                    state <= HEADER;
                end
            end
            NEXT: begin
                if (object_index == 0 || line_full) state <= IDLE;
                else begin
                    object_index <= object_index - 1'b1;
                    frame_rd_addr <= object_index - 1'b1;
                    state <= ATTR_WAIT;
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
                end else begin
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
                run_left[row] <= {1'b0,fetched[15:8],3'd0};
                run_right[row] <= ({5'd0,fetched[15:8]} + {5'd0,fetched[7:0]} + 13'd1) << 3;
                run_base[row] <= {1'b0,fetched[31:16],1'b0};
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
                pixel_y_min <= (top_line*scale + 127) >> 7;
                pixel_y_max <= (bottom_line*scale + 127) >> 7;
                state <= rotation == 0 || repeat_line ? BOUNDS_FINAL : BOUNDS_ROT;
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
                minx = bound_minx[0] < bound_minx[1] ? bound_minx[0] : bound_minx[1];
                maxx = bound_maxx[0] > bound_maxx[1] ? bound_maxx[0] : bound_maxx[1];
                miny = bound_miny[0] < bound_miny[1] ? bound_miny[0] : bound_miny[1];
                maxy = bound_maxy[0] > bound_maxy[1] ? bound_maxy[0] : bound_maxy[1];
                if (bounds_walk) begin
                    if (!walk_valid) begin miny = 0; maxy = 0; end
                    else if (rotation == 0) begin
                        miny = flip_y ? origin_y - bound_bottom : origin_y + bound_top;
                        maxy = flip_y ? origin_y - bound_top : origin_y + bound_bottom;
                    end else if (repeat_line) begin miny = 0; maxy = 240; end
                    else begin
                        miny = origin_y + (miny >>> 8) - 1;
                        maxy = origin_y - ((-maxy) >>> 8) + 2;
                    end
                    if (miny < 0) miny = 0;
                    if (maxy > 240) maxy = 240;
                    if (miny >= maxy || miny >= 240 || maxy <= 0) begin miny = 0; maxy = 0; end
                    frame_we <= 1;
                    frame_wr_addr <= walk_index;
                    frame_wr_data <= {3'd0,object_width,maxy[7:0],miny[7:0],frame_header,frame_data[95:0]};
                    state <= WALK_NEXT;
                end else begin
                    first_x = 0;
                    end_x = 319;
                    if (rotation == 0) begin
                        if (flip_x) begin
                            first_x = repeat_line ? 0 : origin_x - bound_right;
                            end_x = origin_x - bound_left - 1;
                        end else begin
                            first_x = origin_x + bound_left;
                            end_x = repeat_line ? 319 : origin_x + bound_right - 1;
                        end
                    end else if (!repeat_line) begin
                        first_x = origin_x + (minx >>> 8) - 1;
                        end_x = origin_x - ((-maxx) >>> 8) + 1;
                        if (line_y < origin_y + (miny >>> 8) - 1
                         || line_y > origin_y - ((-maxy) >>> 8) + 1) end_x = -1;
                    end
                    if (first_x < 0) first_x = 0;
                    if (end_x > 319) end_x = 319;
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
                    // hold until the drawer releases the pixel pipeline
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
                state <= PIXEL;
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
                prep_col <= source_col - {20'd0,last_left};
                prep_delta <= tile_delta;
                state <= FAST_REM;
            end
            FAST_REM: begin
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
                d_col <= fast_col;
                d_rem <= fast_rem;
                d_step <= fast_step;
                d_step_rem <= fast_step_rem;
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
            PIXEL: begin
                if (line_full) state <= NEXT;
                else if (covmap[draw_x]) advance_pixel;
                else begin
                dist_x = {{12{source_x[59]}},source_x[59:40]};
                dist_y = {{12{source_y[59]}},source_y[59:40]};
                if (flip_x) dist_x = -dist_x - 1;
                if (flip_y) dist_y = -dist_y - 1;
                if (dist_x < 0 || dist_y < 0 || dist_y < $signed(pixel_y_min) || dist_y >= $signed(pixel_y_max)) advance_pixel;
                else begin
                    pixel_dist_x <= dist_x[19:0];
                    pixel_dist_y <= dist_y[19:0];
                    state <= PIXEL_MUL;
                end
                end
            end
            PIXEL_MUL: begin
                prep_col_product <= {pixel_dist_x,7'd0} * scale_inverse;
                prep_step_product <= {pixel_dist_y,7'd0} * scale_inverse;
                state <= PIXEL_CHECK;
            end
            PIXEL_CHECK: begin
                quotient = prep_col_product[58:32];
                if (quotient * scale > {9'd0,pixel_dist_x,7'd0}) quotient = quotient - 1'b1;
                pixel_col <= quotient;
                quotient = prep_step_product[58:32];
                if (quotient * scale > {9'd0,pixel_dist_y,7'd0}) quotient = quotient - 1'b1;
                pixel_line <= quotient;
                state <= PIXEL_LOOKUP;
            end
            PIXEL_LOOKUP: begin
                if (pixel_line < {18'd0,top_line} || pixel_line >= {17'd0,bottom_line}) advance_pixel;
                else if (pixel_col < {15'd0,row_left} || (!repeat_line && pixel_col >= {14'd0,row_right})) advance_pixel;
                else begin
                    tile_count = ({19'd0,row_right} - {20'd0,row_left}) >> 3;
                    tile_delta = ({5'd0,pixel_col} - {20'd0,row_left}) >> 3;
                    pixel_count <= tile_count[8:0];
                    pixel_inverse <= inverse[tile_count];
                    pixel_delta <= tile_delta[26:0];
                    pixel_base <= row_base;
                    if (repeat_line && tile_delta >= tile_count) state <= PIXEL_WRAP_MUL;
                    else begin
                        pixel_wrapped <= tile_delta[26:0];
                        state <= PIXEL_TILE;
                    end
                end
            end
            PIXEL_WRAP_MUL: begin
                prep_col_product <= pixel_delta * pixel_inverse;
                state <= PIXEL_WRAP_CHECK;
            end
            PIXEL_WRAP_CHECK: begin
                quotient = prep_col_product[58:32];
                pixel_quotient <= quotient * pixel_count > {9'd0,pixel_delta} ? quotient - 1'b1 : quotient;
                state <= PIXEL_WRAP_END;
            end
            PIXEL_WRAP_END: begin
                tile_delta = {5'd0,pixel_delta} - pixel_quotient*pixel_count;
                pixel_wrapped <= tile_delta[26:0];
                state <= PIXEL_TILE;
            end
            PIXEL_TILE: begin
                tile_number = {14'd0,pixel_base} + {5'd0,pixel_wrapped};
                tile_bank <= tile_number[0];
                tile_addr <= graphics_addr(tile_number[17:0],pixel_line[2:0]);
                nibble <= pixel_col[2:0] ^ 3'd3;
                state <= TILE;
            end
            TILE: begin
                if (cache_valid && cached_addr == tile_addr && cached_bank == tile_bank) begin
                    pen <= cached_data[{nibble,2'b00}+:4];
                    color_valid[0] <= cached_data[{nibble,2'b00}+:4] != 0;
                    color_x0 <= draw_x;
                    advance_pixel;
                end else request(tile_bank,tile_addr,GFX);
            end
            GFX: begin
                cached_addr <= tile_addr;
                cached_bank <= tile_bank;
                cached_data <= fetched;
                cache_valid <= 1;
                pen <= fetched[{nibble,2'b00}+:4];
                color_valid[0] <= fetched[{nibble,2'b00}+:4] != 0;
                color_x0 <= draw_x;
                advance_pixel;
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
                    frame_wr_addr <= snap_index;
                    frame_wr_data <= {64'd0,ram_data,attr[4],attr[3],attr[2],attr[1],attr[0]};
                    if (attr[0] == 16'hffff || attr[4] == 16'hffff) begin
                        object_count <= snap_index;
                        state <= WALK_INIT;
                    end else if (snap_index == 341) begin
                        object_count <= 342;
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
                frame_rd_addr <= 0;
                state <= WALK_WAIT;
            end
            WALK_WAIT: begin
                if (object_count == 0) begin
                    frame_ready <= 1;
                    state <= IDLE;
                end else state <= WALK_LOAD;
            end
            WALK_LOAD: begin
                for (i=0;i<6;i=i+1) attr[i] <= frame_data[i*16+:16];
                frame_header <= 0;
                object_width <= 0;
                walk_valid <= 0;
                state <= WALK_FETCH;
            end
            WALK_FETCH: begin
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
                if (sr <= 0 || sr > 64 || rotation == 0) state <= WALK_STORE;
                else begin
                    row <= 0;
                    request(1,{2'd0,attr[0]},WALK_DESC);
                end
            end
            WALK_DESC: begin
                sr = ({24'd0,fetched[15:8]} + {24'd0,fetched[7:0]} + 1) * 8;
                if (sr > object_width) object_width <= sr[12:0];
                if ({1'b0,row} + 1'b1 == rows) state <= WALK_STORE;
                else begin
                    row <= row + 1'b1;
                    request(row[0],{2'd0,attr[0]} + {13'd0,row[5:1]} + 18'd1,WALK_DESC);
                end
            end
            WALK_STORE: begin
                bounds_walk <= 1;
                bound_left <= 0;
                bound_right <= 0;
                bound_top <= (top_line*scale + (rotation == 0 ? 127 : 0)) >> 7;
                bound_bottom <= (bottom_line*scale + 127) >> 7;
                bound_width <= (object_width*scale + 127) >> 7;
                state <= !walk_valid || rotation == 0 || repeat_line ? BOUNDS_FINAL : BOUNDS_ROT;
            end
            WALK_NEXT: begin
                if (walk_index + 9'd1 == object_count) begin
                    frame_ready <= 1;
                    state <= IDLE;
                end else begin
                    walk_index <= walk_index + 1'b1;
                    frame_rd_addr <= walk_index + 1'b1;
                    state <= WALK_WAIT;
                end
            end
            default: state <= IDLE;
        endcase
        if (line_start && loaded) begin
            dr_state <= DR_IDLE;
            if (v == 240) begin
                frame_ready <= 0;
                frame_valid <= 0;
                snap_index <= 0;
                offset <= 0;
                list_base <= {ctrl_data[12],12'd0};
                ram_addr <= {ctrl_data[12],12'd0};
                state <= SNAP_WAIT;
            end else if (v == 271 || v < 240) begin
                if (v == 271) begin
                    frame_valid <= frame_ready;
                    overflow <= !frame_ready;
                end else if (frame_valid && (state != IDLE || dr_state != DR_IDLE || color_valid != 0)) overflow <= 1;
                color_valid <= 0;
                write_enable <= 0;
                covmap <= 0;
                shaded <= 0;
                cover_cnt <= 0;
                target_y <= next_y;
                object_index <= object_count - 1'b1;
                frame_rd_addr <= object_count - 1'b1;
                state <= next_y < 240 && object_count != 0 && (v == 271 ? frame_ready : frame_valid) ? ATTR_WAIT : IDLE;
            end
        end
    end
end

endmodule
