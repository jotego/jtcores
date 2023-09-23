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
wire [15:0] fave;
wire        brnw, srst_n, firqn,
            key_cs, cus30b_cs;
wire [ 7:0] bdout, key_dout, sndcpu_dout;
wire [ 1:0] busy;
wire [ 3:0] cpu_cen;
reg  [ 7:0] dbg_mux;

// bit 16 of ROM T10 in sch. is inverted. T10 is also shorter (128kB only)
// limiting to 128kB ROMs for now to allow address mirroring on Splatter
// To do: use a header byte to config this? duplicate content in the MRA?
assign main_addr = { baddr[21:19], 2'd0, &baddr[21:19] ? { ~baddr[16],baddr[15:0]} : baddr[16:0] };
assign sub_addr  = main_addr;
assign debug_view= dbg_mux;

assign vram_addr = baddr[14:1];
assign ram_addr  = baddr[14:1];
assign ram_din   = bdout;
assign ram_dsn   = { baddr[0], ~baddr[0] };
assign ram_we    = ram_cs & ~brnw;

assign sndram_addr = snd_addr[12:0];
assign sndram_din  = sndcpu_dout;
assign bdout16 = {2{bdout}};

// To do:
assign firqn = 1;
assign dip_flip = 0;

always @* begin
    case( debug_bus )
        0: dbg_mux = fave[15:8]; // average CPU frequency (BCD format)
        1: dbg_mux = fave[ 7:0];
        default: dbg_mux = 0;
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
    .dout       ( key_dout  ),

    .prog_en    ( header    ),
    .prog_wr    ( prog_we   ),
    .prog_addr  ( prog_addr[2:0] ),
    .prog_data  ( prog_data )
);

jtshouse_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    (cpu_cen[1:0]),

    .lvbl       ( LVBL      ),
    .firqn      ( firqn     ),     // input that will trigger both FIRQ outputs

    .baddr      ( baddr     ),  // shared by both CPUs
    .bdout      ( bdout     ),
    .brnw       ( brnw      ),

    .cus30b_cs  ( cus30b_cs ),
    .key_cs     ( key_cs    ),
    .key_dout   ( key_dout  ),

    // Video RAM
    .obus_we    ( obus_we   ),
    .obus_addr  ( obus_addr ),
    .obus_dout  ( obus_dout ),
    .vram_dout  ( vram_data ),
    .vram_dsn   ( vram_dsn  ),
    .vram_we    ( vram_we   ),

    .srst_n     ( srst_n    ),

    .mrom_cs    ( main_cs   ),
    .srom_cs    ( sub_cs    ),
    .ram_cs     ( ram_cs    ),
    .mrom_ok    ( main_ok   ),
    .srom_ok    ( sub_ok    ),
    .ram_ok     ( ram_ok    ),
    .mrom_data  ( main_data ),
    .srom_data  ( sub_data  ),
    .ram_dout   ( ram_data  ),
    .bus_busy   ( busy[0]   )
);

jtshouse_sound u_sound(
    .srst_n     ( srst_n    ),
    .clk        ( clk       ),
    .cpu_cen    (cpu_cen[3:2]),
    .cen_fm     ( cen_fm    ),
    .cen_fm2    ( cen_fm2   ),
    .lvbl       ( LVBL      ),

    .ram_we     ( sndram_we ),
    .ram_dout   (sndram_dout),
    .cpu_dout   (sndcpu_dout),

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

jtshouse_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .lvbl       ( LVBL      ),
    .lhbl       ( LHBL      ),
    .hs         ( HS        ),
    .vs         ( VS        ),

    // Video RAM
    .oram_addr  ( oram_addr ),
    .oram_dout  ( oram_dout ),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

endmodule