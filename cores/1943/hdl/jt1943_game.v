/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 18-2-2019 */

module jt1943_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// These signals are used by games which need
// to read back from SDRAM during the ROM download process

parameter CLK_SPEED=48;

wire [8:0] V;
wire [8:0] H;
wire HINIT;

wire [12:0] cpu_AB;
wire flip, char_cs;
wire [7:0] cpu_dout, chram_dout;
wire rd;
wire [7:0] dipsw_a, dipsw_b;

wire LHBL_obj, LVBL_obj;
wire preLHBL, preLVBL;

assign {dipsw_b, dipsw_a} = dipsw[15:0];

jtgng_timer u_timer(
    .clk       ( clk      ),
    .cen6      ( cen6     ),
    .V         ( V        ),
    .H         ( H        ),
    .Hinit     ( HINIT    ),
    .LHBL      ( preLHBL  ),
    .LVBL      ( preLVBL  ),
    .LHBL_obj  ( LHBL_obj ),
    .LVBL_obj  ( LVBL_obj ),
    .HS        ( HS       ),
    .VS        ( VS       ),
    .Vinit     (          )
);

wire wr_n, rd_n;
// sound
wire sres_b;
wire [7:0] snd_latch;
wire [7:0] scrposv, main_ram;

wire char_wait;

wire [15:0] scr1posh, scr2posh;

wire CHON, OBJON, SC2ON, SC1ON;
wire cpu_cen;
// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [12:0] obj_AB;

wire prom_7l_we  = prom_we && ioctl_addr[11:8]== 0;
wire prom_12l_we = prom_we && ioctl_addr[11:8]== 1;
wire prom_12a_we = prom_we && ioctl_addr[11:8]== 2;
wire prom_12m_we = prom_we && ioctl_addr[11:8]== 3;
wire prom_13a_we = prom_we && ioctl_addr[11:8]== 4;
wire prom_14a_we = prom_we && ioctl_addr[11:8]== 5;
wire prom_12c_we = prom_we && ioctl_addr[11:8]== 6;
wire prom_7f_we  = prom_we && ioctl_addr[11:8]== 7;
// wire prom_4b_we  = prom_we && ioctl_addr[11:8]== 8; // Video timing. Unused.
wire prom_7c_we  = prom_we && ioctl_addr[11:8]== 9;
wire prom_8c_we  = prom_we && ioctl_addr[11:8]==10;
wire prom_6l_we  = prom_we && ioctl_addr[11:8]==11;

reg video_flip;

always @(posedge clk)
    video_flip <= dip_flip; // Original 1943 did not have this DIP bit.

localparam [25:0]   MAP1_START = `MAP1_START,
                    SCR1_START = `SCR1_START,
                    OBJ_START  = `OBJ_START,
                    PROM_START = `JTFRAME_PROM_START;

always @* begin
    post_addr = prog_addr;
    if(ioctl_addr>=MAP1_START ) begin
        if( ioctl_addr < SCR1_START) begin // MAP1+MAP2
            post_addr[3:0] = {prog_addr[2:0],prog_addr[3]};
        end else if( ioctl_addr >= OBJ_START && ioctl_addr < PROM_START ) begin
            post_addr[5:1] = {prog_addr[4:1],prog_addr[5]};
        end
    end
end

// 1943 board supports three buttons, but the software only uses two
// to perform a loop with the plane, you have to press buttons 1 and 2
// this is hard to do.
// The assignment below forces buttons 1 and 2 whenever button 3 is pressed
// so the loop can be done with the 3rd button
reg [2:0] joy1_btn;
reg [2:0] joy2_btn;

always @(posedge clk) begin
    joy1_btn <= { {3{joystick1[6]}} & joystick1[6:4] };
    joy2_btn <= { {3{joystick2[6]}} & joystick2[6:4] };
end

assign cpu_cen = cen6;

`ifndef NOMAIN
jt1943_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LVBL       ( LVBL          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    // CHAR
    .char_dout  ( chram_dout    ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_wait  ( char_wait     ),
    .CHON       ( CHON          ),
    // SCROLL
    .scrposv    ( scrposv       ),
    .scr1posh   ( scr1posh      ),
    .scr2posh   ( scr2posh      ),
    .SC1ON      ( SC1ON         ),
    .SC2ON      ( SC2ON         ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .OBJON      ( OBJON         ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p      ( cab_1p       ),
    .coin        ( coin         ),
    .service     ( service      ),
    .joystick1   ( { joy1_btn, joystick1[3:0]}    ),
    .joystick2   ( { joy2_btn, joystick2[3:0]}    ),
    // DIP switches
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .dipsw_c    (               ),
    .dip_pause  ( dip_pause     ),
    .coin_cnt   (               ),
    // unused ports (used in SideArms only)
    .blue_cs    (               ),
    .redgreen_cs(               ),
    .eres_n     (               ),
    .wrerr_n    (               )
);
`else
    assign scr1posh  = 16'h5f3a;
    assign scr2posh  = 16'h6000;
    assign scrposv   = 0;
    assign char_cs   = 0;
    assign SC1ON     = 1;
    assign SC2ON     = 1;
    assign OBJON     = 1;
    assign  CHON     = 1;
    assign main_addr = 0;
    assign main_cs   = 0;
    assign main_ram  = 0;
    assign rd_n      = 1;
    assign wr_n      = 1;
    assign cpu_AB    = 0;
    assign sres_b    = 1;
    assign snd_latch = 0;
    assign cpu_dout  = 0;
    assign OKOUT     = 0;
    assign bus_ack   = 1;
    assign flip      = 0;
`endif

jtgng_sound u_sound (
    .rst            ( rst        ),
    .clk            ( clk        ),
    .cen3           ( cen3       ),
    .cen1p5         ( cen1p5     ),
    // Interface with main CPU
    .sres_b         ( sres_b     ),
    .snd_latch      ( snd_latch  ),
    .snd2_latch     (            ),
    .snd_int        ( V[5]       ),
    // ROM
    .rom_addr       ( snd_addr   ),
    .rom_data       ( snd_data   ),
    .rom_cs         (            ),
    .rom_ok         ( 1'b1       ),
    // sound output
    // sound output
    .fm0            ( fm0        ),
    .fm1            ( fm1        ),
    .psg0           ( psg0       ),
    .psg1           ( psg1       ),
    .debug_bus      ( debug_bus  ),
    .debug_view     ( debug_view )
);

jt1943_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),
    .pxl2_cen   ( pxl2_cen      ),
    .cen8       ( cen8          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V             ),
    .H          ( H             ),
    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    .cpu_dout   ( cpu_dout      ),
    .flip       ( video_flip    ),
    // CHAR
    .char_cs    ( char_cs       ),
    .chram_dout ( chram_dout    ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_wait  ( char_wait     ),
    .char_ok    ( char_ok       ),
    .CHON       ( CHON          ),
    // SCROLL - ROM
    .scr1posh   ( scr1posh      ),
    .scr2posh   ( scr2posh      ),
    .scrposv    ( scrposv       ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .SC1ON      ( SC1ON         ),
    .SC2ON      ( SC2ON         ),
    // Scroll maps
    .map1_addr  ( map1_addr     ),
    .map1_data  ( map1_data     ),
    .map1_ok    ( map1_ok       ),
    .map1_cs    ( map1_cs       ),
    .map2_addr  ( map2_addr     ),
    .map2_data  ( map2_data     ),
    .map2_ok    ( map2_ok       ),
    .map2_cs    ( map2_cs       ),
    // OBJ
    .OBJON      ( OBJON         ),
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .obj_DB     ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    // Color Mix
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // PROM access
    .prog_addr  ( prog_addr[7:0]),
    .prog_din   ( prog_data[3:0]),
    // Char
    .prom_char_we  ( prom_7f_we    ),
    // color mixer proms
    .prom_red_we   ( prom_12a_we   ),
    .prom_green_we ( prom_13a_we   ),
    .prom_blue_we  ( prom_14a_we   ),
    .prom_prior_we ( prom_12c_we   ),
    // scroll 1/2 proms
    .prom_scr1hi_we( prom_6l_we    ),
    .prom_scr1lo_we( prom_7l_we    ),
    .prom_scr2hi_we( prom_12l_we   ),
    .prom_scr2lo_we( prom_12m_we   ),
    // obj proms
    .prom_objhi_we ( prom_7c_we    ),
    .prom_objlo_we ( prom_8c_we    ),
    // Debug
    .gfx_en        ( gfx_en        ),
    .debug_bus     ( debug_bus     ),
    // Pixel Output
    .red           ( red           ),
    .green         ( green         ),
    .blue          ( blue          )
);

endmodule
