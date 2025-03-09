//============================================================================
//  JTFRAME by Jose Tejada Gomez. Twitter: @topapate
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

`ifdef JTFRAME_VERTICAL
`define JTFRAME_MR_DDR
`endif

`ifdef JTFRAME_MR_DDRLOAD
`define JTFRAME_MR_DDR
`endif

module emu
(
    //Master input clock
    input         CLK_50M,

    //Async reset from top-level module.
    //Can be used as initial reset.
    input         RESET,

    //Must be passed to hps_io module
    inout  [48:0] HPS_BUS,

    //Base video clock. Usually equals to CLK_SYS.
    output        CLK_VIDEO,

    //Multiple resolutions are supported using different CE_PIXEL rates.
    //Must be based on CLK_VIDEO
    output        CE_PIXEL,

    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,    // = ~(VBlank | HBlank)
    output        VGA_F1,
    output  [1:0] VGA_SL,
    output        VGA_SCALER,
    output        VGA_DISABLE, // analog out is off

    input  [11:0] HDMI_WIDTH,
    input  [11:0] HDMI_HEIGHT,
    output        HDMI_FREEZE,
    output        HDMI_BLACKOUT,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    output [12:0] VIDEO_ARX,
    output [12:0] VIDEO_ARY,

    output        LED_USER,  // 1 - ON, 0 - OFF.

    // b[1]: 0 - LED status is system status OR'd with b[0]
    //       1 - LED status is controled solely by b[0]
    // hint: supply 2'b00 to let the system control the LED.
    output  [1:0] LED_POWER,
    output  [1:0] LED_DISK,

    // I/O board button press simulation (active high)
    // b[1]: user button
    // b[0]: osd button
    output  [1:0] BUTTONS,

    input         CLK_AUDIO,
    output reg [15:0] AUDIO_L,
    output reg [15:0] AUDIO_R,
    output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
    output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

    //ADC
    inout   [3:0] ADC_BUS,

    //SD-SPI
    output        SD_SCK,
    output        SD_MOSI,
    input         SD_MISO,
    output        SD_CS,
    input         SD_CD,

    //SDRAM interface with lower latency
    output        SDRAM_CLK,
    output        SDRAM_CKE,
    output [12:0] SDRAM_A,
    output [ 1:0] SDRAM_BA,
    inout  [15:0] SDRAM_DQ,
    output        SDRAM_DQML,
    output        SDRAM_DQMH,
    output        SDRAM_nCS,
    output        SDRAM_nCAS,
    output        SDRAM_nRAS,
    output        SDRAM_nWE,

    input         UART_CTS,
    output        UART_RTS,
    input         UART_RXD,
    output        UART_TXD,
    output        UART_DTR,
    input         UART_DSR,

    `ifdef JTFRAME_VERTICAL
    output        FB_EN,
    output [ 4:0] FB_FORMAT,
    output [11:0] FB_WIDTH,
    output [11:0] FB_HEIGHT,
    output [31:0] FB_BASE,
    output [13:0] FB_STRIDE,
    input         FB_VBL,
    input         FB_LL,
    output        FB_FORCE_BLANK,

    // Palette control for 8bit modes.
    // Ignored for other video modes.
    output        FB_PAL_CLK,
    output [ 7:0] FB_PAL_ADDR,
    output [23:0] FB_PAL_DOUT,
    input  [23:0] FB_PAL_DIN,
    output        FB_PAL_WR,
`endif

    output        DDRAM_CLK,
    input         DDRAM_BUSY,
    output [ 7:0] DDRAM_BURSTCNT,
    output [28:0] DDRAM_ADDR,
    input  [63:0] DDRAM_DOUT,
    input         DDRAM_DOUT_READY,
    output        DDRAM_RD,
    output [63:0] DDRAM_DIN,
    output [ 7:0] DDRAM_BE,
    output        DDRAM_WE,

    // Open-drain User port.
    // 0 - D+/RX
    // 1 - D-/TX
    // 2..6 - USR2..USR6
    // Set USER_OUT to 1 to read from USER_IN.
    input   [6:0] USER_IN,
    output  [6:0] USER_OUT,
    output        db15_en,
    output        uart_en,
    output        gun_border_en,
    output        show_osd,
    input         OSD_STATUS
    `ifdef SIMULATION
    ,output       sim_pxl_cen,
    output        sim_pxl_clk,
    output        sim_vb,
    output        sim_hb
    `endif
);

`ifdef JTFRAME_SDRAM_LARGE
    localparam SDRAMW=23; // 64 MB
`else
    localparam SDRAMW=22; // 32 MB
`endif

`ifndef JTFRAME_INTERLACED
assign VGA_F1=1'b0;
`else
wire   field;
assign VGA_F1=field;
`endif

// unused features
assign VGA_SCALER    = 0;
assign VGA_DISABLE   = 0;
assign HDMI_FREEZE   = 0;
assign HDMI_BLACKOUT = 0;
assign AUDIO_MIX     = 0;
assign BUTTONS       = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;

wire [3:0] hoffset, voffset;
wire [1:0] dial_x, dial_y;

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_rom, clk96, clk96sh, clk48, clk48sh, clk24;
wire game_rst, game_service, game_tilt, rst, rst_n;
wire clk_pico;
wire pxl2_cen, pxl_cen;
wire rst96, rst48, rst24;
wire pll_locked;
reg  pll_rst = 1'b0;
wire sys_rst;

// Resets the PLL if it looses lock
jtframe_sync u_sync(
    .clk_in     ( CLK_50M   ),
    .clk_out    ( clk_sys   ),
    .raw        ( RESET     ),
    .sync       ( sys_rst   )
);

always @(posedge clk_sys or posedge sys_rst) begin : pll_controller
    reg last_locked;
    reg [7:0] rst_cnt;

    if( sys_rst ) begin
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

// There are many false paths defined in the
// SDC file between this PLL and the ones
// used in sys_top
pll pll(
    .refclk     ( CLK_50M    ),
    .rst        ( pll_rst    ),
    .locked     ( pll_locked ),
    .outclk_0   ( clk48      ),
    .outclk_1   ( clk48sh    ),
    .outclk_2   ( clk24      ),
    .outclk_3   (            ),
    .outclk_4   ( clk96      ),
    .outclk_5   ( clk96sh    )
);

jtframe_rst_sync u_reset96(
    .rst        ( game_rst  ),
    .clk        ( clk96     ),
    .rst_sync   ( rst96     )
);

jtframe_rst_sync u_reset48(
    .rst        ( game_rst  ),
    .clk        ( clk48     ),
    .rst_sync   ( rst48     )
);

jtframe_rst_sync u_reset24(
    .rst        ( game_rst  ),
    .clk        ( clk24     ),
    .rst_sync   ( rst24     )
);

`ifdef JTFRAME_SDRAM96
    assign clk_rom = clk96;
    assign clk_sys = clk96;
`else
    assign clk_rom = clk48;
    `ifdef JTFRAME_CLK96
    assign clk_sys = clk96;
    `else
    assign clk_sys = clk48;
    `endif
`endif

assign clk_pico = clk48;

generate
    if( `JTFRAME_180SHIFT == 0 ) begin
        `ifdef JTFRAME_SDRAM96
        assign SDRAM_CLK   = clk96sh;
        `else
        assign SDRAM_CLK   = clk48sh;
        `endif
    end else begin
        altddio_out
        #(
            .extend_oe_disable("OFF"),
            .intended_device_family("Cyclone V"),
            .invert_output("OFF"),
            .lpm_hint("UNUSED"),
            .lpm_type("altddio_out"),
            .oe_reg("UNREGISTERED"),
            .power_up_high("OFF"),
            .width(1)
        )
        sdramclk_ddr
        (
            .datain_h(1'b0),
            .datain_l(1'b1),
            .outclock(clk_rom),
            .dataout(SDRAM_CLK),
            .aclr(1'b0),
            .aset(1'b0),
            .oe(1'b1),
            .outclocken(1'b1),
            .sclr(1'b0),
            .sset(1'b0)
        );
    end
endgenerate

///////////////////////////////////////////////////

wire [63:0] status;
wire [ 1:0] buttons;

wire [ 1:0] dip_fxlevel;
wire        dip_pause, dip_flip, dip_test;
wire [31:0] dipsw;

wire        ioctl_wr;
wire [26:0] ioctl_addr; // up to 128MB
wire [ 7:0] ioctl_dout, ioctl_din;

wire [ 9:0] game_joy1, game_joy2, game_joy3, game_joy4;
wire [ 3:0] game_coin, game_start;
wire [ 3:0] gfx_en;
wire [ 7:0] debug_bus, debug_view;
wire [15:0] joyana_l1, joyana_l2, joyana_l3, joyana_l4,
            joyana_r1, joyana_r2, joyana_r3, joyana_r4;

wire        rst_req   = sys_rst | status[0] | buttons[1];
wire [15:0] snd_left, snd_right;
wire [ 5:0] snd_en, snd_vu;
wire [ 7:0] snd_vol;
wire        snd_peak;

assign LED_DISK  = 2'b0;
assign LED_POWER = 2'b0;

// ROM download
wire          ioctl_rom, ioctl_cart, dwnld_busy;

wire [SDRAMW-1:0] prog_addr;
wire [15:0]   prog_data;
wire [ 1:0]   prog_mask, prog_ba;
wire          prog_we, prog_rd, prog_rdy, prog_ack, prog_dst, prog_dok;

// ROM access from game
wire [SDRAMW-1:0] ba0_addr, ba1_addr, ba2_addr, ba3_addr;
wire [ 3:0] ba_rd, ba_rdy, ba_ack, ba_dst, ba_dok, ba_wr;
wire [15:0] ba0_din, ba1_din, ba2_din, ba3_din;
wire [ 1:0] ba0_dsn, ba1_dsn, ba2_dsn, ba3_dsn;
wire [15:0] sdram_dout;

wire [ 7:0] st_addr, st_dout;
wire [ 7:0] paddle_1,  paddle_2,  paddle_3,  paddle_4,
            spinner_1, spinner_2, spinner_3, spinner_4;
wire [15:0] mouse_1p, mouse_2p;
wire [ 1:0] mouse_strobe;
wire [ 8:0] gun_1p_x, gun_1p_y, gun_2p_x, gun_2p_y;

localparam COLORW=`JTFRAME_COLORW;

wire [COLORW-1:0] red, green, blue;
wire              LHBL, LVBL;
wire              hs, vs, sample;
wire              ioctl_ram;
wire              game_rx, game_tx;

`ifndef JTFRAME_UART
    assign game_tx = 1;
`endif

`ifndef JTFRAME_SIGNED_SND
assign AUDIO_S = 1'b1; // Assume signed by default
`else
assign AUDIO_S = `JTFRAME_SIGNED_SND;
`endif

// Line-Frame buffer
wire [ 8:0] game_hdump,   ln_addr;
wire [ 7:0] game_vrender, ln_v;
wire        ln_done, ln_hs, ln_we;
wire [15:0] ln_pxl, ln_data;

jtframe_mister #(
    .SDRAMW         ( SDRAMW         ),
    .BUTTONS        (`JTFRAME_BUTTONS),
    .COLORW         ( COLORW         ),
    .VIDEO_WIDTH    (`JTFRAME_WIDTH  ),
    .VIDEO_HEIGHT   (`JTFRAME_HEIGHT )
)
u_frame(
    .clk_sys        ( clk_sys        ),
    .clk_rom        ( clk_rom        ),
    .clk_pico       ( clk_pico       ),
    .pll_locked     ( pll_locked     ),
    // interface with microcontroller
    .status         ( status         ),
    .HPS_BUS        ( HPS_BUS        ),
    .buttons        ( buttons        ),
    // Extension port (fake USB3)
    .USER_OUT       ( USER_OUT       ),
    .USER_IN        ( USER_IN        ),
    .db15_en        ( db15_en        ),
    .uart_en        ( uart_en        ),
    .game_rx        ( game_rx        ), // core-specific UART
    .game_tx        ( game_tx        ),
    .show_osd       ( show_osd       ),
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

    // Audio
    .snd_lin        ( snd_left       ),
    .snd_rin        ( snd_right      ),
    .snd_sample     ( sample         ),
    .snd_rout       ( AUDIO_R        ),
    .snd_lout       ( AUDIO_L        ),
    .snd_en         ( snd_en         ),
    .snd_vu         ( snd_vu         ),
    .snd_vol        ( snd_vol        ),
    .snd_peak       ( snd_peak       ),
    // line-frame buffer
    .game_vrender   ( game_vrender   ),
    .game_hdump     ( game_hdump     ),
    .ln_addr        ( ln_addr        ),
    .ln_data        ( ln_data        ),
    .ln_done        ( ln_done        ),
    .ln_hs          ( ln_hs          ),
    .ln_pxl         ( ln_pxl         ),
    .ln_v           ( ln_v           ),
    .ln_we          ( ln_we          ),

    `ifdef JTFRAME_VERTICAL
    // Screen rotation
    .FB_EN          ( FB_EN          ),
    .FB_FORMAT      ( FB_FORMAT      ),
    .FB_WIDTH       ( FB_WIDTH       ),
    .FB_HEIGHT      ( FB_HEIGHT      ),
    .FB_BASE        ( FB_BASE        ),
    .FB_STRIDE      ( FB_STRIDE      ),
    .FB_VBL         ( FB_VBL         ),
    .FB_LL          ( FB_LL          ),
    .FB_FORCE_BLANK ( FB_FORCE_BLANK ),

    .FB_PAL_CLK     ( FB_PAL_CLK     ),
    .FB_PAL_ADDR    ( FB_PAL_ADDR    ),
    .FB_PAL_DOUT    ( FB_PAL_DOUT    ),
    .FB_PAL_DIN     ( FB_PAL_DIN     ),
    .FB_PAL_WR      ( FB_PAL_WR      ),
    `endif

    // DDR interface
    .DDRAM_CLK      ( DDRAM_CLK      ), // same as clk_rom
    .DDRAM_BURSTCNT ( DDRAM_BURSTCNT ),
    .DDRAM_ADDR     ( DDRAM_ADDR     ),
    .DDRAM_BE       ( DDRAM_BE       ),
    .DDRAM_WE       ( DDRAM_WE       ),
    .DDRAM_BUSY     ( DDRAM_BUSY     ),
    .DDRAM_DOUT_READY(DDRAM_DOUT_READY ),
    .DDRAM_DOUT     ( DDRAM_DOUT     ),
    .DDRAM_RD       ( DDRAM_RD       ),
    .DDRAM_DIN      ( DDRAM_DIN      ),

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
    // ROM access from game
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

    .sdram_dout     ( sdram_dout     ),

    // ROM load
    .ioctl_addr     ( ioctl_addr     ),
    .ioctl_dout     ( ioctl_dout     ),
    .ioctl_wr       ( ioctl_wr       ),
    .ioctl_ram      ( ioctl_ram      ),
    .ioctl_din      ( ioctl_din      ),

    .ioctl_rom      ( ioctl_rom      ),
    .ioctl_cart     ( ioctl_cart     ),
    .dwnld_busy     ( dwnld_busy     ),
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
    .game_paddle_1  ( paddle_1       ),
    .game_paddle_2  ( paddle_2       ),
    .game_paddle_3  ( paddle_3       ),
    .game_paddle_4  ( paddle_4       ),
    .spinner_1      ( spinner_1      ),
    .spinner_2      ( spinner_2      ),
    .spinner_3      ( spinner_3      ),
    .spinner_4      ( spinner_4      ),
    // Mouse inputs
    .mouse_1p       ( mouse_1p       ),
    .mouse_2p       ( mouse_2p       ),
    .mouse_strobe   ( mouse_strobe   ),
    .LED            ( LED_USER       ),
    // Dial emulation
    .dial_x         ( dial_x         ),
    .dial_y         ( dial_y         ),
    // Lightguns
    .gun_1p_x       ( gun_1p_x       ),
    .gun_1p_y       ( gun_1p_y       ),
    .gun_2p_x       ( gun_2p_x       ),
    .gun_2p_y       ( gun_2p_y       ),
    .gun_border_en  ( gun_border_en  ),
    // DIP and OSD settings
    .dip_test       ( dip_test       ),
    .dip_pause      ( dip_pause      ),
    .dip_flip       ( dip_flip       ),
    .dip_fxlevel    ( dip_fxlevel    ),
    .dipsw          ( dipsw          ),
    // screen
    .rotate         (                ),
    // HDMI
    .hdmi_arx       ( VIDEO_ARX      ),
    .hdmi_ary       ( VIDEO_ARY      ),
    .hdmi_width     ( HDMI_WIDTH     ),
    .hdmi_height    ( HDMI_HEIGHT    ),
    // scan doubler output to VGA pins
    .scan2x_r       ( VGA_R          ),
    .scan2x_g       ( VGA_G          ),
    .scan2x_b       ( VGA_B          ),
    .scan2x_hs      ( VGA_HS         ),
    .scan2x_vs      ( VGA_VS         ),
    .scan2x_clk     ( CLK_VIDEO      ),
    .scan2x_cen     ( CE_PIXEL       ),
    .scan2x_de      ( VGA_DE         ),
    .scan2x_sl      ( VGA_SL         ),
    // status
    .st_addr        ( st_addr        ),
    .st_dout        ( st_dout        ),
    // Debug
    .gfx_en         ( gfx_en         ),
    .debug_bus      ( debug_bus      ),
    .debug_view     ( debug_view     )
);

`include "jtframe_game_instance.v"

`ifndef JTFRAME_STEREO
    assign snd_right = snd_left;
`endif

endmodule
