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
    Date: 21-9-2023 */

module jtshouse_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [21:0] baddr;
wire        brnw, key_cs, srst_n;
wire [ 7:0] bdout, key_dout;
wire [ 1:0] busy, cpu_cen;
reg  [ 7:0] dbg_mux;

// bit 16 of ROM T10 in sch. is inverted:
assign main_addr = (&baddr[21:18] ? 22'h10000 : 22'h0) ^ baddr;
assign sub_addr  = main_addr;

always @* begin
    case( debug_bus )
        0: fave[15:8]; // average CPU frequency (BCD format)
        1: fave[ 7:0];
    endcase
end

jtshouse_cenloop u_cen(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .busy       ( busy      ),

    .cpu_cen    ( cpu_cen   ),
    .fave       ( fave      ),
    .fworst     (           )
);

jtshouse_key u_key(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .cs         ( key_cs    ),
    .rnw        ( brnw      ),
    .addr       ( baddr[7:0]),
    .din        ( bdout     ),
    .dout       ( key_dout  )

    .prog_en    ( header    ),
    .prog_wr    ( prog_wr   ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data )

);

jtshouse_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),

    .lvbl       ( LVBL      ),
    .firqn      ( firqn     ),     // input that will trigger both FIRQ outputs

    .baddr      ( baddr     ),  // shared by both CPUs
    .bdout      ( bdout     ),
    .brnw       ( brnw      ),

    .key_cs     ( key_cs    ),
    .key_dout   ( key_dout  ),

    .srst_n     ( srst_n    ),

    .mrom_cs    ( main_cs   ),
    .srom_cs    ( sub_cs    ),
    .ram_cs     ( ram_cs    ),
    .mrom_ok    ( main_ok   ),
    .srom_ok    ( sub_ok    ),
    .ram_ok     ( ram_ok    ),
    .mrom_data  ( main_data ),
    .srom_data  ( sub_data  ),
    .ram_dout   ( ram_dout  ),
    .bus_busy   ( busy[0]   )
);

jtshouse_sound u_sound(
    .srst_n     ( srst_n    ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    .lvbl       ( lvbl      ),

    .rom_cs     ( snd_cs    ),
    .rom_addr   ( snd_addr  ),
    .rom_data   ( snd_data  ),
    .rom_ok     ( snd_ok    ),
    .bus_busy   ( busy[1]   ),

    .left       ( snd_left  ),
    .right      ( snd_right ),
    .sample     ( sample    ),
    .peak       ( game_led  )
);

endmodule