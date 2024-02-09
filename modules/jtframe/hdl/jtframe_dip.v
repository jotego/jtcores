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
    Date: 20-10-2019 */

module jtframe_dip(
    input              clk,
    input      [63:0]  status,
    input      [ 6:0]  core_mod,
    input              game_pause,

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    output reg [12:0]  hdmi_arx,
    output reg [12:0]  hdmi_ary,
    output reg [ 1:0]  rotate,
    output             rot_control, // rotate player control inputs
    output reg         en_mixing,
    output reg [ 2:0]  scanlines,
    output reg         bw_en,
    output reg         blend_en,

    output reg         enable_fm,
    output reg         enable_psg,
    output             osd_pause,
    input              osd_shown,

    input              game_test,
    output             dip_test,
    // non standard:
    output reg         dip_pause,
    inout              dip_flip,    // this might be set by the core
    output reg [ 1:0]  dip_fxlevel
);

// "T0,RST;", // 15
// "O1,Pause,OFF,ON;",
// "-;",
// "F,rom;",
// "O2,Aspect Ratio,Original,Wide;",
// "OD,Original screen,No,Yes;",
// "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;", -- MiSTer
// "O34,Video Mode, pass thru, linear, analogue, dark;",  -- MiST
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
        assign dip_test = ~game_test;
        `endif
    `else
        assign dip_test = ~(status[10] | game_test); // assumes it is always active low
    `endif
`else
assign dip_test = ~game_test;
`endif

wire [1:0] ar = status[17:16];    // only MiSTer
`ifdef MISTER
always @(*) begin
    scanlines = status[5:3];
`ifdef JTFRAME_OSD60HZ
    if ( !status[19] ) scanlines=0;
`endif
    bw_en     = 0;      // Old TV filter disabled in MiSTer, is not needed anymore
    blend_en  = 0;
end
`else
always @(*) begin
    case( status[4:3] )
        2'd0: { scanlines, bw_en, blend_en } = { 3'd0, 2'd0 }; // pass thru
        2'd1: { scanlines, bw_en, blend_en } = { 3'd0, 2'd1 }; // no scanlines, linear interpolation
        2'd2: { scanlines, bw_en, blend_en } = { 3'd0, 2'd3 }; // analogue
        2'd3: { scanlines, bw_en, blend_en } = { 3'd1, 2'd3 }; // analogue + scan lines
    endcase // status[4:3]
    `ifdef JTFRAME_FEEDTHRU
    { scanlines, bw_en, blend_en } = { 3'd0, 2'd0 }; `endif
end
`endif

`ifdef POCKET
    assign osd_pause = osd_shown;
`else
    `ifndef JTFRAME_OSD_NOCREDITS
        `ifndef MISTER // Only MiST and derivatives can pause via the OSD
            assign osd_pause   = status[12];
        `else
            assign osd_pause   = 1'b0;  // MiSTer relies on the keyboard/gamepad for pause
        `endif
    `else
        assign osd_pause = 1'b0;
    `endif
`endif

// Screen or control rotation
`ifdef JTFRAME_VERTICAL
    // core_mod[0] = 0 horizontal game
    //             = 1 vertical game
    // core_mod[2] = XOR with dip_flip
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
        assign tate = (!MISTER || status_roten) && core_mod[0]; // 1 if screen is vertical (tate in Japanese)
        assign rot_control = 1'b0;
    end else begin // MiST derivativatives are always vertical
        assign tate   = 1'b1 & core_mod[0];
        assign rot_control = status[2];
    end
endgenerate
    wire   swap_ar = ~tate | ~core_mod[0];
`else
    wire   tate   = 1'b0;
    assign rot_control = 1'b0;
    wire   swap_ar = 1'b1;
`endif

// all signals that are not direct re-wirings are latched
always @(posedge clk) begin
    rotate      <= { dip_flip ^ core_mod[2], tate && !rot_control }; // rotate[1] keeps the image upright regardless of dip_flip
    dip_fxlevel <= 2'b10 ^ status[7:6];
    en_mixing   <= ~status[3];
    `ifndef JTFRAME_OSD_SND_EN
    enable_fm   <= 1;
    enable_psg  <= 1;
    `else
    enable_fm   <= ~status[9];
    enable_psg  <= ~status[8];
    `endif
    // only for MiSTer
    hdmi_arx    <= (!ar) ? (swap_ar ? ARX : ARY) : (ar-2'd1);
    hdmi_ary    <= (!ar) ? (swap_ar ? ARY : ARX) : 13'd0;

    `ifdef SIMULATION
        `ifdef DIP_PAUSE
            dip_pause <= 1'b0; // use to simulate pause screen
        `else
            dip_pause <= 1'b1; // avoid having the main CPU halted in simulation
        `endif
    `else
        dip_pause <= ~game_pause; // all dips are active low
    `endif
end

endmodule