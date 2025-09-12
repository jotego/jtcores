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

module jtriders_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

localparam SSRIDERS = 0,
           TMNT2    = 1,
           LGTNFGHT = 2,
           GLFGREAT = 3;

/* verilator tracing_on */
wire        snd_irq, rmrd, rst8, dimmod, dimpol, dma_bsy, psac_cs, psac_bank,
            pal_cs, cpu_we, tilesys_cs, objsys_cs, pcu_cs, cpu_n, enc_done,
            cpu_rnw, vdtac, tile_irqn, tile_nmin, snd_wrn, oaread_en,
            BGn, BRn, BGACKn, prot_irqn, prot_cs, objreg_cs, oram_cs;
wire [15:0] pal_dout, oram_dout, prot_dout, oram_din;
wire [15:0] video_dumpa;
wire [13:1] oram_addr;
reg  [ 7:0] debug_mux;
reg         ssriders=0, tmnt2=0, lgtnfght=0, glfgreat=0;
wire [ 7:0] tilesys_dout, snd2main,
            obj_dout, snd_latch,
            st_main, st_video;
wire [ 7:0] platch;
wire [ 2:0] dim;
wire [ 1:0] oram_we;

`ifdef NOPSAC
wire [ 1:0] lmem_we;
wire [15:0] lmem_dout=0, line_dout=0;
wire [10:1] line_addr;
wire [17:1] t2x2_addr, tmap_addr;
wire [15:0] t2x2_din,  tmap_dout=0;
wire [ 1:0] t2x2_we;
`endif
wire        tmap_ok;
`ifdef POCKET
wire [17:1] t2x2_addr, tmap_addr;
wire [15:0] t2x2_din,  tmap_dout;
wire [ 1:0] t2x2_we;

assign sram_addr =  enc_done ? tmap_addr : t2x2_addr;
assign sram_din  =  t2x2_din;
assign sram_wen  = ~t2x2_we[0];
assign sram_dsn  =  0;
assign tmap_dout =  sram_dout;
assign tmap_ok   =  sram_ok;
`else
assign tmap_ok   = 1;
`endif

assign debug_view = debug_mux;
assign ram_we     = cpu_we & ram_cs;
assign ram_addr   = main_addr[13:1];
assign omsb_din   = ram_din[7:0];
assign oaread_en  = tmnt2;
assign video_dumpa= ioctl_addr[15:0]-16'h80; // subtract NVRAM offset

always @(posedge clk) begin
    case( debug_bus[7:6] )
        0: debug_mux <= st_main;
        1: debug_mux <= st_video;
        2: debug_mux <= { 4'd0,glfgreat,lgtnfght,tmnt2,ssriders };
        3: debug_mux <= { enc_done, 1'b0, dimpol, dimmod, 1'b0, dim };
    endcase
end

always @(posedge clk) begin
    if( prog_addr[3:0]==15 && prog_we && header ) begin
        ssriders <= prog_data[SSRIDERS];
        tmnt2    <= prog_data[TMNT2];
        lgtnfght <= prog_data[LGTNFGHT];
        glfgreat <= prog_data[GLFGREAT];
    end
end

/* verilator tracing_off */
jtriders_main u_main(
    .rst            ( rst           ),
    .clk            ( clk           ),
    .lgtnfght       ( lgtnfght      ),
    .glfgreat       ( glfgreat      ),

    .LVBL           ( LVBL          ),
    .cpu_we         ( cpu_we        ),
    .cpu_dout       ( ram_din       ),
    .vdtac          ( vdtac         ),
    .tile_irqn      ( tile_irqn     ),
    .cpu_n          ( cpu_n         ),

    // protection chip
    .BGACKn         ( BGACKn        ),
    .BRn            ( BRn           ),
    .BGn            ( BGn           ),
    .prot_irqn      ( prot_irqn     ),
    .prot_cs        ( prot_cs       ),
    .prot_dout      ( prot_dout     ),

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
    .joystick1      ( joystick1[6:0]),
    .joystick2      ( joystick2[6:0]),
    .joystick3      ( joystick3[6:0]),
    .joystick4      ( joystick4[6:0]),
    .service        ( {4{service}}  ),

    .vram_dout      ( tilesys_dout  ),
    .oram_dout      ( oram_dout     ),
    .pal_dout       ( pal_dout      ),
    // PSAC
    .psreg_cs       ( psac_cs       ),
    .psac_bank      ( psac_bank     ),
    .lmem_we        ( lmem_we       ),
    .lmem_dout      ( lmem_dout     ),
    .platch         ( platch        ),
    // Object MSB RAM
    .omsb_we        ( omsb_we       ),
    .omsb_addr      ( omsb_addr     ),
    .omsb_dout      ( omsb_dout     ),
    .dma_bsy        ( dma_bsy       ),
    // To video
    .rmrd           ( rmrd          ),
    .dimmod         ( dimmod        ),
    .dimpol         ( dimpol        ),
    .dim            ( dim           ),
    .cbnk           (               ),
    .objreg_cs      ( objreg_cs     ),

    .obj_cs         ( objsys_cs     ),
    .vram_cs        ( tilesys_cs    ),
    .pal_cs         ( pal_cs        ),
    .pcu_cs         ( pcu_cs        ), // priority mixer
    // To sound
    .sndon          ( snd_irq       ),
    .snd2main       ( snd2main      ),
    .snd_wrn        ( snd_wrn       ),
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
jtriders_prot u_prot(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen_16     ( cen_16    ),
    .cen_8      ( cen_8     ),

    .cs         ( prot_cs   ),
    .addr       (main_addr[13:1]),
    .cpu_we     ( cpu_we    ),
    .din        ( ram_din   ), // = cpu_dout
    .dout       ( prot_dout ),
    .ram_we     ( ram_we    ), // includes ram_cs as part of ram_we
    .dsn        ( ram_dsn   ),
    // DMA
    .objsys_cs  ( objsys_cs ),
    .oram_cs    ( oram_cs   ),
    .oram_addr  ( oram_addr ),
    .oram_din   ( oram_din  ),
    .oram_dout  ( oram_dout ),
    .oram_we    ( oram_we   ),
    .irqn       ( prot_irqn ),
    .BRn        ( BRn       ),
    .BGn        ( BGn       ),
    .BGACKn     ( BGACKn    ),

    .debug_bus  ( debug_bus )
);

/* verilator tracing_on */
jtriders_video u_video (
    .rst            ( rst           ),
    .rst8           ( rst8          ),
    .clk            ( clk           ),
    .pxl_cen        ( pxl_cen       ),
    .pxl2_cen       ( pxl2_cen      ),
    .cpu_n          ( cpu_n         ),
    .enc_done       ( enc_done      ),

    .ssriders       ( ssriders      ),
    .lgtnfght       ( lgtnfght      ),
    .glfgreat       ( glfgreat      ),

    .tile_irqn      ( tile_irqn     ),
    .tile_nmin      (               ),

    .lhbl           ( LHBL          ),
    .lvbl           ( LVBL          ),
    .hs             ( HS            ),
    .vs             ( VS            ),
    .flip           ( dip_flip      ),
    // Object DMA
    .oram_we        ( oram_we       ),
    .oram_din       ( oram_din      ),
    .oram_addr      ( oram_addr     ),
    // RAM with ROM MSB address for tile ROM
    .oaread_en      ( oaread_en     ),
    .oaread_dout    ( oaread_dout   ),
    .oaread_addr    ( oaread_addr   ),
    // GFX - CPU interface
    .cpu_we         ( cpu_we        ),
    .objsys_cs      ( oram_cs       ),
    .objreg_cs      ( objreg_cs     ),
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
    .platch         ( platch        ),
    // PSAC GFX
    .psac_cs        ( psac_cs       ),
    .psac_bank      ( psac_bank     ),
    .psc_addr       ( psc_addr      ),
    .psc_data       ( psc_data      ),
    .psc_cs         ( psc_cs        ),
    .psc_ok         ( psc_ok        ),

    .psclo_addr     ( psclo_addr    ),
    .psclo_data     ( psclo_data    ),
    .psclo_ok       ( psclo_ok      ),
    .psclo_cs       ( psclo_cs      ),

    .pschi_addr     ( pschi_addr    ),
    .pschi_data     ( pschi_data    ),
    .pschi_ok       ( pschi_ok      ),
    .pschi_cs       ( pschi_cs      ),

    .line_addr      ( line_addr     ),
    .line_dout      ( line_dout     ),

    .t2x2_addr      ( t2x2_addr     ),
    .t2x2_din       ( t2x2_din      ),
    .t2x2_we        ( t2x2_we       ),
    .tmap_addr      ( tmap_addr     ),
    .tmap_ok        ( tmap_ok       ),
    .tmap_dout      ( tmap_dout     ),
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
    .ioctl_addr     ( video_dumpa   ),
    .ioctl_din      ( ioctl_din     ),
    .ioctl_ram      ( ioctl_ram     ),
    .gfx_en         ( gfx_en        ),
    .st_dout        ( st_video      )
);

/* verilator tracing_on */
jtriders_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen_8      ( cen_8         ),
    .cen_4      ( cen_4         ),
    .cen_fm     ( cen_fm        ),
    .cen_fm2    ( cen_fm2       ),
    .cen_pcm    ( cen_pcm       ),

    .lgtnfght   ( lgtnfght      ),
    .glfgreat   ( glfgreat      ),

    // communication with main CPU
    .main_dout  ( ram_din       ),
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

    .snd_en     ( snd_en        ),
    // Sound output
    .k60_l      ( k60_l         ),
    .k60_r      ( k60_r         )
);

endmodule
