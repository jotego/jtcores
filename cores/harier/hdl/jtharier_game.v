/* SPDX-FileCopyrightText: 2026 Chris Watson/Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 7-8-2026 */

module jtharier_game(
    `include "jtframe_game_ports.inc"
);

wire vint, mcu_we, key_we, fd1089_we;

localparam [21:0] MCU_PROM     = `MCU_START,
                  MAINKEY_PROM = `MAINKEY_START,
                  FD1089_PROM  = `FD1089_START;

wire        main_rnw, ram_cs, char_cs_main, objram_cs_main,
            pal_cs_main, io_cs, subram_cs_main, roadram_cs_main;
wire [15:0] char_dout;
wire [ 1:0] sub_dsn;
wire        sub_rnw, sub_ram_cs, sub_road_cs, sub_rstn, sub_intn;
wire        flip, video_en, colscr_en, rowscr_en;
wire        snd_rstn;   // PPI0 port B bit 5, Z80 /RESET (active low)
wire [ 7:0] snd_latch;
wire        snd_ack;
wire        snd_nmin;
wire [ 8:0] vrender, hdump;
wire [ 7:0] dipsw_a, dipsw_b, st_main, st_sub, st_video, st_road;
wire        scr_bad, i8751, fd1089, blank4, ym2151, cab1p, hicol;
wire [12:0] key_addr;
wire [ 7:0] key_data;
wire [ 2:0] adc;        // number of ADC channels

assign { dipsw_b, dipsw_a } = dipsw[15:0];
// 'V' glyph fix (dipsw[18]): the MRA lists "On,Off" so the all-ones default
// ships faithful to the PCB.
wire vfix_en = ~dipsw[18];
wire [ 7:0] an_x, an_y, an_gas, an_brake;
assign mcu_we     = prom_we && prog_addr[21:12]==MCU_PROM[21:12];
// The 8 KiB FD1089 key follows the 4 KiB MCU image. A high-bit comparison
// would also select the MCU range and overwrite the first half of the key.
assign key_we     = prom_we && prog_addr>=MAINKEY_PROM && prog_addr<FD1089_PROM;
assign fd1089_we  = prom_we && prog_addr[21: 8]==FD1089_PROM [21: 8];

assign dip_flip   = flip;
assign debug_view = 0;

assign xram_we    = ~main_rnw;
assign objram_we  = objram_cs_main & ~main_rnw ? ~main_dsn : 2'b00;
assign pal_we     = pal_cs_main & ~main_rnw ? ~main_dsn : 2'b00;
assign wram_we    = ram_cs & ~main_rnw ? ~main_dsn : 2'b00;
assign subram_we   = subram_cs_main & ~main_rnw ? ~main_dsn : 2'b00;
assign subsh_we    = sub_ram_cs & ~sub_rnw ? ~sub_dsn : 2'b00;
assign ioctl_din  = 0;
// gfx_cs gates the tile-graphics reads to the visible field
assign gfx_cs     = LVBL || vrender==0 || vrender[8];

jtharier_header u_header(
    .clk        ( clk           ),
    .header     ( header        ),
    .prog_we    ( prog_we       ),

    .i8751      ( i8751         ),
    .fd1089     ( fd1089        ),
    .blank4     ( blank4        ),
    .ym2151     ( ym2151        ),
    .cab1p      ( cab1p         ),
    .hicol      ( hicol         ),
    .adc        ( adc           ),
    .prog_addr  ( prog_addr[2:0]),
    .prog_data  ( prog_data     )
);

// Enduro Racer's FD1089B key PROM. Space Harrier does not use it.
jtframe_prom #(.AW(13),.SIMFILE("317-0013a.key")) u_fd1089_key(
    .clk    ( clk              ),
    .cen    ( 1'b1             ),
    .data   ( prog_data        ),
    .rd_addr( key_addr         ),
    .wr_addr( prog_addr[12:0] - MAINKEY_PROM[12:0] ),
    .we     ( key_we           ),
    .q      ( key_data         )
);

jtharier_roadarb u_roadarb(
    .rst        ( rst               ),
    .clk        ( clk               ),

    .main_cs    ( roadram_cs_main   ),
    .main_rnw   ( main_rnw          ),
    .main_dsn   ( main_dsn          ),
    .main_addr  ( main_addr[11:1] ),
    .main_dout  ( main_dout         ),

    .sub_cs     ( sub_road_cs       ),
    .sub_rnw    ( sub_rnw           ),
    .sub_dsn    ( sub_dsn           ),
    .sub_addr   ( subrom_addr[11:1] ),
    .sub_dout   ( sub_cpu_dout      ),

    .ram_addr   ( roadram_addr      ),
    .ram_din    ( roadram_din       ),
    .ram_we     ( roadram_we        )
);

jtharier_cab u_cab(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .LVBL       ( LVBL          ),

    .joystick1  ( joystick1[3:0]),
    .joyana_l1  ( joyana_l1     ),
    .joyana_r1  ( joyana_r1     ),
    .adc        ( adc           ),

    .sprung     ( dipsw[17]     ),
    .invert_y   ( dipsw[16]     ),

    .an_x       ( an_x          ),
    .an_y       ( an_y          ),
    .an_gas     ( an_gas        ),
    .an_brake   ( an_brake      )
);

jtharier_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .i8751      ( i8751         ),
    .fd1089     ( fd1089        ),
    .blank4     ( blank4        ),
    .cab1p      ( cab1p         ),
    .adc        ( adc           ),
    .LVBL       ( LVBL          ),
    .key_addr   ( key_addr      ),
    .key_data   ( key_data      ),
    .fd1089_we  ( fd1089_we     ),
    .hdump      ( hdump         ),   // VWAIT slot phase
    .cpu_cen    (               ),
    .cpu_cenb   (               ),

    .cen_mcu    ( cen_mcu       ),

    .vram_cs    ( vram_cs_main  ),
    .char_cs    ( char_cs_main  ),
    .objram_cs  ( objram_cs_main),
    .pal_cs     ( pal_cs_main   ),
    .io_cs      ( io_cs         ),
    .vram_data  ( xram_data     ),
    .vram_ok    ( xram_ok       ),
    .char_dout  ( char_dout     ),
    .objram_dout( objram_dout   ),
    .pal_dout   ( pal_dout      ),

    .ram_cs     ( ram_cs        ),
    .ram_dout   ( wram_dout     ),

    .addr       ( main_addr ),
    .cpu_dout   ( main_dout     ),
    .RnW        ( main_rnw      ),
    .dsn        ( main_dsn      ),

    .rom_cs     ( main_cs       ),
    .rom_data   ( main_data     ),
    .rom_ok     ( main_ok       ),

    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .dip_test   ( dip_test      ),
    .dip_pause  ( dip_pause     ),
    .cab_1p     ( cab_1p[1:0]   ),
    .coin       ( coin[1:0]     ),
    .service    ( service       ),
    .joystick1  ( joystick1[6:0]),
    .an_x       ( an_x          ),
    .an_y       ( an_y          ),
    .an_gas     ( an_gas        ),
    .an_brake   ( an_brake      ),

    .flip       ( flip          ),
    .mute       ( mute          ),
    .snd_latch  ( snd_latch     ),
    .snd_nmin   ( snd_nmin      ),
    .snd_rstn   ( snd_rstn      ),
    .snd_ack    ( snd_ack       ),
    .video_en   ( video_en      ),
    .colscr_en  ( colscr_en     ),
    .rowscr_en  ( rowscr_en     ),

    .subram_cs  ( subram_cs_main ),
    .roadram_cs ( roadram_cs_main),
    .subram_dout( subram_dout   ),

    .sub_rstn   ( sub_rstn      ),
    .sub_intn   ( sub_intn      ),

    .mcu_we     ( mcu_we        ),
    .prog_addr  ( prog_addr[12:0] ),
    .prog_data  ( prog_data     ),

    .st_addr    ( debug_bus     ),
    .st_dout    ( st_main       )
);
/* verilator tracing_off */
jtharier_sub u_sub(
    .rst        ( rst           ),
    .clk        ( clk           ),

    .rstn       ( sub_rstn      ),
    .intn       ( sub_intn      ),

    .ram_cs     ( sub_ram_cs    ),
    .ram_dout   ( subsh_dout    ),
    .road_cs    ( sub_road_cs   ),
    .road_dout  ( roadram_dout  ),

    .addr       ( subrom_addr   ),
    .cpu_dout   ( sub_cpu_dout  ),
    .RnW        ( sub_rnw       ),
    .dsn        ( sub_dsn       ),

    .rom_cs     ( subrom_cs     ),
    .rom_data   ( subrom_data   ),
    .rom_ok     ( subrom_ok     ),

    .st_addr    ( debug_bus     ),
    .st_dout    ( st_sub        )
);
/* verilator tracing_on */
// Sound board 834-5799. cen_pcm is 16 MHz, not 8 -- see the module header.
jtharier_sound u_snd(
    .snd_rstn   ( snd_rstn      ),
    .clk        ( clk           ),
    .ym2151     ( ym2151        ),

    .cen_fm     ( cen_fm        ),  // 4 MHz
    .cen_fm2    ( cen_fm2       ),  // 2 MHz
    .cen_pcm    ( cen_pcm       ),

    .latch      ( snd_latch     ),
    .nmi_n      ( snd_nmin      ),
    .latch_rd   ( snd_ack       ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    .pcm_addr   ( pcm_addr      ),
    .pcm_cs     ( pcm_cs        ),
    .pcm_data   ( pcm_data      ),
    .pcm_ok     ( pcm_ok        ),

    .fm         ( fm            ),
    .opn_l      ( opn_l         ),
    .opn_r      ( opn_r         ),
    .psg        ( psg           ),
    .pcm_l      ( pcm_l         ),
    .pcm_r      ( pcm_r         )
);
/* verilator tracing_off */
jtharier_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),
    .video_en   ( video_en      ),
    .colscr_en  ( colscr_en     ),
    .rowscr_en  ( rowscr_en     ),
    .vfix_en    ( vfix_en       ),

    .dip_pause  ( dip_pause     ),
    .char_cs    ( char_cs_main  ),
    .cpu_addr   ( main_addr[12:1] ),
    .cpu_dout   ( main_dout     ),
    .dsn        ( main_dsn      ),
    .char_dout  ( char_dout     ),

    .flip       ( flip          ),

    .pal_vaddr  ( pal_vaddr     ),
    .pal_vdata  ( pal_vdata     ),

    .rdram_addr ( rdram_addr    ),
    .rdram_data ( rdram_dout    ),
    .rdrom_addr ( road_addr     ),
    .rdrom_data ( road_data     ),

    .char_ok    ( char_ok       ),
    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .map1_ok    ( map1_ok       ),
    .map1_addr  ( map1_addr     ),
    .map1_data  ( map1_data     ),
    .scr1_ok    ( scr1_ok       ),
    .scr1_addr  ( scr1_addr     ),
    .scr1_data  ( scr1_data     ),
    .map2_ok    ( map2_ok       ),
    .map2_addr  ( map2_addr     ),
    .map2_data  ( map2_data     ),
    .scr2_ok    ( scr2_ok       ),
    .scr2_addr  ( scr2_addr     ),
    .scr2_data  ( scr2_data     ),

    .objdma_addr( objdma_addr   ),
    .objdma_dout( objdma_dout   ),
    .zoom_addr  ( zoom_addr     ),
    .zoom_data  ( zoom_data     ),
    .obj_ok     ( obj_ok        ),
    .obj_cs     ( obj_cs        ),
    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),

    .HS         ( HS            ),
    .VS         ( VS            ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),

    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     ),
    .st_addr    ( debug_bus     ),
    .st_dout    ( st_video      ),
    .st_road    ( st_road       ),
    .scr_bad    ( scr_bad       )
);

endmodule
