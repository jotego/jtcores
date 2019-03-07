/*  This file is part of JT_GNG.
    JT_GNG program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT_GNG program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT_GNG.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 20-2-2019 */

`timescale 1ns/1ps

module jt1943_rom(
    input               rst,
    input               clk,
    input               cen12, // 12 MHz
    input       [ 2:0]  H,
    input               Hsub,
    input               LHBL,
    input               LVBL,
    output  reg         sdram_re, // any edge (rising or falling)
        // means a read request

    input       [13:0]  char_addr, //  32 kB
    input       [17:0]  main_addr, // 160 kB, addressed as 8-bit words
    input       [17:0]  obj_addr,  // 256 kB
    input       [16:0]  scr1_addr, // 256 kB (16-bit words)
    input       [14:0]  scr2_addr, //  64 kB
    input       [13:0]  map1_addr, //  32 kB
    input       [13:0]  map2_addr, //  32 kB

    output  reg [15:0]  char_dout,
    output  reg [ 7:0]  main_dout,
    output  reg [15:0]  obj_dout,
    output  reg [15:0]  map1_dout,
    output  reg [15:0]  map2_dout,
    output  reg [15:0]  scr1_dout,
    output  reg [15:0]  scr2_dout,
    output  reg         ready,
    // ROM interface
    input               downloading,
    input               loop_rst,
    output  reg [21:0]  sdram_addr,
    input       [15:0]  data_read
);

wire [3:0] rd_state = { H, Hsub }; // +4'd1;

// H is used to align with the pixel transfers
// the SDRAM-read state machine will start at roughly pixel 0 (of each 8-pixel tuple)
// the difference in time is less than 1/2 clk24 cycle
// this avoids data coming at unexpected time.

reg  [15:0] scr_aux;
reg main_lsb, snd_lsb;

// Main code
// bme01.12d -> 32kB
// bme02.13d, bme03.14d, -> 128kB, 8 banks of 16kB each
parameter  snd_offset = 22'h14_000; // bm05.4k,  32kB
parameter char_offset = 22'h18_000; // bm04.5h,  32kB
parameter map1_offset = 22'h1C_000; // bm14.5f,  32kB
parameter map2_offset = 22'h20_000; // bmm23.8k, 32kB
parameter scr1_offset = 22'h24_000; // 10f/j, 11f/j, 12f/j, 14f/j 256kB
parameter scr2_offset = 22'h44_000; // 14k/l 64kB
parameter  obj_offset = 22'h4C_000; // 10a/c, 11a/c, 12a/c, 14a/c 256kB
// 6C_000 = ROM LEN

localparam col_w = 9, row_w = 13;
localparam addr_w = 13, data_w = 16;

reg [3:0] ready_cnt;
reg [3:0] rd_state_last;

`ifdef SIMULATION
wire main_rq = rd_state[1:0]==2'b01;
wire  snd_rq = rd_state[1:0]==2'b00;
wire  obj_rq = rd_state[2:0] == 3'b011;
`endif
wire char_rq = rd_state == 4'd2;
wire  scr_rq = rd_state[2:1] == 2'b11;

always @(posedge clk) if(cen12) begin
    if( loop_rst || downloading )
        sdram_re <= 1'b0;   // start strobing before ready signal
            // because first data must be read before that signal.
    else
        sdram_re <= ~sdram_re;
end

always @(posedge clk)
if( loop_rst || downloading ) begin
    sdram_addr <= {(addr_w+col_w){1'b0}};
    main_dout <=  8'd0;
    char_dout <= 16'd0;
    obj_dout  <= 16'd0;
    scr1_dout <= 16'd0;
    scr2_dout <= 16'd0;
    ready_cnt <=  4'd0;
    ready     <=  1'b0;
end else if(cen12) begin
    {ready, ready_cnt}  <= {ready_cnt, 1'b1};
    rd_state_last <= rd_state;
    // Get data from current read
    casez(rd_state_last)
        4'b?100: scr1_dout <= data_read;

        4'b??01: main_dout <= !main_lsb ? data_read[15:8] : data_read[ 7:0];

        4'b0010: char_dout <= data_read;
        4'b0110: ; // unused
        4'b1010: map1_dout <= data_read;
        4'b1110: map2_dout <= data_read;

        4'b?011: obj_dout  <= data_read;
        4'b?111: scr2_dout <= data_read;
        default:;
    endcase
    casez(rd_state)
        4'b?100: sdram_addr <= scr1_offset + { 5'b0, scr1_addr }; // 14:0 B/C ROMs

        4'b??01: begin
            sdram_addr <= { 4'd0, main_addr[17:1] };
            main_lsb <= main_addr[0];
        end

        4'b0010: sdram_addr <= char_offset + { 8'b0, char_addr }; // 12:0
        4'b1010: sdram_addr <= map1_offset + { 8'b0, map1_addr }; // 12:0
        4'b1110: sdram_addr <= map2_offset + { 8'b0, map2_addr }; // 12:0

        4'b?011: sdram_addr <= obj_offset + { 6'b0,  obj_addr }; // 15:0
        4'b?111: sdram_addr <= scr2_offset+ { 7'b0, scr2_addr }; // scr_addr E ROMs
        default:;
    endcase
    // autorefresh <= !LVBL && (char_rq || scr_rq); // rd_state==4'd14;
end

endmodule // jtgng_rom