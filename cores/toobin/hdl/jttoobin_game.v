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

    Author: Andrea Bogazzi. andreabogazzi79@gmail.com
    Version: 1.0
    Date: 25-06-2026 */

// Toobin' (Atari, 1988) top. CPU-spine bring-up: fx68k main + stubbed video/sound.
// Video is black until the tilemap/MO pipeline lands; this is the boot-trace target.
module jttoobin_game(
    `include "jtframe_game_ports.inc"
);

wire [ 8:0] vdump, vrender, vrender1, h9;
wire [ 1:0] cpu_dsn;
wire [13:1] cpu_addr;
wire        cpu_rnw, eeprom_cs, pf_cs, al_cs, mob_cs, cram_cs;
wire [15:0] xscroll, yscroll, slip;
wire [ 4:0] intensity;
wire [ 7:0] snd_cmd;
wire        snd_cmdwr, snd_rstn;

assign red        = 0;
assign green      = 0;
assign blue       = 0;
assign snd        = 0;   // silent until JSA-I lands
assign sample     = 0;
assign debug_view = 0;
assign dip_flip   = 0;

// gfx + sound SDRAM buses idle (no consumers yet)
assign snd_cs  = 0, snd_addr  = 0;
assign char_cs = 0, char_addr = 0;
assign tile_cs = 0, tile_addr = 0;
assign obj_cs  = 0, obj_addr  = 0;
// video read side of the dual-port BRAMs idle
assign pfrd_addr  = 0;
assign alrd_addr  = 0;
assign mobrd_addr = 0;
assign palrd_addr = 0;

/* verilator tracing_off */
jtframe_vtimer #(
    // Toobin' (MAME set_raw 640x416 total, 512x384 visible). H visible count =
    // HCNT_END+1-(HB_END-HB_START) = 640-128 = 512. Refine HS/VS with the SYNGEN
    // sheet during video bring-up; boot trace only needs the size to match.
    // NOTE: H counter is 9-bit (max 511) but toobin htotal=640. Real video needs a
    // half-rate H or HJUMP (revisit with SYNGEN). For boot trace, clamp <=511 so LVBL/
    // LHBL/HS toggle (vsize check is skipped); exact width is intentionally wrong here.
    .V_START  ( 9'd0   ),
    .VB_START ( 9'd383 ),
    .VB_END   ( 9'd415 ),
    .VS_START ( 9'd388 ),
    .HB_START ( 9'd480 ),
    .HB_END   ( 9'd510 ),
    .HS_START ( 9'd490 )
) u_vtimer(
    .clk      ( clk      ),
    .pxl_cen  ( pxl_cen  ),
    .vdump    ( vdump    ),
    .vrender  ( vrender  ),
    .vrender1 ( vrender1 ),
    .H        ( h9       ),
    .Hinit    (          ),
    .Vinit    (          ),
    .LHBL     ( LHBL     ),
    .LVBL     ( LVBL     ),
    .HS       ( HS       ),
    .VS       ( VS       )
);

/* verilator tracing_on */
jttoobin_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .vdump      ( vdump         ),

    .rom_addr   ( main_addr     ),
    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),

    .cpu_addr   ( cpu_addr      ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_rnw    ( cpu_rnw       ),

    .ram_we     ( ram_we        ),
    .ram_dout   ( ram_dout      ),

    .eeprom_cs  ( eeprom_cs     ),
    .nvram_we   ( nvram_we      ),
    .nvram_dout ( nvram_dout    ),

    .pf_cs      ( pf_cs         ),
    .pf_we      ( pf_we         ),
    .pf_dout    ( pf_dout       ),
    .al_cs      ( al_cs         ),
    .al_we      ( al_we         ),
    .al_dout    ( al_dout       ),
    .mob_cs     ( mob_cs        ),
    .mob_we     ( mob_we        ),
    .mob_dout   ( mob_dout      ),
    .cram_cs    ( cram_cs       ),
    .pal_we     ( pal_we        ),
    .pal_dout   ( pal_dout      ),

    .xscroll    ( xscroll       ),
    .yscroll    ( yscroll       ),
    .slip       ( slip          ),
    .intensity  ( intensity     ),

    .snd_cmd    ( snd_cmd       ),
    .snd_cmdwr  ( snd_cmdwr     ),
    .snd_rstn   ( snd_rstn      ),
    .snd_resp   ( 8'hff         ),
    .snd_rdy    ( 1'b1          ),

    .dipsw      ( dipsw[15:0]   ),
    .dip_pause  ( dip_pause     ),
    .service    ( service       ),
    .st_dout    ( debug_view    ),
    .debug_bus  ( debug_bus     )
);

endmodule
