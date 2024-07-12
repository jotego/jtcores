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
    Date: 7-7-2024 */

module jtssriders_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

/* verilator tracing_off */
wire        snd_irq, rmrd, rst8, dimmod, dimpol;
wire        pal_cs, cpu_we, tilesys_cs, objsys_cs, pcu_cs;
wire        cpu_rnw, vdtac, tile_irqn, tile_nmin, snd_wrn;
wire [15:0] pal_dout;
wire [ 7:0] tilesys_dout, objsys_dout, snd2main,
            obj_dout, snd_latch,
            st_main, st_video, st_snd;
wire [ 2:0] dim;
reg  [ 7:0] debug_mux;

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

/* verilator tracing_off */
jtssriders_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .LVBL           ( LVBL          ),

    .cpu_we         ( cpu_we        ),
    .cpu_dout       ( ram_din       ),
    .vdtac          ( vdtac         ),
    .tile_irqn      ( tile_irqn     ),

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
    .rmrd           ( rmrd          ),
    .dimmod         ( dimmod        ),
    .dimpol         ( dimpol        ),
    .dim            ( dim           ),
    .cbnk           (               ),

    .obj_cs         ( objsys_cs     ),
    .vram_cs        ( tilesys_cs    ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ), // priority mixer
    // To sound
    .sndon          ( snd_irq       ),
    .snd2main       ( snd2main      ),
    .snd_wrn        ( snd_wrn       ),
    // EEPROM
    .nv_addr        ( nv_addr       ),
    .nv_dout        ( nv_dout       ),
    .nv_din         ( nv_din        ),
    .nv_we          ( nv_we         ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dip_test       ( dip_test      ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);

/* verilator tracing_off */
jtssriders_video u_video (
    .rst            ( rst           ),
    .rst8           ( rst8          ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),

    .tile_irqn      ( tile_irqn     ),
    .tile_nmin      (               ),

    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),
    // GFX - CPU interface
    .cpu_we         ( cpu_we        ),
    .objsys_cs      ( objsys_cs     ),
    .tilesys_cs     ( tilesys_cs    ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ),
    .cpu_addr       (main_addr[16:1]),
    .cpu_dsn        ( ram_dsn       ),
    .cpu_dout       ( ram_din       ),
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
    // brightness
    .dim            ( dim           ),
    .dimmod         ( dimmod        ),
    .dimpol         ( dimpol        ),
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

/* verilator tracing_on */
jtssriders_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_fm     ( cen_fm        ),
    .cen_fm2    ( cen_fm2       ),
    // communication with main CPU
    .main_dout  ( ram_din[7:0]  ),
    .main_din   ( snd2main      ),
    .main_addr  ( main_addr[1]  ),
    .main_rnw   ( snd_wrn       ),
    .snd_irq    ( snd_irq       ),
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

    // Sound output
    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          ),
    .k60_l      ( k60_l         ),
    .k60_r      ( k60_r         )
);

endmodule
