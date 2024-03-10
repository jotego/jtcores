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
    Date: 31-8-2019 */


module jtgunsmk_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] pre_obj_addr;
wire [12:0] cpu_AB, obj_AB;
wire [ 8:0] V, H;
wire [ 7:0] cpu_dout, char_dout, scr_dout, snd_latch, main_ram;
wire [ 2:0] obj_bank;
wire        char_cs, flip, cpu_cen, char_busy, HINIT,
            cen12, cen6, cen3, cen8, cen1p5,
            LHBL_obj, LVBL_obj, preLHBL, preLVBL,
            wr_n, rd_n, sres_b, nc,
            CHON, OBJON, SCRON, OKOUT, blcnten, bus_req, bus_ack;
reg         video_flip;

wire prom_red_we   = prom_we && ioctl_addr[11:8]==0;
wire prom_green_we = prom_we && ioctl_addr[11:8]==1;
wire prom_blue_we  = prom_we && ioctl_addr[11:8]==2;
wire prom_char_we  = prom_we && ioctl_addr[11:8]==3;
wire prom_scrlo_we = prom_we && ioctl_addr[11:8]==4;
wire prom_scrhi_we = prom_we && ioctl_addr[11:8]==5;
wire prom_objlo_we = prom_we && ioctl_addr[11:8]==6;
wire prom_objhi_we = prom_we && ioctl_addr[11:8]==7;
wire prom_prior_we = prom_we && ioctl_addr[11:8]==9;

wire [7:0] scrposv;
wire [15:0] scrposh;

localparam [25:0]   MAP1_START = `JTFRAME_BA2_START,
                    SCR1_START = `JTFRAME_BA3_START,
                    OBJ_START  = `OBJ_START,
                    PROM_START = `JTFRAME_PROM_START;


assign pxl2_cen = cen12;
assign pxl_cen  = cen6;
assign obj_addr[14:1]  = pre_obj_addr[13:0];
assign obj_addr[17:15] = pre_obj_addr[15:14] == 2'b11 ? obj_bank + 3'b011 : {1'b0, pre_obj_addr[15:14]};

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

/* verilator lint_off PINMISSING */
jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen8   ( cen8      ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);
/* verilator lint_on PINMISSING */

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

jtgunsmk_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    .CHON       ( CHON          ),
    // SCROLL
    .scrposv    ( scrposv       ),
    .scrposh    ( scrposh       ),
    .SCRON      ( SCRON         ),
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
    .obj_bank   ( obj_bank      ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .joystick1  ( joystick1     ),
    .joystick2  ( joystick2     ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   )
);

jtgng_sound u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd2_latch     (                ),
    .snd_int        ( V[5]           ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // sound output
    .fm0            ( fm0            ),
    .fm1            ( fm1            ),
    .psg0           ( psg0           ),
    .psg1           ( psg1           ),
    .debug_bus      ( debug_bus      ),
    .debug_view     ( debug_view     )
);

always @(posedge clk)
    video_flip <= dip_flip; // Original Gun Smoke did not have this DIP bit.

jt1943_video #(
    .CHAR_PAL      ( "../../../rom/gunsmoke/g-01.03b" ),
    .CHAR_IDMSB0   ( 6                                ),
    .CHAR_VFLIP_XOR( 1'b1                             ),
    .CHAR_HFLIP_XOR( 1'b1                             ),
    // Scroll
    .SCRPLANES     ( 1                                ),
    .SCR1_PALHI    ( "../../../rom/gunsmoke/g-06.14a" ),
    .SCR1_PALLO    ( "../../../rom/gunsmoke/g-07.15a" ),
    // Objects
    // DMA timing measured on real PCB was roughly 130us
    // which correspons to these parameters:
    .OBJMAX        ( 10'h180                          ),
    .OBJMAX_LINE   ( 6'd24                            ),
    .OBJ_LAYOUT    ( 2                                ),
    .OBJ_ROM_AW    ( 16                               ),
    // Colour mixer
    .PALETTE_RED   ( "../../../rom/gunsmoke/g-01.03b" ),
    .PALETTE_GREEN ( "../../../rom/gunsmoke/g-02.04b" ),
    .PALETTE_BLUE  ( "../../../rom/gunsmoke/g-03.05b" ),
    .PALETTE_PRIOR ( "../../../rom/gunsmoke/g-05.01f" )
) u_video(
    .rst           ( rst           ),
    .clk           ( clk           ),
    .pxl2_cen      ( cen12         ),
    .pxl_cen       ( cen6          ),
    .cen8          ( cen8          ),
    .cen3          ( cen3          ),
    .cpu_cen       ( cpu_cen       ),
    .cpu_AB        ( cpu_AB[10:0]  ),
    .V             ( V             ),
    .H             ( H             ),
    .rd_n          ( rd_n          ),
    .wr_n          ( wr_n          ),
    .cpu_dout      ( cpu_dout      ),
    .flip          ( video_flip    ), // no software support for DIP flip in GunSmoke
    // CHAR
    .char_cs       ( char_cs       ),
    .chram_dout    ( char_dout     ),
    .char_addr     ( {nc, char_addr}     ),
    .char_data     ( char_data     ),
    .char_wait     ( char_busy     ),
    .char_ok       ( char_ok       ),
    .CHON          ( CHON          ),
    // SCROLL - ROM
    .scr1posh      ( scrposh       ),
    .scr2posh      ( 16'd0         ),
    .scrposv       ( scrposv       ),
    .scr1_addr     ( scr_addr      ),
    .scr1_data     ( scr_data      ),
    .scr2_addr     (               ),
    .scr2_data     (               ),
    .SC1ON         ( SCRON         ),
    .SC2ON         (               ),
    // Scroll maps
    .map1_addr     ( map_addr      ),
    .map1_data     ( map_data      ),
    .map1_ok       ( map_ok        ),
    .map1_cs       ( map_cs        ),
    .map2_ok       ( 1'b1          ),
    .map2_cs       (               ),
    .map2_addr     (               ),
    .map2_data     (               ),
    // OBJ
    .OBJON         ( OBJON         ),
    .HINIT         ( HINIT         ),
    .obj_AB        ( obj_AB        ),
    .obj_DB        ( main_ram      ),
    .obj_addr      ( pre_obj_addr  ),
    .obj_data      ( obj_data      ),
    .obj_ok        ( obj_ok        ),
    .OKOUT         ( OKOUT         ),
    .bus_req       ( bus_req       ), // Request bus
    .bus_ack       ( bus_ack       ), // bus acknowledge
    .blcnten       ( blcnten       ), // bus line counter enable
    // Color Mix
    .preLHBL       ( preLHBL       ),
    .preLVBL       ( preLVBL       ),
    .LHBL          ( LHBL          ),
    .LVBL          ( LVBL          ),
    .LHBL_obj      ( LHBL_obj      ),
    .LVBL_obj      ( LVBL_obj      ),
    // PROM access
    .prog_addr     ( prog_addr[7:0]),
    .prog_din      ( prog_data[3:0]),
    // Char
    .prom_char_we  ( prom_char_we  ),
    // color mixer proms
    .prom_red_we   ( prom_red_we   ),
    .prom_green_we ( prom_green_we ),
    .prom_blue_we  ( prom_blue_we  ),
    .prom_prior_we ( prom_prior_we ),
    // scroll 1/2 proms
    .prom_scr1hi_we( prom_scrhi_we ),
    .prom_scr1lo_we( prom_scrlo_we ),
    .prom_scr2hi_we( 1'b0          ),
    .prom_scr2lo_we( 1'b0          ),
    // obj proms
    .prom_objhi_we ( prom_objhi_we ),
    .prom_objlo_we ( prom_objlo_we ),
    // Debug
    .gfx_en        ( gfx_en        ),
    .debug_bus     ( debug_bus     ),
    // Pixel Output
    .red           ( red           ),
    .green         ( green         ),
    .blue          ( blue          )
);

endmodule
