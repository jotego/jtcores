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
    Date: 02-05-2020 */

module jtcontra_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// Defines which game to render
`ifndef JTCONTRA_PCB
`define  JTCONTRA_PCB 0
`endif

localparam GAME=`JTCONTRA_PCB;

wire        snd_irq;

wire [ 7:0] snd_latch, st_snd;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 3:0] dipsw_c;
reg  [ 7:0] debug_mux;

wire [15:0] cpu_addr;
wire        gfx1_ramcs, gfx2_ramcs, gfx1_cfg_cs, gfx2_cfg_cs, pal_cs;
wire        gfx1_vram_cs, gfx2_vram_cs;
wire        cpu_cen, cpu_rnw, cpu_irqn, cpu_nmin;
wire [ 7:0] gfx1_dout, gfx2_dout, pal_dout, cpu_dout, st_video;
wire [ 7:0] video_bank;
wire        prio_latch;

assign { dipsw_c, dipsw_b, dipsw_a } = dipsw[19:0];
assign debug_view = debug_mux;

always @(posedge clk) begin
    case( debug_bus[7] )
        0: debug_mux <= st_snd;
        1: debug_mux <= st_video;
    endcase
end

`ifdef GFX_ONLY
jtcontra_simloader u_simloader(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .cpu_cen    ( cpu_cen       ),
    // GFX
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_rnw    ( cpu_rnw       ),
    .gfx1_cs    ( gfx1_ramcs    ),
    .gfx2_cs    ( gfx2_ramcs    ),
    .pal_cs     ( pal_cs        ),
    .video_bank ( video_bank    ),
    .prio_latch ( prio_latch    )
);
`else
`ifndef NOMAIN
jtcontra_main #(.GAME(GAME)) u_main(
    .clk            ( clk24         ),        // 24 MHz
    .rst            ( rst24         ),
    .cen3           ( cen3          ),
    .cpu_cen        ( cpu_cen       ),
    // communication with main CPU
    .snd_irq        ( snd_irq       ),
    .snd_latch      ( snd_latch     ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( 1'b1          ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ({1'b1,joystick1}),
    .joystick2      ({1'b1,joystick2}),
    .service        ( service       ),
    // GFX
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_rnw        ( cpu_rnw       ),
    .gfx_irqn       ( cpu_irqn      ),
    .gfx_nmin       ( cpu_nmin      ),
    .gfx1_cs        ( gfx1_ramcs    ),
    .gfx2_cs        ( gfx2_ramcs    ),
    .pal_cs         ( pal_cs        ),

    .gfx1_dout      ( gfx1_dout     ),
    .gfx2_dout      ( gfx2_dout     ),
    .pal_dout       ( pal_dout      ),

    .video_bank     ( video_bank    ),
    .prio_latch     ( prio_latch    ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw_a        ( dipsw_a       ),
    .dipsw_b        ( dipsw_b       ),
    .dipsw_c        ( dipsw_c       )
);
`else
// load a sound code for simulation
assign snd_latch = 8'h22;
reg pre_irq=0;
initial begin
    #100_000_000 pre_irq=1;
end

assign snd_irq = pre_irq;
`endif
`endif

`ifndef NOVIDEO
jtcontra_video #(.GAME(GAME)) u_video (
    .rst            ( rst           ),
    .clk            ( clk           ),
    .clk24          ( clk24         ),
    .pxl2_cen       ( pxl2_cen      ),
    .pxl_cen        ( pxl_cen       ),
    .LHBL           ( LHBL          ),
    .LVBL           ( LVBL          ),
    .HS             ( HS            ),
    .VS             ( VS            ),
    .flip           ( dip_flip      ),
    .dip_pause      ( dip_pause     ),
    .cab_1p   ( &cab_1p ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      ( prog_addr[9:0]),
    .prog_data      ( prog_data[3:0]),
    // GFX - CPU interface
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
    .prio_latch     ( prio_latch    ),
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
    .gfx_en         ( gfx_en        ),
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_video      )
);
`endif

jtcontra_sound u_sound(
    .clk        ( clk24         ), // 24 MHz
    .rst        ( rst24         ),
`ifdef COMSC
    .cen_fm     ( cen3          ),
    .cen_fm2    ( cen1p5        ),
    .fm         ( fm            ),
    .psg        ( psg           ),
    .pcm        ( pcm           ),
`else
    .cen_fm     ( cen_fm        ),
    .cen_fm2    ( cen_fm2       ),
    // Sound output
    .fm_l       ( fm_r          ), // R/L channels reversed in
    .fm_r       ( fm_l          ), // the real PCB too
`endif
    // communication with main CPU
    .snd_irq    ( snd_irq       ),
    .snd_latch  ( snd_latch     ),
    // ROM
    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( 1'b1          ),
    // ADPCM ROM
    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),
    .st_dout    ( st_snd        )
);

endmodule
