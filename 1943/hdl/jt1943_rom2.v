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

module jt1943_rom2(
    input               rst,
    input               clk,
    input               cen12, // 12 MHz
    input               LHBL,
    input               LVBL,
    output  reg         sdram_re, // any edge (rising or falling)
        // means a read request

    input               main_cs,
    input               snd_cs,

    input       [13:0]  char_addr, //  32 kB
    input       [17:0]  main_addr, // 160 kB, addressed as 8-bit words
    input       [14:0]   snd_addr, //  32 kB
    input       [16:0]  obj_addr,  // 256 kB
    input       [16:0]  scr1_addr, // 256 kB (16-bit words)
    input       [14:0]  scr2_addr, //  64 kB
    input       [13:0]  map1_addr, //  32 kB
    input       [13:0]  map2_addr, //  32 kB

    output      [15:0]  char_dout,
    output      [ 7:0]  main_dout,
    // output      [ 7:0]   snd_dout,
    output      [15:0]   obj_dout,
    output      [15:0]  map1_dout,
    output      [15:0]  map2_dout,
    output      [15:0]  scr1_dout,
    output      [15:0]  scr2_dout,
    output  reg         ready,

    output              main_ok,
    // output              snd_ok,
    // ROM interface
    input               downloading,
    input               loop_rst,
    output  reg [21:0]  sdram_addr,
    input       [31:0]  data_read
);

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

always @(posedge clk) if(cen12) begin
    if( loop_rst || downloading )
        sdram_re <= 1'b0;   // start strobing before ready signal
            // because first data must be read before that signal.
    else
        sdram_re <= ~sdram_re;
end

reg [6:0] data_sel;
wire main_req, char_req, map1_req, map2_req, scr1_req, scr2_req, obj_req; //, snd_req;
wire [17:0] main_addr_req;
// wire [14:0]  snd_addr_req;
wire [13:0] char_addr_req;
wire [16:0] obj_addr_req;
wire [16:0] scr1_addr_req;
wire [14:0] scr2_addr_req;
wire [13:0] map1_addr_req;
wire [13:0] map2_addr_req;

wire blank_b = LVBL && LHBL;

jt1943_romrq #(.AW(18),.INVERT_A0(1)) u_main(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( cen12           ),
    .addr     ( main_addr       ),
    .addr_ok  ( main_cs         ),
    .addr_req ( main_addr_req   ),
    .din      ( data_read       ),
    .dout     ( main_dout       ),
    .req      ( main_req        ),
    .data_ok  ( main_ok         ),
    .we       ( data_sel[0]     )
);


// jt1943_romrq #(.AW(15),.INVERT_A0(1)) u_snd(
//     .rst      ( rst             ),
//     .clk      ( clk             ),
//     .cen      ( cen12           ),
//     .addr     ( snd_addr        ),
//     .addr_ok  ( snd_cs          ),
//     .addr_req ( snd_addr_req    ),
//     .din      ( data_read       ),
//     .dout     ( snd_dout        ),
//     .req      ( snd_req         ),
//     .data_ok  ( snd_ok          ),
//     .we       ( data_sel[7]     )
// );

jt1943_romrq #(.AW(14),.DW(16)) u_char(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( cen12           ),
    .addr     ( char_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( char_addr_req   ),
    .din      ( data_read       ),
    .dout     ( char_dout       ),
    .req      ( char_req        ),
    .data_ok  (                 ),
    .we       ( data_sel[1]     )
);

jt1943_romrq #(.AW(14),.DW(16)) u_map1(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( cen12           ),
    .addr     ( map1_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( map1_addr_req   ),
    .din      ( data_read       ),
    .dout     ( map1_dout       ),
    .req      ( map1_req        ),
    .data_ok  (                 ),
    .we       ( data_sel[2]     )
);

jt1943_romrq #(.AW(14),.DW(16)) u_map2(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( cen12           ),
    .addr     ( map2_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( map2_addr_req   ),
    .din      ( data_read       ),
    .dout     ( map2_dout       ),
    .req      ( map2_req        ),
    .data_ok  (                 ),
    .we       ( data_sel[3]     )
);

jt1943_romrq #(.AW(17),.DW(16)) u_scr1(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( cen12           ),
    .addr     ( scr1_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( scr1_addr_req   ),
    .din      ( data_read       ),
    .dout     ( scr1_dout       ),
    .req      ( scr1_req        ),
    .data_ok  (                 ),
    .we       ( data_sel[4]     )
);

jt1943_romrq #(.AW(15),.DW(16)) u_scr2(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( cen12           ),
    .addr     ( scr2_addr       ),
    .addr_ok  ( LVBL            ),
    .addr_req ( scr2_addr_req   ),
    .din      ( data_read       ),
    .dout     ( scr2_dout       ),
    .req      ( scr2_req        ),
    .data_ok  (                 ),
    .we       ( data_sel[5]     )
);

jt1943_romrq #(.AW(17),.DW(16)) u_obj(
    .rst      ( rst             ),
    .clk      ( clk             ),
    .cen      ( cen12           ),
    .addr     ( obj_addr        ),
    .addr_ok  ( 1'b1            ),
    .addr_req ( obj_addr_req    ),
    .din      ( data_read       ),
    .dout     ( obj_dout        ),
    .req      ( obj_req         ),
    .data_ok  (                 ),
    .we       ( data_sel[6]     )
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
    sdram_addr <= {(addr_w+col_w){1'b0}};
    ready_cnt <=  4'd0;
    ready     <=  1'b0;
end else if(cen12) begin
    {ready, ready_cnt}  <= {ready_cnt, 1'b1};
    case( 1'b1 )
        main_req: begin
            sdram_addr <= { 4'd0, main_addr_req[17:1] };
            data_sel   <= 'b1;
        end
        // snd_req: begin
        //     sdram_addr <= snd_offset + { 7'b0, snd_addr_req[14:1] };
        //     data_sel   <= 'b1000_0000;
        // end
        map1_req: begin
            sdram_addr <= map1_offset + { 8'b0, map1_addr_req };
            data_sel   <= 'b100;
        end
        scr1_req: begin
            sdram_addr <= scr1_offset + { 5'b0, scr1_addr_req };
            data_sel   <= 'b1_0000;
        end
        map2_req: begin
            sdram_addr <= map2_offset + { 8'b0, map2_addr_req };
            data_sel   <= 'b1000;
        end
        scr2_req: begin
            sdram_addr <= scr2_offset + { 7'b0, scr2_addr_req };
            data_sel   <= 'b10_0000;
        end
        char_req: begin
            sdram_addr <= char_offset + { 8'b0, char_addr_req };
            data_sel   <= 'b10;
        end
        obj_req: begin
            sdram_addr <= obj_offset + { 5'b0, obj_addr_req };
            data_sel   <= 'b100_0000;
        end
        default: data_sel <= 'b0;
    endcase
end

endmodule // jtgng_rom