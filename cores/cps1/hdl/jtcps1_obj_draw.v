/*  This file is part of JTCORES1.
    JTCORES1 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES1 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES1.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 2.0
    Date: 23-1-2021 */

module jtcps1_obj_draw (
    input              rst,
    input              clk,

    input      [15:0]  obj_code,
    input      [15:0]  obj_attr,
    input      [ 8:0]  obj_hpos,
    input      [ 1:0]  obj_bank,
    `ifdef CPS2
    input      [ 2:0]  obj_prio,
    output reg [ 2:0]  buf_prio,
    `endif

    input              start,
    output reg         idle,
    // Line buffer
    output reg [ 8:0]  buf_addr,
    output reg [ 8:0]  buf_data,
    output reg         buf_wr,

    // ROM interface
    output reg [19:0]  rom_addr,    // up to 1 MB
    output reg [ 1:0]  rom_bank,
    output reg         rom_half,    // selects which half to read
    input      [31:0]  rom_data,
    output reg         rom_cs,
    input              rom_ok
);

wire [ 3:0] vsub;
wire [ 4:0] next_pal;
reg  [ 4:0] pal;
wire        next_hflip;
reg         hflip;
reg         wait_cycle;
reg  [ 7:0] draw_cnt;
reg  [ 8:0] next_buf;
reg         draw, half;
reg  [31:0] pxl_data;
wire        rom_good;

assign vsub     = obj_attr[11:8];
//     vflip    = obj_attr[6];
assign next_hflip = obj_attr[5];
assign next_pal = obj_attr[4:0];
assign rom_good = rom_ok && !wait_cycle;

function [3:0] colour;
    input [31:0] c;
    input        flip;
    colour = flip ? { c[24], c[16], c[ 8], c[0] } :
                    { c[31], c[23], c[15], c[7] };
endfunction

`ifdef SIMULATION
wire skipped = draw && draw_cnt[0] && &pxl_data;
`endif

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rom_addr   <= 20'd0;
        rom_half   <= 1'd0;
        buf_wr     <= 1'b0;
        buf_data   <= 9'd0;
        buf_addr   <= 9'd0;
        rom_cs     <= 1'b0;
        idle       <= 1;
        draw       <= 0;
        wait_cycle <= 0;
        draw_cnt   <= 8'h0;
        rom_bank   <= 2'd0;
    end else begin
        wait_cycle <= 0;
        if( idle ) begin
            if( start && obj_hpos>9'h20 && obj_hpos<9'h1d0 ) begin
                idle       <= 0;
                rom_cs     <= 1;
                rom_addr   <= { obj_code, vsub };
                rom_bank   <= obj_bank;
                next_buf   <= obj_hpos;
                rom_half   <= next_hflip;
                wait_cycle <= 1;
                half       <= 1;    // which half are we drawing?
            end else begin
                rom_cs   <= 0;
                rom_bank <= 2'd0;
            end
        end
        if( draw ) begin
            buf_wr   <= 1;
            buf_addr <= buf_addr+9'd1;
            buf_data <= { pal, colour(pxl_data, hflip) };
            pxl_data <= hflip ? {1'b1,pxl_data[31:1]} : {pxl_data[30:0],1'b1};
            draw_cnt <= draw_cnt>>1;
            if( draw_cnt[0] ) begin
                draw <= 0;
            end
        end else begin
            buf_wr <= 0;
        end
        if( !draw && !idle) begin
            if( rom_good ) begin
                pxl_data <= rom_data;
                half     <= 0;
                if( half ) begin
                    rom_half <= ~rom_half;
                    // copy new object data
                    buf_addr <= next_buf;
                    `ifdef CPS2
                    buf_prio <= obj_prio;
                    `endif
                    pal      <= next_pal;
                    hflip    <= next_hflip;
                end else begin
                    rom_cs <= 0;
                    idle   <= 1; // accept new requests
                end

                if( &rom_data ) begin
                    // skip blank pixels
                    wait_cycle <= 1;
                    buf_addr   <= (half ? next_buf : buf_addr) + 9'd8;
                    if( !half ) begin
                        rom_cs <= 0;
                        idle   <= 1;
                    end
                end else begin
                    draw <= 1;
                    draw_cnt <= 8'h80;
                end
            end
        end
    end
end

endmodule