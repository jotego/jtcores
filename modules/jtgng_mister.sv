//============================================================================
//  Arcade: CAPCOM pre-CPS hardware  by Jose Tejada Gomez. Twitter: @topapate
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

    output  [1:0] ROTATE,

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

// Config string
`include "build_id.v"
`define SEPARATOR "-;",
`include "conf_str.v"

`ifdef SIMULATION
localparam CONF_STR="JTGNG;;";
`else
localparam CONF_STR = {
    `CORENAME,";;",
    "O1,Pause,OFF,ON;",
    `SEPARATOR
    // Common MiSTer options
    "F,rom;",
    "O2,Aspect Ratio,Original,Wide;",
    `ifdef VERTICAL_SCREEN
    "OD,Rotate screen,Yes,No;",
    "OC,Flip screen,OFF,ON;",
    `endif
    "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
    `ifdef HAS_TESTMODE
    "O6,Test mode,OFF,ON;",
    `endif
    "O7,PSG,ON,OFF;",
    `ifdef JT12
    "O8,FM ,ON,OFF;",
    "OAB,FX volume, high, very high, very low, low;",
    `endif
    `SEPARATOR
    `CORE_OSD
    // "J,Button 1,Button 2,1P Start,2P Start,Coin;",
    "R0,RST;",
    "V,v",`BUILD_DATE," patreon.com/topapate;"
};
`endif

`undef SEPARATOR

assign VGA_F1=1'b0;

////////////////////   CLOCKS   ///////////////////

wire clk_sys;
wire cen12, cen6, cen3, cen1p5;
wire pll_locked;
reg  pll_rst = 1'b0;

// Resets the PLL if it looses lock
always @(posedge clk_sys or posedge RESET) begin : pll_controller
    reg last_locked;
    reg [7:0] rst_cnt;

    if( RESET ) begin
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

pll pll(
    .refclk     ( CLK_50M    ),
    .rst        ( pll_rst    ),
    .locked     ( pll_locked ),
    .outclk_0   ( clk_sys    ),
    .outclk_1   ( SDRAM_CLK  )
);

///////////////////////////////////////////////////

wire [31:0] status;
wire [ 1:0] buttons;

wire [7:0] dipsw_a, dipsw_b;
wire [1:0] dip_fxlevel;
wire       enable_fm, enable_psg;
wire       dip_pause, dip_flip, dip_test;
wire [2:0] scanlines; // MiSTer

wire        ioctl_wr;
wire [21:0] ioctl_addr;
wire [ 7:0] ioctl_data;

wire [ 9:0] game_joystick1, game_joystick2;
wire [ 1:0] game_coin, game_start;
wire [ 3:0] gfx_en;

wire        force_scan2x;
wire        downloading, game_rst, rst, rst_n;
wire        rst_req   = RESET | status[0] | buttons[1];


assign LED_DISK  = 2'b0;
assign LED_POWER = 2'b0;

// SDRAM
wire         loop_rst;
wire         sdram_req;
wire [31:0]  data_read;
wire [21:0]  sdram_addr;
wire         data_rdy;
wire         sdram_ack;
wire         refresh_en;

wire         prog_we;
wire [21:0]  prog_addr;
wire [ 7:0]  prog_data;
wire [ 1:0]  prog_mask;

jtframe_mister #( .CONF_STR(CONF_STR),
    .SIGNED_SND(1'b1), .THREE_BUTTONS(1'b1))
u_frame(
    .clk_sys        ( clk_sys        ),
    .clk_rom        ( clk_sys        ),
    .pll_locked     ( pll_locked     ),
    // interface with microcontroller
    .status         ( status         ),
    .HPS_BUS        ( HPS_BUS        ),
    .buttons        ( buttons        ),
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
    // ROM load
    .ioctl_addr     ( ioctl_addr     ),
    .ioctl_data     ( ioctl_data     ),
    .ioctl_wr       ( ioctl_wr       ),
    .prog_addr      ( prog_addr      ),
    .prog_data      ( prog_data      ),
    .prog_mask      ( prog_mask      ),
    .prog_we        ( prog_we        ),
    .downloading    ( downloading    ),
    // ROM access from game
    .loop_rst       ( loop_rst       ),
    .sdram_addr     ( sdram_addr     ),
    .sdram_req      ( sdram_req      ),
    .sdram_ack      ( sdram_ack      ),
    .data_read      ( data_read      ),
    .data_rdy       ( data_rdy       ),
    .refresh_en     ( refresh_en     ),
//////////// board
    .rst            ( rst            ),
    .rst_n          ( rst_n          ), // unused
    .game_rst       ( game_rst       ),
    .game_rst_n     (                ),
    // reset forcing signals:
    .rst_req        ( rst_req        ),
    // joystick
    .game_joystick1 ( game_joystick1 ),
    .game_joystick2 ( game_joystick2 ),
    .game_coin      ( game_coin      ),
    .game_start     ( game_start     ),
    .game_service   (                ), // unused
    .LED            ( /*LED_USER*/       ),
    // DIP and OSD settings
    .hdmi_arx       ( HDMI_ARX       ),
    .hdmi_ary       ( HDMI_ARY       ),
    .enable_fm      ( enable_fm      ),
    .enable_psg     ( enable_psg     ),
    .dip_test       ( dip_test       ),
    .dip_pause      ( dip_pause      ),
    .dip_flip       ( dip_flip       ),
    .dip_fxlevel    ( dip_fxlevel    ),
    // screen
    .rotate         ( ROTATE         ),
    .en_mixing      (                ),
    .scanlines      ( scanlines      ),
    .force_scan2x   ( force_scan2x   ),
    // Debug
    .gfx_en         ( gfx_en         )
);
assign LED_USER = ROTATE[0];
///////////////////////////////////////////////////////////////////

wire hblank, vblank;
wire hs, vs;
wire [3:0] r,g,b;

`ifndef SIM_SKIP_SCAN2X
    `ifdef VERTICAL_SCREEN
        arcade_rotate_fx #(.WIDTH(256),.HEIGHT(224),.DW(12),.CCW(1)) 
        u_rotate_fx(
            .clk_video  ( clk_sys   ),
            .ce_pix     ( cen6      ),
        
            .RGB_in     ( {r,g,b}   ),
            .HBlank     ( hblank    ),
            .VBlank     ( vblank    ),
            .HSync      ( hs        ),
            .VSync      ( vs        ),
        
            .VGA_CLK    (  VGA_CLK  ),
            .VGA_CE     (  VGA_CE   ),
            .VGA_R      (  VGA_R    ),
            .VGA_G      (  VGA_G    ),
            .VGA_B      (  VGA_B    ),
            .VGA_HS     (  VGA_HS   ),
            .VGA_VS     (  VGA_VS   ),
            .VGA_DE     (  VGA_DE   ),
        
            .HDMI_CLK   (  HDMI_CLK ),
            .HDMI_CE    (  HDMI_CE  ),
            .HDMI_R     (  HDMI_R   ),
            .HDMI_G     (  HDMI_G   ),
            .HDMI_B     (  HDMI_B   ),
            .HDMI_HS    (  HDMI_HS  ),
            .HDMI_VS    (  HDMI_VS  ),
            .HDMI_DE    (  HDMI_DE  ),
            .HDMI_SL    (  HDMI_SL  ),
        
            .fx                ( scanlines          ),
            .forced_scandoubler( force_scan2x       ),
            .no_rotate         ( ROTATE[0]          ) // the no_rotate name
                // is misleading. A low value in no_rotate will actually
                // rotate the game video. If the game is vertical, a low value
                // presents the game correctly on a horizontal screen
        );
    `else
        // Horizontal games
        wire [2:0] scale = status[5:3];
        wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
        wire       scandoubler = (scale || force_scan2x); 

        video_mixer #(.LINE_LENGTH(256), .HALF_DEPTH(1)) video_mixer
        (
            .clk_sys        ( VGA_CLK       ),
            .ce_pix         ( cen6          ),
            .ce_pix_out     ( VGA_CE        ),
            .scandoubler    ( scandoubler   ),        
            .scanlines      ( 0             ),
            .hq2x           ( scale==3'd1   ),
            .R              ( r             ),
            .G              ( g             ),
            .B              ( b             ),
            .mono           ( 0             ),
            .HSync          ( hs            ),
            .VSync          ( vs            ),
            .HBlank         ( hblank        ),
            .VBlank         ( vblank        ),
            .VGA_R          ( VGA_R         ),
            .VGA_G          ( VGA_G         ),
            .VGA_B          ( VGA_B         ),
            .VGA_HS         ( VGA_HS        ),
            .VGA_VS         ( VGA_VS        ),
            .VGA_DE         ( VGA_DE        )
        );
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
    `endif
`else
    assign VGA_VS = vs;
    assign VGA_HS = hs;
    assign VGA_R  = r;
    assign VGA_G  = g;
    assign VGA_B  = b;
    assign VGA_CE = cen6;
    assign VGA_CLK= clk_sys;
`endif

`ifdef SIMULATION
assign sim_hs = hs;
assign sim_vs = vs;
assign sim_pxl_clk = clk_sys;
assign sim_pxl_cen = cen6;
`endif

///////////////////////////////////////////////////////////////////


`ifdef SIMULATION
assign sim_pxl_clk = clk_sys;
assign sim_pxl_cen = cen6;
`endif

wire LHBL_dly, LVBL_dly;

assign hblank = ~LHBL_dly;
assign vblank = ~LVBL_dly;

`GAMETOP #(.CLK_SPEED(48)) u_game
(
    .rst          ( game_rst         ),
    .clk          ( clk_sys          ),
    .cen12        ( cen12            ),
    .cen6         ( cen6             ),
    .cen3         ( cen3             ),
    .cen1p5       ( cen1p5           ),

    .red          ( r                ),
    .green        ( g                ),
    .blue         ( b                ),
    .LHBL_dly     ( LHBL_dly         ),
    .LVBL_dly     ( LVBL_dly         ),
    .HS           ( hs               ),
    .VS           ( vs               ),

    .start_button ( game_start       ),
    .coin_input   ( game_coin        ),
    .joystick1    ( game_joystick1[6:0] ),
    .joystick2    ( game_joystick2[6:0] ),

    // Sound control
    .enable_fm    ( enable_fm        ),
    .enable_psg   ( enable_psg       ),
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
    .status       ( status           ),
    .dip_pause    ( dip_pause        ),
    .dip_flip     ( dip_flip         ),
    .dip_test     ( dip_test         ),
    .dip_fxlevel  ( dip_fxlevel      ),  

    .snd          ( AUDIO_L          ),
    .gfx_en       ( gfx_en           ),

    // unconnected
    .sample       (                  )
);

assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 1;

endmodule
