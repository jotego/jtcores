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
    Date: 15-3-2025 */

module jtrthunder_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [15:0] fave;
wire [ 2:0] busy;
reg  [ 7:0] dbg_mux, backcolor;
wire [ 8:0] scr0x, scr0y, scr1x, scr1y;
wire        cen_main, cen_sub, cen_mcu, flip, mmr0_cs, mmr1_cs, bus_rnw;

assign debug_view = dbg_mux;
assign dip_flip   = flip;

assign flip = 0;
assign mmr0_cs = 0,  mmr1_cs = 0, bus_rnw = 1;
assign bus_dout = 0, bus_addr = 0;
assign backcolor = 0, sh0_we=0, sh1_we=0;
assign mcu_addr = 0;

assign mcusub_cs=0,mcusub_addr=0, busy=0;
assign pcm_cs=0, pcm_addr=0, snd_cs=0, snd_addr=0, main_cs=0, main_addr=0;
assign fm_l=0, fm_r=0,pcm=0,cus30_r=0,cus30_l=0;

always @* begin
    case( debug_bus[7:6] )
        // 0: dbg_mux = { 3'd0, mcu_halt, 3'd0, ~srst_n };
        // 1: dbg_mux = st_video;
        // 2: dbg_mux = st_main;
        3: dbg_mux = debug_bus[0] ? fave[7:0] : fave[15:8]; // average CPU frequency (BCD format)
        default: dbg_mux = 0;
    endcase
end

jtrthunder_cenloop u_cen(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .busy       ( busy      ),

    .cen_main   ( cen_main  ),
    .cen_sub    ( cen_sub   ),
    .cen_mcu    ( cen_mcu   ),

    .fave       ( fave      ),
    .fworst     (           )
);

jtrthunder_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .pxl2_cen   ( pxl2_cen  ),
    .flip       ( flip      ),
    .backcolor  ( backcolor ),

    .lvbl       ( LVBL      ),
    .lhbl       ( LHBL      ),
    .hs         ( HS        ),
    .vs         ( VS        ),

    .mmr0_cs    ( mmr0_cs   ),
    .mmr1_cs    ( mmr1_cs   ),
    .rnw        ( bus_rnw   ),
    .cpu_dout   ( bus_dout  ),
    .cpu_addr   ( bus_addr  ),

    // Tile ROM decoder PROM
    .vram0_addr ( vram0_addr),
    .vram1_addr ( vram1_addr),
    .vram0_dout ( vram0_dout),
    .vram1_dout ( vram1_dout),
    .dec0_addr  ( dec0_addr ),
    .dec1_addr  ( dec1_addr ),
    .dec0_data  ( dec0_data ),
    .dec1_data  ( dec1_data ),

    // ROMs
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),
    .obj_ok     ( obj_ok    ),

    .scr0a_cs   ( scr0a_cs  ),
    .scr0a_addr ( scr0a_addr),
    .scr0a_data ( scr0a_data),
    .scr0a_ok   ( scr0a_ok  ),

    .scr0b_cs   ( scr0b_cs  ),
    .scr0b_addr ( scr0b_addr),
    .scr0b_data ( scr0b_data),
    .scr0b_ok   ( scr0b_ok  ),

    .scr1a_cs   ( scr1a_cs  ),
    .scr1a_addr ( scr1a_addr),
    .scr1a_data ( scr1a_data),
    .scr1a_ok   ( scr1a_ok  ),

    .scr1b_cs   ( scr1b_cs  ),
    .scr1b_addr ( scr1b_addr),
    .scr1b_data ( scr1b_data),
    .scr1b_ok   ( scr1b_ok  ),

    // Palette PROMs
    .objpal_addr(objpal_addr),
    .objpal_data(objpal_data),

    .scrpal_addr(scrpal_addr),
    .scrpal_data(scrpal_data),

    .rgb_addr   ( rgb_addr  ),
    .rg_data    ( rgpal_data),
    .b_data     ( bpal_data[3:0] ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      ),
    // Debug
    .ioctl_din  ( ioctl_din ),
    .ioctl_addr ( ioctl_addr[4:0] ),
    .gfx_en     ( gfx_en    ),
    .debug_bus  ( debug_bus )
    // output reg [ 7:0] st_dout
);

endmodule
