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


module jtsectnz_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] scr_part;
wire [12:0] cpu_AB;
wire [10:0] scr_hpos, scr_vpos;
wire [ 8:0] V, H, obj_AB;
wire [ 7:0] cpu_dout, char_dout, scr_dout, main_ram, snd_latch;
wire        rd, cpu_cen, char_busy, scr_busy, scr_cs, RnW, sres_b, snd_int,
            flip, char_cs, blue_cs, redgreen_cs, scr0,
            cen12, cen6, cen3, cen1p5,
            OKOUT, blcnten, bus_req, bus_ack;
reg         game_cfg;

assign debug_view = { 6'd0, flip, game_cfg };
assign pxl2_cen   = cen12;
assign pxl_cen    = cen6;
assign dip_flip   = flip^game_cfg;
assign scr_part   = scr0 ? { scr_data[27:24], scr_data[19:16], scr_data[11: 8], scr_data[ 3: 0] } :
                           { scr_data[31:28], scr_data[23:20], scr_data[15:12], scr_data[ 7: 4] };

localparam [25:0]   OBJ_START  = `JTFRAME_BA3_START;

always @* begin
    post_addr = prog_addr;
    if( ioctl_addr >= OBJ_START ) begin
        post_addr[5:1] = {prog_addr[4:1],prog_addr[5]};
    end
end

always @(posedge clk) begin
    if( header && prog_addr[4:0]==0 && prog_we ) game_cfg <= prog_data[0];
end

/* verilator lint_off PINMISSING */
jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen12  ( cen12     ),
    .cen6   ( cen6      ),
    .cen3   ( cen3      ),
    .cen1p5 ( cen1p5    )
);/* verilator lint_on PINMISSING */

`ifndef NOMAIN
jtcommnd_main #(.GAME(1)) u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cen_sel    ( game_cfg      ),
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
    // Palette
    .redgreen_cs( redgreen_cs   ),
    .blue_cs    ( blue_cs       ),
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
    .prog_addr  ( 8'd0          ),
    .prom_6l_we ( 1'b0          ),
    .prog_din   ( 4'd0          ),
    // DIP switches
    .dip_pause  ( dip_pause     ),
    .dipsw_a    ( dipsw[ 7:0]   ),
    .dipsw_b    ( dipsw[15:8]   ),
    // Unused
    .snd2_latch (               ),
    .char_on    (               ),
    .scr2_hpos  (               ),
    .scr1_on    (               ),
    .scr2_on    (               ),
    .obj_on     (               ),
    .scr1_pal   (               ),
    .scr2_pal   (               )
);
`else
assign main_addr   = 17'd0;
assign char_cs     = 1'b0;
assign scr_cs      = 1'b0;
assign bus_ack     = 1'b0;
assign flip        = 1'b0;
assign RnW         = 1'b1;
assign scr_hpos    = 0;
assign scr_vpos    = 0;
assign cpu_cen     = cen3;
`endif

`ifndef NOSOUND
jtgng_sound #(.LAYOUT(0)) u_sound (
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
    // unused
    .snd2_latch     (                ),
    .debug_bus      ( 8'd0           ),
    .debug_view     (                )
);
`else
assign snd_addr = 15'd0;
assign snd_cs   = 1'b0;
assign snd      = 16'b0;
`endif

jtsectnz_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( cpu_cen       ),
    .cpu_AB     ( cpu_AB[11:0]  ),
    .game_sel   ( game_cfg      ),
    .V          ( V             ),
    .H          ( H             ),
    .RnW        ( RnW           ),
    .flip       ( flip          ),
    .cpu_dout   ( cpu_dout      ),
    // Palette
    .blue_cs    ( blue_cs       ),
    .redgreen_cs( redgreen_cs   ),
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
    .scr_addr   ({scr_addr,scr0}),
    .scr_data   ( scr_part      ),
    .scr_busy   ( scr_busy      ),
    .scr_hpos   ( scr_hpos[8:0] ),
    .scr_vpos   ( scr_vpos[8:0] ),
    .scr_ok     ( scr_ok        ),
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
    // PROMs -- unused --
    // .prog_addr    ( 8'd0        ),
    // .prom_red_we  ( 1'b0        ),
    // .prom_green_we( 1'b0        ),
    // .prom_blue_we ( 1'b0        ),
    // .prom_din     ( 4'd0        ),
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .gfx_en     ( gfx_en        ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          )
);

endmodule
