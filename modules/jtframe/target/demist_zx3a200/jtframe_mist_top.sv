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

// This is the MiST top level

module mist_top(
    input   [1:0]   CLOCK_27,
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

    `ifdef VIVADO
    // SPI interface to arm io controller
	input           SPI_DO_IN,
	output          SPI_DO,	
	`else
	inout           SPI_DO,
    `endif
    input           SPI_DI,
    input           SPI_SCK,
    input           SPI_SS2,
    input           SPI_SS3,
    input           SPI_SS4,
    input           CONF_DATA0,
    // UART pins -MIDI extension
    // UART
    input           UART_RX,
    output          UART_TX,
    // sound
    output          AUDIO_L,
    output          AUDIO_R,
    
    `ifdef DEMISTIFY
    output  [15:0]  DAC_L,   
    output  [15:0]  DAC_R,   
    // Joystick
    input [5:0]     JOY1_BUS,
    input [5:0]     JOY2_BUS,
    output          JOY_SELECT,

    output   [5:0]  RED_x,
    output   [5:0]  GREEN_x,
    output   [5:0]  BLUE_x,
    output          HS_x,
	output			VS_x,
    output          VGA_CE,
    output          VGA_CLK,

    output          clk_rom,
    output          rst,

    output  [19:0]  SRAM_A,
    inout   [15:0]  SRAM_Q,
    output          SRAM_WE,
    output          SRAM_OE,
    output          SRAM_UB,
    output          SRAM_LB,

    output          scan2x_enb,      // scan doubler enable bar = scan doubler disable.
    output          scan2x_toggle,
    output          osd_en,
    `endif   

    // user LED
    output          LED
    `ifdef SIMULATION
    ,output         sim_pxl_cen,
    output          sim_pxl_clk,
    output          sim_vb,
    output          sim_hb,
    output          sim_dwnld_busy
    `endif
);

`ifdef DEMISTIFY
	assign DAC_L = snd_left;
	assign DAC_R = snd_right;
`endif   
    
`ifdef JTFRAME_SDRAM_LARGE
    localparam SDRAMW=23; // 64 MB
`else
    localparam SDRAMW=22; // 32 MB
`endif

wire        rst_n, clk_sys, clk6, clk24, clk48, clk96;
wire [63:0] status;
wire [31:0] joystick1, joystick2;
wire [25:0] ioctl_addr;
wire [ 7:0] ioctl_dout, ioctl_din;
wire        ioctl_wr;
wire        ioctl_ram;
wire [ 1:0] dial_x, dial_y;

wire [15:0] joyana_l1, joyana_l2, joyana_l3, joyana_l4,
            joyana_r1, joyana_r2, joyana_r3, joyana_r4;

wire rst_req   = status[0];

// ROM download
wire          ioctl_rom, ioctl_cart, dwnld_busy;

wire [SDRAMW-1:0] prog_addr;
wire [15:0]   prog_data;
`ifndef JTFRAME_SDRAM_BANKS
wire [ 7:0]   prog_data8;
`endif
wire [ 1:0]   prog_mask, prog_ba;
wire          prog_we, prog_rd, prog_rdy, prog_ack, prog_dst, prog_dok;

// ROM access from game
wire [SDRAMW-1:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr;
wire [ 3:0] ba_rd, ba_rdy, ba_ack, ba_dst, ba_dok, ba_wr;
wire [15:0] ba0_din, ba1_din, ba2_din, ba3_din;
wire [ 1:0] ba0_dsn, ba1_dsn, ba2_dsn, ba3_dsn;
wire [15:0] sdram_dout;

localparam COLORW=`JTFRAME_COLORW;

wire [COLORW-1:0] red;
wire [COLORW-1:0] green;
wire [COLORW-1:0] blue;

wire LHBL, LVBL, hs, vs;
wire [15:0] snd_left, snd_right;
wire        sample;

wire [9:0] game_joy1, game_joy2, game_joy3, game_joy4;
wire [3:0] game_coin, game_start;
wire       game_rst, game_service, game_tilt;
wire       rst96, rst48, rst24, rst6;
wire [3:0] gfx_en;
// SDRAM
wire data_rdy, sdram_ack;

// PLL's
wire pll_locked, clk_pico;


`ifdef DEMISTIFY        // HDMI video output with OSD
// include the on screen display
wire [5:0] osd_r_o;
wire [5:0] osd_g_o;
wire [5:0] osd_b_o;
wire       HSync_osd, VSync_osd;

function [5:0] extend_color;
    input [COLORW-1:0] a;
    case( COLORW )
        3: extend_color = { a, a[2:0] };
        4: extend_color = { a, a[3:2] };
        5: extend_color = { a, a[4] };
        6: extend_color = a;
        7: extend_color = a[6:1];
        8: extend_color = a[7:2];
    endcase
endfunction

wire [5:0] game_r6 = extend_color( red );
wire [5:0] game_g6 = extend_color( green );
wire [5:0] game_b6 = extend_color( blue );

osd #(0,0,6'b01_11_01) osd (
   .clk_sys    ( clk_sys      ),

    // spi for OSD
   .SPI_DI     ( SPI_DI       ),
   .SPI_SCK    ( SPI_SCK      ),
   .SPI_SS3    ( SPI_SS3      ),

   .rotate     ( 2'b00        ),    //osd_rotate

   .R_in       ( game_r6      ),
   .G_in       ( game_g6      ),
   .B_in       ( game_b6      ),
   .HSync      ( hs           ),
   .VSync      ( vs           ),

   .R_out      ( osd_r_o      ),
   .G_out      ( osd_g_o      ),
   .B_out      ( osd_b_o      ),
   .HSync_out  ( HSync_osd    ),
   .VSync_out  ( VSync_osd    )
);

assign RED_x     = osd_r_o;
assign GREEN_x   = osd_g_o;
assign BLUE_x    = osd_b_o;
assign HS_x      = HSync_osd;
assign VS_x      = VSync_osd;
assign VGA_CE    = pxl2_cen;
assign VGA_CLK   = clk_sys;    //clk6 (6MHz 320x224@60); pxl2_cen (12MHz 640x224@60); clk_sys (48MHz 2560x224@60);
// assign VGA_DE    = LHBL & LVBL;

// //// without OSD
// assign RED_x     = game_r6;
// assign GREEN_x   = game_g6;
// assign BLUE_x    = game_b6;
// assign HS_x      = hs;
// assign VS_x      = vs;
// assign VGA_CE    = pxl2_cen;    //pxl_cen
// assign VGA_CLK   = clk_sys;     //clk6 (6MHz 320x224@60); pxl2_cen (12MHz 640x224@60); clk_sys (48MHz 2560x224@60);
// // assign VGA_DE = LHBL & LVBL;

`endif   


// `ifdef DEMISTIFY        // HDMI video output with OSD

// wire [7:0]    scan2x_r, scan2x_g, scan2x_b;
// wire          scan2x_hs, scan2x_vs, scan2x_clk, scan2x_de;

// assign RED_x     = scan2x_r;
// assign GREEN_x   = scan2x_g;
// assign BLUE_x    = scan2x_b;
// assign HS_x      = scan2x_hs;
// assign VS_x      = scan2x_vs;
// assign VGA_CE    = pxl2_cen;        //KO: 1, pxl2_cen, pxl_cen
// assign VGA_CLK   = clk_sys;         //scan2x_clk
// assign VGA_DE    = scan2x_de;

// `endif   



`ifndef JTFRAME_STEREO
    assign snd_right = snd_left;
`endif

`ifndef JTFRAME_SDRAM_BANKS
    assign prog_data = {2{prog_data8}};
    assign ba_rd[3:1] = 0;
    assign ba_wr      = 0;
    assign prog_ba    = 0;
    // tie down unused bank signals
    assign ba1_addr   = 0;
    assign ba2_addr   = 0;
    assign ba3_addr   = 0;
    assign ba0_din    = 0;
    assign ba0_dsn    = 3;
    assign ba1_din    = 0;
    assign ba1_dsn    = 3;
    assign ba2_din    = 0;
    assign ba2_dsn    = 3;
    assign ba3_din    = 0;
    assign ba3_dsn    = 3;
`endif

jtframe_mist_clocks u_clocks(
    .clk_ext    ( CLOCK_27[0]    ),    // 27MHz for MiST, 50MHz for ZXtres

    // PLL outputs
    .clk96      ( clk96          ),
    .clk48      ( clk48          ),
    .clk24      ( clk24          ),
    .clk6       ( clk6           ),
    .pll_locked ( pll_locked     ),

    // System clocks
    .clk_sys    ( clk_sys        ),
    .clk_rom    ( clk_rom        ),
    .SDRAM_CLK  ( SDRAM_CLK      ),

    // reset signals
    .game_rst   ( game_rst       ),
    .rst96      ( rst96          ),
    .rst48      ( rst48          ),
    .rst24      ( rst24          ),
    .rst6       ( rst6           )
);

assign clk_pico = clk48;

wire [ 7:0] debug_bus, debug_view;
wire [ 1:0] dip_fxlevel, game_led;
wire        enable_fm, enable_psg;
wire        dip_pause, dip_flip, dip_test;
wire        pxl_cen, pxl2_cen;
wire [ 7:0] st_addr, st_dout;
wire [ 7:0] paddle_1, paddle_2, paddle_3, paddle_4;
wire [15:0] mouse_1p, mouse_2p;
wire [31:0] dipsw;

`ifdef JTFRAME_DIPBASE
localparam DIPBASE=`JTFRAME_DIPBASE;
`else
localparam DIPBASE=16;
`endif

assign game_led[1] = 1'b0; // Let system LED info go through too

jtframe_mist #(
    .SDRAMW       ( SDRAMW         ),
    .SIGNED_SND   ( `JTFRAME_SIGNED_SND    ),
    .BUTTONS      ( `JTFRAME_BUTTONS  ),
    .DIPBASE      ( DIPBASE        ),
    .COLORW       ( COLORW         ),
    .VIDEO_WIDTH  ( `JTFRAME_WIDTH ),
    .VIDEO_HEIGHT ( `JTFRAME_HEIGHT)
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
    // LED
    .game_led       ( game_led       ),
    // UART
`ifndef JTFRAME_UART
    .uart_rx        ( UART_RX        ),
    .uart_tx        ( UART_TX        ),
`else
    .uart_rx        ( 1'b1           ),
    .uart_tx        (                ),
`endif
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
    `ifdef VIVADO
	.SPI_DO_IN      ( SPI_DO_IN      ),
	.SPI_DO         ( SPI_DO         ),	
	`else
    .SPI_DO         ( SPI_DO         ),
    `endif
    .SPI_DI         ( SPI_DI         ),
    .SPI_SCK        ( SPI_SCK        ),
    .SPI_SS2        ( SPI_SS2        ),
    .SPI_SS3        ( SPI_SS3        ),
    .SPI_SS4        ( SPI_SS4        ),
    .CONF_DATA0     ( CONF_DATA0     ),

    // ROM access from game
    .ba0_addr   ( ba0_addr      ), .ba1_addr   ( ba1_addr      ),
    .ba2_addr   ( ba2_addr      ), .ba3_addr   ( ba3_addr      ),
    .ba_rd      ( ba_rd         ), .ba_wr      ( ba_wr         ),
    .ba_dst     ( ba_dst        ), .ba_dok     ( ba_dok        ),
    .ba_rdy     ( ba_rdy        ), .ba_ack     ( ba_ack        ),
    .ba0_din    ( ba0_din       ), .ba0_dsn    ( ba0_dsn       ),
    .ba1_din    ( ba1_din       ), .ba1_dsn    ( ba1_dsn       ),
    .ba2_din    ( ba2_din       ), .ba2_dsn    ( ba2_dsn       ),
    .ba3_din    ( ba3_din       ), .ba3_dsn    ( ba3_dsn       ),

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

    .ioctl_rom      ( ioctl_rom      ),
    .ioctl_cart     ( ioctl_cart     ),
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
    // Paddle inputs
    .paddle_1       ( paddle_1       ),
    .paddle_2       ( paddle_2       ),
    .paddle_3       ( paddle_3       ),
    .paddle_4       ( paddle_4       ),
    // Mouse inputs
    .mouse_1p       ( mouse_1p       ),
    .mouse_2p       ( mouse_2p       ),
    .LED            ( LED            ),
    // Dial emulation
    .dial_x         ( dial_x         ),
    .dial_y         ( dial_y         ),
    // Unused in MiST
    .BUTTON_n       ( 4'hf           ),
    .ps2_clk        (                ),
    .ps2_dout       (                ),
	`ifdef DEMISTIFY
    .joy1_bus       ( JOY1_BUS       ),
    .joy2_bus       ( JOY2_BUS       ),
    .JOY_SELECT     ( JOY_SELECT     ),
    .scan2x_enb     ( scan2x_enb     ),
    .scan2x_toggle  ( scan2x_toggle  ),        

    .scan2x_r       ( scan2x_r       ),
    .scan2x_g       ( scan2x_g       ), 
    .scan2x_b       ( scan2x_b       ),
    .scan2x_hs      ( scan2x_hs      ),
    .scan2x_vs      ( scan2x_vs      ),
    .scan2x_clk     ( scan2x_clk     ),
    .scan2x_de      ( scan2x_de      ),

    .osd_en         ( osd_en         ),
	`endif   
    // DIP and OSD settings
    .enable_fm      ( enable_fm      ),
    .enable_psg     ( enable_psg     ),
    .dip_test       ( dip_test       ),
    .dip_pause      ( dip_pause      ),
    .dip_flip       ( dip_flip       ),
    .dip_fxlevel    ( dip_fxlevel    ),
    // status
    .st_addr        ( st_addr        ),
    .st_dout        ( st_dout        ),
    // Debug
    .gfx_en         ( gfx_en         ),
    .debug_bus      ( debug_bus      ),
    .debug_view     ( debug_view     )
);

wire        game_tx, game_rx;

`ifdef JTFRAME_UART
assign UART_TX = game_tx,
       game_rx = UART_RX;
`endif

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

    assign SRAM_OE = 1'b0;
    assign SRAM_UB = 1'b0;
    assign SRAM_LB = 1'b0;
`else
    //no SRAM for this core
    assign SRAM_A = 21'd0;
    assign SRAM_Q = 16'bZ;
    assign SRAM_WE = 1'b1;
    assign SRAM_OE = 1'b1;
    assign SRAM_UB = 1'b1;
    assign SRAM_LB = 1'b1;
`endif



endmodule
