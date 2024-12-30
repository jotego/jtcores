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
    Date: 14-1-2023 */

// Game instantiation. Shared by all target top-level modules

localparam STARTW=4;

`ifdef SIMULATION
assign sim_hb         = ~LHBL;
assign sim_vb         = ~LVBL;
assign sim_pxl_clk    = clk_sys;
assign sim_pxl_cen    = pxl_cen;
assign sim_dwnld_busy = dwnld_busy;

`ifdef TESTINPUTS
    test_inputs u_test_inputs(
        .loop_rst       ( ioctl_rom      ),
        .LVBL           ( LVBL           ),
        .game_joystick1 ( game_joy1[6:0] ),
        .button_1p      ( game_start[0]  ),
        .coin_left      ( game_coin[0]   )
    );
    assign game_start[1] = 1'b1;
    assign game_coin[1]  = 1'b1;
    assign game_joystick2 = ~10'd0;
    assign game_joystick3 = ~10'd0;
    assign game_joystick4 = ~10'd0;
    assign game_joystick1[9:7] = 3'b111;
    assign sim_vb = vs;
    assign sim_hb = hs;
`endif
// For simulation, either ~32'd0 or `JTFRAME_SIM_DIPS will be used for DIPs
`ifndef JTFRAME_SIM_DIPS
    `define JTFRAME_SIM_DIPS ~32'd0
`endif
`endif

// `ifndef JTFRAME_LF_BUFFER
//     assign game_vrender = 0,
//            game_hdump   = 0,
//            ln_addr      = 0,
//            ln_data      = 0,
//            ln_done      = 0,
//            ln_we        = 0;
// `endif


`GAMETOP
u_game(
    .rst         ( game_rst       ),
    // The main clock is always the same one as the SDRAM
    .clk         ( clk_rom        ),
    .clk96       ( clk96          ),
    .rst96       ( rst96          ), `ifdef JTFRAME_CLK48
    .clk48       ( clk48          ),
    .rst48       ( rst48          ), `endif
    .clk24       ( clk24          ),
    .rst24       ( rst24          ),
    // Video
    .pxl2_cen    ( pxl2_cen       ),
    .pxl_cen     ( pxl_cen        ),
    .red         ( red            ),
    .green       ( green          ),
    .blue        ( blue           ),
    .LHBL        ( LHBL           ),
    .LVBL        ( LVBL           ),
    .HS          ( hs             ),
    .VS          ( vs             ), `ifdef JTFRAME_INTERLACED
    .field       ( field          ), `endif

    // Inputs
    .cab_1p ( game_start[STARTW-1:0]      ), .coin ( game_coin[STARTW-1:0]       ),
    .joystick1    ( game_joy1[`JTFRAME_BUTTONS+3:0] ), .joystick2  ( game_joy2[`JTFRAME_BUTTONS+3:0] ),
    .joystick3    ( game_joy3[`JTFRAME_BUTTONS+3:0] ), .joystick4  ( game_joy4[`JTFRAME_BUTTONS+3:0] ), `ifdef JTFRAME_PADDLE
    .paddle_1     ( paddle_1         ), .paddle_2     ( paddle_2         ),
    .paddle_3     ( paddle_3         ), .paddle_4     ( paddle_4         ), `endif `ifdef JTFRAME_MOUSE
    .mouse_1p     ( mouse_1p         ), .mouse_2p     ( mouse_2p         ), .mouse_strobe ( mouse_strobe ), `endif `ifdef JTFRAME_SPINNER
    .spinner_1p   ( spinner_1p       ), .spinner_2p   ( spinner_2p       ), `endif
    .joyana_l1    ( joyana_l1        ), .joyana_l2    ( joyana_l2        ),
    .joyana_l3    ( joyana_l3        ), .joyana_l4    ( joyana_l4        ),
    .joyana_r1    ( joyana_r1        ), .joyana_r2    ( joyana_r2        ),
    .joyana_r3    ( joyana_r3        ), .joyana_r4    ( joyana_r4        ),
    .dial_x       ( dial_x           ), .dial_y       ( dial_y           ),
    // Sound control
    .enable_fm   ( enable_fm      ),
    .enable_psg  ( enable_psg     ),
    // PROM programming
    .ioctl_addr  ( ioctl_addr     ),
    .ioctl_dout  ( ioctl_dout     ),
    .ioctl_cart  ( ioctl_cart     ),
    .ioctl_wr    ( ioctl_wr       ),
    .ioctl_ram   ( ioctl_ram      ), `ifdef JTFRAME_IOCTL_RD
    .ioctl_din   ( ioctl_din      ), `endif
    // ROM load
    .ioctl_rom   ( ioctl_rom      ),
    .dwnld_busy  ( dwnld_busy     ),
    .data_read   ( sdram_dout     ),

    `ifdef JTFRAME_LF_BUFFER
    // line-frame buffer
    .game_vrender ( game_vrender     ),
    .game_hdump   ( game_hdump       ),
    .ln_addr      ( ln_addr          ),
    .ln_data      ( ln_data          ),
    .ln_done      ( ln_done          ),
    .ln_hs        ( ln_hs            ),
    .ln_pxl       ( ln_pxl           ),
    .ln_v         ( ln_v             ),
    .ln_we        ( ln_we            ), `endif

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

    .prog_ba    ( prog_ba       ),
    .prog_rdy   ( prog_rdy      ),
    .prog_ack   ( prog_ack      ),
    .prog_dok   ( prog_dok      ),
    .prog_dst   ( prog_dst      ),
    .prog_data  ( prog_data     ),

    // common ROM-load interface
    .prog_addr  ( prog_addr     ),
    .prog_rd    ( prog_rd       ),
    .prog_we    ( prog_we       ),
    .prog_mask  ( prog_mask     ),

    // DIP switches
    .status      ( status[31:0]   ),
    .dip_pause   ( dip_pause      ),
    .dip_flip    ( dip_flip       ),
    .dip_test    ( dip_test       ),
    .dip_fxlevel ( dip_fxlevel    ),
    .service     ( game_service   ),
    .tilt        ( game_tilt      ),
    .dipsw       ( dipsw          ),

`ifdef JTFRAME_GAME_UART
    .uart_tx     ( game_tx        ),
    .uart_rx     ( game_rx        ), `endif
    // sound
`ifndef JTFRAME_STEREO
    .snd         ( snd_left       ),
`else
    .snd_left    ( snd_left       ),
    .snd_right   ( snd_right      ),
`endif
    .sample      ( sample         ),
    .snd_en      ( snd_en         ),
    .snd_vol     ( snd_vol        ),
    .snd_vu      ( snd_vu         ),
    .snd_peak    ( snd_peak       ),
    // Debug
`ifdef JTFRAME_STATUS
    .st_addr     ( st_addr        ),
    .st_dout     ( st_dout        ), `endif
    .gfx_en      ( gfx_en         ),
    .debug_bus   ( debug_bus      ),
    .debug_view  ( debug_view     )
);