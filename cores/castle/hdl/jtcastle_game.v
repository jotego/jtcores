/*  This file is part of JTCONTRA.
    JTCONTRA program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCONTRA program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCONTRA.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 1-2-2023 */

module jtcastle_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire        snd_irq;

wire [ 7:0] snd_latch;
wire        cpu_cen, cen12, cen3, cen1p5;

wire [ 7:0] dipsw_a, dipsw_b;
wire [ 3:0] dipsw_c;
reg  [ 7:0] debug_mux;

wire [15:0] cpu_addr;
wire        gfx1_ramcs, gfx2_ramcs, gfx1_cfg_cs, gfx2_cfg_cs, pal_cs;
wire        gfx1_vram_cs, gfx2_vram_cs;
wire        cpu_rnw, cpu_irqn, cpu_firqn, cpu_nmin;
wire [ 7:0] gfx1_dout, gfx2_dout, pal_dout, cpu_dout;
wire [ 1:0] video_bank;
wire        prio;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
assign dipsw_c    = dipsw[23:20];
assign debug_view = debug_mux;
assign ram_din    = cpu_dout;

always @(posedge clk) begin
    case( debug_bus[1:0] )
        0: debug_mux <= dipsw_a;
        1: debug_mux <= dipsw_b;
        2: debug_mux <= {4'd0, dipsw_c};
        3: debug_mux <= 0;
    endcase
end

jtframe_cen24 u_cen(
    .clk        ( clk24         ),    // 24 MHz
    .cen12      ( cen12         ),
    .cen8       (               ),
    .cen6       (               ),
    .cen4       (               ),
    .cen3       ( cen3          ),
    .cen3q      (               ), // 1/4 advanced with respect to cen3
    .cen1p5     ( cen1p5        ),
    // 180 shifted signals
    .cen12b     (               ),
    .cen6b      (               ),
    .cen3b      (               ),
    .cen3qb     (               ),
    .cen1p5b    (               )
);

jtcastle_main u_main(
    .clk            ( clk           ),        // 24 MHz
    .rst            ( rst           ),
    .cpu_cen        ( cpu_cen       ),
    // communication with main CPU
    .snd_irq        ( snd_irq       ),
    .snd_latch      ( snd_latch     ),
    // ROM
    .rom_addr       ( main_addr     ),
    .rom_cs         ( main_cs       ),
    .rom_data       ( main_data     ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_we         ( ram_we        ),
    .ram_dout       ( ram_dout      ),
    // cabinet I/O
    .start_button   ( start_button  ),
    .coin_input     ( coin_input    ),
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
    .dipsw_c        ( dipsw_c       )
);
/* verilator tracing_off */
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
    .dip_pause      ( dip_pause     ),
    .start_button   ( &start_button ),
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
    .gfx_en         ( gfx_en        )
);
/* verilator tracing_on */

jtcastle_sound u_sound(
    .rst        ( rst24         ),
    .clk        ( clk24         ), // 24 MHz
    .fxlevel    ( dip_fxlevel   ),
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
    .snd        ( snd           ), // channels reversed in
    .sample     ( sample        ),
    .peak       ( game_led      )
);

endmodule