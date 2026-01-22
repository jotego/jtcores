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
    Date: 20-12-2025 */

module jtprmr_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam PRMRSOCR = 0;

/* verilator tracing_on */
wire        snd_irq, rmrd, rst8, dma_bsy, psac_cs,
            pal_cs, cpu_we, tilesys_cs, objsys_cs, pcu_cs, cpu_n,
            cpu_rnw, vdtac, tile_irqn, pair_we, obank, zrmck, psac_bank;
wire [15:0] pal_dout, oram_dout, oram_din;
wire [15:0] video_dumpa;
reg  [ 7:0] debug_mux;
reg         prmrsocr=0, rst_main, rst_snd;
wire [ 7:0] tilesys_dout, pair_dout, obj_dout,
            st_main, st_video, st_snd;
wire [ 1:0] oram_we, objset_cs;

assign debug_view = debug_mux;
assign ram_we     = cpu_we & ram_cs;
assign ram_addr   = main_addr[13:1];
assign video_dumpa= ioctl_addr[15:0]-16'h80; // subtract NVRAM offset

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= st_main;
        1: debug_mux <= st_video;
        2: debug_mux <= st_snd;
        3: debug_mux <= { prmrsocr, 3'd0,rmrd,zrmck,psac_bank,obank };
    endcase
end

always @(posedge clk) begin
    if( prog_addr[3:0]==15 && prog_we && header ) begin
        prmrsocr <= prog_data[PRMRSOCR];
    end
end

always @(posedge clk) begin
    rst_main  <= rst;
    rst_snd   <= rst;
end

/* verilator tracing_off */
jtprmr_main u_main(
    .rst            ( rst_main      ),
    .clk            ( clk           ),

    .LVBL           ( LVBL          ),
    .cpu_we         ( cpu_we        ),
    .cpu_dout       ( ram_din       ),
    .vdtac          ( vdtac         ),
    .tile_irqn      ( tile_irqn     ),
    .cpu_n          ( cpu_n         ),

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
    .cab_1p         ( cab_1p[1:0]   ),
    .coin           ( coin[1:0]     ),
    .joystick1      ( joystick1[6:0]),
    .joystick2      ( joystick2[6:0]),
    .service        ( {2{service}}  ),

    .vram_dout      ( tilesys_dout  ),
    .oram_dout      ( oram_dout     ),
    .pal_dout       ( pal_dout      ),
    // PSAC
    .psreg_cs       ( psac_cs       ),
    .psac_bank      ( psac_bank     ),
    .lmem_we        ( lmem_we       ),
    .lmem_dout      ( lmem_dout     ),
    // To video
    .rmrd           ( rmrd          ),
    .objset_cs      ( objset_cs     ),

    .obj_cs         ( objsys_cs     ),
    .vram_cs        ( tilesys_cs    ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ), // priority mixer
    .obank          ( obank         ),
    .zrmck          ( zrmck         ),
    // To sound
    .sndon          ( snd_irq       ),
    .pair_dout      ( pair_dout     ),
    .pair_we        ( pair_we       ),
    // EEPROM
    .nv_addr        ( nvram_addr    ),
    .nv_dout        ( nvram_dout    ),
    .nv_din         ( nvram_din     ),
    .nv_we          ( nvram_we      ),
    // DIP switches
    .dipsw          ( dipsw[19:0]   ),
    .dip_pause      ( dip_pause     ),
    .dip_test       ( dip_test      ),
    // Debug
    .st_dout        ( st_main       ),
    .debug_bus      ( debug_bus     )
);

/* verilator tracing_off */
jtprmr_video u_video (
    .rst            ( rst           ),
    .rst8           ( rst8          ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .cpu_n          ( cpu_n         ),

    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),
    .tile_irqn      ( tile_irqn     ),
    // GFX - CPU interface
    .cpu_we         ( cpu_we        ),
    .objsys_cs      ( objsys_cs     ),
    .objset_cs      ( objset_cs     ),
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
    .obank          ( obank         ),
    // PSAC GFX
    .psac_cs        ( psac_cs       ),
    .psac_bank      ( psac_bank     ),
    .psc_addr       ( psc_addr      ),
    .psc_data       ( psc_data      ),
    .psc_cs         ( psc_cs        ),
    .psc_ok         ( psc_ok        ),

    .pscmap_addr    ( pscmap_addr   ),
    .pscmap_data    ( pscmap_data   ),
    .pscmap_ok      ( pscmap_ok     ),
    .pscmap_cs      ( pscmap_cs     ),

    .line_addr      ( line_addr     ),
    .line_dout      ( line_dout     ),

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
    .ioctl_addr     ( video_dumpa   ),
    .ioctl_din      ( ioctl_din     ),
    .ioctl_ram      ( ioctl_ram     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

wire nc;

/* verilator tracing_on */
jtrungun_sound #(.PRMR(1)) u_sound(
    .rst            ( rst_snd       ),
    .clk            ( clk           ),
    .cen_8          ( cen_8         ),
    .cen_pcm        ( cen_pcm       ),

    // communication with main CPU
    .main_dout      ( ram_din[7:0]  ),
    .pair_dout      ( pair_dout     ),
    .main_addr      ( main_addr[4:1]),
    .pair_we        ( pair_we       ),

    .snd_irq        ( snd_irq       ),
    // ROM
    .rom_addr       ( snd_addr      ),
    .rom_cs         ( snd_cs        ),
    .rom_data       ( snd_data      ),
    .rom_ok         ( snd_ok        ),
    // ADPCM ROM
    .pcma_addr      ( {nc,pcm_addr} ),
    .pcmb_addr      (               ),
    .pcma_data      ( pcm_data      ),
    .pcmb_data      ( 8'd0          ),
    .pcma_cs        ( pcm_cs        ),
    .pcmb_cs        (               ),
    // Sound output
    .k539_l         ( k539_l        ),
    .k539_r         ( k539_r        ),
    // Debug
    .debug_bus      ( debug_bus     ),
    .st_dout        ( st_snd        )
);

endmodule
