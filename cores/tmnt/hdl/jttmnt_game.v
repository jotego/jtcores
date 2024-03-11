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

module jttmnt_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

/* verilator tracing_off */
wire [ 7:0] snd_latch;
wire        snd_irq, rmrd, rst8;
wire        pal_cs, cpu_we, tilesys_cs, objsys_cs, pcu_cs;
wire        cpu_rnw, odtac, vdtac, tile_irqn, tile_nmin, snd_wrn;
wire [ 7:0] tilesys_dout, objsys_dout, snd2main,
            obj_dout,
            st_main, st_video, st_snd;
wire [15:0] pal_dout;
wire [ 1:0] prio;
reg  [ 7:0] debug_mux;
reg  [ 2:0] game_id;

assign debug_view = debug_mux;
assign ram_addr   = { main_addr[17], main_addr[13:1] };
assign ram_we     = cpu_we;

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= { 7'd0, dip_flip };
        1: debug_mux <= st_video;
        2: debug_mux <= st_snd;
        3: debug_mux <= st_main;
    endcase
end

always @(posedge clk) begin
    if( prog_addr==0 && prog_we && header )
        game_id <= prog_data[2:0];
end

/* verilator tracing_on */
jttmnt_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .LVBL           ( LVBL          ),

    .game_id        ( game_id       ),
    .cpu_we         ( cpu_we        ),
    .cpu_dout       ( ram_din       ),
    .odtac          ( odtac         ),
    .vdtac          ( vdtac         ),
    .tile_irqn      ( tile_irqn     ),
    .tile_nmin      ( tile_nmin     ),

    .main_addr      ( main_addr     ),
    .rom_data       ( main_data     ),
    .rom_cs         ( main_cs       ),
    .rom_ok         ( main_ok       ),
    // RAM
    .ram_dsn        ( ram_dsn       ),
    .ram_dout       ( ram_data      ),
    .ram_cs         ( ram_cs        ),
    .ram_ok         ( ram_ok        ),
    // cabinet I/O
    .cab_1p         ( cab_1p        ),
    .coin           ( coin          ),
    .joystick1      ( joystick1     ),
    .joystick2      ( joystick2     ),
    .joystick3      ( joystick3     ),
    .joystick4      ( joystick4     ),
    .service        ( service       ),

    .vram_dout      ( tilesys_dout  ),
    .oram_dout      ( objsys_dout   ),
    .pal_dout       ( pal_dout      ),
    // To video
    .prio           ( prio          ),
    .rmrd           ( rmrd          ),
    .obj_cs         ( objsys_cs     ),
    .vram_cs        ( tilesys_cs    ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ),
    // To sound
    .snd_latch      ( snd_latch     ),
    .sndon          ( snd_irq       ),
    .snd2main       ( snd2main      ),
    .snd_wrn        ( snd_wrn       ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dip_test       ( dip_test      ),
    .dipsw          ( { dipsw[19:16], dipsw[15:0] } ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);

/* verilator tracing_on */
jttmnt_video u_video (
    .rst            ( rst           ),
    .rst8           ( rst8          ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .game_id        ( game_id       ),
    .cpu_prio       ( prio          ),

    .tile_irqn      ( tile_irqn     ),
    .tile_nmin      ( tile_nmin     ),

    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),
    // PROMs
    .prom_we        ( prom_we       ),
    .prog_addr      ( prog_addr[8:0]),
    .prog_data      ( prog_data[2:0]),
    // GFX - CPU interface
    .cpu_we         ( cpu_we        ),
    .objsys_cs      ( objsys_cs     ),
    .tilesys_cs     ( tilesys_cs    ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ),
    .cpu_addr       (main_addr[16:1]),
    .cpu_dsn        ( ram_dsn       ),
    .cpu_dout       ( ram_din       ),
    .odtac          ( odtac         ),
    .vdtac          ( vdtac         ),
    .tilesys_dout   ( tilesys_dout  ),
    .objsys_dout    ( objsys_dout   ),
    .pal_dout       ( pal_dout      ),
    .rmrd           ( rmrd          ),
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
    .lyra_ok        ( lyra_ok       ),
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


/* verilator tracing_off */
jttmnt_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_fm     ( cen_fm        ),
    .cen_fm2    ( cen_fm2       ),
    .cen_640    ( cen_640       ),
    .cen_20     ( cen_20        ),
    .game_id    ( game_id       ),
    // communication with main CPU
    .main_dout  ( ram_din[7:0]  ),
    .main_din   ( snd2main      ),
    .main_addr  ( main_addr[1]  ),
    .main_rnw   ( snd_wrn       ),
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

    .pcmc_addr  ( pcmc_addr     ),
    .pcmc_dout  ( pcmc_data     ),
    .pcmc_cs    ( pcmc_cs       ),
    .pcmc_ok    ( pcmc_ok       ),

    .pcmd_addr  ( pcmd_addr     ),
    .pcmd_dout  ( pcmd_data     ),
    .pcmd_cs    ( pcmd_cs       ),
    .pcmd_ok    ( pcmd_ok       ),

    .upd_addr   ( upd_addr      ),
    .upd_cs     ( upd_cs        ),
    .upd_data   ( upd_data      ),
    .upd_ok     ( upd_ok        ),
    // Title music
    .title_data ( title_data    ),
    .title_cs   ( title_cs      ),
    .title_addr ( title_addr    ),
    .title_ok   ( title_ok      ),
    // Sound output
    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          ),
    .pcm        ( pcm           ),
    .upd        ( upd           ),
    .k60_l      (               ),
    .k60_r      (               ),
    .title      ( title         ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_snd        )
);

endmodule
