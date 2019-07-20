//============================================================================
//  Arcade: Commando  by Jose Tejada Gomez. Twitter: @topapate 
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

`timescale 1ns/1ps

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
    output        VGA_F1,

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

    //SDRAM interface with lower latency
    output        SDRAM_CLK,
    output        SDRAM_CKE,
    output [12:0] SDRAM_A,
    output  [1:0] SDRAM_BA,
    inout  [15:0] SDRAM_DQ,
    output        SDRAM_DQML,
    output        SDRAM_DQMH,
    output        SDRAM_nCS,
    output        SDRAM_nCAS,
    output        SDRAM_nRAS,
    output        SDRAM_nWE
    `ifdef SIMULATION
    ,output         sim_pxl_cen,
    output          sim_pxl_clk,
    output          sim_vs,
    output          sim_hs
    `endif
);

`include "build_id.v" 
localparam CONF_STR = {
    "A.COM;;", 
    "-;",
    "F,rom;",
    "O1,Aspect Ratio,Original,Wide;",
    "O2,Orientation,Vert,Horz;",
    "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",

    "-;",
    "OCD,Difficulty,Normal,Easy,Hard,Very hard;",
    // "O67,Lives,3,1,2,5;",
    // "O89,Bonus,30/100,30/80,20/100,20/80;",
    "OA,Invulnerability,No,Yes;",
    "-;",
    "R0,Reset;",
    "J,Fire,Bomb,Start 1P,Start 2P,Coin,Pause;",
    "V,v",`BUILD_DATE, " http://patreon.com/topapate;"
};

assign VGA_F1=1'b0;

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire cen12, cen6, cen3, cen1p5;
wire pll_locked;

pll pll(
    .refclk     ( CLK_50M    ),
    .rst        ( 1'b0       ),
    .locked     ( pll_locked ),
    .outclk_0   ( clk_sys    ),
    .outclk_1   ( SDRAM_CLK  )
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_data;

wire [10:0] ps2_key;

wire [15:0] joy_0, joy_1;

wire        forced_scandoubler;
wire        downloading;

assign LED_USER  = downloading;
assign LED_DISK  = 2'b0;
assign LED_POWER = 2'b0;

assign HDMI_ARX = status[1] ? 8'd16 : status[2] ? 8'd4 : 8'd3;
assign HDMI_ARY = status[1] ? 8'd9  : status[2] ? 8'd3 : 8'd4;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
    .clk_sys    ( clk_sys       ),
    .HPS_BUS    ( HPS_BUS       ),

    .conf_str   ( CONF_STR      ),

    .buttons    ( buttons       ),
    .status     ( status        ),
    .forced_scandoubler(forced_scandoubler),

    .ioctl_download(downloading),
    .ioctl_wr   ( ioctl_wr      ),
    .ioctl_addr ( ioctl_addr    ),
    .ioctl_dout ( ioctl_data    ),

    .joystick_0 ( joy_0         ),
    .joystick_1 ( joy_1         ),
    .ps2_key    ( ps2_key       )
);


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
reg btn_test  = 0;

wire       pressed = ps2_key[9];
wire [7:0] code    = ps2_key[7:0];
always @(posedge clk_sys) begin
    reg old_state;
    old_state <= ps2_key[10];
    
    if(old_state != ps2_key[10]) begin
        case(code)
            'h75: btn_up         <= pressed; // up
            'h72: btn_down       <= pressed; // down
            'h6B: btn_left       <= pressed; // left
            'h74: btn_right      <= pressed; // right
            'h05: btn_one_player <= pressed; // F1
            'h06: btn_two_players<= pressed; // F2
            'h04: btn_coin       <= pressed; // F3
            'h0C: btn_pause      <= pressed; // F4
            'h03: btn_test       <= pressed; // F5
            'h14: btn_fire1      <= pressed; // ctrl
            'h11: btn_fire1      <= pressed; // alt
            'h29: btn_fire2      <= pressed; // Space
        endcase
    end
end

reg m_up, m_down, m_left, m_right, m_fire, m_jump, m_pause;
reg m_start1, m_start2, m_coin;
reg m2_up, m2_down, m2_left, m2_right, m2_fire, m2_jump;

always @(posedge clk_sys) begin
    m_up     <= ~(btn_up    | joy_0[3]);
    m_down   <= ~(btn_down  | joy_0[2]);
    m_left   <= ~(btn_left  | joy_0[1]);
    m_right  <= ~(btn_right | joy_0[0]);
    m_fire   <= ~(btn_fire1 | joy_0[4]);
    m_jump   <= ~(btn_fire2 | joy_0[5]);
    m_pause  <= ~(btn_pause | joy_0[9]);
    m_start1 <= ~(btn_one_player  | joy_0[6]);
    m_start2 <= ~(btn_two_players | joy_0[7]);
    m_coin   <= ~(btn_coin        | joy_0[8]);
    m2_up    <= ~joy_1[3];
    m2_down  <= ~joy_1[2];
    m2_left  <= ~joy_1[1];
    m2_right <= ~joy_1[0];
    m2_fire  <= ~joy_1[4];
    m2_jump  <= ~joy_1[5];
end

`ifndef NOMAIN
reg pause = 0;
always @(posedge clk_sys) begin
    reg old_pause;
    
    old_pause <= m_pause;
    if(~old_pause & m_pause) pause <= ~pause;
    if(status[0] | buttons[1]) pause <= 1;
end
`else 
wire pause = 1;  // fast synthesis, NO CPUs
`endif

wire [1:0] dip_lives=2'b10;
wire       dip_level=1'b1;

///////////////////////////////////////////////////////////////////

wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b;

`ifndef SIMULATION
arcade_rotate_fx #(256,224,12,1) arcade_video
(
    .*,

    .clk_video(clk_sys),
    .ce_pix(cen6),

    .RGB_in({r,g,b}),
    .HBlank(~hblank),
    .VBlank(~vblank),
    .HSync(hs),
    .VSync(vs),
    
    .fx(status[5:3]),
    .no_rotate(status[2])
);
`else 
    assign VGA_VS = vs;
    assign VGA_HS = hs;
    assign VGA_R  = r;
    assign VGA_G  = g;
    assign VGA_B  = b;
    assign VGA_CE = cen6;
    assign VGA_CLK= clk_sys;
`endif

///////////////////////////////////////////////////////////////////

wire reset = RESET | status[0] | buttons[1];
// reg [1:0] rstsr;
// wire reset = rstsr[1];
// 
// always @(negedge clk_sys) begin
//     if( RESET || status[0] || buttons[1] || !pll_locked ) rstsr <= 2'b11;
//     else rstsr <= { rstsr[0], 1'b0 };
// end

wire         prog_we;
wire [21:0]  prog_addr;
wire [ 7:0]  prog_data;
wire [ 1:0]  prog_mask;

// SDRAM
wire         loop_rst;
wire         sdram_req;
wire [31:0]  data_read;
wire [21:0]  sdram_addr;
wire         data_rdy;
wire         sdram_ack;
wire         refresh_en;

jtgng_sdram u_sdram(
    .rst        ( RESET         ),
    .clk        ( clk_sys       ), // 48 MHz
    .loop_rst   ( loop_rst      ),
    .read_req   ( sdram_req     ),
    .data_read  ( data_read     ),
    .data_rdy   ( data_rdy      ),
    .refresh_en ( refresh_en    ),
    // ROM-load interface
    .downloading( downloading   ),
    .prog_we    ( prog_we       ),
    .prog_addr  ( prog_addr     ),
    .prog_data  ( prog_data     ),
    .prog_mask  ( prog_mask     ),
    .sdram_addr ( sdram_addr    ),
    .sdram_ack  ( sdram_ack     ),
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
    .SDRAM_CKE  ( SDRAM_CKE     ) 
);

wire [1:0] dip_upright = 2'b00;
wire dip_demosnd = 1'b0;
wire dip_flip    = 1'b0;
wire [1:0] dip_price2 = 2'b11;
wire [1:0] dip_price1 = 2'b11;

`ifdef SIMULATION
assign sim_pxl_clk = clk_sys;
assign sim_pxl_cen = cen6;
`endif

jtcommando_game #(.CLK_SPEED(48)) game
(
    .rst           ( reset           ),

    .clk           ( clk_sys         ),
    .cen12         ( cen12           ),
    .cen6          ( cen6            ),
    .cen3          ( cen3            ),
    .cen1p5        ( cen1p5          ),

    .red           ( r               ),
    .green         ( g               ),
    .blue          ( b               ),
    .LHBL          ( hblank          ),
    .LVBL          ( vblank          ),
    .HS            ( hs              ),
    .VS            ( vs              ),

    .start_button  ( {m_start2, m_start1} ),
    .coin_input    ( {1'b0, m_coin}       ),
    .joystick1     ( {m_jump, m_fire, m_up, m_down, m_left, m_right} ),
    .joystick2     ( {m2_jump, m2_fire, m2_up, m2_down, m2_left, m2_right} ),

    // PROM programming
    .ioctl_addr   ( ioctl_addr[21:0] ),
    .ioctl_data   ( ioctl_data       ),
    .ioctl_wr     ( ioctl_wr         ),
    .prog_addr    ( prog_addr        ),
    .prog_data    ( prog_data        ),
    .prog_mask    ( prog_mask        ),
    .prog_we      ( prog_we          ),

    // ROM load
    .downloading  ( downloading      ),
    .loop_rst     ( loop_rst         ),
    .sdram_req    ( sdram_req        ),
    .sdram_addr   ( sdram_addr       ),
    .data_read    ( data_read        ),
    .sdram_ack    ( sdram_ack        ),
    .data_rdy     ( data_rdy         ),
    .refresh_en   ( refresh_en       ),

    // DIP switches
    .dip_pause    ( pause            ),
    .dip_lives    ( dip_lives        ),
    .dip_level    ( dip_level        ),
    .dip_start    ( 2'b11            ),
    .dip_price1   ( dip_price1       ),
    .dip_price2   ( dip_price2       ),
    .dip_bonus    ( 3'b111           ),
    .dip_upright  ( dip_upright      ), // upright, one joystick
    .dip_demosnd  ( dip_demosnd      ),
    .dip_flip     ( dip_flip         ),

    .snd          ( AUDIO_L          ),
    .gfx_en       ( ~4'b0            ),

    // unconnected
    .sample       (                  )
);

assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 1;

endmodule
