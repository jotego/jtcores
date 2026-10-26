/*  SPDX-FileCopyrightText: 2026 Andrea Bogazzi
    SPDX-License-Identifier: GPL-3.0-or-later

    This file is part of JTCORES.
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

    Author: Andrea Bogazzi <andreabogazzi79@gmail.com>
    Version: 1.0
    Date: 28-8-2026 */

// 8x8 character layer, 64x32 map, TILEMAP_SCAN_ROWS.
//
//   code = fgvram[row*64+col]; tile = code & 0x7fff; flipY on code[15]
//   transparent pen 0xff, palette base 0
//
// gfx_8x8x8_raw is CHUNKY - one byte is one pixel, no planes - so a 32-bit
// read is four finished pixels and there is nothing to de-interleave. That
// is why this does not use jtframe_tilemap: that module extracts pixel bit i
// from byte i, which is the planar layout, and it would want a 64-bit bus
// for BPP=8 anyway. Here a tile row is 8 bytes = two reads.

module jtf1grpr_fg #(parameter CODEW=15, VFLIP=1, HOFFSET=1, VOFFSET=8, SCROLL_COMP=1)(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             flip,
    input      [ 8:0] hdump, vdump,
    input      [ 8:0] h_last,        // last H count, for the fetch wrap
    input      [ 8:0] hsize, vsize,   // visible size, from the GGA
    input      [ 8:0] scrx, scry,

    output     [11:1] fgv_addr,
    input      [15:0] fgv_dout,

    output     [20:2] rom_addr,
    output            rom_cs,
    input      [31:0] rom_data,
    input             rom_ok,

    output     [ 7:0] pxl          // 0xff is transparent
);

// Calibration against MAME's screen.png: the layer sits 1 pixel right and
// 8 lines low without these. The 8 lines are common to every layer and are
// probably the visarea origin (MAME shows lines 8..247), so they may fold
// into the video timing later


// Screen flip mirrors the raster. HOFFSET is a raster origin so it goes INSIDE
// the mirror, otherwise it lands on the wrong side and shows up doubled.
// The pixel select below is a direct index, so no per-tile flip is needed -
// mirroring heff already picks the right pixel
// The prefetch reads the group four pixels ahead. At the end of the line that
// points past it, so the first visible group is fetched from the wrong address
// and the line opens with four dead pixels. Move the discontinuity into
// blanking - vdump has already advanced by then, so the prefetch naturally
// targets the next line. Same trick as hdump_scr in jtpspike_video
wire [ 8:0] hwrap= hdump >= 9'd400 ? hdump - (h_last + 9'd1) : hdump;
wire [ 8:0] hraw = hwrap + HOFFSET;
wire [ 8:0] hdm  = flip ? ~hraw  + hsize : hraw;
wire [ 8:0] vdm  = flip ? ~vdump + vsize : vdump;
// the game writes its own compensation when flipped, +160/+10; cancel it
wire [ 8:0] heff = hdm + scrx - (flip && SCROLL_COMP!=0 ? 9'd160 : 9'd0);
wire [ 8:0] veff = vdm + scry + VOFFSET - (flip && SCROLL_COMP!=0 ? 9'd10 : 9'd0);
// address the tile that owns the NEXT group of four pixels, so the VRAM and
// the ROM both have a full group of pxl_cen to answer. Flipped, heff runs
// backwards, so the next group is four LOWER
wire [ 8:0] hnx  = flip ? heff - 9'd4 : heff + 9'd4;
wire [14:0] code = {{(15-CODEW){1'b0}},fgv_dout[CODEW-1:0]};
wire        vflip= VFLIP!=0 && fgv_dout[15];
wire [ 2:0] row  = vflip ? ~veff[2:0] : veff[2:0];

    localparam [2:0] S_IDLE=0, S_MAP_WAIT=1, S_MAP=2, S_WAIT=3, S_ROM=4;
    reg  [ 2:0] st;
    reg  [10:0] map_addr;
    reg  [18:0] fetch_addr;
    reg         fetch_cs;
    reg  [ 2:0] fetch_row;
    reg         fetch_half;
    reg  [24:0] fetch_tag, cur_tag, nxt_tag;
    reg  [31:0] cur, nxt;
    reg         cur_valid, nxt_valid;
    wire [24:0] target_tag = { vdump, veff, hnx[8:2] };
    wire [24:0] display_tag = { vdump, veff, heff[8:2] };
    wire        target_cur = cur_valid && cur_tag==target_tag;
    wire        target_nxt = nxt_valid && nxt_tag==target_tag;
    wire        display_cur = cur_valid && cur_tag==display_tag;
    wire        display_nxt = nxt_valid && nxt_tag==display_tag;
    wire [31:0] display_word = display_cur ? cur : nxt;
    wire [ 2:0] tile_row = vflip ? ~fetch_row : fetch_row;
    reg  [ 7:0] pixel;

    assign fgv_addr = map_addr;
    assign rom_addr = fetch_addr;
    assign rom_cs   = fetch_cs;
    assign pxl      = display_cur || display_nxt ? pixel : 8'hff;

    always @* begin
        case( heff[1:0] )
            2'd0: pixel = display_word[ 7: 0];
            2'd1: pixel = display_word[15: 8];
            2'd2: pixel = display_word[23:16];
            2'd3: pixel = display_word[31:24];
        endcase
    end

    always @(posedge clk) begin
        if( rst ) begin
            st         <= S_IDLE;
            map_addr   <= 0;
            fetch_addr <= 0;
            fetch_cs   <= 0;
            fetch_row  <= 0;
            fetch_half <= 0;
            fetch_tag  <= 0;
            cur_tag    <= 0;
            nxt_tag    <= 0;
            cur        <= 32'hffffffff;
            nxt        <= 32'hffffffff;
            cur_valid  <= 0;
            nxt_valid  <= 0;
        end else case( st )
            S_IDLE: if( !target_cur && !target_nxt ) begin
                map_addr   <= { veff[7:3], hnx[8:3] };
                fetch_row  <= veff[2:0];
                fetch_half <= hnx[2];
                fetch_tag  <= target_tag;
                st         <= S_MAP_WAIT;
            end
            S_MAP_WAIT: st <= S_MAP;
            S_MAP: begin
                fetch_addr <= { code, tile_row, fetch_half };
                fetch_cs   <= 1;
                st         <= S_WAIT;
            end
            S_WAIT: st <= S_ROM;
            S_ROM: if( rom_ok ) begin
                nxt       <= cur;
                nxt_tag   <= cur_tag;
                nxt_valid <= cur_valid;
                cur       <= rom_data;
                cur_tag   <= fetch_tag;
                cur_valid <= 1;
                fetch_cs  <= 0;
                st        <= S_IDLE;
            end
            default: begin
                fetch_cs <= 0;
                st       <= S_IDLE;
            end
        endcase
    end

`ifdef SIMULATION
    integer sim_pixels, sim_missing, sim_requests, sim_wait;
    always @(posedge clk) begin
        if( rst ) begin
            sim_pixels   <= 0;
            sim_missing  <= 0;
            sim_requests <= 0;
            sim_wait     <= 0;
        end else if( pxl_cen && hdump==0 && vdump==0 ) begin
            $display("FG_FETCH pixels=%0d missing=%0d requests=%0d wait_cycles=%0d",sim_pixels,sim_missing,sim_requests,sim_wait);
            sim_pixels   <= 1;
            sim_missing  <= display_cur || display_nxt ? 0 : 1;
            sim_requests <= 0;
            sim_wait     <= 0;
        end else begin
            if( pxl_cen && hdump<=hsize && vdump<=vsize ) begin
                sim_pixels <= sim_pixels+1;
                if( !display_cur && !display_nxt ) sim_missing <= sim_missing+1;
            end
            if( st==S_MAP ) sim_requests <= sim_requests+1;
            if( st==S_ROM && !rom_ok ) sim_wait <= sim_wait+1;
        end
    end
`endif

endmodule
