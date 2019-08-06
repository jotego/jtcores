//============================================================================
//  Arcade: Ghosts'n'Goblins  by Jose Tejada Gomez. Twitter: @topapate 
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
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

module emu
(
    //Master input clock
    input         CLK_50M,

    //Async reset from top-level module.
    //Can be used as initial reset.
    input         RESET,

    //Must be passed to hps_io module
    inout  [44:0] HPS_BUS,

    //Base video clock. Usually equals to CLK_SYS.
    output        VGA_CLK,

    //Multiple resolutions are supported using different VGA_CE rates.
    //Must be based on CLK_VIDEO
    output        VGA_CE,

    output  [7:0] VGA_R,
    output  [7:0] VGA_G,
    output  [7:0] VGA_B,
    output        VGA_HS,
    output        VGA_VS,
    output        VGA_DE,    // = ~(VBlank | HBlank)

    //Base video clock. Usually equals to CLK_SYS.
    output        HDMI_CLK,

    //Multiple resolutions are supported using different HDMI_CE rates.
    //Must be based on CLK_VIDEO
    output        HDMI_CE,

    output  [7:0] HDMI_R,
    output  [7:0] HDMI_G,
    output  [7:0] HDMI_B,
    output        HDMI_HS,
    output        HDMI_VS,
    output        HDMI_DE,   // = ~(VBlank | HBlank)
    output  [1:0] HDMI_SL,   // scanlines fx

    //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
    output  [7:0] HDMI_ARX,
    output  [7:0] HDMI_ARY,

    output        LED_USER,  // 1 - ON, 0 - OFF.

    // b[1]: 0 - LED status is system status OR'd with b[0]
    //       1 - LED status is controled solely by b[0]
    // hint: supply 2'b00 to let the system control the LED.
    output  [1:0] LED_POWER,
    output  [1:0] LED_DISK,

    output [15:0] AUDIO_L,
    output [15:0] AUDIO_R,
    output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned

    output  [1:0] ROTATE

    `ifdef SIMULATION
    ,output         sim_pxl_cen,
    output          sim_pxl_clk,
    output          sim_vs,
    output          sim_hs
    `endif
);

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : 8'd4;
assign HDMI_ARY = status[1] ? 8'd9  : 8'd3;

`include "build_id.v" 
localparam CONF_STR1 = {
    "A.GnG;;", 
    "-;",
    "F,rom;",
    "O1,Aspect Ratio,Original,Wide;",
    "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;", 
    "-;",
    "OF,Test mode,No,Yes;",
    "O89,Lives,3,4,5,7;",
    "OAB,+1 Life,20K 70K Every 70K,30K 80K Every 80K,20K and 80K Only,30K and 80K Only;",
    "OCD,Difficulty,Normal,Easy,Hard,Very Hard;"
};

localparam CONF_STR2 = {
//  "E,Invulnerable,No,Yes;",
    "-;",
    "O6,PSG,Enabled,Disabled;",
    "O7,FM,Enabled,Disabled;",
    "-;",
    "R0,Reset;",
    "J,Fire,Jump,Start 1P,Start 2P,Coin;",
    "V,v",`BUILD_DATE, " http://patreon.com/topapate;"
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys, pll_locked;

pll pll
(
    .refclk     ( CLK_50M    ),
    .rst        ( 1'b0       ),
    .locked     ( pll_locked ),
    .outclk_0   ( clk_sys    ), // 48 MHz
    .outclk_1   (            )
);

reg cen6, cen3, cen1p5;

reg pxl_cen=1'b0;
always @(negedge clk_sys) begin
    pxl_cen <= ~pxl_cen;
end

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire [10:0] ps2_key;

wire  [8:0] joy_0, joy_1;

wire        forced_scandoubler;

hps_io #(.STRLEN(($size(CONF_STR1)>>3) + ($size(CONF_STR2)>>3) + 1)) hps_io
(
    .clk_sys(clk_sys),
    .HPS_BUS(HPS_BUS),

    .conf_str({CONF_STR1,inv_ena ? "O" : "+",CONF_STR2}),

    .buttons(buttons),
    .status(status),
    .forced_scandoubler(forced_scandoubler),

    .ioctl_download(ioctl_download),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),

    .joystick_0(joy_0),
    .joystick_1(joy_1),
    .ps2_key(ps2_key)
);

wire       pressed = ps2_key[9];
wire [7:0] code    = ps2_key[7:0];

reg btn_one_player = 0;
reg btn_two_players = 0;
reg btn_left = 0;
reg btn_right = 0;
reg btn_down = 0;
reg btn_up = 0;
reg btn_fire1 = 0;
reg btn_fire2 = 0;
reg btn_coin  = 0;
reg btn_pause = 0;

always @(posedge clk_sys) begin
    reg old_state;
    old_state <= ps2_key[10];
    
    if(old_state != ps2_key[10]) begin
        case(code)
            'h75: btn_up            <= pressed; // up
            'h72: btn_down          <= pressed; // down
            'h6B: btn_left              <= pressed; // left
            'h74: btn_right         <= pressed; // right
            'h05: btn_one_player    <= pressed; // F1
            'h06: btn_two_players   <= pressed; // F2
            'h04: btn_coin              <= pressed; // F3
            'h0C: btn_pause     <= pressed; // F4
            'h14: btn_fire1             <= pressed; // ctrl
            'h11: btn_fire1             <= pressed; // alt
            'h29: btn_fire2         <= pressed; // Space
        endcase
    end
end

wire [9:0] joy = joy_0 | joy_1;

wire m_up     = btn_up    | joy[3];
wire m_down   = btn_down  | joy[2];
wire m_left   = btn_left  | joy[1];
wire m_right  = btn_right | joy[0];
wire m_fire   = btn_fire1 | joy[4];
wire m_jump   = btn_fire2 | joy[5];
wire m_pause  = btn_pause | joy[9];

wire m_start1 = btn_one_player  | joy[6];
wire m_start2 = btn_two_players | joy[7];
wire m_coin   = btn_coin        | joy[8];

reg pause = 0;
always @(posedge clk_sys) begin
    reg old_pause;
    
    old_pause <= m_pause;
    if(~old_pause & m_pause) pause <= ~pause;
    if(status[0] | buttons[1]) pause <= 0;
end

///////////////////////////////////////////////////////////////////


wire [3:0] R,G,B;
wire HSync,VSync,HBlank,VBlank;

assign VGA_CLK  = clk_sys;
assign HDMI_CLK = VGA_CLK;
assign HDMI_CE  = VGA_CE;
assign HDMI_R   = VGA_R;
assign HDMI_G   = VGA_G;
assign HDMI_B   = VGA_B;
assign HDMI_DE  = VGA_DE;
assign HDMI_HS  = VGA_HS;
assign HDMI_VS  = VGA_VS;
assign HDMI_SL  = sl[1:0];

wire [2:0] scale = status[5:3];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler); 

wire [1:0]    dip_level = ~status[13:12];
wire [1:0]    dip_lives = ~status[9:8];
wire [1:0]    dip_bonus = ~status[11:10];
wire          dip_test  = ~status[15];

video_mixer #(.LINE_LENGTH(256), .HALF_DEPTH(1)) video_mixer
(
    .*,
    .clk_sys   ( VGA_CLK    ),
    .ce_pix    ( pxl_cen    ),
    .ce_pix_out( VGA_CE     ),

    .scanlines ( 0          ),
    .hq2x      ( scale==1   ),
    .mono      ( 0          ),
    
    .HBlank    ( ~HBlank    ),
    .VBlank    ( ~VBlank    )
);

jtgng_game u_game
(
    .rst(RESET | ioctl_download),
    .soft_rst(status[0] | buttons[1]),
    .clk        ( clk_sys   ),
    .cen12      (           ),
    .cen6       ( cen6      ),
    .cen3       ( cen3      ),
    .cen1p5     ( cen1p5    ),
    .red        ( R         ),
    .green      ( G         ),
    .blue       ( B         ),
    .LHBL       ( HBlank    ),
    .LVBL       ( VBlank    ),
    .HS         ( HSync     ),
    .VS         ( VSync     ),

    .joystick1  (~{m_jump,m_fire,m_up,m_down,m_left,m_right}),
    .joystick2  (~{m_jump,m_fire,m_up,m_down,m_left,m_right}),
    .start_button(~{m_start2,m_start1}),
    .coin_input (~{1'b0,m_coin}),

    .romload_clk    ( clk_sys          ),
    .romload_wr     ( ioctl_wr         ),
    .romload_addr   ( ioctl_addr[18:0] ),
    .romload_data   ( ioctl_dout       ),

    .enable_char    ( 1                ),
    .enable_scr     ( 1                ),
    .enable_obj     ( 1                ),

//  .dipsw({~inv_ena | ~status[14],~status[13:12],~status[11:10],1'b0,~status[9:8],4'h5,{4{status[15]}}}),
    // DIP switches
    .dip_pause      ( ~pause     ),
    .dip_lives      ( dip_lives  ),
    .dip_level      ( dip_level  ),
    .dip_bonus      ( dip_bonus  ),
    .dip_game_mode  ( dip_test   ),
    .dip_upright    ( 1'b1       ),
    .dip_attract_snd( 1'b0       ), // 0 for sound

    .enable_psg     ( ~status[6] ),
    .enable_fm      ( ~status[7] ),
    .ym_snd         ( AUDIO_L    )
);

assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 1;


reg inv_ena = 0;
always @(posedge clk_sys) begin
    reg [3:0] flg;
    if(ioctl_wr) begin
        if(ioctl_addr == 0) flg[0] <= (ioctl_dout == 'h10);
        if(ioctl_addr == 1) flg[1] <= (ioctl_dout == 'h83);
        if(ioctl_addr == 2) flg[2] <= (ioctl_dout == 'h00);
        if(ioctl_addr == 3) flg[3] <= (ioctl_dout == 'h80);
    end
    
    inv_ena <= &flg;
end

endmodule
