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

module jtdd2_game(
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
    input           tilt,
    input           service,
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
wire       [ 7:0]  char_dout, scr_dout, obj_dout, pal_dout;
// video signals
wire               VBL, HBL, IMS, H8;
wire               flip;
// ROM access
wire       [15:0]  char_addr;
wire       [14:0]  snd_addr;
wire       [17:0]  adpcm_addr;
wire       [ 7:0]  char_data, adpcm_data;
wire       [16:0]  scr_addr;
wire       [18:0]  obj_addr;
wire       [15:0]  scr_data, obj_data;
wire               char_ok, scr_ok, obj_ok, main_ok, snd_ok;
wire               adpcm_ok;
wire       [17:0]  main_addr;
wire               main_cs, snd_cs, adpcm_cs;
wire       [ 7:0]  main_data, snd_data;
wire       [15:0]  mcu_addr;
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

wire cen12, cen8, cen6, cen4, cen3, cen3q, cen1p5, cen12b, cen6b, cen3b, cen3qb;
wire cpu_cen;
wire turbo;
// Pixel signals all from 48MHz clock
wire pxl_cenb, main8, main4, alt8, alt4, alt12;

localparam BANK_ADDR   = 22'h00000;
localparam MAIN_ADDR   = 22'h20000;
localparam SND_ADDR    = 22'h28000;
localparam SUB_ADDR    = 22'h30000;
localparam ADPCM_0     = 22'h40000;
localparam ADPCM_1     = 22'h60000;
localparam CHAR_ADDR   = 22'h80000;
// Scroll
localparam SCRZW_ADDR  = 22'h90000;
localparam SCRXY_ADDR  = 22'hB0000;
// objects
localparam OBJWZ_ADDR  = 22'hD0000;
localparam OBJXY_ADDR  = 22'h130000;
// FPGA BRAM:
localparam PROM_ADDR   = 22'h190000;
// ROM length 190200
// reallocated:
localparam [21:0] SCR_SDRAM  = 22'h6_0000;
localparam [21:0] OBJ_SDRAM  = 22'h8_0000;

assign turbo              = status[13];
assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dip_flip = flip;
assign dwnld_busy = downloading;
assign prog_rd    = 0;
assign debug_view = 0;

jtframe_cen48 u_cen(
    .clk     (  clk      ),    // 48 MHz
    .cen12   (  pxl2_cen ),
    .cen16   (           ),
    .cen16b  (           ),
    .cen8    (  main8    ),
    .cen6    (  pxl_cen  ),
    .cen4    (           ),
    .cen4_12 (  main4    ),
    .cen3    (  cen3     ),
    .cen3b   (  cen3b    ),
    .cen3q   (  cen3q    ), // 1/4 advanced with respect to cen3
    .cen3qb  (  cen3qb   ), // 1/4 advanced with respect to cen3b
    .cen1p5  (  cen1p5   ),
    .cen12b  (  cen12b   ),
    .cen6b   (  pxl_cenb ),
    .cen1p5b (           )
);

// CPU and sub CPU from slower clock in order to
// prevent timing error in 6809 CC bit Z
jtframe_cen24 u_cen24(
    .clk     (  clk24    ),    // 48 MHz
    .cen12   (  alt12    ),
    .cen8    (  alt8     ),
    .cen6    (           ),
    .cen4    (  alt4     ),
    .cen3    (           ),
    .cen3b   (           ),
    .cen3q   (           ), // 1/4 advanced with respect to cen3
    .cen3qb  (           ), // 1/4 advanced with respect to cen3b
    .cen1p5  (           ),
    .cen12b  (           ),
    .cen6b   (           ),
    .cen1p5b (           )
);

`ifdef DD48
assign cen12 = pxl2_cen;
assign cen4  = main4;
assign cen8  = main8;
`else
assign cen12 = alt12;
assign cen4  = alt4;
assign cen8  = alt8;
`endif

jtdd_prom_we #(
    .BANK_ADDR   ( BANK_ADDR    ),
    .MAIN_ADDR   ( MAIN_ADDR    ),
    .SND_ADDR    ( SND_ADDR     ),
    .ADPCM_0     ( ADPCM_0      ),
    .ADPCM_1     ( ADPCM_1      ),
    .CHAR_ADDR   ( CHAR_ADDR    ),
    .SCRZW_ADDR  ( SCRZW_ADDR   ),
    .SCRXY_ADDR  ( SCRXY_ADDR   ),
    .OBJWZ_ADDR  ( OBJWZ_ADDR   ),
    .OBJXY_ADDR  ( OBJXY_ADDR   ),
    .PROM_ADDR   ( PROM_ADDR    ),
    .MCU_ADDR    ( PROM_ADDR    )) // must be equal to PROM
u_prom(
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
//wire main_cen = cen12;

jtdd_main u_main(
    .clk            ( clk24         ),  // slower clock to ease synthesis
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
assign mcu_rstb  = 1'b0;

    `ifndef SIMULATION
    assign snd_latch = 8'd0;
    assign snd_irq   = 1'b0;
    `else
    reg [7:0] snd_latch2;
    reg       snd_irq2;
    assign snd_latch = snd_latch2;
    assign snd_irq   = snd_irq2;
    initial begin
        snd_latch2 = 8'hfe;
        snd_irq2   = 1'b0;
        #11_000_000 snd_latch2 = 8'h3a; // coin sound
        snd_irq2 = 1'b1;
        #100_000 snd_irq2 = 1'b0;
        snd_latch2 = 8'hfe;
    end
    `endif
`endif

`ifndef NOMCU
wire mcu_cen = turbo ? cen8 : cen4;

jtdd2_sub u_sub(
    .clk          (  clk24           ), // slower clock
    .rst          (  rst24           ),
    .mcu_rstb     (  mcu_rstb        ),
    .cen4         (  mcu_cen         ),
    .main_cen     (  cpu_cen         ),
    // CPU bus
    .main_AB      (  cpu_AB[8:0]     ),
    .main_wrn     (  cpu_wrn         ),
    .main_dout    (  cpu_dout        ),
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
jtframe_ram #(.aw(9)) u_shared(
    .clk    ( clk         ),
    .cen    ( cpu_cen     ),
    .data   ( cpu_dout    ),
    .addr   ( cpu_AB[8:0] ),
    .we     ( shared_we   ),
    .q      ( mcu_ram     )
);
`endif

jtdd2_sound u_sound(
    .clk         ( clk           ),
    .rst         ( rst           ),
    .H8          ( H8            ),
    // communication with main CPU
    .snd_irq     ( snd_irq       ),
    .snd_latch   ( snd_latch     ),
    // ROM
    .rom_addr    ( snd_addr      ),
    .rom_cs      ( snd_cs        ),
    .rom_data    ( snd_data      ),
    .rom_ok      ( snd_ok        ),

    .adpcm_addr  ( adpcm_addr    ),
    .adpcm_cs    ( adpcm_cs      ),
    .adpcm_data  ( adpcm_data    ),
    .adpcm_ok    ( adpcm_ok      ),

    // Sound output
    .sound       ( snd           ),
    .sample      ( sample        ),
    .peak        ( game_led      )
);

`ifndef NOVIDEO
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
`else
assign red   = 4'd0;
assign blue  = 4'd0;
assign green = 4'd0;
assign char_addr = 16'd0;
assign scr_addr  = 17'd0;
assign obj_addr  = 19'd0;
`endif

localparam SCR_ADDR  = 22'h6_0000;
localparam OBJ_ADDR  = 22'h8_0000;

jtframe_rom #(
    .SLOT0_AW    ( 16              ),   // Char
    .SLOT0_DW    ( 8               ),
    .SLOT0_OFFSET( CHAR_ADDR>>1    ),

    .SLOT1_AW    ( 17              ),   // Scroll
    .SLOT1_DW    ( 16              ),
    .SLOT1_OFFSET( SCR_ADDR        ),

    .SLOT2_AW    ( 18              ),   // ADPCM 0
    .SLOT2_DW    (  8              ),
    .SLOT2_OFFSET( ADPCM_0>>1      ),

    .SLOT5_AW    ( 16              ),   // SUB
    .SLOT5_DW    (  8              ),
    .SLOT5_OFFSET( SUB_ADDR>>1     ),

    .SLOT7_AW    ( 18              ),
    .SLOT7_DW    (  8              ),
    .SLOT7_OFFSET(  0              ),   // Main

    .SLOT8_AW    ( 19              ),   // Objects
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
    .slot2_cs    ( adpcm_cs      ), // ADPCM 0
    .slot3_cs    ( 1'b0          ), // ADPCM 1
    .slot4_cs    ( 1'b0          ), // unused
    .slot5_cs    ( mcu_cs        ),
    .slot6_cs    ( snd_cs        ),
    .slot7_cs    ( main_cs       ),
    .slot8_cs    ( 1'b1          ), // objects

    .slot0_ok    ( char_ok       ),
    .slot1_ok    ( scr_ok        ),
    .slot2_ok    ( adpcm_ok      ),
    .slot5_ok    ( mcu_ok        ),
    .slot6_ok    ( snd_ok        ),
    .slot7_ok    ( main_ok       ),
    .slot8_ok    ( obj_ok        ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( scr_addr      ),
    .slot2_addr  ( adpcm_addr    ),
    .slot5_addr  ( mcu_addr      ),
    .slot6_addr  ( snd_addr      ),
    .slot7_addr  ( main_addr     ),
    .slot8_addr  ( obj_addr      ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( scr_data      ),
    .slot2_dout  ( adpcm_data    ),
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
    // unused
    .slot3_ok    (               ),
    .slot4_ok    (               ),
    .slot3_dout  (               ),
    .slot4_dout  (               ),
    .slot3_addr  (               ),
    .slot4_addr  (               )
);

endmodule