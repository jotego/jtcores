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

module jtgng_rom2(
    input               rst,
    input               clk,
    input               LHBL,
    input               LVBL,

    input               main_cs,
    input               snd_cs,

    input       [12:0]  char_addr,
    input       [16:0]  main_addr,
    input       [14:0]   snd_addr,
    input       [15:0]  obj_addr,
    input       [14:0]  scr_addr,

    output      [15:0]  char_dout,
    output      [ 7:0]  main_dout,
    output      [ 7:0]   snd_dout,
    output      [15:0]   obj_dout,
    output      [15:0]  scr_dout,
    output  reg         ready,

    output              main_ok,
    output              snd_ok,
    // SDRAM controller interface
    input               data_rdy,
    input               sdram_ack,
    input               downloading,
    input               loop_rst,
    output  reg         sdram_req,
    output  reg         refresh_en,
    output  reg [21:0]  sdram_addr,
    input       [31:0]  data_read
);

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
wire main_req, char_req, map1_req, map2_req, scr_req, scr2_req, obj_req; //, snd_req;

reg  [ 4:0] data_sel;
wire [16:0] main_addr_req;
wire [14:0]  snd_addr_req;
wire [12:0] char_addr_req;
wire [15:0] obj_addr_req;
wire [14:0] scr_addr_req;

// wire blank_b = LVBL && LHBL;

always @(posedge clk)
    refresh_en <= !LVBL;

jt1943_romrq #(.AW(17),.INVERT_A0(1)) u_main(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( main_addr       ),
    .addr_ok  ( main_cs         ),
    .addr_req ( main_addr_req   ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( main_dout       ),
    .req      ( main_req        ),
    .data_ok  ( main_ok         ),
    .we       ( data_sel[0]     )
);

jt1943_romrq #(.AW(15),.INVERT_A0(1)) u_snd(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( snd_addr        ),
    .addr_ok  ( snd_cs          ),
    .addr_req ( snd_addr_req    ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( snd_dout        ),
    .req      ( snd_req         ),
    .data_ok  ( snd_ok          ),
    .we       ( data_sel[1]     )
);

jt1943_romrq #(.AW(15),.DW(16)) u_scr(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( scr_addr        ),
    .addr_ok  ( LVBL            ),
    .addr_req ( scr_addr_req    ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( scr_dout        ),
    .req      ( scr_req         ),
    .data_ok  (                 ),
    .we       ( data_sel[2]     )
);

jt1943_romrq #(.AW(16),.DW(16)) u_obj(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( obj_addr        ),
    .addr_ok  ( 1'b1            ),
    .addr_req ( obj_addr_req    ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( obj_dout        ),
    .req      ( obj_req         ),
    .data_ok  (                 ),
    .we       ( data_sel[3]     )
);

jt1943_romrq #(.AW(13),.DW(16)) u_char(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( 1'b1            ),
    .addr     ( char_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( char_addr_req   ),
    .din      ( data_read       ),
    .din_ok   ( data_rdy        ),
    .dout     ( char_dout       ),
    .req      ( char_req        ),
    .data_ok  (                 ),
    .we       ( data_sel[4]     )
);

`ifdef SIMULATION
real busy_cnt=0, total_cnt=0;
always @(posedge clk) begin
    total_cnt <= total_cnt + 1;
    if( |data_sel ) busy_cnt <= busy_cnt+1;
end
always @(posedge LVBL) begin
    $display("INFO: frame ROM stats: %.0f %%", 100.0*busy_cnt/total_cnt);
end
`endif

always @(posedge clk)
if( loop_rst || downloading ) begin
    sdram_addr <= 22'b0;
    ready_cnt  <=  4'd0;
    ready      <=  1'b0;
    sdram_req  <=  1'b0;
    data_sel   <=   'd0;
end else begin
    {ready, ready_cnt}  <= {ready_cnt, 1'b1};
    if( data_rdy ) begin
        data_sel <= 'd0;
    end
    if( sdram_ack ) sdram_req <= 1'b0;
    // accept a new request
    if( data_sel==7'd0 ) begin
        sdram_req <= main_req | scr_req | char_req | obj_req;
        data_sel   <= 'd0;
        case( 1'b1 )
            main_req: begin
                sdram_addr <= { 5'd0, main_addr_req[16:1] };
                data_sel[0] <= 'b1;
            end
            snd_req: begin
                sdram_addr <= snd_offset + { 7'b0, snd_addr_req[14:1] };
                data_sel[1] <= 'b1;
            end
            scr_req: begin
                sdram_addr <= scr_offset + { 7'b0, scr_addr_req };
                data_sel[2] <= 'b1;
            end
            obj_req: begin
                sdram_addr <= obj_offset + { 6'b0, obj_addr_req };
                data_sel[3] <= 'b1;
            end
            char_req: begin
                sdram_addr <= char_offset + { 9'b0, char_addr_req };
                data_sel[4] <= 'b1;
            end
        endcase
    end
end

endmodule // jtgng_rom