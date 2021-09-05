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
    Date: 12-10-2019 */


module jttora_game(
    input           rst,
    input           clk,
    input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [3:0]  red,
    output   [3:0]  green,
    output   [3:0]  blue,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 6:0]  joystick1,
    input   [ 6:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    input   [15:0]  data_read,
    input           data_dst,
    input           data_rdy,
    input           sdram_ack,
    // ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,
    input   [31:0]  dipsw,
    input           service,
    input           dip_pause,
    input           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [3:0]   gfx_en
);

parameter CLK_SPEED=48;

wire [ 8:0] V;
wire [ 8:0] H;
wire        HINIT;
wire        LHBL, LVBL;

wire [13:1] cpu_AB;
wire        snd_cs, snd2_cs;
wire        char_cs, map_cs, col_uw, col_lw;
wire        flip;
wire [15:0] char_dout, cpu_dout;
wire        rd, cpu_cen;
wire        char_busy;

// ROM data
wire [15:0] char_data, scr_data, obj_data, obj_pre;
wire [15:0] main_data, map_data;
wire [ 7:0] snd_data, snd2_data;
// MCU interface
wire [ 7:0] snd_din, snd_dout;
wire        snd_mcu_wr;
wire        mcu_brn;
wire [ 7:0] mcu_din, mcu_dout;
wire [16:1] mcu_addr;
wire        mcu_wr, mcu_DMAn, mcu_DMAONn;

// ROM address
wire [17:1] main_addr;
wire [14:0] snd_addr;
wire [15:0] snd2_addr;
wire [13:0] map_addr;
wire [13:0] char_addr;
wire [18:0] scr_addr;
wire [14:0] scr2_addr;
wire [17:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;

wire        main_ok, map_ok, scr_ok, snd_ok, snd2_ok, obj_ok, obj_ok0, char_ok;
wire        video_cen8;

// A and B are inverted in this game (or in MAME definition)
assign {dipsw_a, dipsw_b} = dipsw[15:0];

/////////////////////////////////////
// 48 MHz based clock enable signals
jtframe_cen48 u_cen48(
    .clk    ( clk           ),
    .cen16  (               ),
    .cen12  ( pxl2_cen      ),
    .cen12b (               ),
    .cen8   ( video_cen8    ),
    .cen6   ( pxl_cen       ),
    .cen6b  (               ),
    .cen4   (               ),
    .cen4_12(               ),
    .cen3   (               ),
    .cen3q  (               ),
    .cen3qb (               ),
    .cen3b  (               ),
    .cen1p5 (               ),
    .cen1p5b(               )
);

/////////////////////////////////////
// 24 MHz based clock enable signals
wire        cen3, mcu_cen, clk_mcu;
wire        cen10, cenfm, cenp384;
wire        nc,ncb;
wire        cen10b;

jtframe_cen24 u_cen(
    .clk    ( clk24     ),
    .cen12  (           ),
    .cen12b (           ),
    .cen8   (           ),
    .cen4   (           ),
    .cen6   ( mcu_cen   ),
    .cen6b  (           ),
    .cen3   ( cen3      ),
    .cen3q  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5 (           ),
    .cen1p5b(           )
);

assign clk_mcu = clk24;

// jtframe_frac_cen u_cen10(
//     .clk    ( clk24          ),
//     .n      ( 10'd5          ),         // numerator
//     .m      ( 10'd12         ),         // denominator
//     .cen    ( {nc,  cen10  } ),
//     .cenb   ( /*{ncb, cen10b }*/ )  // 180 shifted
// );
//
// always @(posedge clk24) cen10b<=cen10;

jtframe_cen3p57 #(.CLK24(1)) u_cen3p57(
    .clk      ( clk24     ),
    .cen_3p57 ( cenfm     ),
    .cen_1p78 (           )     // unused
);

jtframe_cenp384 #(.CLK24(1)) u_cenp384(
    .clk      ( clk24     ),
    .cen_p384 ( cenp384   )
);

wire LHBL_obj, LVBL_obj;

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( pxl_cen  ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL      ( LVBL     ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

wire RnW;
// sound
wire [7:0] snd_latch;

wire        main_cs;
// OBJ
wire OKOUT, blcnten, obj_br, bus_ack;
wire [13:1] obj_AB;     // 1 more bit than older games
wire [15:0] oram_dout;

wire [1:0]  prom_we;
wire        jap;        // high if Japanese ROM was loaded

jttora_dwnld u_dwnld(
    .clk         ( clk             ),
    .downloading ( downloading     ),
    .jap         ( jap             ),

    .ioctl_wr    ( ioctl_wr        ),
    .ioctl_addr  ( ioctl_addr[21:0]),
    .ioctl_dout  ( ioctl_dout      ),

    .prog_data   ( prog_data       ),
    .prog_mask   ( prog_mask       ),
    .prog_addr   ( prog_addr       ),
    .prog_we     ( prog_we         ),
    .prog_rd     ( prog_rd         ),

    .prom_we     ( prom_we         ),
    .sdram_dout  ( data_read[15:0] ),
    .dwnld_busy  ( dwnld_busy      ),
    .sdram_ack   ( sdram_ack       ),
    .data_ok     ( data_rdy        )
);

wire [15:0] scrposh, scrposv;
wire UDSWn, LDSWn;

`ifndef NOMAIN
jtbiocom_main #(.GAME(1)) u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_mcu    ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_cenb   (               ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // sound
    .snd_latch  ( snd_latch     ),
    .snd_nmi_n  (               ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .UDSWn      ( UDSWn         ),
    .LDSWn      ( LDSWn         ),
    // SCROLL
    .scr1_cs    (               ),
    .scr1_busy  ( 1'b0          ),
    .scr1_dout  (               ),
    .scr1_hpos  ( scrposh       ),
    .scr1_vpos  ( scrposv       ),
    .scr_bank   ( scr_addr[18]  ),
    // SCROLL 2 - Unused
    .scr2_cs    (               ),
    .scr2_dout  (               ),
    .scr2_hpos  (               ),
    .scr2_vpos  (               ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .oram_dout  ( oram_dout     ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .obj_br     ( obj_br        ),
    .bus_ack    ( bus_ack       ),
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    // MCU interface
    .mcu_cen    (  mcu_cen      ),
    .mcu_brn    (  mcu_brn      ),
    .mcu_din    (  mcu_din      ),
    .mcu_dout   (  mcu_dout     ),
    .mcu_addr   (  mcu_addr     ),
    .mcu_wr     (  mcu_wr       ),
    .mcu_DMAn   (  mcu_DMAn     ),
    .mcu_DMAONn (  mcu_DMAONn   ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .start_button( start_button ),
    .service     ( service      ),
    .coin_input  ( coin_input   ),
    .joystick1   ( joystick1    ),
    .joystick2   ( joystick2    ),

    .RnW        ( RnW           ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else
    `ifndef SIM_SCR_VPOS
    `define SIM_SCR_HPOS 16'd0
    `define SIM_SCR_VPOS 16'd0
    `define SIM_SCR_BANK 1'b0
    `endif
    `ifndef SIM_SND_LATCH
    `define SIM_SND_LATCH 8'd0
    `endif
    assign main_addr   = 17'd0;
    assign cpu_AB      = 13'd0;
    assign cpu_dout    = 16'd0;
    assign char_cs     = 1'b0;
    assign bus_ack     = 1'b0;
    assign flip        = 1'b0;
    assign RnW         = 1'b1;
    assign scrposh     = `SIM_SCR_HPOS;
    assign scrposv     = `SIM_SCR_VPOS;
    assign scr_addr[18]= `SIM_SCR_BANK;
    assign cpu_cen     = cen10;
    assign OKOUT       = 1'b0;
    assign snd_latch   = `SIM_SND_LATCH;
`endif

`ifdef F1DREAM
`ifndef NOMCU
`define MCU
`endif
`endif

`ifdef MCU
jtbiocom_mcu #(.SINC_XDATA(1)) u_mcu(
    .rst        ( rst             ),
    .clk        ( clk_mcu         ),
    .clk_rom    ( clk             ),
    .clk_cpu    ( clk             ),
    .cen6a      ( mcu_cen         ),       //  6   MHz
    // Main CPU interface
    .DMAONn     ( mcu_DMAONn      ),
    .mcu_din    ( mcu_din         ),
    .mcu_dout   ( mcu_dout        ),
    .mcu_wr     ( mcu_wr          ),   // always write to low bytes
    .mcu_addr   ( mcu_addr        ),
    .mcu_brn    ( mcu_brn         ), // RQBSQn
    .DMAn       ( mcu_DMAn        ),

    // Sound CPU interface
    .snd_din    ( snd_din         ),
    .snd_dout   ( snd_dout        ),
    .snd_mcu_wr ( snd_mcu_wr      ),
    .snd_mcu_rd ( 1'b0            ),
    // ROM programming
    .prog_addr  ( prog_addr[11:0] ),
    .prom_din   ( prog_data       ),
    .prom_we    ( prom_we[1]      )
);
`else
assign mcu_DMAn = 1'b1;
assign mcu_brn  = 1'b1;
assign mcu_wr   = 1'b0;
assign mcu_addr = 16'd0;
assign mcu_dout =  8'd0;
`endif


`ifndef NOSOUND
jttora_sound u_sound (
    .rst            ( rst            ),
    .clk            ( clk24          ),
    .cen3           ( cen3           ),
    .cenfm          ( cenfm          ),
    .cenp384        ( cenp384        ),
    .jap            ( jap            ),
    // Interface with main CPU
    .snd_latch      ( snd_latch      ),
    // Interface with MCU
    .snd_din        ( snd_din        ),
    .snd_dout       ( snd_dout       ),
    .snd_mcu_wr     ( snd_mcu_wr     ),
    // sound control
    .enable_psg     ( enable_psg     ),
    .enable_fm      ( enable_fm      ),
    .psg_level      ( dip_fxlevel    ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // ROM 2
    .rom2_addr      ( snd2_addr      ),
    .rom2_data      ( snd2_data      ),
    .rom2_cs        ( snd2_cs        ),
    .rom2_ok        ( snd2_ok        ),
    // sound output
    .ym_snd         ( snd            ),
    .sample         ( sample         ),
    .peak           ( game_led       )
);
`else
assign snd_addr  = 15'd0;
assign snd2_addr = 15'd0;
assign snd_cs    = 1'b0;
assign snd2_cs   = 1'b0;
assign snd       = 16'b0;
`endif

`ifndef NOPAUSE
reg pause;
always @(posedge clk) pause <= ~dip_pause;
`else
wire pause=1'b0;
`endif

`ifndef NOVIDEO
jttora_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( pxl2_cen      ),
    .cen8       ( video_cen8    ),
    .cen6       ( pxl_cen       ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB        ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .UDSWn      ( UDSWn         ),
    .LDSWn      ( LDSWn         ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    .pause      ( pause         ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL
    .map_data   ( map_data      ),
    .map_addr   ( map_addr      ),
    .map_cs     ( map_cs        ),
    .map_ok     ( map_ok        ),
    .scr_addr   ( scr_addr[17:0]),
    .scr_data   ( scr_data      ),
    .scrposh    ( scrposh       ),
    .scrposv    ( scrposv       ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .oram_dout  ( oram_dout[11:0] ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( obj_br        ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    .obj_ok     ( obj_ok        ),
    // PROMs
    .prog_addr    ( prog_addr[7:0]),
    .prom_prio_we ( prom_we[0]    ),
    .prom_din     ( prog_data[3:0]),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .LHBL_dly   ( LHBL_dly      ),
    .LVBL_dly   ( LVBL_dly      ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);
`else
// Video module may be ommitted for SDRAM load simulation
assign red       = 4'h0;
assign green     = 4'h0;
assign blue      = 4'h0;
assign obj_addr  = 0;
assign scr_addr  = 0;
assign char_addr = 0;
assign blcnten   = 1'b0;
assign obj_br    = 1'b0;
assign char_busy = 1'b0;
`endif

// map2 ports are used for the ADPCM CPU (snd2)
jtframe_rom #(
    .SLOT0_AW    ( 14              ), // Char
    .SLOT0_DW    ( 16              ),
    .SLOT0_OFFSET( 22'h5_8000 >> 1 ),

    .SLOT1_AW    ( 14              ),
    .SLOT1_DW    ( 16              ),
    .SLOT1_OFFSET( 22'h6_0000 >> 1 ), // Map

    .SLOT2_AW    ( 19              ), // Scroll
    .SLOT2_DW    ( 16              ),
    .SLOT2_OFFSET( 22'h10_0000     ), // SCR and OBJ are not shifted

    .SLOT3_AW    ( 17              ), // main
    .SLOT3_DW    ( 16              ),
    .SLOT3_OFFSET(  0              ),

    .SLOT5_AW    ( 15              ), // Sound 1
    .SLOT5_DW    (  8              ),
    .SLOT5_OFFSET( 22'h4_0000 >> 1 ),

    .SLOT6_AW    ( 16              ), // Sound 2
    .SLOT6_DW    (  8              ),
    .SLOT6_OFFSET( 22'h4_8000 >> 1 ),

    .SLOT8_AW    ( 18              ), // Objects
    .SLOT8_DW    ( 16              ),
    .SLOT8_OFFSET( 22'h20_0000     )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    //.pause       ( pause         ),
    .slot0_cs    ( LVBL          ),
    .slot1_cs    ( map_cs        ),
    .slot2_cs    ( LVBL          ),
    .slot3_cs    ( main_cs       ),
    .slot5_cs    ( snd_cs        ),
    .slot6_cs    ( snd2_cs       ),
    .slot8_cs    ( 1'b1          ),

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( map_ok        ),
    .slot2_ok    ( scr_ok        ),
    .slot3_ok    ( main_ok       ),
    .slot5_ok    ( snd_ok        ),
    .slot6_ok    ( snd2_ok       ),
    .slot8_ok    ( obj_ok0       ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( map_addr      ),
    .slot2_addr  ( scr_addr      ),
    .slot3_addr  ( main_addr     ),
    .slot5_addr  ( snd_addr      ),
    .slot6_addr  ( snd2_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( map_data      ),
    .slot2_dout  ( scr_data      ),
    .slot3_dout  ( main_data     ),
    .slot5_dout  ( snd_data      ),
    .slot6_dout  ( snd2_data     ),
    .slot8_dout  ( obj_pre       ),

    // SDRAM interface
    .sdram_req   ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .downloading ( dwnld_busy    ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    // Unused
    .slot4_addr  (               ),
    .slot7_addr  (               ),
    .slot4_dout  (               ),
    .slot7_dout  (               ),
    .slot4_ok    (               ),
    .slot7_ok    (               ),
    .slot4_cs    ( 1'd0          ),
    .slot7_cs    ( 1'd0          )
);

jtframe_avatar u_avatar(
    .rst         ( rst           ),
    .clk         ( clk           ),
    .pause       ( pause         ),
    .obj_addr    ( obj_addr[12:0]),
    .obj_data    ( obj_pre       ),
    .obj_mux     ( obj_data      ),
    .ok_in       ( obj_ok0       ),
    .ok_out      ( obj_ok        )
);

endmodule
