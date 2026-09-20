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
    Date: 6-8-2022 */

module jtframe_pocket #(parameter
    SIGNED_SND             = 1'b0,
    BUTTONS                = 2,
    GAME_INPUTS_ACTIVE_LOW = 1'b1,
    COLORW                 = 4,
    VIDEO_WIDTH            = 384,
    VIDEO_HEIGHT           = 224,
    SDRAMW                 = 23
)(
    input               clk_74a,
    input               clk_sys,
    input               clk_rom,
    input               clk48,
    input               clk_pico,
    input               pll_locked,
    output              rst_req,
    // interface with microcontroller
    output      [63:0]  status,
    output      [31:0]  dipsw,
    // Base video
    input  [COLORW-1:0] game_r, game_g, game_b,
    input               LHBL,
    input               LVBL,
    input               hs,
    input               vs,
    inout               pxl_cen,
    inout               pxl2_cen,
    // Bridge Connection
    inout               spi_clk,
    inout         [1:0] spi_dio,
    input               spi_ss,
    // Pocket video output
    output       [11:0] scal_vid,
    output              scal_clk,
    output              scal_de,
    output              scal_skip,
    output              scal_vs,
    output              scal_hs,
    // ROM programming
    input  [SDRAMW-1:0] prog_addr,
    input        [15:0] prog_data,
    input        [ 1:0] prog_mask,
    input        [ 1:0] prog_ba,
    input               prog_we,
    input               prog_rd,
    output              prog_dst,
    output              prog_dok,
    output              prog_rdy,
    output              prog_ack,
    // ROM access from game
    input  [SDRAMW-1:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr,
`ifdef JTFRAME_SDRAM_CACHE
    input  [SDRAMW-1:0] burst_addr,
    input         [1:0] burst_ba,
    input               burst_rd, burst_wr,
    output              burst_ack, burst_dst, burst_dok, burst_rdy,
`endif
    input         [3:0] ba_rd,    ba_wr,
    output        [3:0] ba_ack,   ba_rdy,   ba_dst,   ba_dok,
    input        [15:0] ba0_din,  ba1_din,  ba2_din,  ba3_din,
    input        [ 1:0] ba0_dsn,  ba1_dsn,  ba2_dsn,  ba3_dsn,
`ifdef JTFRAME_SDRAM_CACHE
    input        [15:0] burst_din,
`endif
    output       [15:0] sdram_dout,
    // SDRAM interface
    inout    [15:0] SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output   [12:0] SDRAM_A,        // SDRAM Address bus 13 Bits
    output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output    [1:0] SDRAM_BA,       // SDRAM Bank Address
    output          SDRAM_CKE,      // SDRAM Clock Enable
    // Pocket inputs
    inout           bridge_1wire,
    // ROM load from SPI
    output reg [25:0] ioctl_addr,
    output reg [ 7:0] ioctl_dout,
    output reg      ioctl_wr,
    input    [ 7:0] ioctl_din,
    output reg      ioctl_ram,
    input           dwnld_busy,
    output          ioctl_rom,
    output          ioctl_cart,

    // Line-Frame buffer
    input    [`JTFRAME_LF_VW-1:0] game_vrender,
    input    [`JTFRAME_LF_HW-1:0] game_hdump,
`ifdef JTFRAME_LF_ZOOM
    input    [ 8:0] game_h_step, game_v_step,
`endif
    input    [`JTFRAME_LF_HW-1:0] ln_addr,
    input    [15:0] ln_data,
    input           ln_done,
    output          ln_hs, ln_vs, ln_lvbl,
    output   [15:0] ln_dout,
    output   [15:0] ln_pxl,
    output   [`JTFRAME_LF_VW-1:0] ln_v,
    input           ln_we,
    input           fb_keep,
    // PSRAM chip
    output  [21:16] cr_addr,
    inout    [15:0] cr_adq,
    output          cr_advn,
    output   [ 1:0] cr_cen,
    output          cr_clk,
    output          cr_cre,
    output   [ 1:0] cr_dsn,
    output          cr_oen,
    input           cr_wait,
    output          cr_wen,
    // SRAM
    output    [16:0]  sram_a,
    inout     [15:0]  sram_dq,
    output            sram_oe_n,
    output            sram_we_n,
    output            sram_ub_n,
    output            sram_lb_n,

    input     [16:0]  sram_addr,
    input     [15:0]  sram_din,
    output    [15:0]  sram_dout,
    input             sram_wen,
    input             sram_dsn,
    output            sram_ok,
    // Analog Video Output
    output    [ 7:0]  cart3_vid, cart2_vid,
    output    [ 4:0]  cart1_vid,
    output            cart1_vdir, cart2_vdir, cart3_vdir,
    output    [23:0]  yc_vid,
    output    [ 1:0]  anv_en,
    output            yc_en,
    // SNAC Controller inputs
    input     [15:0]  snac_p1, snac_p2, snac_p3, snac_p4,
    output    [ 7:0]  snac_cfg,
//////////// board
    output          rst,      // synchronous reset
    output          rst_n,    // asynchronous reset
    output          game_rst,
    output          game_rst_n,
    // Sound
    input   [15:0]  snd_left,
    input   [15:0]  snd_right,
    input           snd_sample,
    input           snd_peak,
    output  [ 5:0]  snd_en,
    input   [ 5:0]  snd_vu,
    output  [ 7:0]  snd_vol,

    output          audio_mclk,
    output          audio_dac,
    output          audio_lrck,
    // joystick
    output   [9:0]  game_joystick1, game_joystick2, game_joystick3, game_joystick4,
    output   [3:0]  coin, game_start,
    output          game_service,
    output          game_tilt,
    output  [15:0]  joyana_l1, joyana_r1, joyana_l2, joyana_r2, joyana_l3, joyana_r3, joyana_l4, joyana_r4,
    // Paddle
    output  [ 7:0]  paddle_1,  paddle_2,  paddle_3,  paddle_4,
    // Mouse
    output  [15:0]  mouse_1p,  mouse_2p,
    output  [ 1:0]  mouse_strobe,
    // Lightguns
    output  [ 8:0]  gun_1p_x, gun_1p_y, gun_2p_x, gun_2p_y,
    // Dial
    output  [ 1:0]  dial_x,    dial_y,
    // DIP and OSD settings
    output          dip_test,
    // non standard:
    output          dip_pause,
    inout           dip_flip,     // A change in dip_flip implies a reset
    output  [ 1:0]  dip_fxlevel,
    // Debug
    output   [ 7:0] st_addr,
    input    [ 7:0] st_dout,
    output   [3:0]  gfx_en,
    output   [7:0]  debug_bus,
    input    [7:0]  debug_view
);

// control
wire [15:0]   joystick1, joystick2, joystick3, joystick4;
reg  [63:0]   board_status;
wire          ps2_kbd_clk, ps2_kbd_data;
wire          osd_shown;

wire [ 7:0]   game_vol;
wire [17:0]   core_mod;
wire [ 3:0]   but_start, but_coin;

wire [ 1:0]   rotate, black_frame;
wire          ioctl_cheat, ioctl_lock, sdram_init;

wire  [15:0]  board_left, board_right;

wire  [ 8:0]  bd_mouse_dx, bd_mouse_dy;
wire          bd_mouse_st, bd_mouse_idx;
wire  [ 7:0]  bd_mouse_f;

wire [3*COLORW-1:0] base_rgb;
wire base_LHBL, base_LVBL, base_hs, base_vs;

wire [ 7:0]  st_target;
wire [25:0]  pre_io_addr;
wire [ 7:0]  pre_io_dout;
wire         pre_io_wr, pre_io_ram;

assign paddle_3 = 0, paddle_4 = 0;

`ifdef JTFRAME_SRAM
    jtframe_pocket_sram u_sram(
        .clk        ( clk48         ),
        // core
        .addr       ( sram_addr     ),
        .din        ( sram_din      ),
        .dout       ( sram_dout     ),
        .wen        ( sram_wen      ),
        .dsn        ( sram_dsn      ),
        .ok         ( sram_ok       ),
        // Pins
        .pin_a      ( sram_a        ),
        .pin_dq     ( sram_dq       ),
        .pin_oe_n   ( sram_oe_n     ),
        .pin_we_n   ( sram_we_n     ),
        .pin_ub_n   ( sram_ub_n     ),
        .pin_lb_n   ( sram_lb_n     )
    );
`else
    assign sram_dout = 0;
    assign sram_ok   = 0;
    assign sram_a    = 0;
    assign sram_dq   = 0;
    assign sram_oe_n = 1;
    assign sram_we_n = 1;
    assign sram_ub_n = 1;
    assign sram_lb_n = 1;
`endif

// This is required for JTCPS1 so timing is met at 96MHz
// Out Run didn't seem to need it at 96MHz though
always @(posedge clk_rom) begin
    ioctl_addr <= pre_io_addr;
    ioctl_dout <= pre_io_dout;
    ioctl_wr   <= pre_io_wr;
    ioctl_ram  <= pre_io_ram;
end

jtframe_pocket_base #(
    .SIGNED_SND     ( SIGNED_SND    ),
    .COLORW         ( COLORW        )
) u_base(
    .rst            ( rst           ),
    .rst_req        ( rst_req       ),
    .sdram_init     ( sdram_init    ),
    .clk_74a        ( clk_74a       ),
    .clk_sys        ( clk_sys       ),
    .clk_rom        ( clk_rom       ),
    .clk48          ( clk48         ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .core_mod       ( core_mod      ),
    .black_frame    ( black_frame   ),
    .dipsw          ( dipsw         ),
    .osd_shown      ( osd_shown     ),
    .rotate         ( rotate        ),
    // Track SDRAM activity
    .prog_we        ( prog_we       ),
    .prog_rdy       ( prog_rdy      ),
    // System communication
    .spi_ss         ( spi_ss        ),
    .spi_dio        ( spi_dio       ),
    .spi_clk        ( spi_clk       ),
    // audio
    .game_vol       ( game_vol      ),
    .snd_sample     ( snd_sample    ),
    .snd_left       ( board_left    ),
    .snd_right      ( board_right   ),

    .audio_mclk     ( audio_mclk    ),
    .audio_dac      ( audio_dac     ),
    .audio_lrck     ( audio_lrck    ),
    // Video after OSD, credits and debugger
    .base_rgb       ( base_rgb      ),
    .base_LHBL      ( base_LHBL     ),
    .base_LVBL      ( base_LVBL     ),
    .base_hs        ( base_hs       ),
    .base_vs        ( base_vs       ),
    .game_r         ( game_r        ),
    .game_g         ( game_g        ),
    .game_b         ( game_b        ),
    // Pocket Video pins
    .scal_vid       ( scal_vid      ),
    .scal_clk       ( scal_clk      ),
    .scal_de        ( scal_de       ),
    .scal_skip      ( scal_skip     ),
    .scal_vs        ( scal_vs       ),
    .scal_hs        ( scal_hs       ),
    // control
    .status         ( status        ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .joystick4      ( joystick4     ),
    .but_start      ( but_start     ),
    .but_coin       ( but_coin      ),
    // Mouse
    .mouse_dy       ( bd_mouse_dy   ),
    .mouse_dx       ( bd_mouse_dx   ),
    .mouse_f        ( bd_mouse_f    ),
    .mouse_idx      ( bd_mouse_idx  ),
    .mouse_st       ( bd_mouse_st   ),
    // Analog joystick
    .joyana_l1      ( joyana_l1     ),
    .joyana_r1      ( joyana_r1     ),
    .joyana_l2      ( joyana_l2     ),
    .joyana_r2      ( joyana_r2     ),
    .joyana_l3      ( joyana_l3     ),
    .joyana_r3      ( joyana_r3     ),
    .joyana_l4      ( joyana_l4     ),
    .joyana_r4      ( joyana_r4     ),
    // Pocket inputs
    .bridge_1wire   ( bridge_1wire  ),
    // line-frame buffer
    .game_vrender   ( game_vrender  ),
    .game_hdump     ( game_hdump    ),
`ifdef JTFRAME_LF_ZOOM
    .game_h_step    ( game_h_step   ),
    .game_v_step    ( game_v_step   ),
`endif
    .ln_addr        ( ln_addr       ),
    .ln_data        ( ln_data       ),
    .ln_done        ( ln_done       ),
    .ln_hs          ( ln_hs         ),
    .ln_dout        ( ln_dout       ),
    .ln_pxl         ( ln_pxl        ),
    .ln_v           ( ln_v          ),
    .ln_vs          ( ln_vs         ),
    .ln_lvbl        ( ln_lvbl       ),
    .ln_we          ( ln_we         ),
    .fb_keep        ( fb_keep       ),
    // PSRAM chip
    .cr_addr        ( cr_addr       ),
    .cr_adq         ( cr_adq        ),
    .cr_advn        ( cr_advn       ),
    .cr_cen         ( cr_cen        ),
    .cr_clk         ( cr_clk        ),
    .cr_cre         ( cr_cre        ),
    .cr_dsn         ( cr_dsn        ),
    .cr_oen         ( cr_oen        ),
    .cr_wait        ( cr_wait       ),
    .cr_wen         ( cr_wen        ),
    // ROM load from SPI
    .ioctl_addr     ( pre_io_addr   ),
    .ioctl_dout     ( pre_io_dout   ),
    .ioctl_din      ( ioctl_din     ),
    .ioctl_wr       ( pre_io_wr     ),
    .ioctl_ram      ( pre_io_ram    ),
    .ioctl_lock     ( ioctl_lock    ),
    .ioctl_cheat    ( ioctl_cheat   ),
    .ioctl_rom      ( ioctl_rom     ),
    .ioctl_cart     ( ioctl_cart    ),
    .st_addr        ( st_addr       ),
    .st_dout        ( st_target     ),
    .debug_bus      ( debug_bus     ),
    // Analog Video Output
    .cart3_vid      ( cart3_vid     ),
    .cart2_vid      ( cart2_vid     ),
    .cart1_vid      ( cart1_vid     ),
    .cart1_vdir     ( cart1_vdir    ),
    .cart2_vdir     ( cart2_vdir    ),
    .cart3_vdir     ( cart3_vdir    ),
    .yc_vid         ( yc_vid        ),
    .yc_en          ( yc_en         ),
    .anv_en         ( anv_en        ),
    .ps2_clk        ( ps2_kbd_clk   ),
    .ps2_data       ( ps2_kbd_data  ),

    // SNAC Controller inputs
    .snac_cfg       ( snac_cfg      ),
    .snac_p1        ( snac_p1       ),
    .snac_p2        ( snac_p2       ),
    .snac_p3        ( snac_p3       ),
    .snac_p4        ( snac_p4       )
);

jtframe_board #(
    .BUTTONS               ( BUTTONS               ),
    .GAME_INPUTS_ACTIVE_LOW( GAME_INPUTS_ACTIVE_LOW),
    .COLORW                ( COLORW                ),
    .VIDEO_WIDTH           ( VIDEO_WIDTH           ),
    .VIDEO_HEIGHT          ( VIDEO_HEIGHT          ),
    .SDRAMW                ( SDRAMW                ),
    .MISTER                ( 0                     )
) u_board(
    .rst            ( rst             ),
    .rst_n          ( rst_n           ),
    .game_rst       ( game_rst        ),
    .game_rst_n     ( game_rst_n      ),
    .rst_req        ( rst_req         ),
    .sdram_init     ( sdram_init      ),
    .pll_locked     ( pll_locked      ),
    .ioctl_cart     ( ioctl_cart      ),
    .ioctl_ram      ( ioctl_ram       ),
    .dwnld_busy     ( dwnld_busy      ), // use busy signal from game module

    .clk_sys        ( clk_sys         ),
    .clk_rom        ( clk_rom         ),
    .clk_pico       ( clk_pico        ),
    .core_mod       ( core_mod        ),
    .game_vol       ( game_vol        ),
    .black_frame    ( black_frame     ),
    // Sound
    .snd_lin        ( snd_left        ),
    .snd_rin        ( snd_right       ),
    .snd_lout       ( board_left      ),
    .snd_rout       ( board_right     ),
    .snd_sample     ( snd_sample      ),
    .snd_en         ( snd_en          ),
    .snd_vu         ( snd_vu          ),
    .snd_vol        ( snd_vol         ),
    .snd_peak       ( snd_peak        ),
    // joystick
    .ps2_kbd_clk    ( ps2_kbd_clk     ),
    .ps2_kbd_data   ( ps2_kbd_data    ),
    .board_joystick1( joystick1       ),
    .board_joystick2( joystick2       ),
    .board_joystick3( joystick3       ),
    .board_joystick4( joystick4       ),
    .joyana_l1      ( joyana_l1       ),
    .joyana_r1      ( joyana_r1       ),
    .joyana_l2      ( joyana_l2       ),
    .joyana_r2      ( joyana_r2       ),
    .board_start    ( but_start       ),
    .board_coin     ( but_coin        ),

    .game_joystick1 ( game_joystick1  ),
    .game_joystick2 ( game_joystick2  ),
    .game_joystick3 ( game_joystick3  ),
    .game_joystick4 ( game_joystick4  ),
    .game_coin      ( coin            ),
    .game_start     ( game_start      ),
    .game_service   ( game_service    ),
    .game_tilt      ( game_tilt       ),
    .dial_x         ( dial_x          ),
    .dial_y         ( dial_y          ),
    // Mouse & paddle
    .bd_mouse_dx    ( bd_mouse_dx     ),
    .bd_mouse_dy    ( bd_mouse_dy     ),
    .bd_mouse_st    ( bd_mouse_st     ),
    .bd_mouse_f     ( bd_mouse_f      ),
    .bd_mouse_idx   ( bd_mouse_idx    ),

    .board_paddle_1 ( 8'd0            ),
    .board_paddle_2 ( 8'd0            ),
    .game_paddle_1  ( paddle_1        ),
    .game_paddle_2  ( paddle_2        ),
    .mouse_1p       ( mouse_1p        ),
    .mouse_2p       ( mouse_2p        ),
    .mouse_strobe   ( mouse_strobe    ),
    // Lightguns
    .gun_1p_x       ( gun_1p_x        ),
    .gun_1p_y       ( gun_1p_y        ),
    .gun_2p_x       ( gun_2p_x        ),
    .gun_2p_y       ( gun_2p_y        ),
    // DIP and OSD settings
    .status         ( status          ),
    .dipsw          ( dipsw           ),
    .dip_test       ( dip_test        ),
    .dip_pause      ( dip_pause       ),
    .dip_flip       ( dip_flip        ),
    .dip_fxlevel    ( dip_fxlevel     ),
    .timestamp      ( 32'd0           ), // MiST doesn't -normally- have a RTC
    // screen
    .rotate         ( rotate          ),
    // LED
    .osd_shown      ( osd_shown       ),
    .led            (                 ),
    // UART
    .uart_rx        ( 1'b0            ),
    .uart_tx        (                 ),
    // SDRAM interface
    // Bank 0: allows R/W
    .ba0_addr       ( ba0_addr        ),
    .ba1_addr       ( ba1_addr        ),
    .ba2_addr       ( ba2_addr        ),
    .ba3_addr       ( ba3_addr        ),
`ifdef JTFRAME_SDRAM_CACHE
    .burst_addr     ( burst_addr      ),
    .burst_ba       ( burst_ba        ),
    .burst_rd       ( burst_rd        ),
    .burst_wr       ( burst_wr        ),
    .burst_ack      ( burst_ack       ),
    .burst_dst      ( burst_dst       ),
    .burst_dok      ( burst_dok       ),
    .burst_rdy      ( burst_rdy       ),
`endif
    .ba_rd          ( ba_rd           ),
    .ba_wr          ( ba_wr           ),
    .ba_dst         ( ba_dst          ),
    .ba_dok         ( ba_dok          ),
    .ba_rdy         ( ba_rdy          ),
    .ba_ack         ( ba_ack          ),
    .ba0_din        ( ba0_din         ),
    .ba0_dsn        ( ba0_dsn         ),
    .ba1_din        ( ba1_din         ),
    .ba1_dsn        ( ba1_dsn         ),
    .ba2_din        ( ba2_din         ),
    .ba2_dsn        ( ba2_dsn         ),
    .ba3_din        ( ba3_din         ),
    .ba3_dsn        ( ba3_dsn         ),
`ifdef JTFRAME_SDRAM_CACHE
    .burst_din      ( burst_din       ),
`endif

    // ROM-load interface
    .prog_addr  ( prog_addr     ),
    .prog_ba    ( prog_ba       ),
    .prog_rd    ( prog_rd       ),
    .prog_we    ( prog_we       ),
    .prog_data  ( prog_data     ),
    .prog_dsn   ( prog_mask     ),
    .prog_rdy   ( prog_rdy      ),
    .prog_dst   ( prog_dst      ),
    .prog_dok   ( prog_dok      ),
    .prog_ack   ( prog_ack      ),
    // SDRAM interface
    .SDRAM_DQ   ( SDRAM_DQ      ),
    .SDRAM_A    ( SDRAM_A       ),
    .SDRAM_DQML ( SDRAM_DQML    ),
    .SDRAM_DQMH ( SDRAM_DQMH    ),
    .SDRAM_nWE  ( SDRAM_nWE     ),
    .SDRAM_nCAS ( SDRAM_nCAS    ),
    .SDRAM_nRAS ( SDRAM_nRAS    ),
    .SDRAM_nCS  ( SDRAM_nCS     ),
    .SDRAM_BA   ( SDRAM_BA      ),
    .SDRAM_CKE  ( SDRAM_CKE     ),

    // Common signals
    .sdram_dout ( sdram_dout    ),

    // Cheat!
    .cheat          ( status[63:32]   ),
    .prog_cheat     ( ioctl_cheat     ),
    .prog_lock      ( ioctl_lock      ),
    .ioctl_wr       ( ioctl_wr        ),
    .ioctl_dout     ( ioctl_dout      ),
    .ioctl_addr     ( ioctl_addr[7:0] ),
    .st_addr        ( st_addr         ),
    .st_dout        ( st_dout         ),

    // Base video
    .osd_rotate     ( rotate          ),
    .game_r         ( game_r          ),
    .game_g         ( game_g          ),
    .game_b         ( game_b          ),
    .LHBL           ( LHBL            ),
    .LVBL           ( LVBL            ),
    .hs             ( hs              ),
    .vs             ( vs              ),
    .pxl_cen        ( pxl_cen         ),
    .pxl2_cen       ( pxl2_cen        ),
    // Video after OSD, credits and debugger
    .base_rgb       ( base_rgb        ),
    .base_lhbl      ( base_LHBL       ),
    .base_lvbl      ( base_LVBL       ),
    .base_hs        ( base_hs         ),
    .base_vs        ( base_vs         ),
    // Debug
    .gfx_en         ( gfx_en          ),
    .debug_bus      ( debug_bus       ),
    .debug_view     ( debug_view      ),
    .target_info    ( st_target       ),
    // Unused ports (MiSTer)
    .hdmi_arx       (                 ),
    .hdmi_ary       (                 )
);

endmodule
