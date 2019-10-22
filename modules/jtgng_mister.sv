//============================================================================
//  Arcade: CAPCOM pre-CPS hardware  by Jose Tejada Gomez. Twitter: @topapate
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

// Config string
`include "build_id.v"
`define SEPARATOR "-;",
`include "conf_str.v"

`ifdef SIMULATION
localparam CONF_STR="JTGNG;;";
`else
localparam CONF_STR = {
    `CORENAME,";;",
    "O1,Credits,OFF,ON;",
    `SEPARATOR
    // Common MiSTer options
    "F,rom;",
    "O2,Aspect Ratio,Original,Wide;",
    `ifdef VERTICAL_SCREEN
    "OD,Rotate screen,Yes,No;",
    "OC,Flip screen,OFF,ON;",
    `endif
    `ifdef JTFRAME_VGA
        "O9,Screen filter,ON,OFF;",
    `else
        "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    `endif
    `ifdef HAS_TESTMODE
    "O6,Test mode,OFF,ON;",
    `endif
    `ifdef JT12
    "O7,PSG,ON,OFF;",
    "O8,FM ,ON,OFF;",
    "OAB,FX volume, high, very high, very low, low;",
    `endif
    `SEPARATOR
    `CORE_OSD
    `CORE_KEYMAP
    "R0,RST;",
    "V,v",`BUILD_DATE," patreon.com/topapate;"
};
`endif

`undef SEPARATOR

assign VGA_F1=1'b0;

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire cen12, cen6, cen3, cen1p5;
wire pll_locked;
reg  pll_rst = 1'b0;

// Resets the PLL if it looses lock
always @(posedge clk_sys or posedge RESET) begin : pll_controller
    reg last_locked;
    reg [7:0] rst_cnt;

    if( RESET ) begin
        pll_rst <= 1'b0;
        rst_cnt <= 8'hd0;
    end else begin
        last_locked <= pll_locked;
        if( last_locked && !pll_locked ) begin
            rst_cnt <= 8'hff; // keep reset high for 256 cycles
            pll_rst <= 1'b1;
        end else begin
            if( rst_cnt != 8'h00 )
                rst_cnt <= rst_cnt - 8'h1;
            else
                pll_rst <= 1'b0;
        end
    end
end

pll pll(
    .refclk     ( CLK_50M    ),
    .rst        ( pll_rst    ),
    .locked     ( pll_locked ),
    .outclk_0   ( clk_sys    ),
    .outclk_1   ( SDRAM_CLK  )
);

///////////////////////////////////////////////////

wire [31:0] status;
wire [ 1:0] buttons;

wire [7:0] dipsw_a, dipsw_b;
wire [1:0] dip_fxlevel;
wire       enable_fm, enable_psg;
wire       dip_pause, dip_flip, dip_test;

wire        ioctl_wr;
wire [21:0] ioctl_addr;
wire [ 7:0] ioctl_data;

wire [ 9:0] game_joy1, game_joy2;
wire [ 1:0] game_coin, game_start;
wire [ 3:0] gfx_en;

wire        downloading, game_rst, rst, rst_n;
wire        rst_req   = RESET | status[0] | buttons[1];


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

`ifndef COLORW
`define COLORW 4
`endif
localparam COLORW=`COLORW;

wire [COLORW-1:0] game_r, game_g, game_b;
wire              LHBL_dly, LVBL_dly;
wire              hs, vs;

jtframe_mister #(
    .CONF_STR      ( CONF_STR ),
    .SIGNED_SND    ( 1'b1     ),
    .THREE_BUTTONS ( 1'b1     ),
    .COLORW        ( COLORW   ))
u_frame(
    .clk_sys        ( clk_sys        ),
    .clk_rom        ( clk_sys        ),
    .clk_vga        ( clk_sys        ),
    .pll_locked     ( pll_locked     ),
    // interface with microcontroller
    .status         ( status         ),
    .HPS_BUS        ( HPS_BUS        ),
    .buttons        ( buttons        ),
    // Base video
    .game_r         ( game_r         ),
    .game_g         ( game_g         ),
    .game_b         ( game_b         ),
    .LHBL           ( LHBL_dly       ),
    .LVBL           ( LVBL_dly       ),
    .hs             ( hs             ),
    .vs             ( vs             ),
    .pxl_cen        ( cen6           ),
    .pxl2_cen       ( cen12          ),
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
    .rst_req        ( rst_req        ),
    // joystick
    .game_joystick1 ( game_joy1      ),
    .game_joystick2 ( game_joy2      ),
    .game_coin      ( game_coin      ),
    .game_start     ( game_start     ),
    .game_service   (                ), // unused
    .LED            ( LED_USER       ),
    // DIP and OSD settings
    .enable_fm      ( enable_fm      ),
    .enable_psg     ( enable_psg     ),
    .dip_test       ( dip_test       ),
    .dip_pause      ( dip_pause      ),
    .dip_flip       ( dip_flip       ),
    .dip_fxlevel    ( dip_fxlevel    ),
    // screen
    .rotate         ( ROTATE         ),
    // HDMI
    .hdmi_r         ( HDMI_R         ),
    .hdmi_g         ( HDMI_G         ),
    .hdmi_b         ( HDMI_B         ),
    .hdmi_hs        ( HDMI_HS        ),
    .hdmi_vs        ( HDMI_VS        ),
    .hdmi_clk       ( HDMI_CLK       ),
    .hdmi_cen       ( HDMI_CE        ),
    .hdmi_de        ( HDMI_DE        ),
    .hdmi_sl        ( HDMI_SL        ),
    .hdmi_arx       ( HDMI_ARX       ),
    .hdmi_ary       ( HDMI_ARY       ),
    // scan doubler output to VGA pins
    .scan2x_r       ( VGA_R          ),
    .scan2x_g       ( VGA_G          ),
    .scan2x_b       ( VGA_B          ),
    .scan2x_hs      ( VGA_HS         ),
    .scan2x_vs      ( VGA_VS         ),
    .scan2x_clk     ( VGA_CLK        ),
    .scan2x_cen     ( VGA_CE         ),
    .scan2x_de      ( VGA_DE         ),
    // Debug
    .gfx_en         ( gfx_en         )
);

`ifdef SIMULATION
assign sim_hs = hs;
assign sim_vs = vs;
assign sim_pxl_clk = clk_sys;
assign sim_pxl_cen = cen6;
`endif

///////////////////////////////////////////////////////////////////


`ifdef SIMULATION
assign sim_pxl_clk = clk_sys;
assign sim_pxl_cen = cen6;
`endif

`GAMETOP #(.CLK_SPEED(48)) u_game
(
    .rst          ( game_rst         ),
    .clk          ( clk_sys          ),
    .cen12        ( cen12            ),
    .cen6         ( cen6             ),
    .cen3         ( cen3             ),
    .cen1p5       ( cen1p5           ),

    .red          ( game_r           ),
    .green        ( game_g           ),
    .blue         ( game_b           ),
    .LHBL_dly     ( LHBL_dly         ),
    .LVBL_dly     ( LVBL_dly         ),
    .HS           ( hs               ),
    .VS           ( vs               ),

    .start_button ( game_start       ),
    .coin_input   ( game_coin        ),
    .joystick1    ( game_joy1[6:0]   ),
    .joystick2    ( game_joy2[6:0]   ),

    // Sound control
    .enable_fm    ( enable_fm        ),
    .enable_psg   ( enable_psg       ),
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

    // DIP switches
    .status       ( status           ),
    .dip_pause    ( dip_pause        ),
    .dip_flip     ( dip_flip         ),
    .dip_test     ( dip_test         ),
    .dip_fxlevel  ( dip_fxlevel      ),  

    `ifdef STEREO_GAME
    .snd_left     ( AUDIO_L          ),
    .snd_right    ( AUDIO_R          ),
    `else
    .snd          ( AUDIO_L          ),
    `endif
    .gfx_en       ( gfx_en           ),

    // unconnected
    .sample       (                  )
);

`ifndef STEREO_GAME
    assign AUDIO_R = AUDIO_L;
`endif

assign AUDIO_S = 1;

endmodule
