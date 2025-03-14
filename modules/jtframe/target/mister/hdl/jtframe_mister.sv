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
    Date: 7-3-2019 */

module jtframe_mister #(parameter
    BUTTONS                 = 2,
    GAME_INPUTS_ACTIVE_LOW  =1'b1,
    COLORW                  = 4,
    VIDEO_WIDTH             = 384,
    VIDEO_HEIGHT            = 224,
    SDRAMW                  = 23
)(
    input           clk_sys,
    input           clk_rom,
    input           clk_pico,
    input           pll_locked,
    // interface with microcontroller
    output [63:0]   status,
    inout  [48:0]   HPS_BUS,
    output [ 1:0]   buttons,
    // LED
    // Extension port (fake USB3)
    input      [6:0] USER_IN,
    output reg [6:0] USER_OUT,
    output          db15_en,
    output          uart_en,
    input           game_tx,
    output          game_rx,
    output          show_osd,
    // Base video
    input [COLORW-1:0] game_r, game_g, game_b,
    input           LHBL,
    input           LVBL,
    input           hs,
    input           vs,
    inout           pxl_cen,
    inout           pxl2_cen,
    // Audio
    input  signed [15:0] snd_lin,  snd_rin,
    output signed [15:0] snd_lout, snd_rout,
    input                snd_sample,
    input                snd_peak,
    output [ 5:0]   snd_en,
    input  [ 5:0]   snd_vu,
    output [ 7:0]   snd_vol,
    // SDRAM interface
    inout  [15:0]   SDRAM_DQ,       // SDRAM Data bus 16 Bits
    output [12:0]   SDRAM_A,        // SDRAM Address bus 13 Bits
    output          SDRAM_DQML,     // SDRAM Low-byte Data Mask
    output          SDRAM_DQMH,     // SDRAM High-byte Data Mask
    output          SDRAM_nWE,      // SDRAM Write Enable
    output          SDRAM_nCAS,     // SDRAM Column Address Strobe
    output          SDRAM_nRAS,     // SDRAM Row Address Strobe
    output          SDRAM_nCS,      // SDRAM Chip Select
    output [ 1:0]   SDRAM_BA,       // SDRAM Bank Address
    input           SDRAM_CLK,      // SDRAM Clock
    output          SDRAM_CKE,      // SDRAM Clock Enable

    // line-frame buffer
    input        [ 7:0] game_vrender,
    input        [ 8:0] game_hdump,
    input        [ 8:0] ln_addr,
    input        [15:0] ln_data,
    input               ln_done,
    input               ln_we,
    output              ln_hs,
    output       [15:0] ln_pxl,
    output       [ 7:0] ln_v,

    // Signals to rotate the screen
`ifdef JTFRAME_VERTICAL
    output          FB_EN,
    output  [4:0]   FB_FORMAT,
    output [11:0]   FB_WIDTH,
    output [11:0]   FB_HEIGHT,
    output [31:0]   FB_BASE,
    output [13:0]   FB_STRIDE,
    input           FB_VBL,
    input           FB_LL,
    output          FB_FORCE_BLANK,

    // Palette control for 8bit modes.
    // Ignored for other video modes.
    output          FB_PAL_CLK,
    output  [7:0]   FB_PAL_ADDR,
    output [23:0]   FB_PAL_DOUT,
    input  [23:0]   FB_PAL_DIN,
    output          FB_PAL_WR,
 `endif

    // DDR3 RAM
    output          DDRAM_CLK,
    input           DDRAM_BUSY,
    output  [7:0]   DDRAM_BURSTCNT,
    output [28:0]   DDRAM_ADDR,
    input  [63:0]   DDRAM_DOUT,
    input           DDRAM_DOUT_READY,
    output          DDRAM_RD,
    output [63:0]   DDRAM_DIN,
    output  [7:0]   DDRAM_BE,
    output          DDRAM_WE,

    // ROM programming
    output       [26:0] ioctl_addr,
    output       [ 7:0] ioctl_dout,
    output              ioctl_wr,
    // NVRAM
    input        [ 7:0] ioctl_din,
    output              ioctl_ram,

    input               dwnld_busy,
    output              ioctl_rom,
    output              ioctl_cart,

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
    input         [3:0] ba_rd,    ba_wr,
    output        [3:0] ba_ack,   ba_rdy,   ba_dst,   ba_dok,
    input        [15:0] ba0_din,  ba1_din,  ba2_din,  ba3_din,
    input        [ 1:0] ba0_dsn,  ba1_dsn,  ba2_dsn,  ba3_dsn,
    output       [15:0] sdram_dout,
//////////// board
    output          rst,      // synchronous reset
    output          rst_n,    // asynchronous reset
    output          game_rst,
    output          game_rst_n,
    // reset forcing signals:
    input           rst_req,
    // joystick
    output  [ 9:0]  game_joystick1, game_joystick2, game_joystick3, game_joystick4,
    // left analogue stick
    output  [15:0]  joyana_l1, joyana_l2, joyana_l3, joyana_l4,
    // right analogue stick
    output  [15:0]  joyana_r1, joyana_r2, joyana_r3, joyana_r4,
    output  [ 3:0]  game_coin, game_start,
    output          game_service,
    output          game_tilt,
    // paddle 0..255
    output  [ 7:0]  game_paddle_1, game_paddle_2, game_paddle_3, game_paddle_4,
    output  [ 8:0]  spinner_1, spinner_2, spinner_3, spinner_4,
    // mouse
    output  [15:0]  mouse_1p,  mouse_2p,
    output  [ 1:0]  mouse_strobe,
    // Lightguns
    output  [ 8:0]  gun_1p_x, gun_1p_y, gun_2p_x, gun_2p_y,
    output          gun_border_en,
    // Dial
    output  [ 1:0]  dial_x,    dial_y,
    // HDMI
    output  [12:0]  hdmi_arx,  hdmi_ary,
    input   [11:0]  hdmi_width,hdmi_height,
    // DIP and OSD settings
    output  [ 1:0]  rotate,

    output          dip_test,
    // scan doubler
    output    [7:0] scan2x_r, scan2x_g, scan2x_b,
    output          scan2x_hs,
    output          scan2x_vs,
    output          scan2x_clk,
    output          scan2x_cen,
    output          scan2x_de,
    output    [1:0] scan2x_sl,
    // non standard:
    output            dip_pause,
    inout             dip_flip,
    output    [ 1:0]  dip_fxlevel,
    // Control words
    output    [31:0]  dipsw,
    // Debug
    output            LED,
    output    [ 3:0]  gfx_en,
    output    [ 7:0]  debug_bus,
    input     [ 7:0]  debug_view,
    output    [ 7:0]  st_addr,
    input     [ 7:0]  st_dout
);

`ifndef JTFRAME_MR_FASTIO
    `ifdef JTFRAME_CLK96
        `define JTFRAME_MR_FASTIO 1
    `else
      `define JTFRAME_MR_FASTIO 0
    `endif
`endif

localparam JTFRAME_MR_FASTIO=`JTFRAME_MR_FASTIO;

wire [21:0] gamma_bus;
wire [31:0] timestamp;
wire [ 7:0] ioctl_index;

wire [3*COLORW-1:0] base_rgb;
wire        base_lhbl, base_lvbl;

wire [ 3:0] hoffset, voffset;
wire [31:0] cheat;
wire        ioctl_cheat, ioctl_lock;

wire [15:0] joystick1, joystick2, joystick3, joystick4;
wire        ps2_kbd_clk, ps2_kbd_data;
wire        force_scan2x, direct_video;
wire        video_rotated;
wire        hide_gunen;

wire [ 6:0] core_mod;
wire [ 7:0] st_lpbuf;
wire [ 7:0] paddle_1, paddle_2, paddle_3, paddle_4;
// Mouse support
wire [24:0] ps2_mouse;
wire [ 8:0] mouse_dx, mouse_dy;
wire [ 7:0] mouse_f;
wire        mouse_st;

wire        hs_resync, vs_resync;

// Horizontal scaling for CRT
wire        hsize_enable;
wire [3:0]  hsize_scale;
wire        hsize_hs, hsize_vs, hsize_hb, hsize_vb;
wire [COLORW-1:0] hsize_r, hsize_g, hsize_b;

wire        hps_download, hps_upload, hps_wr, hps_wait;
wire [15:0] hps_index;
wire [26:0] hps_addr;
wire [ 7:0] hps_dout;

// Screen rotation
wire [ 7:0] rot_burstcnt;
wire [28:0] rot_addr;
wire [63:0] rot_dout;
wire        rot_we, rot_rd, rot_busy;
wire [ 7:0] rot_be;

// Fast DDR load
wire [ 7:0] ddrld_burstcnt;
wire [28:0] ddrld_addr;
wire        ddrld_rd, ddrld_busy;

// UART
wire        uart_rx, uart_tx;
wire [6:0]  joy_in, joy_out;

// Vertical crop
wire [12:0] raw_arx, raw_ary;
wire        raw_de;
reg  [11:0] crop_size;
reg   [4:0] crop_off; // -16...+15
wire  [2:0] crop_scale; //0 - normal, 1 - V-integer, 2 - HV-Integer-, 3 - HV-Integer+, 4 - HV-Integer
wire        crop_en;    // OSD control by the user
reg         crop_ok;    // whether the mister.ini video settings tolerate cropping
wire  [3:0] vcopt;
reg         en216p;
reg   [4:0] voff;
reg         pxl1_cen;

wire  [7:0] target_info;

// UART
// The core and cheat UARTs are connected in parallel
// If JTFRAME_UART is not defined, the core side is disabled
// If JTFRAME_CHEAT is not defined, the cheat side is disabled
// Otherwise, both can listen and talk
always @(posedge clk_sys) begin
    USER_OUT <= db15_en ? joy_out :
        uart_en ? {~6'h0, uart_tx&game_tx } :
        7'h7f;
end

jtframe_mister_status u_status(
    .clk            ( clk_sys        ),
    .status         ( status         ),
    .ps2_mouse      ( ps2_mouse      ),
    .USER_IN        ( USER_IN        ),
    .paddle_3       ( paddle_3       ),
    .paddle_4       ( paddle_4       ),
    .game_paddle_3  ( game_paddle_3  ),
    .game_paddle_4  ( game_paddle_4  ),
    .crop_en        ( crop_en        ),
    .vcopt          ( vcopt          ),
    .crop_scale     ( crop_scale     ),
    .voffset        ( voffset        ),
    .hoffset        ( hoffset        ),
    .hsize_enable   ( hsize_enable   ),
    .hsize_scale    ( hsize_scale    ),
    .joy_in         ( joy_in         ),
    .mouse_st       ( mouse_st       ),
    .mouse_f        ( mouse_f        ),
    .mouse_dx       ( mouse_dx       ),
    .mouse_dy       ( mouse_dy       ),
`ifdef JTFRAME_VERTICAL
    .FB_FORCE_BLANK ( FB_FORCE_BLANK ),
    .FB_PAL_CLK     ( FB_PAL_CLK     ),
    .FB_PAL_ADDR    ( FB_PAL_ADDR    ),
    .FB_PAL_DOUT    ( FB_PAL_DOUT    ),
    .FB_PAL_WR      ( FB_PAL_WR      ),
`endif
    .uart_en        ( uart_en        ),
    .uart_rx        ( uart_rx        ),
    .game_rx        ( game_rx        )
);

jtframe_target_info u_target_info(
    .clk            ( clk_sys        ),
    .joyana_l1      ( joyana_l1      ),
    .joyana_r1      ( joyana_r1      ),
    .joystick1      ( joystick1      ),
    .joystick2      ( joystick2      ),
    .mouse_1p       ( mouse_1p       ),
    .mouse_2p       ( mouse_2p       ),
    .hps_index      ( hps_index      ),
    .spinner_1      ( spinner_1      ),
    .spinner_2      ( spinner_2      ),
    .spinner_3      ( spinner_3      ),
    .spinner_4      ( spinner_4      ),
    .game_paddle_1  ( game_paddle_1  ),
    .game_paddle_2  ( game_paddle_2  ),
    .dial_x         ( dial_x         ),
    .dial_y         ( dial_y         ),
    .st_lpbuf       ( st_lpbuf       ),
    .ioctl_lock     ( ioctl_lock     ),
    .ioctl_cart     ( ioctl_cart     ),
    .ioctl_ram      ( ioctl_ram      ),
    .ioctl_rom      ( ioctl_rom      ),
    .ioctl_wr       ( ioctl_wr       ),
    .dwnld_busy     ( dwnld_busy     ),
    .hps_download   ( hps_download   ),
    .debug_bus      ( debug_bus      ),
    .target_info    ( target_info    )
);

jtframe_resync u_resync(
    .clk        ( clk_sys       ),
    .pxl_cen    ( pxl1_cen      ),
    .hs_in      ( hs            ),
    .vs_in      ( vs            ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .hoffset    ( hoffset       ),
    .voffset    ( voffset       ),
    .hs_out     ( hs_resync     ),
    .vs_out     ( vs_resync     )
);

reg         framebuf_flip;      // extra OSD options for rotation, bit 0 = rotate, bit 1 = flip

// OSD option visibility. This is linked to the d(D) and h(H) prefixes in cfgstr
wire [15:0] status_menumask; // a high value hides the menu item
wire        vertical;

assign status_menumask[15:7] = 0,
       status_menumask[6]    = hide_gunen, // sinden lightgun borders
       status_menumask[5]    = crop_ok, // video crop options
`ifdef JTFRAME_ROTATE       // extra rotate options for vertical games
       status_menumask[4]    = ~vertical,  // shown for vertical games
       status_menumask[1]    = 1,   // hidden
`else
       status_menumask[4]    = 1,   // hidden
       status_menumask[1]    = ~vertical,  // shown for vertical games
`endif
       status_menumask[3]    =~video_rotated, // scan FX options do not work with rotated video (except HQ2x)
       status_menumask[2]    = ~hsize_enable, // horizontal scaling
       status_menumask[0]    = direct_video;

always @(posedge clk_sys) begin
    framebuf_flip <= status[39:38]==2;
end

// this places the pxl1_cen in the pixel centre
always @(posedge clk_sys) pxl1_cen <= pxl2_cen & ~pxl_cen;


jtframe_mister_dwnld u_dwnld(
    .rst            ( rst            ),
    .clk            ( clk_rom        ),

    .prog_we        ( prog_we        ),
    .prog_rdy       ( prog_rdy       ),
    .ioctl_rom      ( ioctl_rom      ),
    .dwnld_busy     ( dwnld_busy     ),

    .hps_download   ( hps_download   ),
    .hps_upload     ( hps_upload     ),
    .hps_index      ( hps_index[7:0] ),
    .hps_wr         ( hps_wr         ),
    .hps_addr       ( hps_addr       ),
    .hps_dout       ( hps_dout       ),
    .hps_wait       ( hps_wait       ),

    .ioctl_wr       ( ioctl_wr       ),
    .ioctl_addr     ( ioctl_addr     ),
    .ioctl_dout     ( ioctl_dout     ),
    .ioctl_ram      ( ioctl_ram      ),
    .ioctl_cart     ( ioctl_cart     ),
    .ioctl_cheat    ( ioctl_cheat    ),
    .ioctl_lock     ( ioctl_lock     ),

    // Configuration
    .core_mod       ( core_mod       ),
    .status         ( status         ),
    .dipsw          ( dipsw          ),
    .cheat          ( cheat          ),

    // DDR
    .ddram_busy     ( ddrld_busy       ),
    .ddram_burstcnt ( ddrld_burstcnt   ),
    .ddram_addr     ( ddrld_addr       ),
    .ddram_dout     ( DDRAM_DOUT       ),
    .ddram_dout_ready(DDRAM_DOUT_READY ),
    .ddram_rd       ( ddrld_rd         )
);

wire [7:0] hps_din;
wire [15:0] joyusb_1, joyusb_2;


`ifndef JTFRAME_NO_DB15
assign db15_en  = status[37];
jtframe_joymux #(.BUTTONS(BUTTONS)) u_joymux(
    .rst        ( rst       ),
    .clk        ( clk_sys   ),
    .show_osd   ( show_osd  ),

    // MiSTer pins
    .USER_IN    ( joy_in    ),
    .USER_OUT   ( joy_out   ),

    // joystick mux
    .db15_en    ( db15_en   ),
    .joyusb_1   ( joyusb_1  ),
    .joyusb_2   ( joyusb_2  ),
    .joymux_1   ( joystick1 ),
    .joymux_2   ( joystick2 )
);
`else
assign db15_en   = 0;
assign show_osd  = 0;
assign joystick1 = joyusb_1;
assign joystick2 = joyusb_2;
`endif

`ifdef JTFRAME_SHADOW
    jtframe_shadow #(
        .AW    ( SDRAMW              ),
        .START ( `JTFRAME_SHADOW     ),
        .LW    ( `JTFRAME_SHADOW_LEN )  // length of data to be dumped as a power of 2
    ) u_shadow (
        .clk_rom    ( clk_rom       ),

        // Capture SDRAM bank 0 inputs
        .ba0_addr   ( ba0_addr      ),
        .wr0        ( ba_wr[0]      ),
        .din        ( ba0_din       ),
        .din_m      ( ba0_dsn       ),  // write mask -active low

        // Let data be dumped via NVRAM interface
        .ioctl_addr ( ioctl_addr    ),
        .ioctl_din  ( hps_din       )
    );
`else
    assign hps_din = ioctl_din;
`endif

hps_io #( .STRLEN(1024), .PS2DIV(32), .WIDE(JTFRAME_MR_FASTIO) ) u_hps_io
(
    .clk_sys         ( clk_rom        ),
    .HPS_BUS         ( HPS_BUS        ),

    .buttons         ( buttons        ),
    .status          ( status         ),
    .status_menumask ( status_menumask),
    .gamma_bus       ( gamma_bus      ),
    .direct_video    ( direct_video   ),
    .forced_scandoubler(force_scan2x  ),
    .video_rotated   ( video_rotated  ),

    .ioctl_download  ( hps_download   ),
    .ioctl_wr        ( hps_wr         ),
    .ioctl_addr      ( hps_addr       ),
    .ioctl_dout      ( hps_dout       ),
    .ioctl_din       ( hps_din        ),
    .ioctl_index     ( hps_index      ),
    .ioctl_wait      ( hps_wait       ),
    .ioctl_upload    ( hps_upload     ),
    // NVRAM support
    .ioctl_rd        (                ), // no need

    .joy_raw         ( joystick1[5:0] ), // DB15 control
    .joystick_0      ( joyusb_1       ),
    .joystick_1      ( joyusb_2       ),
    .joystick_2      ( joystick3      ),
    .joystick_3      ( joystick4      ),
    .joystick_l_analog_0( joyana_l1   ),
    .joystick_l_analog_1( joyana_l2   ),
    .joystick_l_analog_2( joyana_l3   ),
    .joystick_l_analog_3( joyana_l4   ),
    .joystick_r_analog_0( joyana_r1   ),
    .joystick_r_analog_1( joyana_r2   ),
    .joystick_r_analog_2( joyana_r3   ),
    .joystick_r_analog_3( joyana_r4   ),
    .ps2_kbd_clk_out ( ps2_kbd_clk    ),
    .ps2_kbd_data_out( ps2_kbd_data   ),

    // paddle 0..255
    .paddle_0        ( paddle_1       ),
    .paddle_1        ( paddle_2       ),
    .paddle_2        ( paddle_3       ),
    .paddle_3        ( paddle_4       ),

    .spinner_0       ( spinner_1      ),
    .spinner_1       ( spinner_2      ),
    .spinner_2       ( spinner_3      ),
    .spinner_3       ( spinner_4      ),
    // Unused:
    .ps2_key         (                ),
    .RTC             (                ),
    .TIMESTAMP       ( timestamp      ),
    .ps2_mouse       ( ps2_mouse      ),
    .ps2_mouse_ext   (                ),
    .ioctl_file_ext  (                )
);

`ifndef DEBUG_NOHDMI
    // scales base video horizontally
    jtframe_hsize #(.COLORW(COLORW)) u_hsize(
        .clk        ( clk_sys   ),
        .pxl_cen    ( pxl1_cen  ),
        .pxl2_cen   ( pxl2_cen  ),

        .scale      ( hsize_scale  ),
        .offset     ( 5'd0         ),
        .enable     ( hsize_enable ),

        .r_in       ( game_r    ),
        .g_in       ( game_g    ),
        .b_in       ( game_b    ),
        .HS_in      ( hs_resync ),
        .VS_in      ( vs_resync ),
        .HB_in      ( ~LHBL     ),
        .VB_in      ( ~LVBL     ),
        // filtered video
        .HS_out     ( hsize_hs  ),
        .VS_out     ( hsize_vs  ),
        .HB_out     ( hsize_hb  ),
        .VB_out     ( hsize_vb  ),
        .r_out      ( hsize_r   ),
        .g_out      ( hsize_g   ),
        .b_out      ( hsize_b   )
    );
`else
    assign hsize_hs = hs_resync;
    assign hsize_vs = vs_resync;
    assign hsize_hb = ~LHBL;
    assign hsize_vb = ~LVBL;
    assign hsize_r  = game_r;
    assign hsize_g  = game_g;
    assign hsize_b  = game_b;
`endif

localparam VIDEO_DW = COLORW!=5 ? 3*COLORW : 24;

wire [VIDEO_DW-1:0] game_rgb;
wire [COLORW-1:0] base_r, base_g, base_b;

assign {base_r,base_g,base_b} = base_rgb;

// arcade video does not support 15bpp colour, so for that
// case we need to convert it to 24bpp
generate
    if( COLORW!=5 ) begin
        assign game_rgb = base_rgb;
    end else begin
        assign game_rgb = {
            base_r, base_r[4:2],
            base_g, base_g[4:2],
            base_b, base_b[4:2]   };
    end
endgenerate

// VIDEO_WIDTH does not include blanking:
arcade_video #(.WIDTH(VIDEO_WIDTH),.DW(VIDEO_DW))
u_arcade_video(
    .clk_video  ( clk_sys       ),
    .ce_pix     ( pxl_cen       ),

    .RGB_in     ( game_rgb      ),
    .HBlank     ( ~base_lhbl    ),
    .VBlank     ( ~base_lvbl    ),
    .HSync      ( hsize_hs      ),
    .VSync      ( hsize_vs      ),

    .CLK_VIDEO  ( scan2x_clk    ),
    .CE_PIXEL   ( scan2x_cen    ),
    .VGA_R      ( scan2x_r      ),
    .VGA_G      ( scan2x_g      ),
    .VGA_B      ( scan2x_b      ),
    .VGA_HS     ( scan2x_hs     ),
    .VGA_VS     ( scan2x_vs     ),
    .VGA_DE     ( raw_de        ),
    .VGA_SL     ( scan2x_sl     ),

    .gamma_bus  ( gamma_bus     ),
    .fx         ( status[5:3]   ), // scanlines
    .forced_scandoubler( force_scan2x )
);

jtframe_board #(
    .BUTTONS               ( BUTTONS              ),
    .GAME_INPUTS_ACTIVE_LOW(GAME_INPUTS_ACTIVE_LOW),
    .COLORW                ( COLORW               ),
    .VIDEO_WIDTH           ( VIDEO_WIDTH          ),
    .VIDEO_HEIGHT          ( VIDEO_HEIGHT         ),
    .SDRAMW                ( SDRAMW               ),
    .MISTER                ( 1                    )
) u_board(
    .rst            ( rst             ),
    .rst_n          ( rst_n           ),
    .game_rst       ( game_rst        ),
    .game_rst_n     ( game_rst_n      ),
    .rst_req        ( rst_req         ),
    .sdram_init     (                 ),

    .pll_locked     ( pll_locked      ),

    .ioctl_cart     ( ioctl_cart      ),
    .ioctl_ram      ( ioctl_ram       ),
    .dwnld_busy     ( dwnld_busy      ),

    .clk_sys        ( clk_sys         ),
    .clk_rom        ( clk_rom         ),
    .clk_pico       ( clk_pico        ),

    .core_mod       ( core_mod        ),
    .vertical       ( vertical        ),
    .black_frame    (                 ),
    // Sound
    .snd_lin        ( snd_lin         ),
    .snd_rin        ( snd_rin         ),
    .snd_lout       ( snd_lout        ),
    .snd_rout       ( snd_rout        ),
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
    .board_start    ( 4'd0            ),
    .board_coin     ( 4'd0            ),
    .game_joystick1 ( game_joystick1  ),
    .game_joystick2 ( game_joystick2  ),
    .game_joystick3 ( game_joystick3  ),
    .game_joystick4 ( game_joystick4  ),
    .game_coin      ( game_coin       ),
    .game_start     ( game_start      ),
    .game_service   ( game_service    ),
    .game_tilt      ( game_tilt       ),
    // Mouse & paddle
    .bd_mouse_dx    ( mouse_dx        ),
    .bd_mouse_dy    ( mouse_dy        ),
    .bd_mouse_st    ( mouse_st        ),
    .bd_mouse_f     ( mouse_f         ),
    .bd_mouse_idx   ( 1'b0            ),    // MiSTer only supports one mouse

    .board_paddle_1 ( paddle_1        ),
    .board_paddle_2 ( paddle_2        ),
    .game_paddle_1  ( game_paddle_1   ),
    .game_paddle_2  ( game_paddle_2   ),
    .mouse_1p       ( mouse_1p        ),
    .mouse_2p       ( mouse_2p        ),
    .mouse_strobe   ( mouse_strobe    ),
    .spinner_1      ( spinner_1       ),
    .spinner_2      ( spinner_2       ),
    .dial_x         ( dial_x          ),
    .dial_y         ( dial_y          ),
    // Lightguns
    .gun_1p_x       ( gun_1p_x        ),
    .gun_1p_y       ( gun_1p_y        ),
    .gun_2p_x       ( gun_2p_x        ),
    .gun_2p_y       ( gun_2p_y        ),
    .gun_border_en  ( gun_border_en   ),
    .hide_gunen     ( hide_gunen      ),
    // DIP and OSD settings
    .status         ( status          ),
    .dipsw          ( dipsw           ),
    .dip_test       ( dip_test        ),
    .dip_pause      ( dip_pause       ),
    .dip_flip       ( dip_flip        ),
    .dip_fxlevel    ( dip_fxlevel     ),
    .timestamp      ( timestamp       ),
    // screen
    .hdmi_arx       ( raw_arx         ),
    .hdmi_ary       ( raw_ary         ),
    .rotate         ( rotate          ),
    .rot_osdonly    (                 ),
    // LED
    .osd_shown      ( 1'b0            ),
    .led            ( LED             ),
    // UART
    .uart_rx        ( uart_rx         ),
    .uart_tx        ( uart_tx         ),

    // SDRAM interface
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
    .cheat          ( cheat           ),
    .prog_cheat     ( ioctl_cheat     ),
    .prog_lock      ( ioctl_lock      ),
    .ioctl_wr       ( hps_wr          ),
    .ioctl_dout     ( ioctl_dout      ),
    .ioctl_addr     ( ioctl_addr[7:0] ),
    .st_addr        ( st_addr         ),
    .st_dout        ( st_dout         ),
    .target_info    ( target_info     ),

    // input data recording
    .ioctl_din      (                 ),
    .ioctl_merged   (                 ),
    // input video
    .osd_rotate     ( rotate          ),
    .game_r         ( hsize_r         ),
    .game_g         ( hsize_g         ),
    .game_b         ( hsize_b         ),
    .LHBL           ( ~hsize_hb       ),
    .LVBL           ( ~hsize_vb       ),
    .hs             ( hsize_hs        ),
    .vs             ( hsize_vs        ),
    .pxl_cen        ( pxl_cen         ),
    .pxl2_cen       ( pxl2_cen        ),
    // output video with credits and debug informaiton
    .base_lhbl      ( base_lhbl         ),
    .base_lvbl      ( base_lvbl         ),
    .base_rgb       ( base_rgb          ),
    // Debug
    .gfx_en         ( gfx_en          ),
    .debug_bus      ( debug_bus       ),
    .debug_view     ( debug_view      )
);

always @(posedge scan2x_clk) begin
    crop_ok   <= hdmi_width == 1920 && hdmi_height == 1080 && status[5:3]==0 /* scan lines FX */ &&
                 !force_scan2x && crop_scale==0 && !direct_video /*&& !rotate[0]*/;
    crop_off  <= (vcopt < 6) ? {vcopt,1'b0} : ({vcopt,1'b0} - 5'd24);
    crop_size <= (crop_ok & crop_en) ? 10'd216 : 10'd0;
end

video_freak u_crop(
    .CLK_VIDEO  ( scan2x_clk    ),
    .CE_PIXEL   ( scan2x_cen    ),
    .VGA_VS     ( scan2x_vs     ),
    .HDMI_WIDTH ( hdmi_width    ),
    .HDMI_HEIGHT( hdmi_height   ),
    .VGA_DE     ( scan2x_de     ),
    .VIDEO_ARX  ( hdmi_arx      ),
    .VIDEO_ARY  ( hdmi_ary      ),

    .VGA_DE_IN  ( raw_de        ),
    .ARX        ( raw_arx       ),
    .ARY        ( raw_ary       ),
    .CROP_SIZE  ( crop_size     ),
    .CROP_OFF   ( crop_off      ),
    .SCALE      ( crop_scale    )
);


wire rot_clk;

`ifdef JTFRAME_VERTICAL
    screen_rotate u_rotate(
        .CLK_VIDEO      ( scan2x_clk     ),
        .CE_PIXEL       ( scan2x_cen     ),

        .VGA_R          ( scan2x_r       ),
        .VGA_G          ( scan2x_g       ),
        .VGA_B          ( scan2x_b       ),
        .VGA_HS         ( scan2x_hs      ),
        .VGA_VS         ( scan2x_vs      ),
        .VGA_DE         ( scan2x_de      ),

        .rotate_ccw     (  rotate[1]     ),
        .no_rotate      ( ~rotate[0]     ),
        .flip           ( framebuf_flip  ),
        .video_rotated  ( video_rotated  ),

        .FB_EN          ( FB_EN          ),
        .FB_FORMAT      ( FB_FORMAT      ),
        .FB_WIDTH       ( FB_WIDTH       ),
        .FB_HEIGHT      ( FB_HEIGHT      ),
        .FB_BASE        ( FB_BASE        ),
        .FB_STRIDE      ( FB_STRIDE      ),
        .FB_VBL         ( FB_VBL         ),
        .FB_LL          ( FB_LL          ),

        //.debug_bus      ( debug_bus      ),

        //muxed
        .DDRAM_BUSY     ( rot_busy       ),
        .DDRAM_BURSTCNT ( rot_burstcnt   ),
        .DDRAM_ADDR     ( rot_addr       ),
        .DDRAM_BE       ( rot_be         ),
        .DDRAM_WE       ( rot_we         ),
        .DDRAM_RD       ( rot_rd         ),
        // umuxed
        .DDRAM_CLK      ( rot_clk        ), // same as clk_rom
        .DDRAM_DIN      ( DDRAM_DIN      )
    );
`else
    `ifndef JTFRAME_LF_BUFFER assign DDRAM_DIN=64'd0; `endif
    assign rot_clk = clk_rom;
`endif

`ifdef JTFRAME_LF_BUFFER
    // line-frame buffer. This won't work with fast DDR load or vertical games
    jtframe_lfbuf_ddr u_lf_buf(
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

        .ddram_clk  ( DDRAM_CLK     ),
        .ddram_busy ( DDRAM_BUSY    ),
        .ddram_addr ( DDRAM_ADDR    ),
        .ddram_dout ( DDRAM_DOUT    ),
        .ddram_rd   ( DDRAM_RD      ),
        .ddram_din  ( DDRAM_DIN     ),
        .ddram_be   ( DDRAM_BE      ),
        .ddram_we   ( DDRAM_WE      ),
        .ddram_burstcnt  ( DDRAM_BURSTCNT    ),
        .ddram_dout_ready( DDRAM_DOUT_READY  ),
        .st_addr    ( st_addr       ),
        .st_dout    ( st_lpbuf      )
    );
`else
    jtframe_mr_ddrmux u_ddrmux(
        .rst            ( rst             ),
        .clk            ( clk_rom         ),
        .ioctl_rom      ( ioctl_rom       ),
        // Fast DDR load
        .ddrld_burstcnt ( ddrld_burstcnt  ),
        .ddrld_addr     ( ddrld_addr      ),
        .ddrld_rd       ( ddrld_rd        ),
        .ddrld_busy     ( ddrld_busy      ),
        // Rotation signals
        .rot_clk        ( rot_clk         ),
        .rot_burstcnt   ( rot_burstcnt    ),
        .rot_addr       ( rot_addr        ),
        .rot_rd         ( rot_rd          ),
        .rot_we         ( rot_we          ),
        .rot_be         ( rot_be          ),
        .rot_busy       ( rot_busy        ),
        // DDR Signals
        .ddr_clk        ( DDRAM_CLK       ),
        .ddr_busy       ( DDRAM_BUSY      ),
        .ddr_burstcnt   ( DDRAM_BURSTCNT  ),
        .ddr_addr       ( DDRAM_ADDR      ),
        .ddr_rd         ( DDRAM_RD        ),
        .ddr_we         ( DDRAM_WE        ),
        .ddr_be         ( DDRAM_BE        )
    );
`endif

endmodule
