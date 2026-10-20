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
    HEADER=11, DESC=12, PREP=13, PIXEL=14, TILE=15, GFX=16;
reg [4:0] state, return_state;
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
reg [8:0] target_y;
reg [6:0] rows;
reg [8:0] top_line;
reg [9:0] bottom_line;
reg repeat_line;
reg [5:0] row;
reg [11:0] run_left [0:63];
reg [12:0] run_right [0:63];
reg [17:0] run_base [0:63];
reg [12:0] object_width;
reg [8:0] draw_x, last_x;
reg signed [59:0] source_x, source_y, step_x, step_y;
reg [17:0] tile_addr, cached_addr;
reg tile_bank, cached_bank, cache_valid;
reg [31:0] cached_data;
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
wire [11:0] color_index = {attr[1][10:3],pen};
wire [31:0] clut_word = color_select[2] ? clut_h_q : clut_l_q;
wire [4:0] clut_shift = {color_select[1:0] ^ 2'b01,3'b000};
wire [7:0] clut_color = clut_word[clut_shift+:8];
wire line_start = pxl_cen && h == 0;
wire [8:0] next_y = v == 271 ? 9'd0 : v + 9'd1;
integer i, dy, source_line, source_col, source_row, dist_x, dist_y;
integer left_edge, right_edge, first_x, end_x, tile_number, tile_count, tile_delta;
integer st, sb, sr, cx, cy, rx, ry, minx, maxx, miny, maxy;
reg signed [33:0] dx_fixed, dy_fixed, mixed_x, mixed_y;
reg signed [43:0] tilt_x, tilt_y;
reg signed [35:0] slope_scale;
reg [40:0] init_shrink;
reg [26:0] quotient;

function [26:0] divide;
    input [26:0] numerator;
    input [8:0] denominator;
    input [32:0] reciprocal;
    reg [59:0] product;
    reg [26:0] candidate;
    reg [35:0] checked;
    begin
        product = numerator * reciprocal;
        candidate = product[58:32];
        checked = candidate * denominator;
        divide = checked > {9'd0,numerator} ? candidate - 1'b1 : candidate;
    end
endfunction

function [31:0] unscale;
    input [19:0] distance;
    begin
        unscale = {5'd0,divide({distance,7'd0},scale,scale_inverse)};
    end
endfunction

task request;
    input bank;
    input [17:0] address;
    input [4:0] destination;
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
assign rom_l_addr = request_addr;
assign rom_h_addr = request_addr;
assign rom_l_cs = (state == WAIT0 || state == WAIT1) && !request_bank;
assign rom_h_cs = (state == WAIT0 || state == WAIT1) && request_bank;

initial begin
    inverse[0] = 0;
    for (i=1;i<512;i=i+1) inverse[i] = (33'h100000000 + {1'b0,i[31:0]} - 1'b1) / {1'b0,i[31:0]};
    for (i=0;i<257;i=i+1) begin
        init_shrink = 41'h10000000000 / (41'd65536 + {9'd0,i[31:0]}*{9'd0,i[31:0]});
        shrink_table[i] = init_shrink[24:0];
    end
end

always @(posedge clk) begin
    scale_inverse <= inverse[scale];
    shrink <= shrink_table[slope_abs];
    clut_l_q <= clut_l[color_index[11:3]];
    clut_h_q <= clut_h[color_index[11:3]];
    color_select <= color_index[2:0];
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

always @(posedge clk) begin
    write_enable <= 0;
    color_valid <= {color_valid[0],1'b0};
    color_x1 <= color_x0;
    if (color_valid[1]) begin
        write_x <= color_x1;
        write_data <= {clut_color == 8'hff,1'b1,clut_color};
        write_enable <= 1;
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
        nibble <= 0;
        pen <= 0;
        color_valid <= 0;
        color_x0 <= 0;
        color_x1 <= 0;
        write_x <= 0;
        write_data <= 0;
        overflow <= 0;
        for (i=0;i<6;i=i+1) attr[i] <= 0;
    end else begin
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
            WAIT1: if (request_bank ? rom_h_ok : rom_l_ok) begin
                fetched <= request_bank ? rom_h_data : rom_l_data;
                state <= return_state;
            end
            ATTR_WAIT: begin
                ram_addr <= list_base + {2'd0,offset} + 1'b1;
                attr_step <= 0;
                state <= ATTR;
            end
            ATTR: begin
                attr[attr_step] <= ram_data;
                ram_addr <= ram_addr + 1'b1;
                attr_step <= attr_step + 1'b1;
                if (attr_step == 5) state <= ATTR_DONE;
            end
            ATTR_DONE: begin
                dy = line_y - origin_y;
                if (flip_y) dy = -dy - 1;
                if (attr[0] == 16'hffff || attr[4] == 16'hffff) state <= IDLE;
                else if (attr[0] >= 16'h4000 || scale == 0) state <= NEXT;
                else if (rotation == 0 && (dy < 0 || unscale(dy[19:0]) >= 512)) state <= NEXT;
                else request(0,{2'd0,attr[0]},HEADER);
            end
            NEXT: begin
                if (offset >= 2046) state <= IDLE;
                else begin
                    offset <= offset + 11'd6;
                    ram_addr <= list_base + {2'd0,offset} + 13'd6;
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
                object_width <= 0;
                dy = line_y - origin_y;
                if (flip_y) dy = -dy - 1;
                source_line = unscale(dy[19:0]);
                source_row = (source_line - st) >>> 3;
                if (sr <= 0 || sr > 64) state <= NEXT;
                else if (rotation == 0) begin
                    if (source_line < st || source_line >= st + sr*8) state <= NEXT;
                    else begin
                        row <= source_row[5:0];
                        request(!source_row[0],{2'd0,attr[0]} + {12'd0,source_row[6:1]} + {17'd0,source_row[0]},DESC);
                    end
                end else begin
                    row <= 0;
                    request(1,{2'd0,attr[0]},DESC);
                end
            end
            DESC: begin
                run_left[row] <= {1'b0,fetched[15:8],3'd0};
                run_right[row] <= ({5'd0,fetched[15:8]} + {5'd0,fetched[7:0]} + 13'd1) << 3;
                run_base[row] <= {1'b0,fetched[31:16],1'b0};
                sr = ({24'd0,fetched[15:8]} + {24'd0,fetched[7:0]} + 1) * 8;
                if (sr > object_width) object_width <= sr[12:0];
                if (rotation == 0 || {1'b0,row} + 1'b1 == rows) state <= PREP;
                else begin
                    row <= row + 1'b1;
                    request(row[0],{2'd0,attr[0]} + {13'd0,row[5:1]} + 18'd1,DESC);
                end
            end
            PREP: begin
                first_x = 0;
                end_x = 319;
                if (rotation == 0) begin
                    left_edge = (run_left[row]*scale + 127) >> 7;
                    right_edge = (run_right[row]*scale + 127) >> 7;
                    if (flip_x) begin
                        first_x = repeat_line ? 0 : origin_x - right_edge;
                        end_x = origin_x - left_edge - 1;
                    end else begin
                        first_x = origin_x + left_edge;
                        end_x = repeat_line ? 319 : origin_x + right_edge - 1;
                    end
                end else if (!repeat_line) begin
                    st = (top_line*scale) >> 7;
                    sb = (bottom_line*scale + 127) >> 7;
                    sr = (object_width*scale + 127) >> 7;
                    minx = 32'h7fffffff;
                    maxx = -32'h7fffffff;
                    miny = 32'h7fffffff;
                    maxy = -32'h7fffffff;
                    for (i=0;i<4;i=i+1) begin
                        cx = i[0] ? sr : 0;
                        cy = i[1] ? sb : st;
                        if (flip_x) cx = -cx;
                        if (flip_y) cy = -cy;
                        rx = (cx <<< 8) - $signed(slope)*cy;
                        ry = $signed(slope)*cx + (cy <<< 8);
                        if (rx < minx) minx = rx;
                        if (rx > maxx) maxx = rx;
                        if (ry < miny) miny = ry;
                        if (ry > maxy) maxy = ry;
                    end
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
                    dx_fixed = $signed({2'd0,first_x[31:0]}) - $signed({{2{origin_x[31]}},origin_x});
                    dx_fixed = (dx_fixed <<< 16) + 34'sh8000;
                    dy_fixed = $signed({25'd0,target_y}) - $signed({{2{origin_y[31]}},origin_y});
                    dy_fixed = (dy_fixed <<< 16) + 34'sh8000;
                    tilt_x = $signed(slope)*dy_fixed;
                    tilt_y = $signed(slope)*dx_fixed;
                    mixed_x = dx_fixed + $signed(tilt_x[41:8]);
                    mixed_y = dy_fixed - $signed(tilt_y[41:8]);
                    source_x <= mixed_x * $signed({1'b0,shrink});
                    source_y <= mixed_y * $signed({1'b0,shrink});
                    step_x <= $signed({19'd0,shrink,16'd0});
                    slope_scale = $signed(slope)*$signed({1'b0,shrink});
                    step_y <= -$signed({{16{slope_scale[35]}},slope_scale,8'd0});
                    state <= PIXEL;
                end
            end
            PIXEL: begin
                dist_x = {{12{source_x[59]}},source_x[59:40]};
                dist_y = {{12{source_y[59]}},source_y[59:40]};
                if (flip_x) dist_x = -dist_x - 1;
                if (flip_y) dist_y = -dist_y - 1;
                source_line = unscale(dist_y[19:0]);
                source_col = unscale(dist_x[19:0]);
                source_row = (source_line - {23'd0,top_line}) >>> 3;
                if (dist_x < 0 || dist_y < 0 || source_line < top_line || source_line >= bottom_line) advance_pixel;
                else if (source_col < run_left[source_row] || (!repeat_line && source_col >= run_right[source_row])) advance_pixel;
                else begin
                    tile_count = ({19'd0,run_right[source_row]} - {20'd0,run_left[source_row]}) >> 3;
                    tile_delta = (source_col - {20'd0,run_left[source_row]}) >> 3;
                    if (repeat_line && tile_delta >= tile_count) begin
                        quotient = divide(tile_delta[26:0],tile_count[8:0],inverse[tile_count]);
                        tile_delta = tile_delta - quotient*tile_count;
                    end
                    tile_number = {14'd0,run_base[source_row]} + tile_delta;
                    tile_bank <= tile_number[0];
                    tile_number = tile_number >> 1;
                    if (tile_number >= 49152) tile_number = tile_number - 49152;
                    else if (tile_number >= 24576) tile_number = tile_number - 24576;
                    tile_addr <= {tile_number[14:0],source_line[2:0]};
                    nibble <= source_col[2:0] ^ 3'd3;
                    state <= TILE;
                end
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
            default: state <= IDLE;
        endcase
        if (line_start && loaded) begin
            if (v == 0) overflow <= 0;
            if (state != IDLE || color_valid != 0) overflow <= 1;
            color_valid <= 0;
            write_enable <= 0;
            target_y <= next_y;
            offset <= 0;
            list_base <= {ctrl_data[12],12'd0};
            ram_addr <= {ctrl_data[12],12'd0};
            state <= next_y < 240 ? ATTR_WAIT : IDLE;
        end
    end
end

endmodule
