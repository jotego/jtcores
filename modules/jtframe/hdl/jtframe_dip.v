/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-10-2019 */

module jtframe_dip(
    input              clk,
    input      [63:0]  status,
    input              game_pause,
                       vertical, dipflip_xor,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    output reg [12:0]  hdmi_arx,
    output reg [12:0]  hdmi_ary,
    output reg [ 1:0]  rotate,
    output reg         rot_osdonly,
    output reg         rot_control, // rotate player control inputs

    output reg         osd_pause,
    input              osd_shown,

    input              game_test,
    output             dip_test,
    // non standard:
    output reg         dip_pause,
    inout              dip_flip,    // this might be set by the core
    output reg [ 1:0]  dip_fxlevel
);

parameter XOR_ROT=0;

// "T0,RST;", // 15
// "O1,Pause,OFF,ON;",
// "-;",
// "F,rom;",
// "O2,Aspect Ratio,Original,Wide;",
// "OD,Original screen,No,Yes;",
// "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;", -- MiSTer
// "O34,Video Mode, pass thru, linear, analogue, scanlines;",  -- MiST
// "O6,Test mode,OFF,ON;",
// "O7,PSG,ON,OFF;",
// "O8,FM ,ON,OFF;",
// "O3,Screen filter,ON,OFF;",
// "OAB,FX volume, high, very high, very low, low;",
// core-specific settings should start at letter G (i.e. 16)

localparam MISTER= `ifdef MISTER 1 `else 0 `endif;
localparam POCKET= `ifdef POCKET 1 `else 0 `endif;

`ifdef JTFRAME_ARX
localparam [12:0] ARX = `JTFRAME_ARX;
`else
localparam [12:0] ARX = 13'd4;
`endif

`ifdef JTFRAME_ARY
localparam [12:0] ARY = `JTFRAME_ARY;
`else
localparam [12:0] ARY = 13'd3;
`endif

`ifdef JTFRAME_OSD_FLIP
assign dip_flip    = ~status[1];
`endif

`ifdef JTFRAME_OSD_TEST
    `ifdef SIMULATION
        `ifdef DIP_TEST
        assign dip_test = 0;
        `else
        assign dip_test = game_test;
        `endif
    `else
        assign dip_test = ~status[10] & game_test; // assumes it is always active low
    `endif
`else
assign dip_test = game_test;
`endif

wire [1:0] ar = status[17:16];    // only MiSTer

// Screen or control rotation
`ifdef JTFRAME_VERTICAL
    // status[13]  = 0 Rotate screen
    //             = 1 no rotation
    wire tate;
generate
    if ( MISTER || POCKET ) begin
        `ifdef JTFRAME_ROTATE
            wire status_roten= status[40:39]==0;
        `else
            wire status_roten= ~status[2];
        `endif
        assign tate = (!MISTER || status_roten) && vertical; // 1 if screen is vertical (tate in Japanese)
        initial rot_control = 0;
        initial rot_osdonly = 0;
    end else begin // MiST derivativatives are always vertical
        assign tate   = vertical;
        always @(posedge clk) begin
            rot_control <= (status[2]^XOR_ROT[0]) & tate & rot_osdonly;
            rot_osdonly <= !status[13];
        end
    end
endgenerate
    wire   swap_ar = ~tate | ~vertical;
`else
    wire    tate        = 0;
    initial rot_control = 0;
    initial rot_osdonly = 0;
    wire    swap_ar     = 1;
`endif

initial osd_pause = 0;
`ifndef JTFRAME_OSD_NOCREDITS
`ifndef MISTER // Only MiST and derivatives can pause via the OSD
always @* begin
        osd_pause = status[12];
end
`endif
`endif

// all signals that are not direct re-wirings are latched
always @(posedge clk) begin
    rotate      <= { dip_flip ^ dipflip_xor, tate && !rot_control }; // rotate[1] keeps the image upright regardless of dip_flip
    dip_fxlevel <= 2'b10 ^ status[7:6];
    // only for MiSTer
    hdmi_arx    <= ar==0 ? (swap_ar ? ARX : ARY) : {11'd0,ar-2'd1};
    hdmi_ary    <= ar==0 ? (swap_ar ? ARY : ARX) : 13'd0;

    dip_pause   <= ~game_pause & ~osd_shown; // active low
    `ifdef SIMULATION
        `ifdef DIP_PAUSE
            dip_pause <= 1'b0; // use to simulate pause screen
        `else
            dip_pause <= 1'b1; // avoid having the main CPU halted in simulation
        `endif
    `endif
end

endmodule
