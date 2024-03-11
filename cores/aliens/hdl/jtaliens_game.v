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

module jtaliens_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

/* verilator tracing_off */
wire [ 7:0] snd_latch;
wire        cpu_cen, snd_irq, rmrd, rst8, init;
wire        pal_we, cpu_we, tilesys_cs, objsys_cs;
wire        cpu_rnw, cpu_irq_n, cpu_nmi_n;
wire [ 7:0] tilesys_dout, objsys_dout,
            obj_dout, pal_dout, cpu_dout,
            st_main, st_video, st_snd;
wire [ 1:0] prio;
reg  [ 7:0] debug_mux;
reg  [ 1:0] game_id;
reg         gx878;

assign debug_view = debug_mux;
assign ram_din    = cpu_dout;

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= st_main;
        1: debug_mux <= st_video;
        2: debug_mux <= st_snd;
        3: debug_mux <= {init,rmrd, prio, 2'd0, game_id};
    endcase
end

always @(posedge clk) begin
    if( prog_addr==0 && prog_we && header )
        { game_id, gx878 } <= prog_data[2:0];
end

// always @(*) begin
//     post_addr = prog_addr;
//     if( prog_ba[1] ) begin
//         post_addr[]
//     end
// end

/* verilator tracing_off */
jtaliens_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen_ref        ( cen24         ),
    .cen12          ( cen12         ),
    .cpu_cen        ( cpu_cen       ),

    .cfg            ( game_id       ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_we         ( cpu_we        ),

    .rom_addr       ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_we         ( ram_we        ),
    .ram_dout       ( ram_dout      ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .joystick4      ( joystick4     ),
    .service        ( service       ),

    // From video
    .rst8           ( rst8          ),
    .irq_n          ( cpu_irq_n     ),
    .nmi_n          ( cpu_nmi_n     ),

    .tilesys_dout   ( tilesys_dout  ),
    .objsys_dout    ( objsys_dout   ),

    .pal_dout       ( pal_dout      ),
    // To video
    .prio           ( prio          ),
    .objsys_cs      ( objsys_cs     ),
    .tilesys_cs     ( tilesys_cs    ),
    .init           ( init          ),
    .rmrd           ( rmrd          ),
    .pal_we         ( pal_we        ),
    // To sound
    .snd_latch      ( snd_latch     ),
    .snd_irq        ( snd_irq       ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dipsw          ( dipsw[19:0]   ),
    // PMC (Thunder Force)
    .pmc_we         ( pmc_we        ),
    .pmc_addr       ( pmc_addr      ),
    .pmc_dout       ( pmc_dout      ),
    .pmc_din        ( pmc_din       ),
    .cpu2pmc_we     ( cpu2pmc_we    ),
    .pmc2main_data  ( pmc2main_data ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_main       )
);

/* verilator tracing_off */
jtaliens_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_fm     ( cen_fm        ),
    .cen_fm2    ( cen_fm2       ),
    .fxlevel    ( dip_fxlevel   ),
    .cfg        ( game_id       ),
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

    // Sound output
    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          ),
    .pcm        ( pcm           ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_snd        )
);

/* verilator tracing_off */
jtaliens_video u_video (
    .rst            ( rst           ),
    .rst8           ( rst8          ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .gx878          ( gx878         ),
    .cfg            ( game_id       ),
    .cpu_prio       ( prio          ),

    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      (prog_addr[ 7:0]),
    .prog_data      ( prog_data[2:0]),
    // GFX - CPU interface
    .cpu_we         ( cpu_we        ),
    .objsys_cs      ( objsys_cs     ),
    .tilesys_cs     ( tilesys_cs    ),
    .pal_we         ( pal_we        ),
    .cpu_addr       (main_addr[15:0]),
    .cpu_dout       ( cpu_dout      ),
    .tilesys_dout   ( tilesys_dout  ),
    .objsys_dout    ( objsys_dout   ),
    .pal_dout       ( pal_dout      ),
    .rmrd           ( rmrd          ),
    .cpu_irq_n      ( cpu_irq_n     ),
    .cpu_nmi_n      ( cpu_nmi_n     ),
    // SDRAM
    .lyra_addr      ( lyra_addr     ),
    .lyrb_addr      ( lyrb_addr     ),
    .lyrf_addr      ( lyrf_addr     ),
    .lyro_addr      ( lyro_addr     ),
    .lyra_data      ( lyra_data     ),
    .lyrb_data      ( lyrb_data     ),
    .lyro_data      ( lyro_data     ),
    .lyrf_data      ( lyrf_data     ),
    .lyrf_cs        ( lyrf_cs       ),
    .lyra_cs        ( lyra_cs       ),
    .lyrb_cs        ( lyrb_cs       ),
    .lyro_cs        ( lyro_cs       ),
    .lyro_ok        ( lyro_ok       ),
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
