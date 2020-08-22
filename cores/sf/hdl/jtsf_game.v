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
    Date: 17-8-2020 */

module jtsf_game(
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
    input   [ 9:0]  joystick1,
    input   [ 9:0]  joystick2,
    // SDRAM interface
    input           downloading,
    output          dwnld_busy,
    input           loop_rst,
    output          sdram_req,
    output  [21:0]  sdram_addr,
    output  [ 1:0]  sdram_wrmask,
    output          sdram_rnw,
    output  [15:0]  data_write,
    input   [31:0]  data_read,
    input           data_rdy,
    input           sdram_ack,
    output          refresh_en,
    // ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_data,
    input           ioctl_wr,
    output  [21:0]  prog_addr,
    output  [ 7:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output          prog_we,
    output          prog_rd,
    // DIP switches
    input   [31:0]  status,
    input   [31:0]  dipsw,
    input           dip_pause,
    input           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd_left,
    output  signed [15:0] snd_right,
    output          sample,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [3:0]   gfx_en
);

localparam
    MAINW = 19, // 16 bit
    RAMW  = 15, // 32k x 16 bits
    CHARW = 13, // 16 bit reads
    MAP1W = 16, // 128 kBytes read in 16-bit words -> 64kW = 2^16
    MAP2W = MAP1W,
    SCR1W = 19,
    SCR2W = 18,
    SND1W = 15, // 32 kB
    SND2W = 18, // 256 kB
    MCUW  = 12, // 4kB
    OBJW  = 21;

localparam [21:0] MAIN_OFFSET = 22'h0,
                  SND_OFFSET  = 22'h06_0000 >> 1,
                  SND2_OFFSET = 22'h06_8000 >> 1,
                  MCU_OFFSET  = 22'h0A_8000 >> 1,
                  MAP2_OFFSET = 22'h0A_9000 >> 1,
                  MAP1_OFFSET = 22'h0C_9000 >> 1,
                  CHAR_OFFSET = 22'h0E_9000 >> 1,
                  SCR1_OFFSET = 22'h0E_D000 >> 1,
                  SCR2_OFFSET = 22'h1E_D000 >> 1,
                  OBJ_OFFSET  = 22'h26_D000 >> 1;
localparam [24:0] PROM_START  = 25'h42_D000;
localparam [21:0] RAM_OFFSET  = PROM_START[22:1];

wire [ 8:0] V;
wire [ 8:0] H;
wire        HINIT;
wire        LHBL, LVBL;

wire [13:1] cpu_AB;
wire        main_cs, ram_cs,
            snd1_cs, snd2_cs,
            char_cs, col_uw,  col_lw;
wire        charon, scr1on, scr2on, objon;
wire        flip;
wire [15:0] char_dout, cpu_dout;
wire [15:0] scr1posh, scr2posh;
wire        rd, cpu_cen;
wire        char_busy;
wire        service = 1'b1;

// ROM data
wire [15:0] char_data, scr1_data, scr2_data, obj_data;
wire [15:0] main_data, ram_data;
wire [31:0] map1_data, map2_data, map1_swap, map2_swap;
wire [ 7:0] snd1_data, snd2_data;
// MCU interface
// wire        mcu_brn;
// wire [ 7:0] mcu_din, mcu_dout;
// wire [16:1] mcu_addr;
// wire        mcu_wr, mcu_DMAn, mcu_DMAONn;

// ROM addresses
wire [MAINW  :1] main_addr;
wire [RAMW   :1] ram_addr;
wire [SND1W-1:0] snd1_addr;
wire [SND2W-1:0] snd2_addr;
wire [MAP1W-1:0] map1_addr;
wire [MAP2W-1:0] map2_addr;
wire [CHARW-1:0] char_addr;
wire [SCR1W-1:0] scr1_addr;
wire [SCR2W-1:0] scr2_addr;
wire [OBJW-1 :0] obj_addr;

wire [15:0] dipsw_a, dipsw_b;

wire        main_ok, ram_ok,  map1_ok, map2_ok, scr1_ok, scr2_ok,
            snd1_ok, snd2_ok, obj_ok, char_ok;

// A and B are inverted in this game (or in MAME definition)
assign {dipsw_a, dipsw_b} = dipsw[31:0];
assign dwnld_busy         = downloading;
assign map1_swap          = { map1_data[15:0], map1_data[31:16] };
assign map2_swap          = { map2_data[15:0], map2_data[31:16] };

/////////////////////////////////////
// 48 MHz based clock enable signals
jtframe_cen48 u_cen48(
    .clk    ( clk           ),
    .cen16  ( pxl2_cen      ),
    .cen12  (               ),
    .cen12b (               ),
    .cen8   ( pxl_cen       ),
    .cen6   (               ),
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
wire        mcu_cen, cen24_8;
reg         cen24_8b;

jtframe_cen24 u_cen(
    .clk    ( clk24     ),
    .cen12  (           ),
    .cen12b (           ),
    .cen8   ( cen24_8   ),
    .cen6   ( mcu_cen   ),
    .cen6b  (           ),
    .cen4   (           ),
    .cen3   (           ),
    .cen3q  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5 (           ),
    .cen1p5b(           )
);

always @(posedge clk24) cen24_8b<=cen24_8;

wire LHBL_obj, LVBL_obj;

// Frame rate and blanking as the original
// Sync pulses slightly adjusted
jtframe_vtimer #(
    .HB_START ( 9'h1C7 ),
    //.HB_END   ( 9'h047 ),
    .HB_END   ( 9'h04F ),
    .HCNT_END ( 9'h1FF ),
    .VB_START ( 9'hF0  ),
    .VB_END   ( 9'h10  ),
    .VCNT_END ( 9'hFF  ),
    //.VS_START ( 9'h0   ),
    .VS_START ( 9'hF8   ),
    //.VS_END   ( 9'h8   ),
    .HS_START ( 9'h1F8 ),
    .HS_END   ( 9'h020 ),
    .H_VB     ( 9'h7   ),
    .H_VS     ( 9'h1FF ),
    .H_VNEXT  ( 9'h1FF ),
    .HINIT    ( 9'h20 )
) u_timer(
    .clk       ( clk      ),
    .pxl_cen   ( pxl_cen  ),
    .vdump     ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( LHBL     ),
    .LVBL      ( LVBL     ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          ),
    // unused
    .vrender   (          ),
    .vrender1  (          )
);

wire       RnW;
// sound
wire [7:0] snd_latch;
wire       snd_nmi_n;

// OBJ
wire        OKOUT, blcnten, obj_br, bus_ack;
wire [11:0] obj_AB;
wire [15:0] oram_dout;

wire [21:0] pre_prog;

assign prog_addr = (ioctl_addr[22:1]>=OBJ_OFFSET && ioctl_addr[22:1]<PROM_START) ?
    { pre_prog[21:6],pre_prog[4:1],pre_prog[5],pre_prog[0]} :
    pre_prog;

jtframe_dwnld #(
    .PROM_START ( PROM_START )
)
u_dwnld(
    .clk         ( clk           ),
    .downloading ( downloading   ),

    .ioctl_addr  ( ioctl_addr    ),
    .ioctl_data  ( ioctl_data    ),
    .ioctl_wr    ( ioctl_wr      ),

    .prog_addr   ( pre_prog      ),
    .prog_data   ( prog_data     ),
    .prog_mask   ( prog_mask     ),
    .prog_we     ( prog_we       ),
    .prom_we     (               ),

    .sdram_ack   ( sdram_ack     )
);

wire [15:0] scrposh, scrposv;
wire        UDSWn, LDSWn;
wire [ 1:0] dsn;

assign dsn = {UDSWn, LDSWn};

`ifndef NOMAIN
jtsf_main #( .MAINW(MAINW), .RAMW(RAMW) ) u_main (
    .rst        ( rst           ),
    .clk        ( clk24         ),
    .cen8       ( cen24_8       ),
    .cen8b      ( cen24_8b      ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // sound
    .snd_latch  ( snd_latch     ),
    .snd_nmi_n  ( snd_nmi_n     ),
    // CPU data bus
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_dout  ( char_dout     ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .UDSWn      ( UDSWn         ),
    .LDSWn      ( LDSWn         ),
    // SCROLL
    .scr1posh   ( scr1posh      ),
    .scr2posh   ( scr2posh      ),
    // GFX enable signals
    .charon     ( charon        ),
    .scr1on     ( scr1on        ),
    .scr2on     ( scr2on        ),
    .objon      ( objon         ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .obj_br     ( obj_br        ),
    .bus_ack    ( bus_ack       ),
    .col_uw     ( col_uw        ),
    .col_lw     ( col_lw        ),
    // MCU interface
    // .mcu_cen    (  mcu_cen      ),
    // .mcu_brn    (  mcu_brn      ),
    // .mcu_din    (  mcu_din      ),
    // .mcu_dout   (  mcu_dout     ),
    // .mcu_addr   (  mcu_addr     ),
    // .mcu_wr     (  mcu_wr       ),
    // .mcu_DMAn   (  mcu_DMAn     ),
    // .mcu_DMAONn (  mcu_DMAONn   ),
    .addr       ( main_addr     ),
    // RAM
    .ram_addr   ( ram_addr      ),
    .ram_cs     ( ram_cs        ),
    .ram_data   ( ram_data      ),
    .ram_ok     ( ram_ok        ),
    // ROM
    .rom_cs     ( main_cs       ),
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
    `ifndef SIM_SND_LATCH
    `define SIM_SND_LATCH 8'd0
    `endif
    assign main_addr   = {MAINW{1'b0}};
    assign cpu_AB      = 13'd0;
    assign cpu_dout    = 16'd0;
    assign char_cs     = 0;
    assign bus_ack     = 0;
    assign flip        = 0;
    assign RnW         = 1;
    assign UDSWn       = 1;
    assign LDSWn       = 1;
    assign scr1posh    = 16'd0;
    assign scr2posh    = 16'd0;
    assign cpu_cen     = cen24_8;
    assign OKOUT       = 0;
    assign snd_latch   = `SIM_SND_LATCH;
`endif

`ifndef NOSOUND
jtsf_sound #(
    .SND1W( SND1W ),
    .SND2W( SND2W )
) u_sound (
    .rst            ( rst            ),
    .clk            ( clk24          ),
    // Interface with main CPU
    .snd_latch      ( snd_latch      ),
    .snd_nmi_n      ( snd_nmi_n      ),
    // ROM
    .rom_addr       ( snd1_addr      ),
    .rom_data       ( snd1_data      ),
    .rom_cs         ( snd1_cs        ),
    .rom_ok         ( snd1_ok        ),
    // ROM 2
    .rom2_addr      ( snd2_addr      ),
    .rom2_data      ( snd2_data      ),
    .rom2_cs        ( snd2_cs        ),
    .rom2_ok        ( snd2_ok        ),
    // sound output
    .left           ( snd_left       ),
    .right          ( snd_right      ),
    .sample         ( sample         )
);
`else
assign snd1_addr = {SND1W{1'b0}};
assign snd2_addr = {SND2W{1'b0}};
assign snd1_cs   = 0;
assign snd2_cs   = 0;
assign snd_left  = 16'b0;
assign snd_right = 16'b0;
`endif

`ifndef NOVIDEO
jtsf_video #(
    .CHARW  ( CHARW ),
    .MAP1W  ( MAP1W ),
    .MAP2W  ( MAP2W ),
    .SCR1W  ( SCR1W ),
    .SCR2W  ( SCR2W ),
    .OBJW   ( OBJW  )
) u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB        ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .UDSWn      ( UDSWn         ),
    .LDSWn      ( LDSWn         ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // GFX enable signals
    .charon     ( charon        ),
    .scr1on     ( scr1on        ),
    .scr2on     ( scr2on        ),
    .objon      ( objon         ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL 1
    .map1_data  ( map1_data     ),
    .map1_addr  ( map1_addr     ),
    .map1_ok    ( map1_ok       ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .scr1posh   ( scr1posh      ),
    .scr1_ok    ( scr1_ok       ),
    // SCROLL 2
    .map2_data  ( map2_data     ),
    .map2_addr  ( map2_addr     ),
    .map2_ok    ( map2_ok       ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .scr2posh   ( scr2posh      ),
    .scr2_ok    ( scr2_ok       ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( ram_data      ),
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
    // .prog_addr    ( prog_addr[7:0]),
    // .prom_prio_we ( prom_we[0]    ),
    // .prom_din     ( prog_data[3:0]),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
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
assign scr1_addr = {SCR1W{1'b0}};
assign scr2_addr = {SCR2W{1'b0}};
assign char_addr = {CHARW{1'b0}};
assign blcnten   = 1'b0;
assign obj_br    = 1'b0;
assign char_busy = 1'b0;
`endif

wire [9:0] slot_cs, slot_ok, slot_wr, slot_clr;

assign slot_cs = {
  LVBL, 1'b1, LVBL, snd2_cs, snd1_cs,
  LVBL, main_cs, LVBL, ram_cs, LVBL };


assign {
  map1_ok, obj_ok, map2_ok, snd2_ok, snd1_ok,
  scr2_ok, main_ok, scr1_ok, ram_ok, char_ok } = slot_ok;

assign slot_wr[9:2] = 7'd0;
assign slot_wr[1]   = !RnW;
assign slot_wr[0]   = 1'd0;
assign slot_clr     = 10'd0;

jtframe_sdram_mux #(
    .SLOT0_AW    ( CHARW         ), // Char
    .SLOT0_DW    ( 16            ),

    .SLOT1_AW    ( RAMW          ), // Main CPU RAM
    .SLOT1_DW    ( 16            ),
    .SLOT1_TYPE  ( 2             ), // R/W access

    .SLOT2_AW    ( SCR1W         ), // Scroll 1
    .SLOT2_DW    ( 16            ),

    .SLOT3_AW    ( MAINW         ), // main ROM
    .SLOT3_DW    ( 16            ),

    .SLOT4_AW    ( SCR2W         ), // Scroll 2
    .SLOT4_DW    ( 16            ),

    .SLOT5_AW    ( SND1W         ), // Sound 1
    .SLOT5_DW    (  8            ),

    .SLOT6_AW    ( SND2W         ), // Sound 2
    .SLOT6_DW    (  8            ),

    .SLOT7_AW    ( MAP2W         ), // Map 2
    .SLOT7_DW    ( 32            ),

    .SLOT8_AW    ( OBJW          ), // Objects
    .SLOT8_DW    ( 16            ),

    .SLOT9_AW    ( MAP1W         ), // Map 1
    .SLOT9_DW    ( 32            )
) u_rom (
    .rst         ( rst           ),
    .clk         ( clk           ),
    .vblank      ( ~LVBL         ),

    .slot0_offset( CHAR_OFFSET   ),
    .slot1_offset( RAM_OFFSET    ),
    .slot2_offset( SCR1_OFFSET   ),
    .slot3_offset( MAIN_OFFSET   ),
    .slot4_offset( SCR2_OFFSET   ),
    .slot5_offset( SND_OFFSET    ),
    .slot6_offset( SND2_OFFSET   ),
    .slot7_offset( MAP2_OFFSET   ),
    .slot8_offset( OBJ_OFFSET    ),
    .slot9_offset( MAP1_OFFSET   ),

    .slot1_din   ( cpu_dout      ),
    .slot1_wrmask( dsn           ),

    .slot0_addr  ( char_addr     ),
    .slot1_addr  ( ram_addr      ),
    .slot2_addr  ( scr1_addr     ),
    .slot3_addr  ( main_addr     ),
    .slot4_addr  ( scr2_addr     ),
    .slot5_addr  ( snd1_addr     ),
    .slot6_addr  ( snd2_addr     ),
    .slot7_addr  ( map2_addr     ),
    .slot8_addr  ( obj_addr      ),
    .slot9_addr  ( map1_addr     ),

    .slot0_dout  ( char_data     ),
    .slot1_dout  ( ram_data      ),
    .slot2_dout  ( scr1_data     ),
    .slot3_dout  ( main_data     ),
    .slot4_dout  ( scr2_data     ),
    .slot5_dout  ( snd1_data     ),
    .slot6_dout  ( snd2_data     ),
    .slot7_dout  ( map2_data     ),
    .slot8_dout  ( obj_data      ),
    .slot9_dout  ( map1_data     ),

    // bus signals
    .slot_cs     ( slot_cs       ),
    .slot_ok     ( slot_ok       ),
    .slot_wr     ( slot_wr       ),
    .slot_clr    ( slot_clr      ),

    // SDRAM interface
    .downloading ( downloading   ),
    .loop_rst    ( loop_rst      ),
    .sdram_ack   ( sdram_ack     ),
    .sdram_req   ( sdram_req     ),
    .refresh_en  ( refresh_en    ),
    .sdram_addr  ( sdram_addr    ),
    .sdram_rnw   ( sdram_rnw     ),
    .sdram_wrmask( sdram_wrmask  ),
    .data_rdy    ( data_rdy      ),
    .data_read   ( data_read     ),
    .data_write  ( data_write    ),

    // Unused:
    .ready       (               ),
    .slot_active (               ),
    .slot0_din   (               ),
    .slot2_din   (               ),
    .slot3_din   (               ),
    .slot4_din   (               ),
    .slot5_din   (               ),
    .slot6_din   (               ),
    .slot7_din   (               ),
    .slot8_din   (               ),
    .slot9_din   (               )
);

endmodule
