/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-9-2026 */

module jtskykid_scroll(
    input               clk, pxl_cen, flip, rot,
    input        [ 8:0] hdump, vdump,
    input        [ 8:0] scrx,
    input        [ 7:0] scry,

    output reg   [11:1] vram_addr,
    input        [15:0] vram_dout,

    output reg          rom_cs,
    output reg   [12:1] rom_addr,
    input        [15:0] rom_data,
    input               rom_ok,

    output reg   [ 6:0] pal,
    output       [ 1:0] pxl
);

parameter [8:0] HOFFSET = 9'h041,
                VOFFSET = 9'h110;
parameter [8:0] HSCR = 9'd35;
parameter [7:0] VSCR = 8'd25;

wire [ 8:0] hadj = hdump - HOFFSET;
wire [ 8:0] vadj = vdump - VOFFSET;
wire        rev  = flip ^ rot;
wire [ 8:0] sx   = flip ? {scrx[8:1],~scrx[0]} : scrx;
wire [ 8:0] walk = rot ? hadj - sx + 9'd189 : hadj + sx + HSCR;
reg  [ 7:0] vmap;
wire [ 2:0] ph   = walk[2:0];

always @* begin
    case( {rot,flip} )
        2'b00: vmap = vadj[7:0] + scry + VSCR;
        2'b01: vmap = 8'd230 - vadj[7:0] - scry;
        2'b10: vmap = 8'd248 - vadj[7:0] + scry;
        2'b11: vmap = vadj[7:0] - scry + 8'd7;
    endcase
end

wire [ 7:0] vbyte = idx[0] ? vram_dout[15:8] : vram_dout[7:0];
reg  [10:0] idx;
reg  [ 7:0] code_b, attr_b;
reg  [15:0] shift, rom_buf;
reg         rom_good;

wire [ 8:0] wnx = walk + 9'd8;
wire [ 8:0] hnx = rev ? ~wnx : wnx;
always @* idx = { vmap[7:3], hnx[8:3] };

assign pxl = shift[1:0];

function [1:0] tpx(input [7:0] b, input [1:0] k);
    tpx = { b[7-k], b[3-k] };
endfunction

always @(posedge clk) begin
    rom_cs <= 1;
    if( rom_cs && rom_ok && !rom_good ) begin
        rom_buf  <= rom_data;
        rom_good <= 1;
    end
    if( pxl_cen ) begin
        case( ph )
            0: vram_addr <= {1'b0, idx[10:1]};
            1: begin
                code_b    <= vbyte;
                vram_addr <= {1'b1, idx[10:1]};
            end
            2: begin
                attr_b   <= vbyte;
                rom_addr <= { vbyte[0], code_b, vmap[2:0] };
                rom_good <= 0;
            end
            default:;
        endcase
        if( ph==7 ) begin
            pal   <= { attr_b[0], attr_b[6:1] };
            shift <= rev ?
                     { tpx(rom_buf[ 7:0],2'd0), tpx(rom_buf[ 7:0],2'd1),
                       tpx(rom_buf[ 7:0],2'd2), tpx(rom_buf[ 7:0],2'd3),
                       tpx(rom_buf[15:8],2'd0), tpx(rom_buf[15:8],2'd1),
                       tpx(rom_buf[15:8],2'd2), tpx(rom_buf[15:8],2'd3) } :
                     { tpx(rom_buf[15:8],2'd3), tpx(rom_buf[15:8],2'd2),
                       tpx(rom_buf[15:8],2'd1), tpx(rom_buf[15:8],2'd0),
                       tpx(rom_buf[ 7:0],2'd3), tpx(rom_buf[ 7:0],2'd2),
                       tpx(rom_buf[ 7:0],2'd1), tpx(rom_buf[ 7:0],2'd0) };
        end else begin
            shift <= shift>>2;
        end
    end
end

endmodule
