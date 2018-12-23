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
    
`timescale 1ns/1ps

module jtgng_game(
    input           rst,
    input           soft_rst,
    input           clk,        // 24 MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL,
    output          LVBL,
    // cabinet I/O
    input   [7:0]   joystick1,
    input   [7:0]   joystick2,  
    // SDRAM interface
    input           SDRAM_CLK,      // SDRAM Clock 81 MHz
    inout  [15:0]   SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output [12:0]   SDRAM_A,        // SDRAM Address bus 13 Bits
    output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output [1:0]    SDRAM_BA,       // SDRAM Bank Address
    output          SDRAM_CKE,      // SDRAM Clock Enable
    // ROM load
    input           downloading,
    input   [24:0]  romload_addr,
    input   [15:0]  romload_data,
    input           romload_wr,
    // DEBUG
    input           enable_char,
    input           enable_obj,
    input           enable_scr,
    // DIP switches
    input           dip_game_mode,
    input           dip_attract_snd,
    input           dip_upright,
    // Sound output
    output  signed [15:0] ym_snd
);

    wire [8:0] V;
    wire [8:0] H;
    wire Hinit;

    wire [12:0] cpu_AB;
    wire char_cs;
    wire flip;
    wire [7:0] cpu_dout, char_dout;
    wire rd;
    wire char_mrdy;
    wire [12:0] char_addr;
    wire [ 7:0] chram_dout,scram_dout;
    wire [15:0] chrom_data;
    wire [1:0] char_col;
    wire rom_ready;

wire [31:0] crc;

reg rst_game;
reg rst_aux;

always @(posedge clk or posedge rst or negedge rom_ready)
    if( rst || !rom_ready ) begin
        {rst_game,rst_aux} <= 2'b11;
    end
    else begin
        {rst_game,rst_aux} <= {rst_aux, downloading };
    end

reg cen_6;

reg [1:0] cen_cnt;
always @(posedge clk)
    if( rst )
        cen_cnt <= 2'b0;
    else
        cen_cnt <= cen_cnt+2'b1;

always @(negedge clk)
    cen_6 <= cen_cnt==2'b0; // 6MHz clock divider


jtgng_timer timers (
    .clk       ( clk      ),
    .clk_en    ( cen_6    ),
    .rst       ( rst      ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( Hinit    ),
    .LHBL      ( LHBL     ),
    .LVBL      ( LVBL     ),
    .LHBL_short(LHBL_short)
);

    wire RnW;
    wire [3:0] char_pal;

jtgng_char chargen (
    .clk        ( clk           ),
    .clk_en     ( cen_6         ),
    .AB         ( cpu_AB[10:0]  ),
    .V128       ( V[7:0]        ),
    .H128       ( H[7:0]        ),
    .char_cs    ( char_cs       ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( chram_dout    ),
    .rd         ( RnW           ),
    .MRDY_b     ( char_mrdy     ),
    .char_addr  ( char_addr     ),
    .chrom_data ( chrom_data    ),
    .char_col   ( char_col      ),
    .char_pal   ( char_pal      )
);

wire scr_mrdy, scrwin;
wire [14:0] scr_addr;
wire [23:0] scr_dout;
wire [ 2:0] scr_col;
wire [ 2:0] scr_pal;
wire [ 2:0] HS;

jtgng_scroll scrollgen (
    .clk        ( clk           ),
    .AB         ( cpu_AB[10:0]  ),
    .V128       ( V[7:0]        ),
    .H          ( H             ),
    .HSlow      ( HS            ),
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),
    .flip       ( flip          ),
    .din        ( cpu_dout      ),
    .dout       ( scram_dout    ),
    .rd         ( RnW           ),
    .MRDY_b     ( scr_mrdy      ),
    .scr_addr   ( scr_addr      ),
    .scr_col    ( scr_col       ),
    .scr_pal    ( scr_pal       ),
    .scrom_data ( scr_dout      ),
    .scrwin     ( scrwin        )
);


wire [3:0] cc;
wire blue_cs;
wire redgreen_cs;
wire [ 5:0] obj_pxl;

jtgng_colmix colmix (
    .rst        ( rst           ),
    .clk        ( clk           ),
    // .H           ( H[2:0]        ),
    // characters
    .chr_col    ( char_col      ),
    .chr_pal    ( char_pal      ),
    // scroll
    .scr_col    ( scr_col       ),
    .scr_pal    ( scr_pal       ),
    .scrwin     ( scrwin        ),
    // objects
    .obj_pxl    ( obj_pxl       ),
    // DEBUG
    .enable_char( enable_char   ),
    .enable_obj ( enable_obj    ),
    .enable_scr ( enable_scr    ),
    // CPU interface
    .AB         ( cpu_AB[7:0]   ),
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    .DB         ( cpu_dout      ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);


    wire bus_ack, bus_req;
    wire [16:0] main_addr;
    wire [7:0] main_dout;
    wire [15:0] sdram_din;
    wire [12:0] wr_row;
    wire [ 8:0] wr_col; 
    wire        main_cs;
// OBJ  
    wire [ 8:0] obj_AB;
    wire OKOUT;
    wire [7:0] main_ram;
    wire blcnten, rom_mrdy;
// sound
    wire sres_b;
    wire [7:0] snd_latch;
jtgng_main main (
    .clk        ( clk           ),
    .rst        ( rst_game      ),
    .soft_rst   ( soft_rst      ),
    .ch_mrdy    ( char_mrdy     ),
    .scr_mrdy   ( scr_mrdy      ),
    .char_dout  ( chram_dout    ),
    .scr_dout   ( scram_dout    ),
    // bus sharing
    .ram_dout   ( main_ram      ),
    .obj_AB     ( obj_AB        ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    
    .LVBL       ( LVBL          ),
    .main_cs    ( main_cs       ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .scr_cs     ( scr_cs        ),
    .scrpos_cs  ( scrpos_cs     ),
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    .flip       ( flip          ),
    .bus_ack    ( bus_ack       ),
    .cpu_AB     ( cpu_AB        ),
    .RnW        ( RnW           ),
    .rom_addr   ( main_addr     ),
    .rom_dout   ( main_dout     ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),  
    // SDRAM programming
    .sdram_din  ( sdram_din     ),
    .wr_row     ( wr_row        ),
    .wr_col     ( wr_col        ),
    .sdram_we   ( sdram_we      ),
    .crc        ( crc           ),  
    .rom_mrdy   ( rom_mrdy      ),
    // DIP switches
    .dip_flip       ( 1'b0      ),
    .dip_game_mode  ( dip_game_mode     ),
    .dip_attract_snd( dip_attract_snd   ),
    .dip_upright    ( dip_upright       )
);

wire [14:0] obj_addr;
wire [31:0] obj_dout;

jtgng_obj obj (
    .clk     (clk     ),
    .rst     (rst     ),
    .AB      (obj_AB  ),
    .DB      (main_ram),
    .OKOUT   (OKOUT   ),
    .bus_req (bus_req ),
    .bus_ack (bus_ack ),
    .blen    (blcnten ),
    .LVBL    ( LVBL   ),
    .LHBL    ( LHBL   ),
    .HINIT   ( Hinit  ),
    .flip    ( flip   ),
    .V       ( V[7:0] ),
    .H       ( H      ),
    // SDRAM interface
    .obj_addr( obj_addr ),
    .objrom_data( obj_dout ),
    // pixel data
    .obj_pxl ( obj_pxl )
);


    wire [14:0] snd_addr;
    wire [ 7:0] snd_dout;
    wire        snd_cs;
    wire        snd_wait_n;
jtgng_sound sound (
    .clk            ( clk           ),
    .clk_en         ( cen_6         ),
    .rst            ( rst_game      ),
    .soft_rst       ( soft_rst      ),
    .sres_b         ( sres_b        ),
    .snd_latch      ( snd_latch     ),
    .V32            ( V[5]          ),
    .rom_addr       ( snd_addr      ),
    .rom_dout       ( snd_dout      ),
    .rom_cs         ( snd_cs        ),
    .ym_snd         ( ym_snd        )  
);


jtgng_rom rom (
    .clk        ( SDRAM_CLK     ),
    .rst        ( rst           ),
    .char_addr  ( char_addr     ),
    .main_addr  ( main_addr     ),
    .snd_addr   ( snd_addr      ),
    .obj_addr   ( obj_addr      ),
    .scr_addr   ( scr_addr      ),

    .char_dout  ( chrom_data    ),
    .main_dout  ( main_dout     ),
    .snd_dout   ( snd_dout      ),
    .obj_dout   ( obj_dout      ),
    .scr_dout_pxl( scr_dout     ),
    .ready      ( rom_ready     ),
    // SDRAM programming
    .din        ( sdram_din     ),
    .wr_row     ( wr_row        ),
    .wr_col     ( wr_col        ),
    .we         ( sdram_we      ),  
    // SDRAM interface
    .SDRAM_DQ   ( SDRAM_DQ      ),
    .SDRAM_A    ( SDRAM_A       ),
    .SDRAM_DQML ( SDRAM_DQML    ),
    .SDRAM_DQMH ( SDRAM_DQMH    ),
    .SDRAM_nWE  ( SDRAM_nWE     ),
    .SDRAM_nCAS ( SDRAM_nCAS    ),
    .SDRAM_nRAS ( SDRAM_nRAS    ),
    .SDRAM_nCS  ( SDRAM_nCS     ),
    .SDRAM_BA   ( SDRAM_BA      ),
    .SDRAM_CKE  ( SDRAM_CKE     ),
    // ROM load
    .downloading( downloading ),
    .romload_addr( romload_addr ),
    .romload_data( romload_data ),
    .romload_wr ( romload_wr    ),
    .crc_out    ( crc           )
);


endmodule // jtgng