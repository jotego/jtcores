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
    Date: 23-7-2023 */

module jtsimson_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

/* verilator tracing_off */
wire [ 7:0] snd2main, video_dump;
wire        cpu_cen, snd_irq, rmrd, rst8, init;
wire        pal_we, pal_bank,
            cpu_we, tilesys_cs, objsys_cs, pcu_cs, objcha_n;
wire        cpu_rnw, cpu_irqn, dma_bsy, snd_wrn, mono, objreg_cs;
wire [ 7:0] tilesys_dout, objsys_dout,
            obj_dout, pal_dout, cpu_dout,
            st_main, st_video, st_snd;
wire [15:0] cpu_addr;
wire [14:0] video_dumpa;
reg  [ 7:0] debug_mux;
reg         simson, paroda, vendetta;

assign debug_view = debug_mux;
assign ram_din    = cpu_dout;
assign ioctl_din  = video_dump;
assign video_dumpa= ioctl_addr[14:0]-15'h80;

always @(posedge clk) begin
    if( header && prog_we && prog_addr[1:0]==0 ) begin
        simson   <= prog_data[1:0]==0;
        paroda   <= prog_data[1:0]==1;
        vendetta <= prog_data[1:0]==2;
    end
    case( debug_bus[7:6] )
        0: debug_mux <= st_main;
        1: debug_mux <= st_video;
        2: debug_mux <= st_snd;
        3: debug_mux <= {init,rmrd, 6'd0 };
    endcase
end

/* verilator tracing_on */
jtsimson_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .cen_ref        ( cen24         ), // should it be cen12?
    .cpu_cen        ( cpu_cen       ),

    .simson         ( simson        ),
    .paroda         ( paroda        ),
    .vendetta       ( vendetta      ),

    .cpu_addr       ( cpu_addr      ),
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
    .LVBL           ( LVBL          ),
    .irq_n          ( cpu_irqn      ),
    .dma_bsy        ( dma_bsy       ),

    .tilesys_dout   ( tilesys_dout  ),
    .objsys_dout    ( objsys_dout   ),
    .pal_dout       ( pal_dout      ),
    // To video
    .objsys_cs      ( objsys_cs     ),
    .objreg_cs      ( objreg_cs     ),
    .tilesys_cs     ( tilesys_cs    ),
    .pcu_cs         ( pcu_cs        ),
    .init           ( init          ),
    .rmrd           ( rmrd          ),
    .pal_bank       ( pal_bank      ),
    .pal_we         ( pal_we        ),
    .objcha_n       ( objcha_n      ),
    // To sound
    .snd_irq        ( snd_irq       ),
    .snd2main       ( snd2main      ),
    .snd_wrn        ( snd_wrn       ),
    .mono           ( mono          ),
    // EEPROM
    .nv_addr        ( nv_addr       ),
    .nv_dout        ( nv_dout       ),
    .nv_din         ( nv_din        ),
    .nv_we          ( nv_we         ),
    // DIP switches
    .dip_test       ( dip_test      ),
    .dip_pause      ( dip_pause     ),
    .dipsw          ( dipsw[23:0]   ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_main       )
);

/* verilator tracing_off */
jtsimson_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_fm     ( cen_fm        ),
    .cen_fm2    ( cen_fm2       ),

    .simson     ( simson        ),
    // communication with main CPU
    .snd_irq    ( snd_irq       ),
    .main_dout  ( cpu_dout      ),
    .main_din   ( snd2main      ),
    .main_addr  ( cpu_addr[0]   ),
    .main_rnw   ( snd_wrn       ),
    .mono       ( mono          ),
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
    .pcm_l      ( pcm_l         ),
    .pcm_r      ( pcm_r         ),
    // Debug
    .debug_bus  ( debug_bus     ),
    .st_dout    ( st_snd        )
);

/* verilator tracing_on */
jtsimson_video u_video (
    .rst            ( rst           ),
    .rst8           ( rst8          ),
    .clk            ( clk           ),

    .simson         ( simson        ),
    .paroda         ( paroda        ),

    // base video
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),

    // GFX - CPU interface
    .cpu_addr       ( cpu_addr      ),
    .cpu_dout       ( cpu_dout      ),
    .cpu_we         ( cpu_we        ),

    .pal_dout       ( pal_dout      ),
    .tilesys_dout   ( tilesys_dout  ),
    .objsys_dout    ( objsys_dout   ),

    .pal_bank       ( pal_bank      ),
    .pal_we         ( pal_we        ),
    .pcu_cs         ( pcu_cs        ),
    .tilesys_cs     ( tilesys_cs    ),
    .objsys_cs      ( objsys_cs     ),
    .objreg_cs      ( objreg_cs     ),

    // control
    .rmrd           ( rmrd          ),
    .objcha_n       ( objcha_n      ),
    .cpu_irqn       ( cpu_irqn      ),
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
    .lyro_ok        ( lyro_ok       ),
    // pixels
    .red            ( red           ),
    .green          ( green         ),
    .blue           ( blue          ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .ioctl_addr     ( video_dumpa   ),
    .ioctl_din      ( video_dump    ),
    .ioctl_ram      ( ioctl_ram     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

endmodule
