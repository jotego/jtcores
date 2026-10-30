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

// This is the top level module for
// the Analogue Pocket target

module jtframe_pocket_top(
    ///////////////////////////////////////////////////
    // clock inputs 74.25mhz. not phase aligned, so treat these domains as asynchronous

    input             clk_74a, // mainclk1
    input             clk_74b, // mainclk1

    ///////////////////////////////////////////////////
    // cartridge interface
    // switches between 3.3v and 5v mechanically
    // output enable for multibit translators controlled by pic32

    // GBA AD[15:8]
    inout     [7:0]   cart_tran_bank2,
    output            cart_tran_bank2_dir,

    // GBA AD[7:0]
    inout     [7:0]   cart_tran_bank3,
    output            cart_tran_bank3_dir,

    // GBA A[23:16]
    inout     [7:0]   cart_tran_bank1,
    output            cart_tran_bank1_dir,

    // GBA [7] PHI#
    // GBA [6] WR#
    // GBA [5] RD#
    // GBA [4] CS1#/CS#
    //     [3:0] unwired
    inout     [7:4]   cart_tran_bank0,
    output            cart_tran_bank0_dir,

    // GBA CS2#/RES#
    inout             cart_tran_pin30,
    output            cart_tran_pin30_dir,
    // when GBC cart is inserted, this signal when low or weak will pull GBC /RES low with a special circuit
    // the goal is that when unconfigured, the FPGA weak pullups won't interfere.
    // thus, if GBC cart is inserted, FPGA must drive this high in order to let the level translators
    // and general IO drive this pin.
    output            cart_pin30_pwroff_reset,

    // GBA IRQ/DRQ
    inout             cart_tran_pin31,
    output            cart_tran_pin31_dir,

    // infrared
    input             port_ir_rx,
    output            port_ir_tx,
    output            port_ir_rx_disable,

    // GBA link port
    inout             port_tran_si,
    output            port_tran_si_dir,
    inout             port_tran_so,
    output            port_tran_so_dir,
    inout             port_tran_sck,
    output            port_tran_sck_dir,
    inout             port_tran_sd,
    output            port_tran_sd_dir,

    ///////////////////////////////////////////////////
    // cellular psram 0 and 1, two chips (64Mbit x2 dual die per chip)

    output    [21:16] cram0_a,      // used as frame buffer
    inout     [15:0]  cram0_dq,
    input             cram0_wait,
    output            cram0_clk,
    output            cram0_adv_n,
    output            cram0_cre,
    output            cram0_ce0_n,
    output            cram0_ce1_n,
    output            cram0_oe_n,
    output            cram0_we_n,
    output            cram0_ub_n,
    output            cram0_lb_n,

    output    [21:16] cram1_a,
    inout     [15:0]  cram1_dq,
    input             cram1_wait,
    output            cram1_clk,
    output            cram1_adv_n,
    output            cram1_cre,
    output            cram1_ce0_n,
    output            cram1_ce1_n,
    output            cram1_oe_n,
    output            cram1_we_n,
    output            cram1_ub_n,
    output            cram1_lb_n,

    ///////////////////////////////////////////////////
    // sdram, 512 Mbit 16bit (64 MBytes)

    output    [12:0]  dram_a,
    output    [1:0]   dram_ba,
    inout     [15:0]  dram_dq,
    output    [1:0]   dram_dqm,
    output            dram_clk,
    output            dram_cke,
    output            dram_ras_n,
    output            dram_cas_n,
    output            dram_we_n,

    ///////////////////////////////////////////////////
    // sram, 2 Mbit 16bit (256kB)

    output    [16:0]  sram_a,
    inout     [15:0]  sram_dq,
    output            sram_oe_n,
    output            sram_we_n,
    output            sram_ub_n,
    output            sram_lb_n,

    ///////////////////////////////////////////////////
    // vblank driven by dock for sync in a certain mode

    input             vblank,

    ///////////////////////////////////////////////////
    // i/o to 6515D breakout usb uart

    output            dbg_tx,
    input             dbg_rx,

    ///////////////////////////////////////////////////
    // i/o pads near jtag connector user can solder to

    output            user1,
    input             user2,

    ///////////////////////////////////////////////////
    // RFU internal i2c bus

    inout             aux_sda,
    output            aux_scl,

    ///////////////////////////////////////////////////
    // RFU, do not use
    inout             bist,
    output            vpll_feed,


    //
    // logical connections
    //

    // video, audio output to scaler
    output     [11:0] scal_vid,
    output            scal_clk,
    output            scal_de,
    output            scal_skip,
    output            scal_vs,
    output            scal_hs,

    output            scal_audmclk,
    input             scal_audadc,
    output            scal_auddac,
    output            scal_audlrck,

    inout             spi_clk,
    inout       [1:0] spi_dio,
    input             spi_ss,

    // controller data
    inout             bridge_1wire
);

localparam COLORW       =`JTFRAME_COLORW;
localparam GAME_BUTTONS =`JTFRAME_BUTTONS;

`ifdef JTFRAME_SDRAM_LARGE
    localparam SDRAMW=23; // 64 MB
`else
    localparam SDRAMW=22; // 32 MB
`endif

wire          rst, rst_n,
              clk_sys, clk24, clk48, clk96, clk_rom;
wire [63:0]   status;
wire [25:0]   ioctl_addr;
wire [ 7:0]   ioctl_dout, ioctl_din;
wire          ioctl_wr, ioctl_ram;
wire [ 5:0]   snd_en, snd_vu;
wire [ 7:0]   snd_vol;
wire          snd_peak;

wire [15:0] joyana_l1, joyana_l2, joyana_l3, joyana_l4,
            joyana_r1, joyana_r2, joyana_r3, joyana_r4;

// Line-Frame buffer
wire [`JTFRAME_LF_HW-1:0] game_hdump, ln_addr;
wire [`JTFRAME_LF_VW-1:0] game_vrender, ln_v;
wire        ln_done, ln_hs, ln_vs, ln_lvbl, ln_we, fb_keep;
wire [15:0] ln_dout, ln_pxl, ln_data;

// ROM download
wire          ioctl_rom, ioctl_cart, dwnld_busy;

wire [SDRAMW-1:0] prog_addr;
wire [15:0]   prog_data;
wire [ 1:0]   prog_mask, prog_ba;
wire          prog_we, prog_rd, prog_rdy, prog_ack, prog_dst, prog_dok;

// ROM access from game
wire [SDRAMW-1:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr;
wire [ 3:0] ba_rd, ba_rdy, ba_ack, ba_dst, ba_dok;
wire [ 3:0] ba_wr;
wire [15:0] ba0_din, ba1_din, ba2_din, ba3_din;
wire [ 1:0] ba0_dsn, ba1_dsn, ba2_dsn, ba3_dsn;
`ifdef JTFRAME_SDRAM_CACHE
wire [SDRAMW-1:0] burst_addr;
wire [ 1:0] burst_ba;
wire        burst_rd, burst_wr, burst_ack, burst_dst, burst_dok, burst_rdy;
wire [15:0] burst_din;
`endif
wire [15:0] sdram_dout;

wire [COLORW-1:0] red;
wire [COLORW-1:0] green;
wire [COLORW-1:0] blue;

wire LHBL, LVBL, hs, vs;
wire [15:0] snd_left, snd_right;
wire        sample;

wire [9:0] game_joy1, game_joy2, game_joy3, game_joy4;
wire [3:0] game_coin, game_start;
wire       game_rst, game_service, game_tilt;
wire       rst96, rst48, rst24;
wire [3:0] gfx_en;
wire [1:0] dial_x, dial_y;
// SDRAM
wire data_rdy, sdram_ack;

// PLL's
wire pll_locked, clk_pico;

wire [ 7:0] debug_bus, debug_view;
wire [ 1:0] dip_fxlevel;
wire        dip_pause, dip_flip, dip_test;
wire        pxl_cen, pxl2_cen;
wire [ 7:0] st_addr, st_dout;
wire [ 7:0] paddle_1, paddle_2, paddle_3, paddle_4;
wire [15:0] mouse_1p, mouse_2p;
wire [ 1:0] mouse_strobe;
wire [ 8:0] gun_1p_x, gun_1p_y, gun_2p_x, gun_2p_y;
wire [31:0] dipsw;
// Analog Video (Analogizer)
wire [23:0] yc_vid;
wire [ 7:0] cart3_vid, cart2_vid;
wire [ 4:0] cart1_vid;
wire        cart1_vdir, cart2_vdir, cart3_vdir;
wire [ 7:0] cart1_out, cart2_out, cart3_out;
wire        cart1_dir;
wire        cart2_dir, cart3_dir, yc_en, vid_en;
wire [ 1:0] anv_en;
// SNAC interface (Analogizer)
wire [15:0] snac_p1, snac_p2, snac_p3, snac_p4;
wire [ 7:0] snac_cont;
// wire [ 7:6] cart1_out;
wire [ 7:4] cart0_out;
wire        cart0_dir, cartp30_dir,cartp31_dir;
wire        cartp30_out, cartp31_out, cartp30_pwrst, snac_en;
wire [ 3:0] out_en;
wire [ 7:6] snac1_bus;
wire [ 7:4] snac0_bus;
wire        snac31_bus, snac30_bus;
wire        snac0_dir, snac31_dir, snac30_dir;

`ifndef JTFRAME_STEREO
assign snd_right = snd_left;
`endif

jtframe_mist_clocks u_clocks(
    .clk_ext    ( clk_74b        ), // 74.25 MHz

    // PLL outputs
    .clk96      ( clk96          ),
    .clk48      ( clk48          ),
    .clk24      ( clk24          ),
    .pll_locked ( pll_locked     ),

    // System clocks
    .clk_sys    ( clk_sys        ),
    .clk_rom    ( clk_rom        ),
    .SDRAM_CLK  ( dram_clk       ),

    // reset signals
    .game_rst   ( game_rst       ),
    .rst96      ( rst96          ),
    .rst48      ( rst48          ),
    .rst24      ( rst24          )
);

assign clk_pico = clk48;

// Unused Pocket ports
assign port_ir_tx              = 0;
assign port_ir_rx_disable      = 1;
assign cart_tran_bank3         = vid_en    ? cart3_out     : 8'hzz;
assign cart_tran_bank3_dir     = vid_en    ? cart3_dir     : 1'b0;
assign cart_tran_bank2         = vid_en    ? cart2_out     : 8'hzz;
assign cart_tran_bank2_dir     = vid_en    ? cart2_dir     : 1'b0;
assign cart_tran_bank1         = out_en[0] ? cart1_out     : 8'hzz;
assign cart_tran_bank1_dir     = out_en[0] ? cart1_dir     : 1'b0;
assign cart_tran_bank0         = out_en[3] ? cart0_out     : 4'hZ;
assign cart_tran_bank0_dir     = snac_en   ? cart0_dir     : 1'b1;
assign cart_tran_pin30         = out_en[2] ? cartp30_out   : 1'bZ;
assign cart_tran_pin30_dir     = snac_en   ? cartp30_dir   : 1'b0;
assign cart_pin30_pwroff_reset = out_en[0] ? cartp30_pwrst : 1'b0;
assign cart_tran_pin31         = out_en[1] ? cartp31_out   : 1'bz;
assign cart_tran_pin31_dir     = snac_en   ? cartp31_dir   : 1'b0;
assign port_tran_so            = 1'bz;
assign port_tran_so_dir        = 0;
assign port_tran_si            = 1'bz;
assign port_tran_si_dir        = 0;
assign port_tran_sck           = 1'bz;
assign port_tran_sck_dir       = 0;
assign port_tran_sd            = 1'bz;
assign port_tran_sd_dir        = 0;
assign cram1_a                 = 0;
assign cram1_dq                = 0;
assign cram1_clk               = 0;
assign cram1_adv_n             = 1;
assign cram1_cre               = 0;
assign cram1_ce0_n             = 1;
assign cram1_ce1_n             = 1;
assign cram1_oe_n              = 1;
assign cram1_we_n              = 1;
assign cram1_ub_n              = 1;
assign cram1_lb_n              = 1;
assign dbg_tx                  = 0;
assign aux_scl                 = 0;
assign user1                   = 1'bz;
assign vpll_feed               = 1'bz;
assign bist                    = 1'bz;

jtframe_pocket #(
    .SDRAMW       ( SDRAMW         ),
    .SIGNED_SND   ( `JTFRAME_SIGNED_SND ),
    .BUTTONS      ( `JTFRAME_BUTTONS    ),
    .COLORW       ( COLORW         ),
    .VIDEO_WIDTH  ( `JTFRAME_WIDTH ),
    .VIDEO_HEIGHT (`JTFRAME_HEIGHT )
)
u_frame(
    .clk_74a        ( clk_74a        ),
    .clk_sys        ( clk_sys        ),
    .clk_rom        ( clk_rom        ),
    .clk_pico       ( clk_pico       ),
    .clk48          ( clk48          ),
    .pll_locked     ( pll_locked     ),
    .status         ( status         ),
    .dipsw          ( dipsw          ),
    // System communication
    .spi_ss         ( spi_ss         ),
    .spi_dio        ( spi_dio        ),
    .spi_clk        ( spi_clk        ),
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
    // Pocket video pins
    .scal_vid       ( scal_vid       ),
    .scal_clk       ( scal_clk       ),
    .scal_de        ( scal_de        ),
    .scal_skip      ( scal_skip      ),
    .scal_vs        ( scal_vs        ),
    .scal_hs        ( scal_hs        ),
    // SDRAM interface
    .SDRAM_DQ       ( dram_dq        ),
    .SDRAM_A        ( dram_a         ),
    .SDRAM_DQML     ( dram_dqm[0]    ),
    .SDRAM_DQMH     ( dram_dqm[1]    ),
    .SDRAM_nWE      ( dram_we_n      ),
    .SDRAM_nCAS     ( dram_cas_n     ),
    .SDRAM_nRAS     ( dram_ras_n     ),
    .SDRAM_nCS      (                ),
    .SDRAM_BA       ( dram_ba        ),
    .SDRAM_CKE      ( dram_cke       ),
    // SDRAM
    .sram_a         ( sram_a         ),
    .sram_dq        ( sram_dq        ),
    .sram_oe_n      ( sram_oe_n      ),
    .sram_we_n      ( sram_we_n      ),
    .sram_ub_n      ( sram_ub_n      ),
    .sram_lb_n      ( sram_lb_n      ),
    .sram_addr      ( sram_addr      ),
    .sram_din       ( sram_din       ),
    .sram_dout      ( sram_dout      ),
    .sram_wen       ( sram_wen       ),
    .sram_dsn       ( sram_dsn       ),
    .sram_ok        ( sram_ok        ),
    // Controllers
    .bridge_1wire   ( bridge_1wire   ),
    // ROM access from game
    // Bank 0: allows R/W
    .ba0_addr       ( ba0_addr       ),
    .ba1_addr       ( ba1_addr       ),
    .ba2_addr       ( ba2_addr       ),
    .ba3_addr       ( ba3_addr       ),
`ifdef JTFRAME_SDRAM_CACHE
    .burst_addr     ( burst_addr     ),
    .burst_ba       ( burst_ba       ),
    .burst_rd       ( burst_rd       ),
    .burst_wr       ( burst_wr       ),
    .burst_ack      ( burst_ack      ),
    .burst_dst      ( burst_dst      ),
    .burst_dok      ( burst_dok      ),
    .burst_rdy      ( burst_rdy      ),
`endif
    .ba_rd          ( ba_rd          ),
    .ba_wr          ( ba_wr          ),
    .ba_dst         ( ba_dst         ),
    .ba_dok         ( ba_dok         ),
    .ba_rdy         ( ba_rdy         ),
    .ba_ack         ( ba_ack         ),
    .ba0_din        ( ba0_din        ),
    .ba0_dsn        ( ba0_dsn        ),
    .ba1_din        ( ba1_din        ),
    .ba1_dsn        ( ba1_dsn        ),
    .ba2_din        ( ba2_din        ),
    .ba2_dsn        ( ba2_dsn        ),
    .ba3_din        ( ba3_din        ),
    .ba3_dsn        ( ba3_dsn        ),
`ifdef JTFRAME_SDRAM_CACHE
    .burst_din      ( burst_din      ),
`endif

    // ROM-load interface
    .prog_addr      ( prog_addr      ),
    .prog_ba        ( prog_ba        ),
    .prog_rd        ( prog_rd        ),
    .prog_we        ( prog_we        ),
    .prog_data      ( prog_data      ),
    .prog_mask      ( prog_mask      ),
    .prog_ack       ( prog_ack       ),
    .prog_dst       ( prog_dst       ),
    .prog_dok       ( prog_dok       ),
    .prog_rdy       ( prog_rdy       ),

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

    // line-frame buffer
    .game_vrender   ( game_vrender   ),
    .game_hdump     ( game_hdump     ),
    .ln_addr        ( ln_addr        ),
    .ln_data        ( ln_data        ),
    .ln_done        ( ln_done        ),
    .ln_hs          ( ln_hs          ),
    .ln_dout        ( ln_dout        ),
    .ln_pxl         ( ln_pxl         ),
    .ln_v           ( ln_v           ),
    .ln_vs          ( ln_vs          ),
    .ln_lvbl        ( ln_lvbl        ),
    .ln_we          ( ln_we          ),
    .fb_keep        ( fb_keep        ),
    // PSRAM chip
    .cr_addr        ( cram0_a        ),
    .cr_adq         ( cram0_dq       ),
    .cr_advn        ( cram0_adv_n    ),
    .cr_cen         ( {cram0_ce1_n,cram0_ce0_n} ),
    .cr_clk         ( cram0_clk      ),
    .cr_cre         ( cram0_cre      ),
    .cr_dsn         ( {cram0_ub_n,cram0_lb_n} ),
    .cr_oen         ( cram0_oe_n     ),
    .cr_wait        ( cram0_wait     ),
    .cr_wen         ( cram0_we_n     ),
    // Analog Video Output
    .cart1_vid      ( cart1_vid      ),
    .cart2_vid      ( cart2_vid      ),
    .cart3_vid      ( cart3_vid      ),
    .cart1_vdir     ( cart1_vdir     ),
    .cart2_vdir     ( cart2_vdir     ),
    .cart3_vdir     ( cart3_vdir     ),
    .anv_en         ( anv_en         ),
    .yc_vid         ( yc_vid         ),
    .yc_en          ( yc_en          ),
    // SNAC Controller inputs
    .snac_cfg       ( snac_cont      ),
    .snac_p1        ( snac_p1        ),
    .snac_p2        ( snac_p2        ),
    .snac_p3        ( snac_p3        ),
    .snac_p4        ( snac_p4        ),
//////////// board
    .rst            ( rst            ),
    .rst_n          ( rst_n          ), // unused
    .game_rst       ( game_rst       ),
    .game_rst_n     (                ),
    // Sound from game
    .snd_left       ( snd_left       ),
    .snd_right      ( snd_right      ),
    .snd_sample     ( sample         ),
    .snd_en         ( snd_en         ),
    .snd_vu         ( snd_vu         ),
    .snd_vol        ( snd_vol        ),
    .snd_peak       ( snd_peak       ),
    // Sound to Pcket
    .audio_mclk     ( scal_audmclk   ),
    .audio_dac      ( scal_auddac    ),
    .audio_lrck     ( scal_audlrck   ),
    .game_joystick1 ( game_joy1      ),
    .game_joystick2 ( game_joy2      ),
    .game_joystick3 ( game_joy3      ),
    .game_joystick4 ( game_joy4      ),
    .coin           ( game_coin      ),
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
    .mouse_strobe   ( mouse_strobe   ),
    // Dial emulation
    .dial_x         ( dial_x         ),
    .dial_y         ( dial_y         ),
    // Lightguns
    .gun_1p_x       ( gun_1p_x       ),
    .gun_1p_y       ( gun_1p_y       ),
    .gun_2p_x       ( gun_2p_x       ),
    .gun_2p_y       ( gun_2p_y       ),
    // DIP and OSD settings
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

jtframe_analogizer u_analogizer(
    .rst          ( rst             ),
    .clk          ( clk_sys         ),
    .pxl_cen      ( pxl_cen         ),
    .pxl2_cen     ( pxl2_cen        ),
    .anv_en       ( anv_en          ),
    .out_en       ( out_en          ),
    .snac_en      ( snac_en         ),
    .vid_en       ( vid_en          ),
    .snac_cont    ( snac_cont       ),
    .snac_p1      ( snac_p1         ),
    .snac_p2      ( snac_p2         ),
    .snac_p3      ( snac_p3         ),
    .snac_p4      ( snac_p4         ),
    .cart0_in     ( cart_tran_bank0 ),
    .cartp30_in   ( cart_tran_pin30 ),
    .cartp31_in   ( cart_tran_pin31 ),
    .yc_en        ( yc_en           ),
    .yc_vid       ( yc_vid          ),
    .cart1_vid    ( cart1_vid       ),
    .cart2_vid    ( cart2_vid       ),
    .cart3_vid    ( cart3_vid       ),
    .cart1_vdir   ( cart1_vdir      ),
    .cart2_vdir   ( cart2_vdir      ),
    .cart3_vdir   ( cart3_vdir      ),
    .cart0_out    ( cart0_out       ),
    .cart0_dir    ( cart0_dir       ),
    .cart1_out    ( cart1_out       ),
    .cart1_dir    ( cart1_dir       ),
    .cart2_out    ( cart2_out       ),
    .cart2_dir    ( cart2_dir       ),
    .cart3_out    ( cart3_out       ),
    .cart3_dir    ( cart3_dir       ),
    .cart30_out   ( cartp30_out     ),
    .cart30_dir   ( cartp30_dir     ),
    .cartp30_pwrst( cartp30_pwrst   ),
    .cart31_out   ( cartp31_out     ),
    .cart31_dir   ( cartp31_dir     )
);

wire game_tx, game_rx;

`include "jtframe_game_instance.v"

endmodule
