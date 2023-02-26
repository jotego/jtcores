/*  This file is part of JTDD.
    JTDD program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTDD program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTDD.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-12-2019 */

module jtdd_game(
    input           rst,
    input           clk,
    input           rst24,
    input           clk24,
    output          pxl2_cen,
    output          pxl_cen,
    output          LVBL,
    output          LHBL,
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
    input           tilt,
    input           dip_pause,
    inout           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output (monoaural game)
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // video
    output  [ 3:0]  red,
    output  [ 3:0]  green,
    output  [ 3:0]  blue,
    // Debug
    input   [ 7:0]  debug_bus,
    output  [ 7:0]  debug_view,
    input   [ 3:0]  gfx_en
);

wire       [12:0]  cpu_AB;
wire               pal_cs;
wire               char_cs, scr_cs, obj_cs;
wire               cpu_wrn;
wire       [ 7:0]  cpu_dout;
wire               cen_E, cen_Q;
wire       [ 7:0]  char_dout, scr_dout, obj_dout, pal_dout;
// video signals
wire               VBL, HBL, IMS, H8;
wire               flip;
// ROM access
wire       [15:0]  char_addr;
wire       [14:0]  snd_addr;
wire       [15:0]  adpcm0_addr, adpcm1_addr;
wire       [ 7:0]  char_data, adpcm0_data, adpcm1_data;
wire       [16:0]  scr_addr;
wire       [18:0]  obj_addr;
wire       [15:0]  scr_data, obj_data;
wire               char_ok, scr_ok, obj_ok, main_ok, snd_ok;
wire               adpcm0_ok, adpcm1_ok;
wire       [17:0]  main_addr;
wire               main_cs, snd_cs, adpcm0_cs, adpcm1_cs;
wire       [ 7:0]  main_data, snd_data;
wire       [13:0]  mcu_addr;
wire       [ 7:0]  mcu_data;
wire               mcu_cs, mcu_ok;
// Sound
wire               mcu_rstb, snd_irq;
wire       [ 7:0]  snd_latch;
// DIP
wire       [ 7:0]  dipsw_a, dipsw_b;
// MCU
wire               mcu_irqmain, mcu_halt, com_cs, mcu_nmi_set, mcu_ban;
wire       [ 7:0]  mcu_ram;
// PROM programming
wire               prom_prio_we;

wire       [ 8:0]  scrhpos, scrvpos;

wire cen12, cen6, cen3, cen1p5;
wire cpu_cen;

// Pixel signals all from 48MHz clock
wire pxl_cenb;
wire turbo;

assign turbo              = status[13];
assign dwnld_busy         = downloading;
assign prog_rd            = 0;

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dip_flip           = flip;
assign debug_view         = 0;

jtframe_cen48 u_cen(
    .clk     (  clk      ),    // 48 MHz
    .cen12   (  pxl2_cen ),
    .cen16   (           ),
    .cen16b  (           ),
    .cen8    (           ),
    .cen6    (  pxl_cen  ),
    .cen4    (           ),
    .cen4_12 (           ),
    .cen3    (           ),
    .cen3b   (           ),
    .cen3q   (           ),
    .cen3qb  (           ),
    .cen1p5  (           ),
    .cen12b  (           ),
    .cen6b   (  pxl_cenb ),
    .cen1p5b (           )
);

wire alt12, alt6;

// CPU and sub CPU from slower clock in order to
// prevent timing error in 6809 CC bit Z
jtframe_cen24 u_cen24(
    .clk     (  clk24    ),    // 48 MHz
    .cen12   (  cen12    ),
    .cen8    (           ),
    .cen6    (  cen6     ),
    .cen4    (           ),
    .cen3    (  cen3     ),
    .cen3b   (           ),
    .cen3q   (           ),
    .cen3qb  (           ),
    .cen1p5  (  cen1p5   ),
    .cen12b  (           ),
    .cen6b   (           ),
    .cen1p5b (           )
);

jtdd_prom_we u_prom(
    .clk          ( clk             ),
    .downloading  ( downloading     ),
    .ioctl_addr   ( ioctl_addr      ),
    .ioctl_dout   ( ioctl_dout      ),
    .ioctl_wr     ( ioctl_wr        ),
    .prog_addr    ( prog_addr       ),
    .prog_data    ( prog_data       ),
    .prog_mask    ( prog_mask       ),
    .prog_we      ( prog_we         ),
    .prom_we      ( prom_prio_we    ),
    .sdram_ack    ( sdram_ack       )
);

`ifndef NOMAIN
wire main_cen = turbo ? 1'd1 : cen12;

jtdd_main u_main(
    .clk            ( clk24         ),
    .rst            ( rst24         ),
    .cen12          ( main_cen      ),
    .cpu_cen        ( cpu_cen       ),
    .VBL            ( VBL           ),
    .IMS            ( IMS           ), // =VPOS[3]
    // MCU
    .mcu_irqmain    ( mcu_irqmain   ),
    .mcu_halt       ( mcu_halt      ),
    .mcu_ban        ( mcu_ban       ),
    .com_cs         ( com_cs        ),
    .mcu_nmi_set    ( mcu_nmi_set   ),
    .mcu_ram        ( mcu_ram       ),
    // Palette
    .pal_cs         ( pal_cs        ),
    .pal_dout       ( pal_dout      ),
    .flip           ( flip          ),
    // Sound
    .mcu_rstb       ( mcu_rstb      ),
    .snd_irq        ( snd_irq       ),
    .snd_latch      ( snd_latch     ),
    // Characters
    .char_dout      ( char_dout     ),
    .cpu_dout       ( cpu_dout      ),
    .char_cs        ( char_cs       ),
    // Objects
    .obj_dout       ( obj_dout      ),
    .obj_cs         ( obj_cs        ),
    // scroll
    .scr_dout       ( scr_dout      ),
    .scr_cs         ( scr_cs        ),
    .scrhpos        ( scrhpos       ),
    .scrvpos        ( scrvpos       ),
    // cabinet I/O
    .start_button   ( start_button  ),
    .coin_input     ( coin_input    ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    // BUS sharing
    .cpu_AB         ( cpu_AB        ),
    .RnW            ( cpu_wrn       ),
    // ROM access
    .rom_cs         ( main_cs       ),
    .rom_addr       ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .service        ( service       ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       )
);
`else
assign main_cs   = 1'b0;
assign main_addr = 18'd0;
assign char_cs   = 1'b0;
assign scr_cs    = 1'b0;
assign obj_cs    = 1'b0;
assign pal_cs    = 1'b0;
assign mcu_cs    = 1'b0;
assign flip      = 1'b0;
assign cpu_AB    = 13'd0;
assign cpu_wrn   = 1'b1;
assign scrhpos   = 9'h0;
assign scrvpos   = 9'h0;
assign snd_latch = 8'd0;
assign snd_irq   = 1'b0;
assign mcu_rstb  = 1'b0;
`endif

`ifndef NOMCU
wire mcu_cen = turbo ? cen3 : cen1p5;

jtdd_mcu u_mcu(
    .clk          (  clk24           ),
    .mcu_rstb     (  mcu_rstb        ),
    .mcu_cen      (  mcu_cen         ),
    // CPU bus
    .cpu_AB       (  cpu_AB[8:0]     ),
    .cpu_wrn      (  cpu_wrn         ),
    .cpu_dout     (  cpu_dout        ),
    .shared_dout  (  mcu_ram         ),
    // CPU Interface
    .com_cs       (  com_cs          ),
    .mcu_nmi_set  (  mcu_nmi_set     ),
    .mcu_halt     (  mcu_halt        ),
    .mcu_irqmain  (  mcu_irqmain     ),
    .mcu_ban      (  mcu_ban         ),
    // PROM programming
    .rom_addr     (  mcu_addr        ),
    .rom_data     (  mcu_data        ),
    .rom_cs       (  mcu_cs          ),
    .rom_ok       (  mcu_ok          )
);
`else
reg    irqmain;
assign mcu_irqmain = irqmain;
assign mcu_ban = 1'b0;
always @(posedge clk) irqmain <= mcu_nmi_set;
wire shared_we = com_cs && !cpu_wrn;
jtframe_ram #(.AW(9)) u_shared(
    .clk    ( clk         ),
    .cen    ( cpu_cen     ),
    .data   ( cpu_dout    ),
    .addr   ( cpu_AB[8:0] ),
    .we     ( shared_we   ),
    .q      ( mcu_ram     )
);
`endif

jtdd_sound u_sound(
    .clk         ( clk24         ),
    .rst         ( rst24         ),
    .cen6        ( cen6          ),
    .H8          ( H8            ),
    // communication with main CPU
    .snd_irq     ( snd_irq       ),
    .snd_latch   ( snd_latch     ),
    // ROM
    .rom_addr    ( snd_addr      ),
    .rom_cs      ( snd_cs        ),
    .rom_data    ( snd_data      ),
    .rom_ok      ( snd_ok        ),

    .adpcm0_addr ( adpcm0_addr   ),
    .adpcm0_cs   ( adpcm0_cs     ),
    .adpcm0_data ( adpcm0_data   ),
    .adpcm0_ok   ( adpcm0_ok     ),

    .adpcm1_addr ( adpcm1_addr   ),
    .adpcm1_cs   ( adpcm1_cs     ),
    .adpcm1_data ( adpcm1_data   ),
    .adpcm1_ok   ( adpcm1_ok     ),
    // Sound output
    .sound       ( snd           ),
    .sample      ( sample        ),
    .peak        ( game_led      )
);

jtdd_video u_video(
    .clk          (  clk             ),
    .rst          (  rst             ),
    .pxl_cen      (  pxl_cen         ),
    .pxl_cenb     (  pxl_cenb        ),
    .cen_Q        (  cpu_cen         ),
    .cpu_AB       (  cpu_AB          ),
    .pal_cs       (  pal_cs          ),
    .char_cs      (  char_cs         ),
    .scr_cs       (  scr_cs          ),
    .obj_cs       (  obj_cs          ),
    .cpu_wrn      (  cpu_wrn         ),
    .cpu_dout     (  cpu_dout        ),
    .char_dout    (  char_dout       ),
    .scr_dout     (  scr_dout        ),
    .obj_dout     (  obj_dout        ),
    .pal_dout     (  pal_dout        ),
    // Scroll position
    .scrhpos      ( scrhpos          ),
    .scrvpos      ( scrvpos          ),
    // video signals
    .VBL          (  VBL             ),
    .LVBL_dly     (  LVBL            ),
    .VS           (  VS              ),
    .HBL          (  HBL             ),
    .LHBL_dly     (  LHBL            ),
    .HS           (  HS              ),
    .IMS          (  IMS             ),
    .flip         (  flip            ),
    .H8           (  H8              ),
    // ROM access
    .char_addr    (  char_addr       ),
    .char_data    (  char_data       ),
    .char_ok      (  char_ok         ),
    .scr_addr     (  scr_addr        ),
    .scr_data     (  scr_data        ),
    .scr_ok       (  scr_ok          ),
    .obj_addr     (  obj_addr        ),
    .obj_data     (  obj_data        ),
    .obj_ok       (  obj_ok          ),
    // PROM programming
    .prog_addr    (  prog_addr[7:0]  ),
    .prom_prio_we (  prom_prio_we    ),
    .prom_din     (  prog_data[3:0]  ),
    // Pixel output
    .red          (  red             ),
    .green        (  green           ),
    .blue         (  blue            ),
    // Debug
    .gfx_en       (  gfx_en          )
);

// Same as locations inside JTDD.rom file
localparam BANK_ADDR   = 22'h0_0000;
localparam MAIN_ADDR   = 22'h2_0000;
localparam SND_ADDR    = 22'h2_8000;
localparam ADPCM_0     = 22'h3_0000;
localparam ADPCM_1     = 22'h4_0000;
localparam CHAR_ADDR   = 22'h5_0000;

// reallocated:
localparam SCR_ADDR  = 22'h6_0000;
localparam OBJ_ADDR  = 22'h8_0000;
localparam MCU_ADDR  = 22'hC_0000;


jtframe_rom #(
    .SLOT0_AW    ( 15              ),   // Char
    .SLOT0_DW    ( 8               ),
    .SLOT0_OFFSET( CHAR_ADDR>>1    ),

    .SLOT1_AW    ( 17              ),   // Scroll
    .SLOT1_DW    ( 16              ),
    .SLOT1_OFFSET( SCR_ADDR        ),

    .SLOT2_AW    ( 16              ),   // ADPCM 0
    .SLOT2_DW    (  8              ),
    .SLOT2_OFFSET( ADPCM_0>>1      ),

    .SLOT3_AW    ( 16              ),   // ADPCM 1
    .SLOT3_DW    (  8              ),
    .SLOT3_OFFSET( ADPCM_1>>1      ),

    .SLOT5_AW    ( 14              ),   // MCU
    .SLOT5_DW    (  8              ),
    .SLOT5_OFFSET( MCU_ADDR        ),

    .SLOT7_AW    ( 18              ),
    .SLOT7_DW    (  8              ),
    .SLOT7_OFFSET(  0              ),   // Main

    .SLOT8_AW    ( 18              ),   // Objects
    .SLOT8_DW    ( 16              ),
    .SLOT8_OFFSET( OBJ_ADDR        ),

    .SLOT6_AW    ( 15              ),   // Sound
    .SLOT6_DW    (  8              ),
    .SLOT6_OFFSET( SND_ADDR>>1     )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),

    .slot0_cs    ( ~VBL          ),
    .slot1_cs    ( ~VBL          ),
    .slot2_cs    ( adpcm0_cs     ), // ADPCM 0
    .slot3_cs    ( adpcm1_cs     ), // ADPCM 1
    .slot4_cs    ( 1'b0          ), // unused
    .slot5_cs    ( mcu_cs        ),
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ), // objects

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( scr_ok        ),
    .slot2_ok    ( adpcm0_ok     ),
    .slot3_ok    ( adpcm1_ok     ),
    .slot5_ok    ( mcu_ok        ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr[14:0] ),
    .slot1_addr  ( scr_addr      ),
    .slot2_addr  ( adpcm0_addr   ),
    .slot3_addr  ( adpcm1_addr   ),
    .slot5_addr  ( mcu_addr      ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr[17:0]),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( scr_data      ),
    .slot2_dout  ( adpcm0_data   ),
    .slot3_dout  ( adpcm1_data   ),
    .slot5_dout  ( mcu_data      ),
    .slot6_dout  ( snd_data      ),
    .slot7_dout  ( main_data     ),
    .slot8_dout  ( obj_data      ),

    // SDRAM interface
    .sdram_rd    ( sdram_req     ),
    .sdram_ack   ( sdram_ack     ),
    .data_dst    ( data_dst      ),
    .data_rdy    ( data_rdy      ),
    .downloading ( downloading   ),
    .sdram_addr  ( sdram_addr    ),
    .data_read   ( data_read     ),
    // Unused
    .slot4_addr  (               ),
    .slot4_dout  (               ),
    .slot4_ok    (               )
);

endmodule