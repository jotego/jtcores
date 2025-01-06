/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 22-2-2019 */

`ifdef MCP
    `define MC2_PINS
`endif

`ifdef MC2
    `define MC2_PINS
`endif

`ifndef MC2
    `ifndef MCP
        `define NEPTUNO_PINS
    `endif
`endif

//`default_nettype none

module neptuno_top(
    input           CLK50,
    output  [5:0]   VGA_R,
    output  [5:0]   VGA_G,
    output  [5:0]   VGA_B,
    output          VGA_HS,
    output          VGA_VS,
    // SDRAM interface
    inout  [15:0]   SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output [12:0]   SDRAM_A,        // SDRAM Address bus 13 Bits
    output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output [1:0]    SDRAM_BA,       // SDRAM Bank Address
    inout           SDRAM_CLK,      // SDRAM Clock
    output          SDRAM_CKE,      // SDRAM Clock Enable
   // SPI interface to arm io controller
    inout           SPI_DO,
    input           SPI_DI,
    input           SPI_SCK,
    input           SPI_SS2,
    // sound
    output          AUDIO_L,
    output          AUDIO_R,
    // user LED
    output          LED,

    // NeptUNO exclusive pins
    // PS2
    input           PS2_CLK,
    input           PS2_DATA,
    inout           PS2_MOUSE_CLK,
    inout           PS2_MOUSE_DATA

    // Joystick
`ifndef MC2
    // joy pins for neptUNO and Multicore 2 plus
    ,output         JOY_CLK,
    output          JOY_LOAD,
    input           JOY_DATA
`else
    //joy pins for Multicore 2
   ,input [5:0]     JOY1,
    input [5:0]     JOY2
`endif

    ,output          JOY_SELECT

`ifdef MC2_PINS
    // only MC2 and MC2+ pins
    ,input [3:0]     BUTTON_n,

    // SD Card
    output          SD_CS,
    output          SD_SCLK,
    output          SD_MOSI,
    input           SD_MISO,

    // SRAM
    output  [20:0]  SRAM_ADDR,
    inout   [7:0]   SRAM_DATA,
    output          SRAM_WE,
    output          SRAM_OE
`endif

`ifdef NEPTUNO_PINS
    // SRAM
    ,output [20:0]  SRAM_A,
    inout   [15:0]  SRAM_Q,
    output          SRAM_WE,
    output          SRAM_OE,
    output          SRAM_UB,
    output          SRAM_LB,

    //I2S audio
    output          I2S_BCLK,
    output          I2S_LRCLK,
    output          I2S_DATA
`endif

    //STM32
    ,output   		STM_RESET,
    output    		SPI_nWAIT

`ifdef MCP
    //Multicore 2 plus exclusive pins
    ,inout [31:0] GPIO
`endif

`ifdef SIMULATION
    ,output         sim_pxl_cen,
    output          sim_pxl_clk,
    output          sim_vb,
    output          sim_hb
`endif
);

//---------------------------------------------------------
//-- Multicores defaults
//---------------------------------------------------------
`ifdef MC2_PINS
    //no SRAM for this core
    assign SRAM_WE  = 1'b1;
    assign SRAM_OE  = 1'b1;

    //all the SD reading goes thru the microcontroller for this core
    assign SD_CS   = 1'bZ;
    assign SD_SCLK = 1'bZ;
    assign SD_MOSI = 1'bZ;
`endif

    assign STM_RESET = 1'bZ;

`ifdef MCP
   //disable external interfaces for this core
    assign GPIO = 32'Hzzzz;
`endif

`ifdef NEPTUNO_PINS
    `ifdef JTFRAME_LF_BUFFER
        assign SRAM_OE = 1'b0;
        assign SRAM_UB = 1'b0;
        assign SRAM_LB = 1'b0;
    `else
        //no SRAM for this core
        assign SRAM_A = 21'd0;
        assign SRAM_Q = 16'bZ;
        assign SRAM_WE = 1'b1;
        assign SRAM_OE = 1'b1;
        assign SRAM_UB = 1'b0;
        assign SRAM_LB = 1'b0;
    `endif
`endif

`ifdef JTFRAME_SDRAM_LARGE
    localparam SDRAMW=23; // 64 MB
`else
    localparam SDRAMW=22; // 32 MB
`endif

wire          rst, rst_n, clk_sys, clk_rom, clk24, clk48, clk96;
wire [63:0]   status;
wire [31:0]   joystick1, joystick2;
wire [24:0]   ioctl_addr;
wire [ 7:0]   ioctl_dout;
wire [ 7:0]   ioctl_din;
wire          ioctl_wr;
wire          ioctl_ram, ioctl_cart;
wire [ 1:0]   dial_x, dial_y;

wire [15:0] joyana_l1, joyana_l2, joyana_l3, joyana_l4,
            joyana_r1, joyana_r2, joyana_r3, joyana_r4;

wire rst_req   = status[0];

// ROM download
wire          downloading, dwnld_busy;

wire [SDRAMW-1:0] prog_addr;
wire [15:0]   prog_data;
wire [ 1:0]   prog_mask, prog_ba;
wire          prog_we, prog_rd, prog_rdy, prog_ack, prog_dst, prog_dok;
wire [ 7:0]   st_addr, st_dout;
wire [ 7:0]   paddle_1, paddle_2, paddle_3, paddle_4;

// ROM access from game
wire [SDRAMW-1:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr;
wire [ 3:0] ba_rd, ba_rdy, ba_ack, ba_dst, ba_dok, ba_wr;
wire [15:0] ba0_din, ba1_din, ba2_din, ba3_din;
wire [ 1:0] ba0_dsn, ba1_dsn, ba2_dsn, ba3_dsn;
wire [15:0] sdram_dout;

`ifndef JTFRAME_COLORW
`define JTFRAME_COLORW 4
`endif

`ifndef MC2_PINS
    wire [3:0] BUTTON_n = 4'hf;
`endif

localparam COLORW=`JTFRAME_COLORW;

wire [COLORW-1:0] red;
wire [COLORW-1:0] green;
wire [COLORW-1:0] blue;

wire LHBL, LVBL, hs, vs;
wire [15:0] snd_left, snd_right;
wire [ 5:0] snd_en, snd_vu;
wire [ 7:0] snd_vol;
wire        sample, snd_peak;


wire [9:0] game_joy1, game_joy2, game_joy3, game_joy4;
wire [3:0] game_coin, game_start;
wire       game_rst, game_service, game_tilt;
wire       rst96, rst48, rst24;
wire [3:0] gfx_en;
// SDRAM
wire data_rdy, sdram_ack;

// PLL's
wire pll_locked, clk_pico;

`ifndef JTFRAME_STEREO
assign snd_right = snd_left;
`endif

//joysticks
wire [5:0] joy1_bus;
wire [5:0] joy2_bus;

`ifndef MC2
    joystick_serial u_serial(
        .clk_i           ( clk_sys     ),
        .joy_data_i      ( JOY_DATA    ),
        .joy_clk_o       ( JOY_CLK     ),
        .joy_load_o      ( JOY_LOAD    ),

        .joy1_up_o       ( joy1_bus[3] ),
        .joy1_down_o     ( joy1_bus[2] ),
        .joy1_left_o     ( joy1_bus[1] ),
        .joy1_right_o    ( joy1_bus[0] ),
        .joy1_fire1_o    ( joy1_bus[4] ),
        .joy1_fire2_o    ( joy1_bus[5] ),

        .joy2_up_o       ( joy2_bus[3] ),
        .joy2_down_o     ( joy2_bus[2] ),
        .joy2_left_o     ( joy2_bus[1] ),
        .joy2_right_o    ( joy2_bus[0] ),
        .joy2_fire1_o    ( joy2_bus[4] ),
        .joy2_fire2_o    ( joy2_bus[5] )
    );
`else
    assign joy1_bus = JOY1;
    assign joy2_bus = JOY2;
`endif


jtframe_mist_clocks u_clocks(
    .clk_ext    ( CLK50          ),    // 27MHz for MiST, 50MHz for Neptuno

    // PLL outputs
    .clk96      ( clk96          ),
    .clk48      ( clk48          ),
    .clk24      ( clk24          ),
    .pll_locked ( pll_locked     ),

    // System clocks
    .clk_sys    ( clk_sys        ),
    .clk_rom    ( clk_rom        ),
    .SDRAM_CLK  ( SDRAM_CLK      ),

    // reset signals
    .game_rst   ( game_rst       ),
    .rst96      ( rst96          ),
    .rst48      ( rst48          ),
    .rst24      ( rst24          )
);

assign clk_pico = clk48;


wire [7:0] debug_bus, debug_view;
wire [1:0] dip_fxlevel;
wire       enable_fm, enable_psg;
wire       dip_pause, dip_flip, dip_test;
wire       pxl_cen, pxl2_cen;
wire [31:0]dipsw;

`ifdef JTFRAME_DIPBASE
localparam DIPBASE=`JTFRAME_DIPBASE;
`else
localparam DIPBASE=16;
`endif

jtframe_mist #(
    .SDRAMW       ( SDRAMW         ),
    .SIGNED_SND   ( `JTFRAME_SIGNED_SND ),
    .BUTTONS      ( `JTFRAME_BUTTONS    ),
    .DIPBASE      ( DIPBASE        ),
    .COLORW       ( COLORW         )
    `ifdef JTFRAME_WIDTH
    ,.VIDEO_WIDTH ( `JTFRAME_WIDTH   )
    `endif
    `ifdef JTFRAME_HEIGHT
    ,.VIDEO_HEIGHT( `JTFRAME_HEIGHT  )
    `endif
)
u_frame(
    .clk_sys        ( clk_sys        ),
    .clk_rom        ( clk_rom        ),
    .clk_pico       ( clk_pico       ),
    .pll_locked     ( pll_locked     ),
    .status         ( status         ),
    .dipsw          ( dipsw          ),
    // Base video
    .game_r         ( red            ),
    .game_g         ( green          ),
    .game_b         ( blue           ),
    .LHBL           ( LHBL           ),
    .LVBL           ( LVBL           ),
    .hs             ( hs             ),
    .vs             ( vs             ),
    .pxl_cen        ( pxl_cen        ),
    .pxl2_cen       ( pxl2_cen       ),
    // MiST VGA pins
    .VGA_R          ( VGA_R          ),
    .VGA_G          ( VGA_G          ),
    .VGA_B          ( VGA_B          ),
    .VGA_HS         ( VGA_HS         ),
    .VGA_VS         ( VGA_VS         ),
    // SDRAM interface
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
    // SPI interface to arm io controller
    .SPI_DO         ( SPI_DO         ),
    .SPI_DI         ( SPI_DI         ),
    .SPI_SCK        ( SPI_SCK        ),
    .SPI_SS2        ( SPI_SS2        ),

    .joy1_bus       ( joy1_bus       ),
    .joy2_bus       ( joy2_bus       ),

    .JOY_SELECT     ( JOY_SELECT     ),

    .ps2_clk        ( PS2_CLK        ),
    .ps2_dout       ( PS2_DATA       ),

    .BUTTON_n       ( BUTTON_n       ),

    // ROM access from game
    // Bank 0: allows R/W
    .ba0_addr   ( ba0_addr      ),
    .ba1_addr   ( ba1_addr      ),
    .ba2_addr   ( ba2_addr      ),
    .ba3_addr   ( ba3_addr      ),
    .ba_rd      ( ba_rd         ),
    .ba_wr      ( ba_wr         ),
    .ba_dst     ( ba_dst        ),
    .ba_dok     ( ba_dok        ),
    .ba_rdy     ( ba_rdy        ),
    .ba_ack     ( ba_ack        ),
    .ba0_din    ( ba0_din       ),
    .ba0_dsn    ( ba0_dsn       ),
    .ba1_din    ( ba1_din       ),
    .ba1_dsn    ( ba1_dsn       ),
    .ba2_din    ( ba2_din       ),
    .ba2_dsn    ( ba2_dsn       ),
    .ba3_din    ( ba3_din       ),
    .ba3_dsn    ( ba3_dsn       ),

    // ROM-load interface
    .prog_addr  ( prog_addr     ),
    .prog_ba    ( prog_ba       ),
    .prog_rd    ( prog_rd       ),
    .prog_we    ( prog_we       ),
    .prog_data  ( prog_data     ),
    .prog_mask  ( prog_mask     ),
    .prog_ack   ( prog_ack      ),
    .prog_dst   ( prog_dst      ),
    .prog_dok   ( prog_dok      ),
    .prog_rdy   ( prog_rdy      ),

    // ROM load
    .ioctl_addr     ( ioctl_addr     ),
    .ioctl_dout     ( ioctl_dout     ),
    .ioctl_din      ( ioctl_din      ),
    .ioctl_wr       ( ioctl_wr       ),
    .ioctl_ram      ( ioctl_ram      ),
    .ioctl_cart     ( ioctl_cart     ),

    .downloading    ( downloading    ),
    .dwnld_busy     ( dwnld_busy     ),

    .sdram_dout     ( sdram_dout     ),
//////////// board
    .rst            ( rst            ),
    .rst_n          ( rst_n          ), // unused
    .game_rst       ( game_rst       ),
    .game_rst_n     (                ),
    // reset forcing signals:
    .rst_req        ( rst_req        ),
    // Sound
    .snd_left       ( snd_left       ),
    .snd_right      ( snd_right      ),
    .snd_sample     ( sample         ),
    .snd_en         ( snd_en         ),
    .snd_vu         ( snd_vu         ),
    .snd_vol        ( snd_vol        ),
    .snd_peak       ( snd_peak       ),
    .AUDIO_L        ( AUDIO_L        ),
    .AUDIO_R        ( AUDIO_R        ),
    // joystick
    .game_joystick1 ( game_joy1      ),
    .game_joystick2 ( game_joy2      ),
    .game_joystick3 ( game_joy3      ),
    .game_joystick4 ( game_joy4      ),
    .game_coin      ( game_coin      ),
    .game_start     ( game_start     ),
    .game_service   ( game_service   ),
    .game_tilt      ( game_tilt      ),
    .joyana_l1      ( joyana_l1      ),
    .joyana_l2      ( joyana_l2      ),
    .joyana_l3      ( joyana_l3      ),
    .joyana_l4      ( joyana_l4      ),
    .joyana_r1      ( joyana_r1      ),
    .joyana_r2      ( joyana_r2      ),
    .joyana_r3      ( joyana_r3      ),
    .joyana_r4      ( joyana_r4      ),
    .paddle_1       ( paddle_1       ),
    .paddle_2       ( paddle_2       ),
    .paddle_3       ( paddle_3       ),
    .paddle_4       ( paddle_4       ),
    .dial_x         ( dial_x         ),
    .dial_y         ( dial_y         ),
    .LED            ( LED            ),
    // DIP and OSD settings
    .enable_fm      ( enable_fm      ),
    .enable_psg     ( enable_psg     ),
    .dip_test       ( dip_test       ),
    .dip_pause      ( dip_pause      ),
    .dip_flip       ( dip_flip       ),
    .dip_fxlevel    ( dip_fxlevel    ),
    // Debug
    .st_addr        ( st_addr        ),
    .st_dout        ( st_dout        ),
    .gfx_en         ( gfx_en         ),
    .debug_bus      ( debug_bus      ),
    .debug_view     ( debug_view     )
);

wire        game_tx, game_rx;

`include "jtframe_game_instance.v"


`ifdef JTFRAME_LF_BUFFER

    // line-frame buffer
    wire        [ 7:0] game_vrender;
    wire        [ 8:0] game_hdump;
    wire        [ 8:0] ln_addr;
    wire        [15:0] ln_data;
    wire               ln_done;
    wire               ln_we;
    wire               ln_hs;
    wire        [15:0] ln_pxl;
    wire        [ 7:0] ln_v;

    wire [ 7:0] st_lpbuf;

    // this places the pxl1_cen in the pixel centre
    reg pxl1_cen;
    always @(posedge clk_sys) pxl1_cen <= pxl2_cen & ~pxl_cen;

    // line-frame buffer.
    jtframe_lfbuf_sram u_lf_buf(
        .rst        ( rst           ),
        .clk        ( clk_rom       ),
        .pxl_cen    ( pxl1_cen      ),

        .vs         ( vs            ),
        .lvbl       ( LVBL          ),
        .lhbl       ( LHBL          ),
        .vrender    ( game_vrender  ),
        .hdump      ( game_hdump    ),

        // interface with the game core
        .ln_addr    ( ln_addr       ),
        .ln_data    ( ln_data       ),
        .ln_done    ( ln_done       ),
        .ln_hs      ( ln_hs         ),
        .ln_pxl     ( ln_pxl        ),
        .ln_v       ( ln_v          ),
        .ln_we      ( ln_we         ),

        .sram_addr ( SRAM_A         ),
        .sram_data ( SRAM_Q         ),
        .sram_we   ( SRAM_WE        ),	//negative logic

        .st_addr    ( st_addr       ),
        .st_dout    ( st_lpbuf      )
    );
`endif


`ifdef NEPTUNO_PINS
    audio_top u_audio_i2s(
        .clk_50MHz (CLK50           ),
        .dac_SCLK  (I2S_BCLK        ),
        .dac_SDIN  (I2S_DATA        ),
        .dac_LRCK  (I2S_LRCLK       ),
        .L_data    (snd_left        ),
        .R_data    (snd_right       )
    );
`endif


endmodule
