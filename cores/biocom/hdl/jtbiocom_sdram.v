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
    Date: 10-1-2020 */


module jtbiocom_sdram(
    input           rst,
    input           clk,

    input           LVBL,

    input           main_cs,
    input           snd_cs,

    output          main_ok,
    output          snd_ok,
    output          char_ok,
    output          scr1_ok,
    output          scr2_ok,
    output          obj_ok,

    input [17:1]    main_addr,
    input [14:0]     snd_addr,
    input [12:0]    char_addr,
    input [16:0]    scr1_addr,
    input [14:0]    scr2_addr,
    input [16:0]     obj_addr,

    output [15:0]   main_data,
    output [ 7:0]   snd_data,
    output [15:0]   char_data,
    output [15:0]   scr1_data,
    output [15:0]   scr2_data,
    output [15:0]   obj_data,

    // SDRAM
    // Bank 0: allows R/W
    output   [21:0] ba0_addr,
    output   [21:0] ba1_addr,
    output   [21:0] ba2_addr,
    output   [21:0] ba3_addr,
    output   [ 3:0] ba_rd,
    output          ba0_wr,
    output   [15:0] ba0_din,
    output   [ 1:0] ba0_din_m,  // write mask
    input    [ 3:0] ba_dst,
    input    [ 3:0] ba_rdy,
    input    [ 3:0] ba_ack,

    input    [15:0] data_read
);

localparam [21:0] ZERO_OFFSET = 22'd0,
                  SCR1_OFFSET = 22'h10_0000,
                  SCR2_OFFSET = 22'h02_0000,
                   OBJ_OFFSET = 22'h10_0000;

assign ba0_wr    = 0;
assign ba0_din   = 0;
assign ba0_din_m = 3;

// Bank 0: M68000
jtframe_rom_1slot #(
    .SLOT0_AW    ( 17            ),
    .SLOT0_DW    ( 16            )
) u_bank0 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( main_cs       ),
    .slot0_ok    ( main_ok       ),
    .slot0_addr  ( main_addr     ),
    .slot0_dout  ( main_data     ),

    .sdram_addr  ( ba0_addr      ),
    .sdram_req   ( ba_rd[0]      ),
    .sdram_ack   ( ba_ack[0]     ),
    .data_dst    ( ba_dst[0]     ),
    .data_rdy    ( ba_rdy[0]     ),
    .data_read   ( data_read     )
);

// Bank 1: Sound
jtframe_rom_1slot #(
    .SLOT0_AW    ( 15            ),
    .SLOT0_DW    (  8            )
) u_bank1 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( snd_cs        ),
    .slot0_ok    ( snd_ok        ),
    .slot0_addr  ( snd_addr      ),
    .slot0_dout  ( snd_data      ),

    .sdram_addr  ( ba1_addr      ),
    .sdram_req   ( ba_rd[1]      ),
    .sdram_ack   ( ba_ack[1]     ),
    .data_dst    ( ba_dst[1]     ),
    .data_rdy    ( ba_rdy[1]     ),
    .data_read   ( data_read     )
);
// Bank 2: Char/SCR1
jtframe_rom_2slots #(
    // Slot 0: Char
    .SLOT0_AW    ( 13            ),
    .SLOT0_DW    ( 16            ),
    .SLOT0_OFFSET( ZERO_OFFSET   ),

    // Slot 1: Scroll 1
    .SLOT1_AW    ( 17            ),
    .SLOT1_DW    ( 16            ),
    .SLOT1_OFFSET( SCR1_OFFSET   )
) u_bank2 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ),
    .slot1_cs    ( LVBL          ),

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( scr1_ok       ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( scr1_addr     ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( scr1_data     ),

    .sdram_addr  ( ba2_addr      ),
    .sdram_req   ( ba_rd[2]      ),
    .sdram_ack   ( ba_ack[2]     ),
    .data_dst    ( ba_dst[2]     ),
    .data_rdy    ( ba_rdy[2]     ),
    .data_read   ( data_read     )
);

// Bank 3: SCR2/Obj
jtframe_rom_2slots #(
    // Slot 0: Scroll 2
    .SLOT0_AW    ( 15            ),
    .SLOT0_DW    ( 16            ),
    .SLOT0_OFFSET( SCR2_OFFSET   ),

    // Slot 1: Obj
    .SLOT1_AW    ( 17            ),
    .SLOT1_DW    ( 16            ),
    .SLOT1_OFFSET(  OBJ_OFFSET   )
) u_bank3 (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( LVBL          ),
    .slot1_cs    ( 1'b1          ), // obj

    .slot0_ok    ( scr2_ok       ),
    .slot1_ok    ( obj_ok        ),

    .slot0_addr  ( scr2_addr     ),
    .slot1_addr  (  obj_addr     ),

    .slot0_dout  ( scr2_data     ),
    .slot1_dout  ( obj_data      ),

    .sdram_addr  ( ba3_addr      ),
    .sdram_req   ( ba_rd[3]      ),
    .sdram_ack   ( ba_ack[3]     ),
    .data_dst    ( ba_dst[3]     ),
    .data_rdy    ( ba_rdy[3]     ),
    .data_read   ( data_read     )
);

endmodule
