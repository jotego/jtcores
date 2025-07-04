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
    Date: 28-6-2025 */

module jtajax_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

/* xxverilator tracing_off */
wire        cpu_cen, snd_irq, rmrd, rst8, vr_cs, rio_cs, sub_we, rvo,
            pal_we, cpu_we, tilesys_cs, objsys_cs, mcom_we, srstn, sub_firq,
            rvch_cs, cpu_rnw, cpu_irq_n, sub_irq_n;
wire [ 7:0] tilesys_dout, objsys_dout, mcom_dout, sub_dout, snd_latch,
            obj_dout, pal_dout, main_dout, rgfx_dout,
            st_main, st_video, st_snd;
wire        tilesys_rom_dtack, psacck_ok;
wire        prio;
reg  [ 7:0] debug_mux;

assign debug_view = debug_mux;
assign ram_din    = main_dout;

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= st_main;
        1: debug_mux <= st_video;
        2: debug_mux <= st_snd;
        3: debug_mux <= {1'b0,rmrd, 1'b0, prio, 4'd0};
    endcase
end

/* verilator tracing_on */
jtajax_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen_ref        ( cen24         ),
    .cen12          ( cen12         ),
    .cpu_cen        ( cpu_cen       ),
    .srstn          ( srstn         ),
    .sub_firq       ( sub_firq      ),

    .cpu_dout       ( main_dout     ),
    .cpu_we         ( cpu_we        ),

    .rom_addr       ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_we         ( ram_we        ),
    .ram_dout       ( ram_dout      ),
    // cabinet I/O
    .cab_1p         ( cab_1p[1:0]   ),
    .coin           ( coin[1:0]     ),
    .joystick1      ( joystick1     ),
    .service        ( service       ),

    // From video
    .rst8           ( rst8          ),
    .irq_n          ( cpu_irq_n     ),

    .com_we         ( mcom_we       ),
    .com_dout       ( mcom_dout     ),
    .objsys_dout    ( objsys_dout   ),

    .pal_dout       ( pal_dout      ),
    // To video
    .prio           ( prio          ),
    .objsys_cs      ( objsys_cs     ),
    .pal_we         ( pal_we        ),
    // To sound
    .snd_latch      ( snd_latch     ),
    .snd_irq        ( snd_irq       ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw          ( dipsw[19:0]   ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_main       )
);

jtajax_sub u_sub(
    .rstn           ( srstn         ),
    .clk            ( clk24         ),
    .clk48          ( clk           ),
    .cen3           ( cen3          ),

    .firq_trg       ( sub_firq      ),
    .irq_n          ( sub_irq_n     ),
    .vram_dout      ( tilesys_dout  ),
    .rmrd           ( rmrd          ),
    .rvo            ( rvo           ),
    .vr_cs          ( vr_cs         ),
    .io_cs          ( rio_cs        ),
    .vram_cs        ( tilesys_cs    ),
    .cpu_dout       ( sub_dout      ),
    .we             ( sub_we        ),
    // Communication RAM
    .main_addr      (main_addr[12:0]),
    .main_dout      ( main_dout     ),
    .main_we        ( mcom_we       ),
    .mcom_dout      ( mcom_dout     ),
    // ROM
    .rom_addr       ( sub_addr      ),
    .rom_cs         ( sub_cs        ),
    .rom_data       ( sub_data      ),
    .rom_ok         ( sub_ok        ),
    // 051316 - R chip outpus
    .psac_ok        ( psacck_ok     ),
    .rvch_cs        ( rvch_cs       ),
    .rrom_data      ( psac_data     ),
    .rgfx_dout      ( rgfx_dout     )
);

/* verilator tracing_off */
jtajax_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_fm     ( cen_fm        ),
    .cen_fm2    ( cen_fm2       ),
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
    .pcma_dout  ( pcma_data     ),
    .pcma_cs    ( pcma_cs       ),
    .pcma_ok    ( pcma_ok       ),

    .pcmb_addr  ( pcmb_addr     ),
    .pcmb_dout  ( pcmb_data     ),
    .pcmb_cs    ( pcmb_cs       ),
    .pcmb_ok    ( pcmb_ok       ),

    // ADPCM 2 ROM
    .pcm2a_addr ( pcm2a_addr    ),
    .pcm2a_dout ( pcm2a_data    ),
    .pcm2a_cs   ( pcm2a_cs      ),
    .pcm2a_ok   ( pcm2a_ok      ),

    .pcm2b_addr ( pcm2b_addr    ),
    .pcm2b_dout ( pcm2b_data    ),
    .pcm2b_cs   ( pcm2b_cs      ),
    .pcm2b_ok   ( pcm2b_ok      ),

    // Sound output
    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          ),
    .pcm1       ( pcm1          ),
    .pcm2       ( pcm2          ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_snd        )
);

/* xxxverilator tracing_off */
/* verilator tracing_on */
jtajax_video u_video (
    .rst            ( rst           ),
    .rst8           ( rst8          ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .cen24          ( cen24         ),
    .cpu_prio       ( prio          ),

    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),
    .rvo            ( rvo           ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      ( prog_addr[8:0]),
    .prog_data      ( prog_data[2:0]),
    // GFX - CPU interface
    .main_we        ( cpu_we        ),
    .sub_addr       ( sub_addr[15:0]),
    .sub_dout       ( sub_dout      ),
    .sub_we         ( sub_we        ),
    .vr_cs          ( vr_cs         ),
    .rio_cs         ( rio_cs        ),
    .objsys_cs      ( objsys_cs     ),
    .tilesys_cs     ( tilesys_cs    ),
    .pal_we         ( pal_we        ),
    .main_addr      (main_addr[15:0]),
    .main_dout      ( main_dout     ),
    .tilesys_dout   ( tilesys_dout  ),
    .tilesys_rom_dtack ( tilesys_rom_dtack ),
    .psacck_ok      ( psacck_ok     ),
    .psac_dout      ( rgfx_dout     ),
    .objsys_dout    ( objsys_dout   ),
    .pal_dout       ( pal_dout      ),
    .rmrd           ( rmrd          ),
    .obj_irqn       ( cpu_irq_n     ),
    .tile_irqn      ( sub_irq_n     ),
    // SDRAM
    .lyra_addr      ( lyra_addr     ),
    .lyrb_addr      ( lyrb_addr     ),
    .lyrf_addr      ( lyrf_addr     ),
    .lyro_addr      ( lyro_addr     ),
    .psac_addr      ( psac_addr     ),
    .psac_data      ( psac_data     ),
    .lyra_data      ( lyra_data     ),
    .lyrb_data      ( lyrb_data     ),
    .lyro_data      ( lyro_data     ),
    .lyrf_data      ( lyrf_data     ),
    .lyrf_cs        ( lyrf_cs       ),
    .lyra_cs        ( lyra_cs       ),
    .lyrb_cs        ( lyrb_cs       ),
    .lyro_cs        ( lyro_cs       ),
    .psac_cs        ( psac_cs       ),
    .lyra_ok        ( lyra_ok       ),
    .lyro_ok        ( lyro_ok       ),
    .psac_ok        ( psac_ok       ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .ioctl_addr     (ioctl_addr[14:0]),
    .ioctl_din      ( ioctl_din     ),
    .ioctl_ram      ( ioctl_ram     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

endmodule
