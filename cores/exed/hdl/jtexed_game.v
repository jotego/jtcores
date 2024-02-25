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
    Date: 6-8-2021 */

module jtexed_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

assign debug_view = 0;

wire [8:0] V, H;

wire [12:0] cpu_AB;
wire [ 7:0] cpu_dout, char_dout;
wire [15:0] scr2_hpos;
wire [10:0] scr1_hpos, scr1_vpos;
wire        char_cs, blue_cs, redgreen_cs;
wire        flip;
wire        rd, cpu_cen;
wire        char_busy;
wire [ 2:0] scr1_pal, scr2_pal;

wire cen12, cen8, cen6, cen3, cen1p5;

wire char_on, scr1_on, scr2_on, obj_on;

// PROMs
localparam PROM_IRQ = 8;
reg  [11:0] prom;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;
assign sample=1'b1;

always @(*) begin
    prom = 0;
    if( prom_we ) prom[ prog_addr[11:8] ] = 1;
end

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    ),
    // unused:
    .cen16  (           ),
    .cen8   ( cen8      ),
    .cen4   (           ),
    .cen4_12(           ),
    .cen3q  (           ),
    .cen16b (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5b(           )
);

wire RnW;
// sound
wire sres_b, snd_int;
wire [7:0] snd_latch;

// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [ 8:0] obj_AB;
wire [ 7:0] main_ram;

localparam  MAP2_START  = `MAP2_START,
            CHAR_START  = `CHAR_START,
            SCR1_START  = `JTFRAME_BA3_START,
            SCR2_START  = `SCR2_START,
            OBJ_START   = `OBJ_START,
            PROM_START  = `JTFRAME_PROM_START;

always @(*) begin
    // IOCTL
    pre_addr = ioctl_addr;
    if( ioctl_addr>=MAP2_START[25:0] && ioctl_addr<CHAR_START[25:0] ) // Map 2
        pre_addr[6:0] = { ioctl_addr[5:0], ioctl_addr[6] };

    if( ioctl_addr>=SCR2_START[25:0] && ioctl_addr<OBJ_START[25:0] )  // Scroll 2
        pre_addr[7:1] = { ioctl_addr[5:1], ioctl_addr[7:6] };

    // Programming address
    post_addr = prog_addr;
    if(ioctl_addr>=SCR1_START[25:0] && ioctl_addr<SCR2_START[25:0]) post_addr[5:1] = { prog_addr[4:1], prog_addr[5] };
    if(ioctl_addr>= OBJ_START[25:0] && ioctl_addr<PROM_START[25:0]) post_addr[5:1] = { prog_addr[4:1], prog_addr[5] };
end

`ifndef NOMAIN
jtcommnd_main #(.GAME(3)) u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cen_sel    ( 1'b0          ), // 3MHz CPU
    // Timing
    .flip       (               ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .H1         ( H[0]          ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    .snd2_latch (               ),
    .snd_int    ( snd_int       ),
    // Palette - unused
    .redgreen_cs(               ),
    .blue_cs    (               ),
    // Layer enable bits
    .char_on    ( char_on       ),
    .scr1_on    ( scr1_on       ),
    .scr2_on    ( scr2_on       ),
    .obj_on     ( obj_on        ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_busy  ( char_busy     ),
    // SCROLL
    .scr_dout   ( 8'd0          ),
    .scr_cs     (               ),
    .scr_busy   ( 1'b0          ),
    .scr_hpos   ( scr1_hpos     ),
    .scr_vpos   ( scr1_vpos     ),
    .scr1_pal   ( scr1_pal      ),
    .scr2_pal   ( scr2_pal      ),
    // SCROLL 2
    .scr2_hpos  ( scr2_hpos     ),
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
    .prom_6l_we ( prom[PROM_IRQ]),
    .prog_din   ( prog_data[3:0]),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   )
);
`else
assign main_addr   = 17'd0;
assign char_cs     = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
assign scr1_hpos   = 0;
assign scr1_vpos   = 0;
assign cpu_cen     = cen3;
`endif

jt1942_sound #(.EXEDEXES(1)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    .sres_b         ( 1'b1           ),
    .game_id        ( 2'd0           ),
    .main_dout      ( cpu_dout       ),
    .main_latch0_cs ( 1'b0           ),
    .main_latch1_cs ( 1'b0           ),
    .snd_latch      ( snd_latch      ),
    .snd_int        ( snd_int        ),
    .rom_cs         ( snd_cs         ),
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_ok         ( snd_ok         ),
    .snd            ( snd            ),
    .sample         (                ),
    .peak           ( game_led       ),
    // pins used for Higemaru but unused here
    .main_a0        ( 1'b0           ),
    .main_ay0_cs    ( 1'b0           ),
    .main_ay1_cs    ( 1'b0           ),
    .main_wr_n      ( 1'b1           )
);

jtexed_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen8       ( cen8          ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[11:0]  ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( dip_flip      ),
    .cpu_dout   ( cpu_dout      ),
    // Layer enable
    .char_on    ( char_on       ),
    .scr1_on    ( scr1_on       ),
    .scr2_on    ( scr2_on       ),
    .obj_on     ( obj_on        ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_busy     ),
    .char_ok    ( char_ok       ),
    // SCROLL 1 - ROM
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .scr1_ok    ( scr1_ok       ),
    .scr1_hpos  ( scr1_hpos     ),
    .scr1_vpos  ( scr1_vpos     ),
    .scr1_pal   ( scr1_pal      ),
    .map1_addr  ( map1_addr     ), // 16kB in 8 bits or 8kW in 16 bits
    .map1_data  ( map1_data     ),
    .map1_cs    ( map1_cs       ),
    .map1_ok    ( map1_ok       ),
    // SCROLL 2
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_pal   ( scr2_pal      ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .scr2_ok    ( scr2_ok       ),
    .map2_addr  ( map2_addr     ), // 8kB in 8 bits or 4kW in 16 bits
    .map2_data  ( map2_data     ),
    .map2_cs    ( map2_cs       ),
    .map2_ok    ( map2_ok       ),
    // OBJ
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
    .prog_addr  ( prog_addr[7:0]),
    .prom_we    ( prom          ),
    .prom_din   ( prog_data     ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    // Debug
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
