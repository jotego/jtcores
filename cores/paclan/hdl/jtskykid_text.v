/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 25-9-2026 */

module jtskykid_text(
    input               clk, pxl_cen, flip,
    input        [ 8:0] hdump, vdump,

    output reg   [10:1] vram_addr,
    input        [15:0] vram_dout,

    output reg          rom_cs,
    output reg   [12:1] rom_addr,
    input        [15:0] rom_data,
    input               rom_ok,

    output reg   [ 5:0] pal,
    output reg   [ 3:0] cat,
    output       [ 1:0] pxl
);

parameter [8:0] HOFFSET = 9'h041,
                VOFFSET = 9'h110;

wire [ 8:0] hadj   = hdump - HOFFSET;
wire [ 8:0] vadj   = vdump - VOFFSET;
wire [ 5:0] scol   = hadj[8:3]+6'd1;
wire [ 5:0] col_nx = flip ? 6'd35-scol : scol;
wire [ 4:0] row    = flip ? 5'd27-vadj[7:3] : vadj[7:3];
wire [ 2:0] ph     = hadj[2:0];

reg  [ 5:0] c6;
reg  [ 4:0] r5;
reg  [ 9:0] idx;
reg  [ 7:0] code_b, attr_b;
reg  [15:0] shift, rom_buf;
reg         rom_good;

always @* begin
    c6  = col_nx - 6'd2;
    r5  = row    + 5'd2;
    idx = c6[5] ? {5'd0,r5} + {c6[4:0],5'd0}
                : {5'd0,c6[4:0]} + {r5,5'd0};
end

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
            0: vram_addr <= {1'b0, idx[9:1]};
            1: begin
                code_b    <= idx[0] ? vram_dout[15:8] : vram_dout[7:0];
                vram_addr <= {1'b1, idx[9:1]};
            end
            2: begin
                attr_b   <= idx[0] ? vram_dout[15:8] : vram_dout[7:0];
                rom_addr <= { flip, code_b, vadj[2:0] };
                rom_good <= 0;
            end
            default:;
        endcase
        if( ph==7 ) begin
            pal   <= attr_b[5:0];
            cat   <= code_b[7:4];
            shift <= { tpx(rom_buf[ 7:0],2'd3), tpx(rom_buf[ 7:0],2'd2),
                       tpx(rom_buf[ 7:0],2'd1), tpx(rom_buf[ 7:0],2'd0),
                       tpx(rom_buf[15:8],2'd3), tpx(rom_buf[15:8],2'd2),
                       tpx(rom_buf[15:8],2'd1), tpx(rom_buf[15:8],2'd0) };
        end else begin
            shift <= shift>>2;
        end
    end
end

endmodule
