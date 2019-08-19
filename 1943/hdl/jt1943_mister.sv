//============================================================================
//  Arcade: 1943  by Jose Tejada Gomez. Twitter: @topapate
//
//  Port to MiSTer
//  Thanks to Sorgelig for his continuous support
//  Original repository: http://github.com/jotego/jt_gng
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

`timescale 1ns/1ps

module emu
(
    //Master input clock
    input         CLK_50M,

    //Async reset from top-level module.
    //Can be used as initial reset.
    input         RESET,

    //Must be passed to hps_io module
    inout  [44:0] HPS_BUS,

    //Base video clock. Usually equals to CLK_SYS.
    output        VGA_CLK,

    //Multiple resolutions are supported using different VGA_CE rates.
    //Must be based on CLK_VIDEO
    output        VGA_CE,

    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,    // = ~(VBlank | HBlank)
    output        VGA_F1,

    //Base video clock. Usually equals to CLK_SYS.
    output        HDMI_CLK,

    //Multiple resolutions are supported using different HDMI_CE rates.
    //Must be based on CLK_VIDEO
    output        HDMI_CE,

    output  [7:0] HDMI_R,
    output  [7:0] HDMI_G,
    output  [7:0] HDMI_B,
    output        HDMI_HS,
    output        HDMI_VS,
    output        HDMI_DE,   // = ~(VBlank | HBlank)
    output  [1:0] HDMI_SL,   // scanlines fx

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    output  [7:0] HDMI_ARX,
    output  [7:0] HDMI_ARY,

    output        LED_USER,  // 1 - ON, 0 - OFF.

    // b[1]: 0 - LED status is system status OR'd with b[0]
    //       1 - LED status is controled solely by b[0]
    // hint: supply 2'b00 to let the system control the LED.
    output  [1:0] LED_POWER,
    output  [1:0] LED_DISK,

    output [15:0] AUDIO_L,
    output [15:0] AUDIO_R,
    output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned

    output  [1:0] ROTATE,

    //SDRAM interface with lower latency
    output        SDRAM_CLK,
    output        SDRAM_CKE,
    output [12:0] SDRAM_A,
    output  [1:0] SDRAM_BA,
    inout  [15:0] SDRAM_DQ,
    output        SDRAM_DQML,
    output        SDRAM_DQMH,
    output        SDRAM_nCS,
    output        SDRAM_nCAS,
    output        SDRAM_nRAS,
    output        SDRAM_nWE
    `ifdef SIMULATION
    ,output         sim_pxl_cen,
    output          sim_pxl_clk,
    output          sim_vs,
    output          sim_hs
    `endif
);
// 00000000001111111111222222222233
// 00000000000123456789012345678901
// 0123456789ABCDEFGHIJKLMNOPQRSTUV

`include "build_id.v"
localparam CONF_STR = {
    "JT1943;;",
    "-;",
    "F,rom;",
    "OL,Aspect Ratio,Original,Wide;", // L=21
    "OK,Orientation,Vert,Horz;",      // K=20
    "OMN,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;", // 22,23
    "-;",
    "O23,Difficulty,Normal,Easy,Hard,Very hard;", // 42
    "O4,Test mode,OFF,ON;", // 20
    "O7,PSG,ON,OFF;", // 14
    "O8,FM ,ON,OFF;", // 14
    "OCD,FX volume, high, very high, very low, low;",
    // "OB,Flip screen,OFF,ON;",
    "-;",
    "R0,Reset;",
    "J,Fire,Bomb,Start 1P,Start 2P,Coin,Pause;",
    "V,v",`BUILD_DATE, " http://patreon.com/topapate;"
};

assign VGA_F1=1'b0;

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire cen12, cen6, cen3, cen1p5;
wire pll_locked;

pll pll(
    .refclk     ( CLK_50M    ),
    .rst        ( 1'b0       ),
    .locked     ( pll_locked ),
    .outclk_0   ( clk_sys    ),
    .outclk_1   ( SDRAM_CLK  )
);

///////////////////////////////////////////////////

wire [31:0] status;
wire [ 1:0] buttons;

wire        ioctl_wr;
wire [21:0] ioctl_addr;
wire [ 7:0] ioctl_data;

wire [ 9:0] game_joystick1, game_joystick2;
wire [ 1:0] game_coin, game_start;
wire        game_pause;
wire        dip_pause = ~game_pause;
wire [ 3:0] gfx_en;

wire        forced_scandoubler;
wire        downloading, game_rst, rst, rst_n;
wire        rst_req  = RESET | status[0] | buttons[1];
wire        dip_flip = status[32'hb];
wire        dip_test = ~status[4];

assign LED_DISK  = 2'b0;
assign LED_POWER = 2'b0;

// SDRAM
wire         loop_rst;
wire         sdram_req;
wire [31:0]  data_read;
wire [21:0]  sdram_addr;
wire         data_rdy;
wire         sdram_ack;
wire         refresh_en;

wire         prog_we;
wire [21:0]  prog_addr;
wire [ 7:0]  prog_data;
wire [ 1:0]  prog_mask;

wire       orientation = status[20];
wire       widescreen  = status[21];
wire [1:0] scanlines   = status[23:22];

assign HDMI_ARX = widescreen ? 8'd16 : orientation ? 8'd4 : 8'd3;
assign HDMI_ARY = widescreen ? 8'd9  : orientation ? 8'd3 : 8'd4;

jtframe_mister #( .CONF_STR(CONF_STR),
    .SIGNED_SND(1'b1), .THREE_BUTTONS(1'b1))
u_frame(
    .clk_sys        ( clk_sys        ),
    .clk_rom        ( clk_sys        ),
    .pll_locked     ( pll_locked     ),
    // interface with microcontroller
    .status         ( status         ),
    .HPS_BUS        ( HPS_BUS        ),
    .buttons        ( buttons        ),
    // SDRAM interface
    .SDRAM_CLK      ( SDRAM_CLK      ),
    .SDRAM_DQ       ( SDRAM_DQ       ),
    .SDRAM_A        ( SDRAM_A        ),
    .SDRAM_DQML     ( SDRAM_DQML     ),
    .SDRAM_DQMH     ( SDRAM_DQMH     ),
    .SDRAM_nWE      ( SDRAM_nWE      ),
    .SDRAM_nCAS     ( SDRAM_nCAS     ),
    .SDRAM_nRAS     ( SDRAM_nRAS     ),
    .SDRAM_nCS      ( SDRAM_nCS      ),
    .SDRAM_BA       ( SDRAM_BA       ),
    .SDRAM_CKE      ( SDRAM_CKE      ),
    // ROM load
    .ioctl_addr     ( ioctl_addr     ),
    .ioctl_data     ( ioctl_data     ),
    .ioctl_wr       ( ioctl_wr       ),
    .prog_addr      ( prog_addr      ),
    .prog_data      ( prog_data      ),
    .prog_mask      ( prog_mask      ),
    .prog_we        ( prog_we        ),
    .downloading    ( downloading    ),
    // ROM access from game
    .loop_rst       ( loop_rst       ),
    .sdram_addr     ( sdram_addr     ),
    .sdram_req      ( sdram_req      ),
    .sdram_ack      ( sdram_ack      ),
    .data_read      ( data_read      ),
    .data_rdy       ( data_rdy       ),
    .refresh_en     ( refresh_en     ),
//////////// board
    .rst            ( rst            ),
    .rst_n          ( rst_n          ), // unused
    .game_rst       ( game_rst       ),
    .game_rst_n     (                ),
    // reset forcing signals:
    .dip_flip       ( dip_flip       ),
    .rst_req        ( rst_req        ),
    // joystick
    .game_joystick1 ( game_joystick1 ),
    .game_joystick2 ( game_joystick2 ),
    .game_coin      ( game_coin      ),
    .game_start     ( game_start     ),
    .game_pause     ( game_pause     ),
    .game_service   (                ), // unused
    .LED            ( LED_USER       ),
    // Debug
    .gfx_en         ( gfx_en         )
);

///////////////////////////////////////////////////////////////////

wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b;

`ifndef SIMULATION
arcade_rotate_fx #(256,224,12,1) u_rotate_fx
(
    .clk_video  ( clk_sys   ),
    .ce_pix     ( cen6      ),

    .RGB_in     ( {r,g,b}   ),
    .HBlank     ( ~hblank   ),
    .VBlank     ( ~vblank   ),
    .HSync      ( hs        ),
    .VSync      ( vs        ),

    .VGA_CLK    (  VGA_CLK  ),
    .VGA_CE     (  VGA_CE   ),
    .VGA_R      (  VGA_R    ),
    .VGA_G      (  VGA_G    ),
    .VGA_B      (  VGA_B    ),
    .VGA_HS     (  VGA_HS   ),
    .VGA_VS     (  VGA_VS   ),
    .VGA_DE     (  VGA_DE   ),

    .HDMI_CLK   (  HDMI_CLK ),
    .HDMI_CE    (  HDMI_CE  ),
    .HDMI_R     (  HDMI_R   ),
    .HDMI_G     (  HDMI_G   ),
    .HDMI_B     (  HDMI_B   ),
    .HDMI_HS    (  HDMI_HS  ),
    .HDMI_VS    (  HDMI_VS  ),
    .HDMI_DE    (  HDMI_DE  ),
    .HDMI_SL    (  HDMI_SL  ),

    .fx                ( scanlines          ),
    .forced_scandoubler( forced_scandoubler ),
    .no_rotate         ( orientation        )
);
`else
    assign VGA_VS = vs;
    assign VGA_HS = hs;
    assign VGA_R  = r;
    assign VGA_G  = g;
    assign VGA_B  = b;
    assign VGA_CE = cen6;
    assign VGA_CLK= clk_sys;
`endif

`ifdef SIMULATION
assign sim_hs = hs;
assign sim_vs = vs;
assign sim_pxl_clk = clk_sys;
assign sim_pxl_cen = cen6;
`endif

///////////////////////////////////////////////////////////////////
wire       dip_upright   = 1'b1;
wire       dip_credits2p = 1'b1;
wire       dip_demosnd   = 1'b0;
wire       dip_continue  = 1'b1;
wire [2:0] dip_price2    = 3'b100;
wire [2:0] dip_price1    = ~3'b0;
reg  [3:0] dip_level;
wire [1:0] dip_fxlevel = 2'b10 ^ status[13:12];

// play level
always @(posedge clk_sys)
    case( status[3:2] )
        2'b00: dip_level <= 4'b0111; // normal
        2'b01: dip_level <= 4'b1111; // easy
        2'b10: dip_level <= 4'b0011; // hard
        2'b11: dip_level <= 4'b0000; // very hard
    endcase // status[3:2]

assign ROTATE = 2'b01;
`ifdef SIMULATION
assign sim_pxl_clk = clk_sys;
assign sim_pxl_cen = cen6;
`endif

jt1943_game #(.CLK_SPEED(48)) u_game
(
    .rst           ( game_rst        ),

    .clk_rom       ( clk_sys         ),
    .clk           ( clk_sys         ),
    .cen12         ( cen12           ),
    .cen6          ( cen6            ),
    .cen3          ( cen3            ),
    .cen1p5        ( cen1p5          ),

    .red           ( r               ),
    .green         ( g               ),
    .blue          ( b               ),
    .LHBL          ( hblank          ),
    .LVBL          ( vblank          ),
    .HS            ( hs              ),
    .VS            ( vs              ),

    .start_button  ( {m_start2, m_start1} ),
    .coin_input    ( {1'b0, m_coin}       ),
    .joystick1     ( {1'b0, m_jump, m_fire, m_up, m_down, m_left, m_right} ),
    .joystick2     ( {1'b0, m2_jump, m2_fire, m2_up, m2_down, m2_left, m2_right} ),

    // Sound control
    .enable_fm    ( 1'b1             ),
    .enable_psg   ( 1'b1             ),
    // PROM programming
    .ioctl_addr   ( ioctl_addr[21:0] ),
    .ioctl_data   ( ioctl_data       ),
    .ioctl_wr     ( ioctl_wr         ),
    .prog_addr    ( prog_addr        ),
    .prog_data    ( prog_data        ),
    .prog_mask    ( prog_mask        ),
    .prog_we      ( prog_we          ),

    // ROM load
    .downloading  ( downloading      ),
    .loop_rst     ( loop_rst         ),
    .sdram_req    ( sdram_req        ),
    .sdram_addr   ( sdram_addr       ),
    .data_read    ( data_read        ),
    .sdram_ack    ( sdram_ack        ),
    .data_rdy     ( data_rdy         ),
    .refresh_en   ( refresh_en       ),

    .dip_test     ( dip_test         ),
    .dip_pause    ( dip_pause        ),
    .dip_upright  ( dip_upright      ),
    .dip_credits2p( dip_credits2p    ),
    .dip_level    ( dip_level        ),
    .dip_demosnd  ( dip_demosnd      ),
    .dip_continue ( dip_continue     ),
    .dip_price2   ( dip_price2       ),
    .dip_price1   ( dip_price1       ),
    .dip_flip     ( dip_flip         ),
    .dip_fxlevel  ( dip_fxlevel      ),

    .snd          ( AUDIO_L          ),
    .gfx_en       ( ~4'b0            ),

    // unconnected
    .coin_cnt     (                  ),
    .sample       (                  )
);

assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 1;

endmodule
