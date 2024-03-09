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
    Date: 1-2-2023 */

module jtcastle_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        snd_irq;

wire [ 7:0] snd_latch;
wire        cpu_cen;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 3:0] dipsw_c;
reg  [ 7:0] debug_mux;

wire [15:0] cpu_addr;
wire        gfx1_ramcs, gfx2_ramcs, gfx1_cfg_cs, gfx2_cfg_cs, pal_cs;
wire        gfx1_vram_cs, gfx2_vram_cs;
wire        cpu_rnw, cpu_irqn, cpu_firqn, cpu_nmin;
wire [ 7:0] gfx1_dout, gfx2_dout, pal_dout, cpu_dout, st_video;
wire [ 1:0] video_bank;
wire        prio, buserror;

assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[19:0];
assign debug_view = debug_mux;
assign ram_din    = cpu_dout;

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= st_video;
        1: debug_mux <= dipsw_a;
        2: debug_mux <= dipsw_b;
        3: debug_mux <= { dipsw_c, buserror, prio, video_bank };
    endcase
end

jtcastle_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cpu_cen        ( cpu_cen       ),
    .cen24          ( cen24         ),
    .cen12          ( cen12         ),
    // communication with main CPU
    .snd_irq        ( snd_irq       ),
    .snd_latch      ( snd_latch     ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_addr       ( ram_addr      ),
    .ram_we         ( ram_we        ),
    .ram_dout       ( ram_dout      ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .service        ( service       ),
    // GFX
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),
    .gfx_firqn      ( cpu_firqn     ),
    .gfx_irqn       ( cpu_irqn      ),
    .gfx_nmin       ( cpu_nmin      ),
    .gfx1_cs        ( gfx1_ramcs    ),
    .gfx2_cs        ( gfx2_ramcs    ),
    .pal_cs         ( pal_cs        ),

    .gfx1_dout      ( gfx1_dout     ),
    .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),

    .video_bank     ( video_bank    ),
    .prio           ( prio          ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    .dipsw_c        ( dipsw_c       ),
    .buserror       ( buserror      )
);
/* xxxverilator tracing_off */
jtcastle_video u_video (
    .rst            ( rst           ),
    .clk            ( clk           ),
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( dip_flip      ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      (prog_addr[10:0]),
    .prog_data      ( prog_data[3:0]),
    // GFX - CPU interface
    .cpu_firqn      ( cpu_firqn     ),
    .cpu_irqn       ( cpu_irqn      ),
    .cpu_nmin       ( cpu_nmin      ),
    .gfx1_cs        ( gfx1_ramcs    ),
    .gfx2_cs        ( gfx2_ramcs    ),
    .pal_cs         ( pal_cs        ),
    .cpu_rnw        ( cpu_rnw       ),
    .cpu_cen        ( cpu_cen       ),
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .gfx1_dout      ( gfx1_dout     ),
    .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),
    .video_bank     ( video_bank    ),
    .prio           ( prio          ),
    // SDRAM
    .gfx1_addr      ( gfx1_addr     ),
    .gfx1_data      ( gfx1_data     ),
    .gfx1_ok        ( gfx1_ok       ),
    .gfx1_romcs     ( gfx1_cs       ),
    .gfx2_addr      ( gfx2_addr     ),
    .gfx2_data      ( gfx2_data     ),
    .gfx2_ok        ( gfx2_ok       ),
    .gfx2_romcs     ( gfx2_cs       ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Test
    .debug_bus      ( debug_bus     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

jtcastle_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    // communication with main CPU
    .snd_irq    ( snd_irq       ),
    .snd_latch  ( snd_latch     ),
    // ROM
    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),
    // ADPCM ROM
    .pcma_addr  ( pcma_addr     ),
    .pcma_cs    ( pcma_cs       ),
    .pcma_data  ( pcma_data     ),
    .pcma_ok    ( pcma_ok       ),

    .pcmb_addr  ( pcmb_addr     ),
    .pcmb_cs    ( pcmb_cs       ),
    .pcmb_data  ( pcmb_data     ),
    .pcmb_ok    ( pcmb_ok       ),
    // Sound output
    .fm         ( fm            ),
    .pcm_a      ( pcm_a         ),
    .pcm_b      ( pcm_b         ),
    .scc        ( scc           ),
    .debug_bus  ( debug_bus     )
);

endmodule
