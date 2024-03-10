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
    Date: 29-6-2019 */


module jtcommnd_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [ 8:0] V, H;
wire        HINIT, preLVBL, preLHBL;
wire [10:0] scr_hpos, scr_vpos;

wire [12:0] cpu_AB;
wire        flip;
wire [ 7:0] cpu_dout, char_dout, scr_dout;
wire        rd, cpu_cen, char_busy, scr_busy,
            char_cs, scr_cs, RnW;

wire [ 7:0] dipsw_a, dipsw_b;

// sound
wire sres_b, snd_int;
wire [7:0] snd_latch;

// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [ 8:0] obj_AB;
wire [7:0] main_ram;

reg  [5:0] prom_sel;

wire LHBL_obj, LVBL_obj;
wire prom_1d = prom_sel[0];
wire prom_2d = prom_sel[1];
wire prom_3d = prom_sel[2];
// wire prom_1h = prom_sel[3];
wire prom_6l = prom_sel[4];
// wire prom_6e = prom_sel[5];

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;

assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dip_flip = flip;
assign debug_view = 0;

localparam OBJ_START = `JTFRAME_BA2_START + (`OBJ_OFFSET<<1);

always @* begin
    post_addr = prog_addr;
    if( ioctl_addr[24:0]>=OBJ_START[24:0] && ioctl_addr<`JTFRAME_BA3_START ) begin
        post_addr[5:1] = { post_addr[4:1], post_addr[5] };
    end
end

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

always @* begin
    prom_sel = 0;
    prom_sel[ prog_addr[10:8] ] = 1;
end

jtcommnd_main u_main(
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
    .H1         ( H[0]          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    .snd_int    ( snd_int       ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // SCROLL
    .scr_dout   ( scr_dout      ),
    .scr_cs     ( scr_cs        ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    // ROM
    .rom_cs     ( main_cs       ),
    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),
    // Cabinet input
    .cab_1p     ( cab_1p        ),
    .coin       ( coin          ),
    .service    ( service       ),
    .joystick1  ( joystick1[5:0]),
    .joystick2  ( joystick2[5:0]),

    .RnW        ( RnW           ),
    // PROM 6L (interrupts)
    .prog_addr  ( prog_addr[7:0]),
    .prom_6l_we ( prom_6l       ),
    .prog_din   ( prog_data[3:0]),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    // Unused pins
    .blue_cs     (              ),
    .redgreen_cs (              ),
    .char_on     (              ),
    .snd2_latch  (              ),
    .scr2_hpos   (              ),
    .cen_sel     (              ),
    .scr1_on     (              ),
    .scr2_on     (              ),
    .obj_on      (              ),
    .scr1_pal    (              ),
    .scr2_pal    (              )
);

jtgng_sound #(.LAYOUT(1)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd_int        ( snd_int        ),
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
    // Unused
    .debug_bus      ( debug_bus      ),
    .debug_view     (                ),
    .snd2_latch     (                )
);

jtgng_video #(
    .OBJ_PAL      (2'b10),
    .PALETTE_PROM (1),
    .SCRWIN       (0),
    .PALETTE_RED  ("../../../rom/commando/vtb1.1d"),
    .PALETTE_GREEN("../../../rom/commando/vtb2.2d"),
    .PALETTE_BLUE ("../../../rom/commando/vtb3.3d")
) u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen6       ( cen6          ),
    .cpu_AB     ( cpu_AB[10:0]  ),
    .V          ( V[7:0]        ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL - ROM
    .scr_cs     ( scr_cs        ),
    .scr_dout   ( scr_dout      ),
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data[23:0]),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos[8:0] ),
    .scr_vpos   ( scr_vpos[8:0] ),
    .scr_ok     ( scr_ok        ),
    // OBJ
    .HINIT      ( HINIT         ),
    .obj_AB     ( obj_AB        ),
    .main_ram   ( main_ram      ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .OKOUT      ( OKOUT         ),
    .bus_req    ( bus_req       ), // Request bus
    .bus_ack    ( bus_ack       ), // bus acknowledge
    .blcnten    ( blcnten       ), // bus line counter enable
    // PROMs
    .prog_addr    ( prog_addr[7:0]),
    .prom_red_we  ( prom_1d       ),
    .prom_green_we( prom_2d       ),
    .prom_blue_we ( prom_3d       ),
    .prom_din     ( prog_data[3:0]),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .LHBL_obj   ( LHBL_obj      ),
    .LVBL_obj   ( LVBL_obj      ),
    .preLHBL    ( preLHBL       ),
    .preLVBL    ( preLVBL       ),
    .gfx_en     ( gfx_en        ),
    .blue_cs    ( 1'b0          ),
    .redgreen_cs( 1'b0          ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
