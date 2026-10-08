/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 29-3-2026 */

module jtcps3_obj #(
    parameter CMDW      = 96,
    parameter VPOS_OFFS = 10'd17,
    parameter FRACW     = 16
)(
    input               rst,
    input               clk,
    input               draw,
    input       [CMDW-1:0] cmd,
    input       [ 8:0]  draw_v,

    output reg          busy,
    output reg          done,

    output reg          tiles_rd,
    output reg  [22:4]  tiles_addr,
    input       [127:0] tiles_data,
    input               tiles_ok,

    input       [16:0]  buf_dout,
    output reg          wr_en,
    output reg  [ 9:0]  wr_addr,
    output reg  [16:0]  wr_pxl
);

localparam ST_IDLE       = 3'd0,
           ST_SETUP      = 3'd1,
           ST_DRAW       = 3'd2,
           ST_FETCH_REQ  = 3'd3,
           ST_FETCH_WAIT = 3'd4,
           ST_BLEND_WAIT = 3'd5,
           ST_BLEND_WR   = 3'd6,
           ST_DONE       = 3'd7;

reg  [ 2:0] st;
reg  [14:0] tileno, fetch_tile, row_tile;
reg  [ 8:0] pal;
reg  [ 7:0] draw_w, draw_h, dst_x;
reg  [ 2:0] x_tiles, y_tiles;
reg  [22:0] step_x, step_y;
reg         hflip, vflip, alpha, bpp, row_valid;
reg         blend_6bpp;
reg  [ 7:0] blend_pxl;
reg  [31:0] row_data0, row_data1, row_data2, row_data3;
reg  signed [11:0] sprite_x0, line_delta;
reg  [31:0] src_x_mul, src_y_mul;
wire [ 6:0] src_x_pre, src_y_pre, src_x_eff, src_y_eff, native_w, native_h;
wire [ 1:0] tile_x_cur, tile_y_cur;
wire [ 3:0] pixel_x_cur;
wire [ 4:0] subtile;
wire [14:0] tile_code;
wire [ 7:0] pxl_cur;
wire [16:0] norm_pxl_cur, blend_pxl_cur;
wire        is_in_xrange, is_blend, is_opaque;
wire signed [11:0] screen_x_cur;
wire [ 2:0] cmd_x_tiles, cmd_y_tiles;
wire [ 7:0] cmd_draw_w, cmd_draw_h;
wire [ 6:0] cmd_native_w, cmd_native_h;
wire signed [11:0] cmd_sprite_x0, cmd_line_delta;

assign src_x_pre     = src_x_mul[FRACW +: 7];
assign src_y_pre     = src_y_mul[FRACW +: 7];
assign src_x_eff     = hflip ? (native_w - 7'd1 - src_x_pre) : src_x_pre;
assign src_y_eff     = vflip ? (native_h - 7'd1 - src_y_pre) : src_y_pre;
assign tile_x_cur    = src_x_eff[5:4];
assign tile_y_cur    = src_y_eff[5:4];
assign pixel_x_cur   = src_x_eff[3:0];
assign screen_x_cur  = sprite_x0 + $signed({ 4'd0, dst_x });
assign is_in_xrange  = screen_x_cur >= 0 && screen_x_cur < 12'sd1024;
assign is_blend      = alpha && is_in_xrange && is_opaque;
assign is_opaque     = pxl_cur != 8'd0;

assign norm_pxl_cur  = bpp ? { 2'd0, pal, pxl_cur[5:0] } :
                             { pal, pxl_cur };
assign blend_pxl_cur = blend_6bpp ?
    (buf_dout | { 1'b0, blend_pxl[3:0], 12'd0 }) :
    (buf_dout | { pal[0], blend_pxl[0], 15'd0 });

assign subtile = tile_offset(tile_x_cur, y_tiles) + { 3'd0, tile_y_cur };
assign tile_code  = tileno + { 10'd0, subtile };
assign native_w = { x_tiles, 4'd0 };
assign native_h = { y_tiles, 4'd0 };
assign cmd_x_tiles  = decode_tiles(cmd[65:64]);
assign cmd_y_tiles  = decode_tiles(cmd[67:66]);
assign cmd_draw_w   = { 1'b0, cmd[86:80] } + 8'd1;
assign cmd_draw_h   = { 1'b0, cmd[94:88] } + 8'd1;
assign cmd_native_w = { cmd_x_tiles, 4'd0 };
assign cmd_native_h = { cmd_y_tiles, 4'd0 };
assign cmd_sprite_x0 = wrap10_center_x(cmd[57:48], cmd_draw_w) + 12'sd64;
assign cmd_line_delta = ({ 3'd0, draw_v }) - sign10(sprite_top_raw(cmd[41:32], cmd_draw_h));

jtcps3_pixel u_pixel(
    .w0         ( row_data0    ),
    .w1         ( row_data1    ),
    .w2         ( row_data2    ),
    .w3         ( row_data3    ),
    .px         ( pixel_x_cur  ),
    .pxl        ( pxl_cur      )
);


function [2:0] decode_tiles;
    input [1:0] code;
begin
    case( code )
        2'd1: decode_tiles = 3'd1;
        2'd2: decode_tiles = 3'd2;
        2'd3: decode_tiles = 3'd4;
        default: decode_tiles = 3'd0;
    endcase
end
endfunction

function signed [11:0] sign10;
    input [9:0] value;
begin
    sign10 = value[9] ? { 2'b11, value } : { 2'b00, value };
end
endfunction

function signed [11:0] wrap10_center_x;
    input [9:0] xpos;
    input [7:0] draw_w;
    reg   [10:0] xpos_adj;
begin
    xpos_adj = { 1'b0, xpos } - { 3'd0, draw_w[7:1] };
    wrap10_center_x = sign10(xpos_adj[9:0]);
end
endfunction

function [9:0] sprite_top_raw;
    input [9:0] ypos;
    input [7:0] draw_h;
    reg   [10:0] ypos_sum;
begin
    ypos_sum = { 1'b0, ypos } + { 3'd0, draw_h[7:1] };
    sprite_top_raw = ~ypos_sum[9:0] - VPOS_OFFS[9:0];
end
endfunction

function [4:0] tile_offset;
    input [1:0] tile_x;
    input [2:0] y_tiles;
begin
    case( y_tiles )
        3'd1: tile_offset = { 3'd0, tile_x };
        3'd2: tile_offset = { 2'd0, tile_x, 1'b0 };
        3'd4: tile_offset = { 1'd0, tile_x, 2'd0 };
        default: tile_offset = 5'd0;
    endcase
end
endfunction

`ifdef SIMULATION
reg nozoom;

always @(posedge clk) begin
    case(st)
        ST_SETUP: nozoom <= {1'b0,native_h} == draw_w && {1'b0,native_h} == draw_h;
        ST_DONE:  nozoom <= 0;
        default:;
    endcase
end
`endif

function [16:0] reciprocal_16;
    input [7:0] draw_sz;
begin
    case( draw_sz )
            8'd  1: reciprocal_16 = 17'd65536;
            8'd  2: reciprocal_16 = 17'd32768;
            8'd  3: reciprocal_16 = 17'd21845;
            8'd  4: reciprocal_16 = 17'd16384;
            8'd  5: reciprocal_16 = 17'd13107;
            8'd  6: reciprocal_16 = 17'd10922;
            8'd  7: reciprocal_16 = 17'd9362;
            8'd  8: reciprocal_16 = 17'd8192;
            8'd  9: reciprocal_16 = 17'd7281;
            8'd 10: reciprocal_16 = 17'd6553;
            8'd 11: reciprocal_16 = 17'd5957;
            8'd 12: reciprocal_16 = 17'd5461;
            8'd 13: reciprocal_16 = 17'd5041;
            8'd 14: reciprocal_16 = 17'd4681;
            8'd 15: reciprocal_16 = 17'd4369;
            8'd 16: reciprocal_16 = 17'd4096;
            8'd 17: reciprocal_16 = 17'd3855;
            8'd 18: reciprocal_16 = 17'd3640;
            8'd 19: reciprocal_16 = 17'd3449;
            8'd 20: reciprocal_16 = 17'd3276;
            8'd 21: reciprocal_16 = 17'd3120;
            8'd 22: reciprocal_16 = 17'd2978;
            8'd 23: reciprocal_16 = 17'd2849;
            8'd 24: reciprocal_16 = 17'd2730;
            8'd 25: reciprocal_16 = 17'd2621;
            8'd 26: reciprocal_16 = 17'd2520;
            8'd 27: reciprocal_16 = 17'd2427;
            8'd 28: reciprocal_16 = 17'd2340;
            8'd 29: reciprocal_16 = 17'd2259;
            8'd 30: reciprocal_16 = 17'd2184;
            8'd 31: reciprocal_16 = 17'd2114;
            8'd 32: reciprocal_16 = 17'd2048;
            8'd 33: reciprocal_16 = 17'd1985;
            8'd 34: reciprocal_16 = 17'd1927;
            8'd 35: reciprocal_16 = 17'd1872;
            8'd 36: reciprocal_16 = 17'd1820;
            8'd 37: reciprocal_16 = 17'd1771;
            8'd 38: reciprocal_16 = 17'd1724;
            8'd 39: reciprocal_16 = 17'd1680;
            8'd 40: reciprocal_16 = 17'd1638;
            8'd 41: reciprocal_16 = 17'd1598;
            8'd 42: reciprocal_16 = 17'd1560;
            8'd 43: reciprocal_16 = 17'd1524;
            8'd 44: reciprocal_16 = 17'd1489;
            8'd 45: reciprocal_16 = 17'd1456;
            8'd 46: reciprocal_16 = 17'd1424;
            8'd 47: reciprocal_16 = 17'd1394;
            8'd 48: reciprocal_16 = 17'd1365;
            8'd 49: reciprocal_16 = 17'd1337;
            8'd 50: reciprocal_16 = 17'd1310;
            8'd 51: reciprocal_16 = 17'd1285;
            8'd 52: reciprocal_16 = 17'd1260;
            8'd 53: reciprocal_16 = 17'd1236;
            8'd 54: reciprocal_16 = 17'd1213;
            8'd 55: reciprocal_16 = 17'd1191;
            8'd 56: reciprocal_16 = 17'd1170;
            8'd 57: reciprocal_16 = 17'd1149;
            8'd 58: reciprocal_16 = 17'd1129;
            8'd 59: reciprocal_16 = 17'd1110;
            8'd 60: reciprocal_16 = 17'd1092;
            8'd 61: reciprocal_16 = 17'd1074;
            8'd 62: reciprocal_16 = 17'd1057;
            8'd 63: reciprocal_16 = 17'd1040;
            8'd 64: reciprocal_16 = 17'd1024;
            8'd 65: reciprocal_16 = 17'd1008;
            8'd 66: reciprocal_16 = 17'd992;
            8'd 67: reciprocal_16 = 17'd978;
            8'd 68: reciprocal_16 = 17'd963;
            8'd 69: reciprocal_16 = 17'd949;
            8'd 70: reciprocal_16 = 17'd936;
            8'd 71: reciprocal_16 = 17'd923;
            8'd 72: reciprocal_16 = 17'd910;
            8'd 73: reciprocal_16 = 17'd897;
            8'd 74: reciprocal_16 = 17'd885;
            8'd 75: reciprocal_16 = 17'd873;
            8'd 76: reciprocal_16 = 17'd862;
            8'd 77: reciprocal_16 = 17'd851;
            8'd 78: reciprocal_16 = 17'd840;
            8'd 79: reciprocal_16 = 17'd829;
            8'd 80: reciprocal_16 = 17'd819;
            8'd 81: reciprocal_16 = 17'd809;
            8'd 82: reciprocal_16 = 17'd799;
            8'd 83: reciprocal_16 = 17'd789;
            8'd 84: reciprocal_16 = 17'd780;
            8'd 85: reciprocal_16 = 17'd771;
            8'd 86: reciprocal_16 = 17'd762;
            8'd 87: reciprocal_16 = 17'd753;
            8'd 88: reciprocal_16 = 17'd744;
            8'd 89: reciprocal_16 = 17'd736;
            8'd 90: reciprocal_16 = 17'd728;
            8'd 91: reciprocal_16 = 17'd720;
            8'd 92: reciprocal_16 = 17'd712;
            8'd 93: reciprocal_16 = 17'd704;
            8'd 94: reciprocal_16 = 17'd697;
            8'd 95: reciprocal_16 = 17'd689;
            8'd 96: reciprocal_16 = 17'd682;
            8'd 97: reciprocal_16 = 17'd675;
            8'd 98: reciprocal_16 = 17'd668;
            8'd 99: reciprocal_16 = 17'd661;
            8'd100: reciprocal_16 = 17'd655;
            8'd101: reciprocal_16 = 17'd648;
            8'd102: reciprocal_16 = 17'd642;
            8'd103: reciprocal_16 = 17'd636;
            8'd104: reciprocal_16 = 17'd630;
            8'd105: reciprocal_16 = 17'd624;
            8'd106: reciprocal_16 = 17'd618;
            8'd107: reciprocal_16 = 17'd612;
            8'd108: reciprocal_16 = 17'd606;
            8'd109: reciprocal_16 = 17'd601;
            8'd110: reciprocal_16 = 17'd595;
            8'd111: reciprocal_16 = 17'd590;
            8'd112: reciprocal_16 = 17'd585;
            8'd113: reciprocal_16 = 17'd579;
            8'd114: reciprocal_16 = 17'd574;
            8'd115: reciprocal_16 = 17'd569;
            8'd116: reciprocal_16 = 17'd564;
            8'd117: reciprocal_16 = 17'd560;
            8'd118: reciprocal_16 = 17'd555;
            8'd119: reciprocal_16 = 17'd550;
            8'd120: reciprocal_16 = 17'd546;
            8'd121: reciprocal_16 = 17'd541;
            8'd122: reciprocal_16 = 17'd537;
            8'd123: reciprocal_16 = 17'd532;
            8'd124: reciprocal_16 = 17'd528;
            8'd125: reciprocal_16 = 17'd524;
            8'd126: reciprocal_16 = 17'd520;
            8'd127: reciprocal_16 = 17'd516;
            8'd128: reciprocal_16 = 17'd512;
        default: reciprocal_16 = 17'd0;
    endcase
end
endfunction

function [22:0] scale_step;
    input [6:0] native_sz;
    input [7:0] draw_sz;
    reg   [16:0] recip;
begin
    recip = reciprocal_16(draw_sz);
    case( native_sz )
        7'd16: scale_step = { 2'd0, recip, 4'd0 };
        7'd32: scale_step = { 1'd0, recip, 5'd0 };
        7'd64: scale_step = { recip, 6'd0 };
        default: scale_step = 23'd0;
    endcase
end
endfunction

always @(posedge clk) begin
    if( rst ) begin
        st         <= ST_IDLE;
        busy       <= 1'b0;
        done       <= 1'b0;
        tiles_rd   <= 1'b0;
        tiles_addr <= 19'd0;
        wr_en      <= 1'b0;
        wr_addr    <= 10'd0;
        wr_pxl     <= 17'd0;
        tileno     <= 15'd0;
        pal        <= 9'd0;
        draw_w     <= 8'd0;
        draw_h     <= 8'd0;
        dst_x      <= 8'd0;
        x_tiles    <= 3'd0;
        y_tiles    <= 3'd0;
        step_x     <= 23'd0;
        step_y     <= 23'd0;
        fetch_tile <= 15'd0;
        row_tile   <= 15'd0;
        hflip      <= 1'b0;
        vflip      <= 1'b0;
        alpha      <= 1'b0;
        bpp        <= 1'b0;
        row_valid  <= 1'b0;
        blend_6bpp <= 1'b0;
        blend_pxl  <= 8'd0;
        row_data0  <= 32'd0;
        row_data1  <= 32'd0;
        row_data2  <= 32'd0;
        row_data3  <= 32'd0;
        sprite_x0  <= 12'sd0;
        line_delta <= 12'sd0;
        src_x_mul  <= 32'd0;
        src_y_mul  <= 32'd0;
    end else begin
        done     <= 1'b0;
        wr_en    <= 1'b0;
        tiles_rd <= 1'b0;

        case( st )
            ST_IDLE: begin
                busy <= 1'b0;
                if( draw ) begin
                    tileno     <= cmd[31:17];
                    hflip      <= cmd[12];
                    vflip      <= cmd[11];
                    alpha      <= cmd[10];
                    bpp        <= cmd[9];
                    pal        <= cmd[8:0];
                    draw_w     <= cmd_draw_w;
                    draw_h     <= cmd_draw_h;
                    x_tiles    <= cmd_x_tiles;
                    y_tiles    <= cmd_y_tiles;
                    step_x     <= scale_step(cmd_native_w, cmd_draw_w);
                    step_y     <= scale_step(cmd_native_h, cmd_draw_h);
                    sprite_x0  <= cmd_sprite_x0;
                    line_delta <= cmd_line_delta;
                    row_valid  <= 1'b0;
                    busy       <= 1'b1;
                    st         <= ST_SETUP;
                end
            end

            ST_SETUP: begin
                if( x_tiles == 0 || y_tiles == 0 ) begin
                    st <= ST_DONE;
                end else begin
                    dst_x     <= 8'd0;
                    src_x_mul <= 32'd0;
                    src_y_mul <= { 16'd0, line_delta[7:0] } * step_y;
                    row_valid <= 1'b0;
                    st        <= ST_DRAW;
                end
            end

            ST_DRAW: begin
                if( dst_x >= draw_w ) begin
                    st <= ST_DONE;
                end else if( !row_valid || row_tile != tile_code ) begin
                    row_valid    <= 1'b0;
                    fetch_tile   <= tile_code;
                    tiles_addr   <= { tile_code, src_y_eff[3:0] };
                    st           <= ST_FETCH_REQ;
                end else if( !is_opaque || !is_in_xrange ) begin
                    src_x_mul <= ( { 24'd0, dst_x } + 32'd1 ) * step_x;
                    dst_x <= dst_x + 8'd1;
                end else if( is_blend ) begin
                    blend_pxl     <= pxl_cur;
                    blend_6bpp    <= bpp;
                    wr_addr       <= screen_x_cur[9:0];
                    st            <= ST_BLEND_WAIT;
                end else begin
                    wr_en   <= 1'b1;
                    wr_addr <= screen_x_cur[9:0];
                    wr_pxl  <= norm_pxl_cur;
                    src_x_mul <= ( { 24'd0, dst_x } + 32'd1 ) * step_x;
                    dst_x   <= dst_x + 8'd1;
                end
            end

            ST_FETCH_REQ: begin
                tiles_rd   <= 1'b1;
                st         <= ST_FETCH_WAIT;
            end

            ST_FETCH_WAIT: begin
                if( tiles_ok ) begin
                    row_data0 <= tiles_data[31:0];
                    row_data1 <= tiles_data[63:32];
                    row_data2 <= tiles_data[95:64];
                    row_data3 <= tiles_data[127:96];
                    row_tile  <= fetch_tile;
                    row_valid <= 1'b1;
                    st        <= ST_DRAW;
                end
            end

            ST_BLEND_WAIT: begin
                st <= ST_BLEND_WR;
            end

            ST_BLEND_WR: begin
                wr_en   <= 1'b1;
                wr_pxl  <= blend_pxl_cur;
                src_x_mul <= ( { 24'd0, dst_x } + 32'd1 ) * step_x;
                dst_x <= dst_x + 8'd1;
                st      <= ST_DRAW;
            end

            ST_DONE: begin
                busy   <= 1'b0;
                done   <= 1'b1;
                wr_pxl <= 0;
                st     <= ST_IDLE;
            end

            default: st <= ST_IDLE;
        endcase
    end
end

endmodule
