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
    Date: 27-10-2017 */

module jtgng_rom(
    input               rst,
    input               clk,
    input               cen12, // 12 MHz
    input       [ 2:0]  H,
    input               Hsub,
    input               LHBL,
    input               LVBL,
    output  reg         sdram_re, // any edge (rising or falling)
        // means a read request

    input       [12:0]  char_addr,
    input       [16:0]  main_addr,
    input       [14:0]  snd_addr,
    input       [15:0]  obj_addr,
    input       [14:0]  scr_addr,

    output  reg [15:0]  char_dout,
    output  reg [ 7:0]  main_dout,
    output  reg [ 7:0]  snd_dout,
    output  reg [15:0]  obj_dout,
    output  reg [23:0]  scr_dout,
    output  reg         ready,
    // ROM interface
    input               downloading,
    input               loop_rst,
    output  reg         autorefresh,
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

// Default values correspond to G&G
parameter  snd_offset = 22'h0A000;
parameter char_offset = 22'h0E000;
parameter  scr_offset = 22'h10000;
parameter scr2_offset = 22'h08000; // upper byte of each tile
parameter  obj_offset = 22'h20000;

localparam col_w = 9, row_w = 13;
localparam addr_w = 13, data_w = 16;

reg [3:0] ready_cnt;
reg [3:0] rd_state_last;

`ifdef SIMULATION
wire main_rq = rd_state[1:0] ==  2'b01;
wire  snd_rq = rd_state[2:0] == 3'b000;
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

// 0, 8:        sound
// 1, 4, 9, 12: main
// 2            char
// 3, 11        obj
// 6, 14, 7, 15 scr

always @(posedge clk)
if( loop_rst || downloading ) begin
    //rd_state    <= { H,1'b1 };
    autorefresh <= 1'b0;
    sdram_addr <= {(addr_w+col_w){1'b0}};
    snd_dout  <=  8'd0;
    main_dout <=  8'd0;
    char_dout <= 16'd0;
    obj_dout  <= 16'd0;
    scr_dout  <= 24'd0;
    ready_cnt <=  4'd0;
    ready     <=  1'b0;
end else if(cen12) begin
    {ready, ready_cnt}  <= {ready_cnt, 1'b1};
    rd_state_last <= rd_state;
    // Get data from current read
    casez(rd_state_last) // I hope the -4'd1 gets re-encoded in the
        // case list, rather than getting implemented as an actual adder
        // but it depends on how good the synthesis tool is.
        // Anyway, the idea is that we get the data for the last address
        // requested but rd_state has already gone up by 1, that's why
        // we need this
        4'b??00: snd_dout  <=  !snd_lsb ? data_read[15:8] : data_read[ 7:0];
        4'b??01: main_dout <= !main_lsb ? data_read[15:8] : data_read[ 7:0];
        4'b0010: char_dout <= data_read;
        4'b?011: obj_dout  <= data_read;
        4'b?110: scr_aux   <= data_read; // coding: z - y - x bytes as in G&G schematics
        4'b?111: scr_dout  <= { data_read[7:0] | data_read[15:8], scr_aux }; // for the upper byte, it doesn't matter which half of the word was used, as long as one half is zero.
        default:;
    endcase
    casez(rd_state)
        4'b??00: begin
            sdram_addr <= snd_offset + { 8'b0,  snd_addr[14:1] }; // 14:0
            snd_lsb <= snd_addr[0];
        end
        4'b??01: begin
            sdram_addr <= { 6'd0, main_addr[16:1] }; // 16:0
            main_lsb <= main_addr[0];
        end
        4'b0010: sdram_addr <= char_offset + { 9'b0, char_addr }; // 12:0
        4'b?011: sdram_addr <=  obj_offset + { 6'b0,  obj_addr }; // 15:0
        4'b?110: sdram_addr <=  scr_offset + { 6'b0,  scr_addr }; // 14:0 B/C ROMs
        4'b?111: sdram_addr <=  sdram_addr + scr2_offset; // scr_addr E ROMs
        default:;
    endcase
    autorefresh <= !LVBL && (char_rq || scr_rq); // rd_state==4'd14;
end

endmodule // jtgng_rom