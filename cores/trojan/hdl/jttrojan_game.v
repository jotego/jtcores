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

module jttrojan_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] scr2_hpos, scr_part;
wire [12:0] cpu_AB;
wire [ 8:0] scr_hpos, scr_vpos;
wire [ 8:0] obj_AB, V, H;
reg  [ 7:0] dipsw_a, dipsw_b;
wire [ 7:0] cpu_dout, char_dout, scr_dout,
            snd_latch, snd2_latch, main_ram,
            mcu_mdin, mcu_mdout, mcu_sdin;
wire        blue_cs, redgreen_cs, flip, HINIT, scr0,
            rd, base_cen, char_busy, scr_busy, char_cs, scr_cs,
            sres_b, snd_int, RnW, OKOUT, blcnten, bus_req, bus_ack,
            mcu_mrd, mcu_mwr, mcu_srd, mcu_swr, mcu_cen, cpu_cen;
reg         trojan, avengers, mcu_en, rst_mcu;

assign pxl2_cen = cen12;
assign pxl_cen  = cen6;
assign dip_flip = flip^avengers;
assign scr_part = scr0 ? { scr_data[27:24], scr_data[19:16], scr_data[11: 8], scr_data[ 3: 0] } :
                         { scr_data[31:28], scr_data[23:20], scr_data[15:12], scr_data[ 7: 4] };
assign base_cen  = trojan ? cen3 : cen6;
assign debug_view = debug_bus[0] ? scr2_hpos[15:8] : scr2_hpos[7:0];

localparam [25:0]   OBJ_START  = `OBJ_START,
                    PROM_START = `JTFRAME_PROM_START;

always @* begin
    post_addr = prog_addr;
    if( ioctl_addr >= OBJ_START && ioctl_addr < PROM_START ) begin
        post_addr[5:1] = {prog_addr[4:1],prog_addr[5]};
    end
end

always @(posedge clk) begin
    if( header && ioctl_addr[3:0]==8 ) {mcu_en,avengers,trojan} <= prog_data[2:0];
    dipsw_a <= avengers ? dipsw[15:8] : dipsw[ 7:0];
    dipsw_b <= avengers ? dipsw[ 7:0] : dipsw[15:8];
    rst_mcu <= rst24 | ~mcu_en;
end

jtframe_crossclk_cen u_crosscen(
    .clk_in     ( clk       ),
    .cen_in     ( base_cen  ),
    .clk_out    ( clk24     ),
    .cen_out    ( mcu_cen   )
);

jttrojan_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .base_cen   ( base_cen      ),
    .cpu_cen    ( cpu_cen       ),
    .nmi_sel    ( avengers      ),
    // Timing
    .flip       ( flip          ),
    .V          ( V             ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .H1         ( H[0]          ),
    // MCU
    .main_latch ( mcu_mdin      ),
    .mcu_latch  ( mcu_mdout     ),
    .mcu_rd     ( mcu_mrd       ),
    .mcu_wr     ( mcu_mwr       ),
    // sound
    .sres_b     ( sres_b        ),
    .snd_latch  ( snd_latch     ),
    .snd2_latch ( snd2_latch    ),
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
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
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
    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       )
);

jttrojan_mcu u_mcu(
    .rst        ( rst_mcu         ),
    .clk        ( clk24           ),
    .clk_rom    ( clk             ),
    .cen        ( mcu_cen         ), // 6 MHz
    .LVBL       ( LVBL            ),
    .vdump      ( V               ),
    // Main CPU interface
    .mrd        ( mcu_mrd         ),
    .mwr        ( mcu_mwr         ),
    .to_main    ( mcu_mdin        ),
    .from_main  ( mcu_mdout       ),
    // Sound CPU interface
    .srd        ( mcu_srd         ),
    .swr        ( mcu_swr         ),
    .to_snd     ( mcu_sdin        ),
    .from_snd   ( snd_latch       ),
    // ROM programming
    .prog_addr  ( prog_addr[11:0] ),
    .prom_din   ( prog_data       ),
    .prom_we    ( prom_we         )
);

jttrojan_sound u_sound (
    .rst            ( rst            ),
    .clk            ( clk            ),
    .cen3           ( cen3           ),
    .cen1p5         ( cen1p5         ),
    .cenp384        ( cenp384        ),
    .avengers       ( avengers       ),
    // Interface with main CPU
    .sres_b         ( sres_b         ),
    .snd_latch      ( snd_latch      ),
    .snd2_latch     ( snd2_latch     ),
    .snd_int        ( snd_int        ),
    // Interface with MCU
    .mcu_sdout      (                ),
    .mcu_sdin       ( mcu_sdin       ),
    .mcu_srd        ( mcu_srd        ),
    .mcu_swr        ( mcu_swr        ),
    // ROM
    .rom_addr       ( snd_addr       ),
    .rom_data       ( snd_data       ),
    .rom_cs         ( snd_cs         ),
    .rom_ok         ( snd_ok         ),
    // ROM 2
    .rom2_addr      ( snd2_addr      ),
    .rom2_data      ( snd2_data      ),
    .rom2_cs        ( snd2_cs        ),
    .rom2_ok        ( snd2_ok        ),
    // sound output
    .fm0            ( fm0            ),
    .fm1            ( fm1            ),
    .psg0           ( psg0           ),
    .psg1           ( psg1           ),
    .pcm            ( pcm            ),
    .debug_view     (                )
);
/* verilator tracing_off */
jttrojan_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen12      ( cen12         ),
    .cen8       ( cen8          ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cpu_cen    ( base_cen      ),
    .avengers   ( avengers      ),
    .cpu_AB     ( cpu_AB[11:0]  ),
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
    // SCROLL 2
    .scr2_hpos  ( scr2_hpos     ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),
    .map2_addr  ( map_addr      ), // 32kB in 8 bits or 16kW in 16 bits
    .map2_data  ( map_data      ),
    .map2_cs    ( map_cs        ),
    .map2_ok    ( map_ok        ),
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
    // Color Mix
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    // Pixel Output
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    // Debug
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     )
);

endmodule
