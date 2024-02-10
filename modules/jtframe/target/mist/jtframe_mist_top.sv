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
    input    [1:0]  CLOCK_27,

    output          LED,
    output   [VGA_BITS-1:0] VGA_R,
    output   [VGA_BITS-1:0] VGA_G,
    output   [VGA_BITS-1:0] VGA_B,
    output          VGA_HS,
    output          VGA_VS,

`ifdef USE_HDMI
    output          HDMI_RST,
    output    [7:0] HDMI_R,
    output    [7:0] HDMI_G,
    output    [7:0] HDMI_B,
    output          HDMI_HS,
    output          HDMI_VS,
    output          HDMI_PCLK,
    output          HDMI_DE,
    inout           HDMI_SDA,
    inout           HDMI_SCL,
    input           HDMI_INT,
`endif

    input           SPI_SCK,
    inout           SPI_DO,
    input           SPI_DI,
    input           SPI_SS2,
    input           SPI_SS3,
    input           CONF_DATA0,

    `ifdef USE_QSPI
    input           QSCK,
    input           QCSn,
    inout     [3:0] QDAT,
    `endif
    `ifndef NO_DIRECT_UPLOAD
    input           SPI_SS4,
    `endif

    output   [12:0] SDRAM_A,
    inout    [15:0] SDRAM_DQ,
    output          SDRAM_DQML,
    output          SDRAM_DQMH,
    output          SDRAM_nWE,
    output          SDRAM_nCAS,
    output          SDRAM_nRAS,
    output          SDRAM_nCS,
    output    [1:0] SDRAM_BA,
    output          SDRAM_CLK,
    output          SDRAM_CKE,

    `ifdef DUAL_SDRAM
    output   [12:0] SDRAM2_A,
    inout    [15:0] SDRAM2_DQ,
    output          SDRAM2_DQML,
    output          SDRAM2_DQMH,
    output          SDRAM2_nWE,
    output          SDRAM2_nCAS,
    output          SDRAM2_nRAS,
    output          SDRAM2_nCS,
    output    [1:0] SDRAM2_BA,
    output          SDRAM2_CLK,
    output          SDRAM2_CKE,
    `endif

    output          AUDIO_L,
    output          AUDIO_R,
    `ifdef I2S_AUDIO
    output          I2S_BCK,
    output          I2S_LRCK,
    output          I2S_DATA,
    `endif
    `ifdef I2S_AUDIO_HDMI
    output          HDMI_MCLK,
    output          HDMI_BCK,
    output          HDMI_LRCK,
    output          HDMI_SDATA,
    `endif
    `ifdef SPDIF_AUDIO
    output          SPDIF,
    `endif

    input           UART_RX,
    output          UART_TX

    `ifdef SIMULATION
    ,output         sim_pxl_cen,
    output          sim_pxl_clk,
    output          sim_vb,
    output          sim_hb,
    output          sim_dwnld_busy
    `endif

);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
assign HDMI_RST = 1'b1;
localparam bit HDMI = 1;
`else
localparam bit HDMI = 0;
`endif

// remove this if the 2nd chip is actually used
`ifdef DUAL_SDRAM
assign SDRAM2_A = 13'hZZZZ;
assign SDRAM2_BA = 0;
assign SDRAM2_DQML = 0;
assign SDRAM2_DQMH = 0;
assign SDRAM2_CKE = 0;
assign SDRAM2_CLK = 0;
assign SDRAM2_nCS = 1;
assign SDRAM2_DQ = 16'hZZZZ;
assign SDRAM2_nCAS = 1;
assign SDRAM2_nRAS = 1;
assign SDRAM2_nWE = 1;
`endif

`ifdef JTFRAME_SDRAM_LARGE
    localparam SDRAMW=23; // 64 MB
`else
    localparam SDRAMW=22; // 32 MB
`endif

wire        rst, rst_n, clk_sys, clk_rom, clk6, clk24, clk48, clk96;
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
    .clk_ext    ( CLOCK_27[0]    ),    // 27MHz for MiST, 50MHz for Neptuno

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

`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_sys) begin
    HDMI_BCK <= I2S_BCK;
    HDMI_LRCK <= I2S_LRCK;
    HDMI_SDATA <= I2S_DATA;
end
`endif

jtframe_mist #(
    .SDRAMW       ( SDRAMW         ),
    .SIGNED_SND   ( `JTFRAME_SIGNED_SND    ),
    .BUTTONS      ( `JTFRAME_BUTTONS  ),
    .DIPBASE      ( DIPBASE        ),
    .COLORW       ( COLORW         ),
    .VIDEO_WIDTH  ( `JTFRAME_WIDTH ),
    .VIDEO_HEIGHT ( `JTFRAME_HEIGHT),
    .VGA_BITS     ( VGA_BITS       ),
    .QSPI         ( QSPI           ),
    .HDMI         ( HDMI           )
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
    // HDMI pins
`ifdef USE_HDMI
    .HDMI_R         ( HDMI_R         ),
    .HDMI_G         ( HDMI_G         ),
    .HDMI_B         ( HDMI_B         ),
    .HDMI_HS        ( HDMI_HS        ),
    .HDMI_VS        ( HDMI_VS        ),
    .HDMI_PCLK      ( HDMI_PCLK      ),
    .HDMI_DE        ( HDMI_DE        ),
    .HDMI_SDA       ( HDMI_SDA       ),
    .HDMI_SCL       ( HDMI_SCL       ),
`else
    .HDMI_R         (                ),
    .HDMI_G         (                ),
    .HDMI_B         (                ),
    .HDMI_HS        (                ),
    .HDMI_VS        (                ),
    .HDMI_PCLK      (                ),
    .HDMI_DE        (                ),
    .HDMI_SDA       (                ),
    .HDMI_SCL       (                ),
`endif
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
    .SPI_DO         ( SPI_DO         ),
    .SPI_DI         ( SPI_DI         ),
    .SPI_SCK        ( SPI_SCK        ),
    .SPI_SS2        ( SPI_SS2        ),
    .SPI_SS3        ( SPI_SS3        ),
    .SPI_SS4        ( SPI_SS4        ),
    .CONF_DATA0     ( CONF_DATA0     ),
    `ifdef USE_QSPI
    .QSCK           ( QSCK           ),
    .QCSn           ( QCSn           ),
    .QDAT           ( QDAT           ),
    `else
    .QSCK           ( 1'b0           ),
    .QCSn           ( 1'b1           ),
    .QDAT           ( 4'h0           ),
    `endif
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
    `ifdef I2S_AUDIO
    .I2S_BCK        ( I2S_BCK        ),
    .I2S_LRCK       ( I2S_LRCK       ),
    .I2S_DATA       ( I2S_DATA       ),
    `else
    .I2S_BCK        (                ),
    .I2S_LRCK       (                ),
    .I2S_DATA       (                ),
    `endif
    `ifdef SPDIF_AUDIO
    .SPDIF          ( SPDIF          ),
    `else
    .SPDIF          (                ),
    `endif
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
    .joy1_bus       (                ),
    .joy2_bus       (                ),
    .JOY_SELECT     (                ),
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
    jtframe_lfbuf_bram u_lf_buf(
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

        .st_addr    ( st_addr       ),
        .st_dout    ( st_lpbuf      )
    );
`endif

endmodule
