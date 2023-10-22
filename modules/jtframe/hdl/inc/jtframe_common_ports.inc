// standard game interface for JTFRAME based
// games. The different configurations are
// enabled via macros defined in cfg/macros.def
    input           rst,
    input           clk,        // always matched to the SDRAM clock
`ifdef JTFRAME_CLK6
    input           rst6,  clk6,
`endif
`ifdef JTFRAME_CLK24
    input           rst24, clk24,
`endif
`ifdef JTFRAME_CLK48
    input           rst48, clk48,
`endif
`ifdef JTFRAME_CLK96
    input           rst96, clk96,
`endif
`ifdef JTFRAME_PXLCLK
    input           pxl2_cen, pxl_cen,
`else
    output          pxl2_cen, pxl_cen,
`endif
    output   [`JTFRAME_COLORW-1:0]  red, green, blue,
    output          LHBL, LVBL, HS, VS,
    output          game_led,
    // cabinet I/O
`ifdef JTFRAME_4PLAYERS
    input   [ 3:0]  cab_1p, coin,
    input   [`JTFRAME_BUTTONS+3:0] joystick1, joystick2, joystick3, joystick4,
`else
    input   [ 1:0]  cab_1p, coin,
    input   [`JTFRAME_BUTTONS+3:0] joystick1, joystick2,
`endif
`ifdef JTFRAME_PADDLE
    input   [ 7:0]  paddle_0, paddle_1, `ifdef JTFRAME_4PLAYERS paddle_2, paddle_3, `endif
`endif
`ifdef JTFRAME_DIAL
    input   [ 1:0]  dial_x, dial_y,
`endif
`ifdef JTFRAME_MOUSE
    input   [15:0]  mouse_1p, mouse_2p,
`endif
`ifdef JTFRAME_SPINNER
    input   [ 7:0]  spinner_1p, spinner_2p,
`endif
`ifdef JTFRAME_ANALOG
    input   [15:0]  joyana_l1, joyana_l2,
    `ifdef JTFRAME_ANALOG_DUAL
        input   [15:0]  joyana_r1, joyana_r2,
    `endif
    `ifdef JTFRAME_4PLAYERS
        input   [15:0]  joyana_l3, joyana_l4,
        `ifdef JTFRAME_ANALOG_DUAL
            input   [15:0]  joyana_r3, joyana_r4,
        `endif
    `endif
`endif
    // Sound control
    input           enable_fm, enable_psg,
    // DIP switches
    input   [31:0]  status, dipsw,
    input           dip_pause, dip_test, service, tilt,
`ifdef JTFRAME_OSD_FLIP // splits the declaration because verilator doesn't handle the inout well
    input           dip_flip,
`else
    output           dip_flip,
`endif
    input   [ 1:0]  dip_fxlevel,
`ifdef JTFRAME_GAME_UART
    output          uart_tx,
    input           uart_rx,
`endif
    // Sound output
`ifndef JTFRAME_STEREO
    output  signed [15:0] snd,
`else
    output  signed [15:0] snd_left, snd_right,
`endif
    output          sample,
    // Debug
`ifdef JTFRAME_STATUS
    input      [7:0] st_addr,
    output     [7:0] st_dout,
`endif
    input   [3:0]   gfx_en,
    input      [7:0] debug_bus,
    output     [7:0] debug_view,
    // the most common case is the register
    // Line-frame buffer for object drawing, supported only
    // on PocketFPGA and MiSTer. It could be added to NeptUNO too
`ifdef JTFRAME_LF_BUFFER
    output   [ 7:0] game_vrender,
    output   [ 8:0] game_hdump,
    output   [ 8:0] ln_addr,
    output   [15:0] ln_data,
    output          ln_done,
    output          ln_we,
    input           ln_hs,
    input    [15:0] ln_pxl,
    input    [ 7:0] ln_v,
`endif
