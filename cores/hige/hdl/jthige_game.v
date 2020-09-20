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
    Date: 20-1-2019 */

module jthige_game(
    input           rst,
    input           clk,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [2:0]  red,
    output   [2:0]  green,
    output   [2:0]  blue,
    output          LHBL,
    output          LVBL,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 4:0]  joystick1, // MSB unused
    input   [ 4:0]  joystick2, // MSB unused

    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    input           loop_rst,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [31:0]  data_read,
    input           data_rdy,
    input           sdram_ack,
    output          refresh_en,

    // ROM LOAD
    input   [22:0]  ioctl_addr,
    input   [ 7:0]  ioctl_data,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,     // ignored
    input   [31:0]  dipsw,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  [15:0]  snd,
    output          sample,
    input           enable_psg, // unused
    input           enable_fm,  // unused
    // Debug
    input   [ 3:0]  gfx_en
);

// These signals are used by games which need
// to read back from SDRAM during the ROM download process
assign prog_rd    = 1'b0;
assign dwnld_busy = downloading;

wire [ 8:0] V;
wire [ 8:0] H;
wire        HINIT;
wire [12:0] cpu_AB;
wire [ 7:0] cpu_dout, char_dout;
wire [ 7:0] chram_dout;
wire [ 7:0] dipsw_a, dipsw_b;
wire        char_cs, flip, cpu_cen;
wire        main_ok, char_ok, obj_ok;
wire        cen12, cen6, cen3, cen1p5;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

assign sample=1'b1;

wire LHBL_obj, Hsub;

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dip_flip = ~flip;

localparam [21:0] CHAR_OFFSET = 22'h8000 >> 1,
                  OBJ_OFFSET  = 22'hA000 >> 1,
                  PROM_START  = 22'hE000;

localparam CHAR_AW=12, OBJ_AW=13, MAIN_AW=14;

// ROM data
wire  [CHAR_AW-1:0] char_addr;
wire  [ OBJ_AW-1:0] obj_addr;
wire  [MAIN_AW-1:0] main_addr;

wire  [15:0] char_data, obj_data;
wire  [ 7:0] main_data;

wire         wr_n, rd_n;
wire         main_cs, obj_cs;
wire         char_busy;
wire         prom_we;

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( LVBL     ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

jtframe_dwnld #(.PROM_START( PROM_START )) u_dwnld(
    .clk         ( clk           ),
    .downloading ( downloading   ),

    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_data  ( ioctl_data    ),
    .ioctl_wr    ( ioctl_wr      ),

    .prog_addr   ( prog_addr     ),
    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_we     ( prog_we       ),
    .prom_we     ( prom_we       ),

    .sdram_ack   ( sdram_ack     )
);

wire prom_pal_we   = prom_we && prog_addr < 22'he020;
wire prom_char_we  = prom_we && prog_addr >=22'he020 && prog_addr < 22'he120;
wire prom_obj_we   = prom_we && prog_addr >= 22'he220 && prog_addr < 22'he320;
wire prom_irq_we   = prom_we && prog_addr >= 22'he320;

wire [8:0] prom_addr = prog_addr[8:0] - 9'h20;

`ifndef NOMAIN
jthige_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cen1p5     ( cen1p5        ),
    .cpu_cen    ( cpu_cen       ),
    .LHBL       ( LHBL          ),
    .cpu_dout   ( cpu_dout      ),
    .dip_pause  ( dip_pause     ),
    // Char
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .char_dout  ( chram_dout    ),
    // video (other)
    .obj_cs     ( obj_cs        ),
    .flip       ( flip          ),
    .V          ( V[7:0]        ),
    .cpu_AB     ( cpu_AB        ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    // SDRAM / ROM access
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .coin_input  ( coin_input   ),
    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),
    // PROM K6
    .prog_addr  ( prom_addr[7:0]),
    .prom_irq_we( prom_irq_we   ),
    .prog_din   ( prog_data[3:0]),
    // DIP switches
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .coin_cnt   (               ),
    // Sound output
    .snd        ( snd           )
);
`else
assign main_cs   = 1'b0;
assign cpu_cen   = cen3;
assign char_cs   = 1'b0;
assign obj_cs    = 1'b0;
assign flip      = 1'b0;
`endif

jthige_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( cen6          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_addr  ( char_addr     ), // CHAR ROM
    .char_data  ( char_data     ),
    .char_ok    ( char_ok       ),
    .char_busy  ( char_busy     ),
    // OBJ
    .obj_cs     ( obj_cs        ),
    .HINIT      ( HINIT         ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL       ( LVBL          ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .gfx_en     ( gfx_en        ),
    // PROM access
    .prog_addr  ( prog_addr[7:0]),
    .prom_addr  ( prom_addr[7:0]),
    .prog_din   ( prog_data[3:0]),
    .prom_char_we( prom_char_we ),
    .prom_obj_we( prom_obj_we   ),
    .prom_pal_we( prom_pal_we   )
);

jtframe_rom #(
    .SLOT0_OFFSET( CHAR_OFFSET ),
    .SLOT8_OFFSET( OBJ_OFFSET  ),

    .SLOT0_DW    ( 16         ),
    .SLOT7_DW    (  8         ),
    .SLOT8_DW    ( 16         ),

    .SLOT0_AW    ( CHAR_AW    ),    // char
    .SLOT7_AW    ( MAIN_AW    ),    // main
    .SLOT8_AW    ( OBJ_AW     )     // OBJ
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .vblank      ( ~LVBL         ),

    .slot0_cs    ( LVBL          ),
    .slot1_cs    ( 1'b0          ),
    .slot2_cs    ( 1'b0          ),
    .slot3_cs    ( 1'b0          ), // unused
    .slot4_cs    ( 1'b0          ), // unused
    .slot5_cs    ( 1'b0          ), // unused
    .slot6_cs    ( 1'b0          ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ),

    .slot0_ok    ( char_ok       ),
    .slot1_ok    (               ),
    .slot2_ok    (               ),
    .slot6_ok    (               ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  (               ),
    .slot2_addr  (               ),
    .slot6_addr  (               ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  (               ),
    .slot2_dout  (               ),
    .slot6_dout  (               ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  ( obj_data      ),

    .ready       (               ),
    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    .refresh_en  ( refresh_en    )
);

endmodule
