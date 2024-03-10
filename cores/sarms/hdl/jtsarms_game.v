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
    Date: 2-8-2020 */

module jtsarms_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam [25:0] MAP_START  = `MAP_START;

wire [8:0] V, H;

wire [12:0] cpu_AB;
wire [ 7:0] cpu_dout, char_dout, scr_dout,
            dipsw_a, dipsw_b, dipsw_c;
wire        char_cs, blue_cs, redgreen_cs;
wire        eres_n, wrerr_n;
wire        flip;
wire        star_hscan, star_vscan;
wire        rd, cpu_cen;
wire        char_wait;
wire        star_fix_n, is_obj;

wire        CHON, SCRON, STARON, OBJON,
            cen16, cen12, cen8, cen6, cen4, cen3;

assign dip_flip           = flip;
assign pxl2_cen           = cen16;
assign pxl_cen            = cen8;
assign star_fix_n         = status[13];
assign {dipsw_b, dipsw_a} = dipsw[15:0];
assign dipsw_c = 8'hff; // Only the freeze is contained here, and users often get
    // confused with it, so I'd rather leave it fixed and hidden
/* verilator lint_off PINMISSING */
jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen16  ( cen16     ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen8   ( cen8      ),
    .cen4   ( cen4      ),
    // unused:
    .cen1p5 (           ),
    .cen4_12(           ),
    .cen3q  (           ),
    .cen12b (           ),
    .cen6b  (           ),
    .cen3b  (           ),
    .cen3qb (           ),
    .cen1p5b(           )
); /* verilator lint_on PINMISSING */

wire rd_n, wr_n;
// sound
wire sres_b;
wire [7:0] snd_latch;
// OBJ
wire OKOUT, blcnten, bus_req, bus_ack;
wire [12:0] obj_AB;
wire [ 7:0] main_ram;

wire        scr_cs;
wire [15:0] scr_hpos, scr_vpos;

assign cpu_cen = cen8;
assign is_obj  = prog_ba==3 && ioctl_addr<MAP_START;

always @* begin
    post_addr = prog_addr;
    if(is_obj) post_addr[5:1] = { prog_addr[4:1],prog_addr[5]} ;
end


`ifndef NOMAIN
wire [13:0] nc;
jt1943_main #(.GAME(1)) u_main(
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
    // Palette
    .redgreen_cs( redgreen_cs   ),
    .blue_cs    ( blue_cs       ),
    .eres_n     ( eres_n        ),
    .wrerr_n    ( wrerr_n       ),
    // CHAR
    .char_dout  ( char_dout     ),
    .cpu_dout   ( cpu_dout      ),
    .char_cs    ( char_cs       ),
    .char_wait  ( char_wait     ),
    .CHON       ( CHON          ),
    // SCROLL
    .scr1posh   ( scr_hpos      ),
    .scrposv    ( scr_vpos      ),
    .SC1ON      ( SCRON         ),
    .SC2ON      ( STARON        ),
    // Star Field
    .scr2posh   ( { nc, star_hscan, star_vscan } ),
    // OBJ - bus sharing
    .obj_AB     ( obj_AB        ),
    .cpu_AB     ( cpu_AB        ),
    .ram_dout   ( main_ram      ),
    .OKOUT      ( OKOUT         ),
    .blcnten    ( blcnten       ),
    .bus_req    ( bus_req       ),
    .bus_ack    ( bus_ack       ),
    .OBJON      ( OBJON         ),
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

    .rd_n       ( rd_n          ),
    .wr_n       ( wr_n          ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .dipsw_c    ( dipsw_c       ),
    // unused
    .coin_cnt   (               )
);
`else
assign main_addr   = 18'd0;
assign char_cs     = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign wr_n        = 1'b1;
assign scr_hpos    = 16'd0;
assign scr_vpos    = 16'd0;
`endif

`ifndef NOSOUND
jtgng_sound #(.LAYOUT(8)) u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen4           ),
    .cen1p5         (                ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd2_latch     (                ),
    .snd_int        (                ),
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
    .debug_bus      ( 8'd0           ),
    .debug_view     ( debug_view     )
);
`else
    assign snd_addr = 0;
    assign snd_cs   = 0;
    assign fm0      = 0;
    assign fm1      = 0;
    assign psg0     = 0;
    assign psg1     = 0;
`endif

jtsarms_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .cen12      ( cen12         ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[11:0]  ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( wr_n          ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // Palette
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
    .eres_n     ( eres_n        ),
    .wrerr_n    ( wrerr_n       ),
    // CHAR
    .char_cs    ( char_cs       ),
    .char_dout  ( char_dout     ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_busy  ( char_wait     ),
    .char_ok    ( char_ok       ),
    .CHON       ( CHON          ),
    // SCROLL - ROM
    .scr_addr   ( scr_addr      ),
    .scr_data   ( scr_data      ),
    .scr_hpos   ( scr_hpos      ),
    .scr_vpos   ( scr_vpos      ),
    .scr_ok     ( scr_ok        ),
    .map_addr   ( map_addr      ), // 32kB in 8 bits or 16kW in 16 bits
    .map_data   ( map_data      ),
    .map_cs     ( map_cs        ),
    .map_ok     ( map_ok        ),
    .SCRON      ( SCRON         ),
    // STAR FIELD
    .star_hscan ( star_hscan    ),
    .star_vscan ( star_vscan    ),
    .star_addr  ( star_addr     ),
    .star_data  ( star_data     ),
    .star_ok    ( star_ok       ),
    .star_fix_n ( star_fix_n    ),
    .STARON     ( STARON        ),
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
    .OBJON      ( OBJON         ),
    // PROMs
    // .prog_addr    ( prog_addr[7:0] ),
    // .prom_prio_we ( prom_we        ),
    // .prom_din     ( prog_data[3:0] ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
