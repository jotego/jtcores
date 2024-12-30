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
    Date: 23-8-2024 */

module jtxmen_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// localparam [2:0] XMEN     = 3'd2;

/* verilator tracing_off */
wire        snd_irq, rmrd, rst8, dma_bsy,
            pal_cs, cpu_we, tilesys_cs, objsys_cs, pcu_cs, mute, objcha_n,
            cpu_rnw, vdtac, tile_irqn, tile_nmin, snd_wrn,
            objreg_cs, pair_we;
wire [15:0] pal_dout, oram_dout;
wire [15:0] video_dumpa;
wire [13:1] oram_addr;
reg  [ 7:0] debug_mux;
// reg  [ 2:0] game_id;
// reg         xmen;
wire [ 7:0] tilesys_dout, snd2main,
            obj_dout, snd_latch, pair_dout,
            st_main, st_video, st_snd;
wire [ 1:0] oram_we;

assign debug_view = debug_mux;
assign ram_we     = cpu_we & ram_cs;
assign ram_addr   = main_addr[13:1];
assign video_dumpa= ioctl_addr[15:0]-16'h80; // subtract NVRAM offset

always @(posedge clk) begin
    debug_mux <= st_snd;
    // case( debug_bus[7:6] )
    //     0: debug_mux <= st_main;
    //     1: debug_mux <= st_video;
    //     2: debug_mux <= st_snd;
    //     3: debug_mux <= { mute, /*xmen,*/ 7'b0 };
    //     default: debug_mux <= 0;
    // endcase
end

/*always @(posedge clk) begin
    if( prog_addr[3:0]==15 && prog_we && header ) game_id <= prog_data[2:0];
    xmen     <= game_id == XMEN;
end
*/
/* verilator tracing_off */
jtxmen_main u_main(
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
    .service        ( {4{service}}  ),

    .vram_dout      ( tilesys_dout  ),
    .oram_dout      ( oram_dout     ),
    .pal_dout       ( pal_dout      ),
    // To video
    .rmrd           ( rmrd          ),
    .dma_bsy        ( dma_bsy       ),
    .objreg_cs      ( objreg_cs     ),
    .objcha_n       ( objcha_n      ),

    .obj_cs         ( objsys_cs     ),
    .vram_cs        ( tilesys_cs    ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ), // priority mixer
    // To sound
    .sndon          ( snd_irq       ),
    .snd2main       ( snd2main      ),
    .snd_wrn        ( snd_wrn       ),
    .mute           ( mute          ),
    .pair_we        ( pair_we       ),
    .pair_dout      ( pair_dout     ),
    // EEPROM
    .nv_addr        ( nvram_addr    ),
    .nv_dout        ( nvram_dout    ),
    .nv_din         ( nvram_din     ),
    .nv_we          ( nvram_we      ),
    // DIP switches
    .dip_pause      ( dip_pause     ),
    .dip_test       ( dip_test      ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);

assign oram_we   = ~ram_dsn & {2{cpu_we}};
assign oram_addr = {main_addr[6:5], main_addr[1], main_addr[13:7], main_addr[4:2]};

/* verilator tracing_on */
jtxmen_video u_video (
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
    // Object DMA
    .oram_we        ( oram_we       ),
    .oram_din       ( ram_din       ),
    .oram_addr      ( oram_addr     ),
    // GFX - CPU interface
    .cpu_we         ( cpu_we        ),
    .objsys_cs      ( objsys_cs     ),
    .objreg_cs      ( objreg_cs     ),
    .objcha_n       ( objcha_n      ),
    .tilesys_cs     ( tilesys_cs    ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ),
    .cpu_addr       (main_addr[16:1]),
    .cpu_dsn        ( ram_dsn       ),
    .cpu_dout       ( ram_din       ),
    .vdtac          ( vdtac         ),
    .tilesys_dout   ( tilesys_dout  ),
    .objsys_dout    ( oram_dout     ),
    .pal_dout       ( pal_dout      ),
    .rmrd           ( rmrd          ),
    .dma_bsy        ( dma_bsy       ),
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
    .dim            (  3'b0         ),
    .dimmod         (  1'b0         ),
    .dimpol         (  1'b0         ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .ioctl_addr     ( video_dumpa   ),
    .ioctl_din      ( ioctl_din     ),
    .ioctl_ram      ( ioctl_ram     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

/* verilator tracing_on */
jtxmen_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_8      ( cen_8         ),
    .cen_4      ( cen_4         ),
    .cen_2      ( cen_2         ),
    .cen_pcm    ( cen_pcm       ),

    .pair_we    ( pair_we       ),
    .pair_dout  ( pair_dout     ),
    // communication with main CPU
    .main_dout  ( ram_din[7:0]  ),
    .main_din   ( snd2main      ),
    .main_addr  ( main_addr[4:1]),
    .main_rnw   ( snd_wrn       ),
    .snd_irq    ( snd_irq       ),
    // ROM
    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),
    // ADPCM ROM
    .pcm_addr   ( pcm_addr      ),
    .pcm_dout   ( pcm_data      ),
    .pcm_cs     ( pcm_cs        ),
    // Sound output
    .fm_l       ( fm_l          ),
    .fm_r       ( fm_r          ),
    .k539_l     ( k539_l        ),
    .k539_r     ( k539_r        ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_snd        )
);

endmodule
