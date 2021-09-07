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
    Date: 14-9-2019 */


module jtbiocom_game(
    input           rst,
    input           clk,
    input           rst24,
    input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [4:0]  red,
    output   [4:0]  green,
    output   [4:0]  blue,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 5:0]  joystick1,
    input   [ 5:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          dwnld_busy,

    // Bank 0: allows R/W
    output   [21:0] ba0_addr,
    output   [21:0] ba1_addr,
    output   [21:0] ba2_addr,
    output   [21:0] ba3_addr,
    output   [15:0] ba0_din,
    output   [ 1:0] ba0_din_m,  // write mask
    output   [ 3:0] ba_rd,
    output          ba_wr,
    input    [ 3:0] ba_ack,
    input    [ 3:0] ba_dst,
    input    [ 3:0] ba_dok,
    input    [ 3:0] ba_rdy,

    input   [15:0]  data_read,
    // ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [15:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output  [ 1:0]  prog_ba,
    output          prog_we,
    output          prog_rd,
    input           prog_ack,
    input           prog_dst,
    input           prog_dok,
    input           prog_rdy,

    // DIP switches
    input   [31:0]  status,
    input   [31:0]  dipsw,
    input           service,     // unused in this game
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd_left,
    output  signed [15:0] snd_right,
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

wire [13:1] cpu_AB;
wire        snd_cs;
wire        char_cs, col_uw, col_lw;
wire        flip;
wire [ 7:0] char_dout, scr1_dout, scr2_dout;
wire [15:0] cpu_dout;
wire        rd, cpu_cen;
wire        char_busy, scr1_busy, scr2_busy;
wire        clk_mcu;

// ROM data
wire [15:0] char_data, scr1_data, scr2_data;
wire [15:0] obj_data;
wire [15:0] main_data;
wire [ 7:0] snd_data;
// MCU interface
wire [ 7:0] snd_din, snd_dout;
wire        snd_mcu_wr, snd_mcu_rd;
wire        mcu_brn;
wire [ 7:0] mcu_din, mcu_dout;
wire [16:1] mcu_addr;
wire        mcu_wr, mcu_DMAn, mcu_DMAONn;

// ROM address
wire [17:1] main_addr;
wire [14:0] snd_addr;
wire [12:0] char_addr;
wire [16:0] scr1_addr;
wire [14:0] scr2_addr;
wire [16:0] obj_addr;
wire [ 7:0] dipsw_a, dipsw_b;
wire        LHBL, LVBL;

wire        main_ok, snd_ok, obj_ok, obj_ok0;
wire        scr1_ok, scr2_ok, char_ok;
wire        video_cen8;

wire cen8;

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign game_led = 0;
assign ba_wr = 0;

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
    .cen3b  (               ),
    .cen3q  (               ),
    .cen3qb (               ),
    .cen1p5 (               ),
    .cen1p5b(               )
);

/////////////////////////////////////
// 24 MHz based clock enable signals
wire        cen3, mcu_cen;
wire        cen10, cenfm, cenp384;
wire        nc,ncb;
reg         cen10b;

jtframe_cen24 u_cen24(
    .clk    ( clk24     ),
    .cen12  (           ),
    .cen12b (           ),
    .cen6   (           ),
    .cen3   ( cen3      ),
    // Unused:
    .cen6b  (           ),
    .cen1p5 ( mcu_cen   ),
    .cen1p5b(           ),
    .cen8   (           ),
    .cen4   (           ),
    .cen3q  (           ),
    .cen3b  (           ),
    .cen3qb (           )
);

assign clk_mcu = clk24;

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
// wire [7:0] snd_hack;

wire        main_cs, snd_nmi_n;
// OBJ
wire OKOUT, blcnten, obj_br, bus_ack;
wire [13:1] obj_AB;     // 1 more bit than older games
wire [15:0] oram_dout;

wire [ 1:0] prom_we;
wire        prom_mcu_we  = prom_we[0];
wire        prom_prio_we = prom_we[1];

jtbiocom_dwnld u_dwnld(
    .clk         ( clk             ),
    .downloading ( downloading     ),

    .ioctl_wr    ( ioctl_wr        ),
    .ioctl_addr  ( ioctl_addr[21:0]),
    .ioctl_dout  ( ioctl_dout      ),

    .prog_data   ( prog_data       ),
    .prog_mask   ( prog_mask       ),
    .prog_addr   ( prog_addr       ),
    .prog_we     ( prog_we         ),
    .prog_rd     ( prog_rd         ),
    .prog_ba     ( prog_ba         ),

    .prom_we     ( prom_we         ),
    .sdram_dout  ( data_read[15:0] ),
    .dwnld_busy  ( dwnld_busy      ),
    .sdram_ack   ( prog_ack        ),
    .data_ok     ( prog_rdy        )
);

wire scr1_cs, scr2_cs;
wire [9:0] scr1_hpos, scr1_vpos;
wire [8:0] scr2_hpos, scr2_vpos;

`ifndef NOMAIN
jtbiocom_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_cenb   (               ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // sound
    .snd_latch  ( snd_latch     ),
    .snd_nmi_n  ( snd_nmi_n     ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // SCROLL 1
    .scr1_dout  ( scr1_dout     ),
    .scr1_cs    ( scr1_cs       ),
    .scr1_busy  ( scr1_busy     ),
    .scr1_hpos  ( scr1_hpos     ),
    .scr1_vpos  ( scr1_vpos     ),
    .scr_bank   (               ),  // only Tiger Road
    // SCROLL 2
    .scr2_dout  ( scr2_dout     ),
    .scr2_cs    ( scr2_cs       ),
    .scr2_busy  ( scr2_busy     ),
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_vpos  ( scr2_vpos     ),
    // OBJ - bus sharing
    .UDSWn      (               ),
    .LDSWn      (               ),
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
    .coin_input  ( coin_input   ),
    .joystick1   ( joystick1[5:0] ),
    .joystick2   ( joystick2[5:0] ),

    .RnW        ( RnW           ),
    // DIP switches
    .service    ( service       ),
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);
`else
    `ifndef SIM_SCR1_HPOS
    `define SIM_SCR1_HPOS 10'd0
    `endif
    `ifndef SIM_SCR1_VPOS
    `define SIM_SCR1_VPOS 10'd0
    `endif
    `ifndef SIM_SCR2_HPOS
    `define SIM_SCR2_HPOS 9'd0
    `endif
    `ifndef SIM_SCR2_VPOS
    `define SIM_SCR2_VPOS 9'd0
    `endif

    assign main_addr   = 17'd0;
    assign cpu_AB      = 13'd0;
    assign cpu_dout    = 16'd0;
    assign char_cs     = 1'b0;
    assign scr1_cs     = 1'b0;
    assign scr2_cs     = 1'b0;
    assign bus_ack     = 1'b0;
    assign flip        = 1'b0;
    assign RnW         = 1'b1;
    assign scr1_hpos   = `SIM_SCR1_HPOS;
    assign scr1_vpos   = `SIM_SCR1_VPOS;
    assign scr2_hpos   = `SIM_SCR2_HPOS;
    assign scr2_vpos   = `SIM_SCR2_VPOS;
    assign cpu_cen     = pxl2_cen;
    assign OKOUT       = 1'b0;
`endif

`ifndef NOMCU
jtbiocom_mcu u_mcu(
    .rst        ( rst24         ),
    .clk        ( clk_mcu       ),
    .rst_cpu    ( rst           ),
    .clk_rom    ( clk           ),
    .clk_cpu    ( clk           ),
    .cen6a      ( mcu_cen       ),       //  6   MHz
    // Main CPU interface
    .DMAONn     ( mcu_DMAONn    ),
    .mcu_din    ( mcu_din       ),
    .mcu_dout   ( mcu_dout      ),
    .mcu_wr     ( mcu_wr        ),   // always write to low bytes
    .mcu_addr   ( mcu_addr      ),
    .mcu_brn    ( mcu_brn       ), // RQBSQn
    .DMAn       ( mcu_DMAn      ),

    // Sound CPU interface
    .snd_din    ( snd_din       ),
    .snd_dout   ( snd_dout      ),
    .snd_mcu_wr ( snd_mcu_wr    ),
    .snd_mcu_rd ( snd_mcu_rd    ),
    // ROM programming
    .prog_addr  ( prog_addr[11:0] ),
    .prom_din   ( prog_data[7:0]  ),
    .prom_we    ( prom_mcu_we     )
);
`else
assign mcu_DMAn = 1'b1;
assign mcu_brn  = 1'b1;
assign mcu_wr   = 1'b1;
assign mcu_addr = 16'd0;
assign mcu_din  =  8'd0;
`endif

`ifndef NOSOUND

wire cen_fm, cen_fm2;

jtframe_cen3p57 #(.CLK24(1)) u_cen3p57(
    .clk        ( clk24     ),       // 48 MHz
    .cen_3p57   ( cen_fm    ),
    .cen_1p78   ( cen_fm2   )
);

jtbiocom_sound u_sound (
    .rst            ( rst            ),
    .clk            ( clk24          ),
    .cen_alt        ( cen3           ), // CPU CEN, it should be cen_fm really
    //.cen_alt        ( cen_fm         ), // CPU CEN, it should be cen_fm really
    // cen6    X
    // cen_fm2 X
    // cen_fm  O
    .cen_fm         ( cen_fm         ),
    .cen_fm2        ( cen_fm2        ),
    // Interface with main CPU
    .snd_latch      ( snd_latch      ),
    .nmi_n          ( snd_nmi_n      ),
    // Interface with MCU
    .snd_din        ( snd_din        ),
    .snd_dout       ( snd_dout       ),
    .snd_mcu_wr     ( snd_mcu_wr     ),
    .snd_mcu_rd     ( snd_mcu_rd     ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // sound output
    .left           ( snd_left       ),
    .right          ( snd_right      ),
    .sample         (     sample     )
);
`else
assign snd_addr   = 15'd0;
assign snd_cs     = 1'b0;
assign snd_left   = 16'b0;
assign snd_right  = 16'b0;
assign snd_mcu_wr = 1'b0;
assign snd_mcu_rd = 1'b0;
assign snd_dout   = 8'd0;
`endif

reg pause;
always @(posedge clk) pause <= ~dip_pause;

`ifndef NOVIDEO
jtbiocom_video #(
    .OBJ_PAL      (2'b10),
    .PALETTE_PROM (1),
    .SCRWIN       (0),
    .AVATAR_MAX   (9)
) u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( pxl2_cen      ),
    .cen8       ( video_cen8    ),
    .cen6       ( pxl_cen       ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB        ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
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
    // SCROLL 1
    .scr1_cs    ( scr1_cs       ),
    .scr1_dout  ( scr1_dout     ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .scr1_busy  ( scr1_busy     ),
    .scr1_hpos  ( scr1_hpos     ),
    .scr1_vpos  ( scr1_vpos     ),
    .scr1_ok    ( scr1_ok       ),
    // SCROLL 2
    .scr2_cs    ( scr2_cs       ),
    .scr2_dout  ( scr2_dout     ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .scr2_busy  ( scr2_busy     ),
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_vpos  ( scr2_vpos     ),
    .scr2_ok    ( scr2_ok       ),
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
    .prom_prio_we ( prom_prio_we  ),
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
assign red       = 5'h0;
assign green     = 5'h0;
assign blue      = 5'h0;
assign obj_addr  = 0;
assign scr1_addr = 0;
assign scr2_addr = 0;
assign char_addr = 0;
`endif

// Scroll data: Z, Y, X
jtbiocom_sdram u_sdram(
    .rst         ( rst           ),
    .clk         ( clk           ),

    .LVBL        ( LVBL          ),
    .pause       ( pause         ),

    .main_cs     ( main_cs       ),
    .snd_cs      ( snd_cs        ),

    .main_ok     ( main_ok       ),
    .snd_ok      ( snd_ok        ),
    .char_ok     ( char_ok       ),
    .scr1_ok     ( scr1_ok       ),
    .scr2_ok     ( scr2_ok       ),
    .obj_ok      ( obj_ok        ),

    .main_addr   ( main_addr     ),
    .snd_addr    ( snd_addr      ),
    .char_addr   ( char_addr     ),
    .scr1_addr   ( scr1_addr     ),
    .scr2_addr   ( scr2_addr     ),
    .obj_addr    ( obj_addr      ),

    .main_data   ( main_data     ),
    .snd_data    ( snd_data      ),
    .char_data   ( char_data     ),
    .scr1_data   ( scr1_data     ),
    .scr2_data   ( scr2_data     ),
    .obj_data    ( obj_data      ),

    // SDRAM interface
    // Bank 0: allows R/W
    .ba0_addr    ( ba0_addr      ),
    .ba1_addr    ( ba1_addr      ),
    .ba2_addr    ( ba2_addr      ),
    .ba3_addr    ( ba3_addr      ),
    .ba_rd       ( ba_rd         ),
    .ba0_wr      ( ba0_wr        ),
    .ba_ack      ( ba_ack        ),
    .ba_dst      ( ba_dst        ),
    .ba_rdy      ( ba_rdy        ),
    .ba0_din     ( ba0_din       ),
    .ba0_din_m   ( ba0_din_m     ),

    .data_read   ( data_read     )
);

endmodule
