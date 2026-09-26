/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

(c) LMN-san, OScherler, Raki 2020-2023.

       Raki: https://www.patreon.com/ikamusume
    LMN-san: https://ko-fi.com/lmnsan
  OScherler: https://ko-fi.com/oscherler

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

--------------------------------------------------------------------------
Ported to JTCORES from https://github.com/GX400-Friends/gx400-src by
Andrea Bogazzi, 2026. The port replaces the hand-written SDRAM/download
plumbing with the mem.yaml-generated interface; the GX400 chip models and
the main/sound/video boards are the original authors' work, unmodified.
*/

module jtnemesis_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

// ---------------------------------------------------------------------------
// Clock enables. gx400_cen derives everything from the 49.152MHz base clock
// (JTFRAME_PLL=jtframe_pll6144): 9.216MHz 68000, 6.144MHz pixel, 3.579545MHz
// audio. The "48 MHz" in gx400_cen's comments is the nominal MiSTer clock.
// ---------------------------------------------------------------------------
wire        cen9, cen6, cen6b, clk6, cen12, cen3p5, cen1p7, cen_audio_clk_div;

wire        hflip, vflip;
wire        chacs_n, objram_n, vcs2, vcs1, vzcs;
wire        video_1h_n, video_2h, video_256v;

wire [15:1] video_addr;
wire [ 7:0] sound_din;
wire [15:0] video_din, video_dout;
wire        main_lds_n, main_uds_n, main_rw_n, sound_on_n, data_n;

wire [10:0] pal_addr;
wire [ 4:0] red5, green5, blue5, red5_blk, green5_blk, blue5_blk;
wire [14:0] rgb, rgb_blk;
wire        preLHBL, preLVBL, preLVBL_n;

// joystick indices (jtframe delivers RLDU in [3:0])
localparam  dir_right  = 0,
            dir_left   = 1,
            dir_down   = 2,
            dir_up     = 3,
            btn_option = 4,
            btn_fire   = 5,
            btn_bomb   = 6;

assign pxl_cen  = cen6;
assign pxl2_cen = cen12;
assign dip_flip = 0;

gx400_cen u_cen(
    .i_clk               ( clk               ),
    .i_vsync60           ( 1'b0              ),

    .o_cen12             ( cen12             ),
    .o_cen6              ( cen6              ),
    .o_cen6b             ( cen6b             ),
    .o_clk6              ( clk6              ),
    .o_cen9              ( cen9              ),
    .o_cen3p5            ( cen3p5            ),
    .o_cen1p7            ( cen1p7            ),
    .o_cen_audio_clk_div ( cen_audio_clk_div )
);

// ---------------------------------------------------------------------------
// ROM buses. main/snd are declared by mem.yaml; the CPUs are held in reset
// until the Z80 ROM answers, so neither runs against an empty SDRAM.
// ---------------------------------------------------------------------------
wire        main_rom_cs, z80_cs;
wire [16:0] main_rom_addr;
wire [13:0] z80_addr;
wire [ 3:0] wav1_data, wav2_data;
wire [ 7:0] wav1_vol_data, wav2_vol_data;
wire [ 7:0] wav1_addr, wav1_vol_addr, wav2_addr, wav2_vol_addr;

reg  cpu_start;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cpu_start <= 0;
    end else if( snd_ok ) begin
        cpu_start <= 1;
    end
end

// Define ROM_DEBUG_Z80 or ROM_DEBUG_MAIN to dump the first 255 bytes of the
// respective ROM through debug_view. Otherwise a pass-through.
nemesis_rom_debug u_rom_debug(
    .i_clk             ( clk                  ),
    .i_cen             ( cen6                 ),

    .i_debug_bus       ( debug_bus            ),
    .o_debug_view      ( debug_view           ),

    .i_z80_cs          ( z80_cs | ~cpu_start  ),
    .i_z80_ok          ( snd_ok               ),
    .i_z80_addr        ( z80_addr             ),
    .i_z80_data        ( snd_data             ),
    .o_z80_sdram_cs    ( snd_cs               ),
    .o_z80_sdram_addr  ( snd_addr             ),

    .i_main_cs         ( main_rom_cs | ~cpu_start ),
    .i_main_ok         ( main_ok              ),
    .i_main_addr       ( main_rom_addr        ),
    .i_main_data       ( main_data            ),
    .o_main_sdram_cs   ( main_cs              ),
    .o_main_sdram_addr ( main_addr            )
);

// ---------------------------------------------------------------------------
// K005289 wave PROMs and the volume table.
// prog_addr carries the byte index while prom_we is high, so the per-PROM
// offsets below are byte offsets into the ROM image.
// ---------------------------------------------------------------------------
localparam [21:0] WAV1_OFFSET = 22'h04_4000,
                  WAV2_OFFSET = 22'h04_4100,
                  PROM_END    = 22'h04_4200;

wire [7:0] prog_addr_wave1 = prog_addr[7:0] - WAV1_OFFSET[7:0],
           prog_addr_wave2 = prog_addr[7:0] - WAV2_OFFSET[7:0];

wire prom_a01_we = prom_we && ( prog_addr >= WAV1_OFFSET ) && ( prog_addr < WAV2_OFFSET ),
     prom_a02_we = prom_we && ( prog_addr >= WAV2_OFFSET ) && ( prog_addr < PROM_END    );

// ** 256 x 4 PROM [6301] @ 7A **
jtframe_prom #(.AW(8),.DW(4)) u_wav1_rom(
    .clk     ( clk             ),
    .cen     ( 1'b1            ),
    .rd_addr ( wav1_addr       ),
    .wr_addr ( prog_addr_wave1 ),
    .data    ( prog_data[3:0]  ),
    .we      ( prom_a01_we     ),
    .q       ( wav1_data       )
);

// ** 256 x 4 PROM [6301] @ 7B **
jtframe_prom #(.AW(8),.DW(4)) u_wav2_rom(
    .clk     ( clk             ),
    .cen     ( 1'b1            ),
    .rd_addr ( wav2_addr       ),
    .wr_addr ( prog_addr_wave2 ),
    .data    ( prog_data[3:0]  ),
    .we      ( prom_a02_we     ),
    .q       ( wav2_data       )
);

// Volume table: models the switched resistor ladders at the output of the 6301
// PROMs @ 7A, 7B. Not a PCB ROM -- a computed constant, so it is built in
// rather than carried by the MRA. Two readers -> two copies.
jtframe_prom #(.AW(8),.DW(8),
    .SIMHEX("nemesis_wavvol.hex"), .SYNHEX("nemesis_wavvol.hex")) u_wav1_vol_rom(
    .clk     ( clk                ),
    .cen     ( 1'b1               ),
    .rd_addr ( wav1_vol_addr      ),
    .wr_addr ( 8'd0               ),
    .data    ( 8'd0               ),
    .we      ( 1'b0               ),
    .q       ( wav1_vol_data      )
);

jtframe_prom #(.AW(8),.DW(8),
    .SIMHEX("nemesis_wavvol.hex"), .SYNHEX("nemesis_wavvol.hex")) u_wav2_vol_rom(
    .clk     ( clk                ),
    .cen     ( 1'b1               ),
    .rd_addr ( wav2_vol_addr      ),
    .wr_addr ( 8'd0               ),
    .data    ( 8'd0               ),
    .we      ( 1'b0               ),
    .q       ( wav2_vol_data      )
);

// ---------------------------------------------------------------------------
// Main board
// ---------------------------------------------------------------------------
nemesis_main u_main(
    .i_clk          ( clk             ),
    .i_rst          ( rst             ),

    // LS244 @ 18E
    .i_cen9         ( cen9            ),
    .i_vblank       ( preLVBL_n       ),
    .i_256v         ( video_256v      ),
    .i_blk          (                 ),
    .i_cen6         ( cen6            ),
    .i_clk6         ( clk6            ),
    .i_1h_n         ( video_1h_n      ),
    .i_2h           ( video_2h        ),

    // LS244 @ 18G
    .i_vsinc        (                 ),
    .i_sync         (                 ),
    .o_chacs_n      ( chacs_n         ),
    .o_rw_n         ( main_rw_n       ),
    .o_uds_n        ( main_uds_n      ),
    .o_lds_n        ( main_lds_n      ),

    // LS244 @ 18J
    .o_inter_non    (                 ),
    .o_288_256      (                 ),
    .o_vflip        ( vflip           ),
    .o_hflip        ( hflip           ),
    .o_objram_n     ( objram_n        ),
    .o_vcs2         ( vcs2            ),
    .o_vcs1         ( vcs1            ),
    .o_vzcs         ( vzcs            ),

    // ROM
    .o_rom_cs       ( main_rom_cs     ),
    .o_rom_addr     ( main_rom_addr   ),
    .i_rom_data     ( main_data       ),
    .i_rom_ok       ( main_ok         ),

    // Sound
    .o_sound_on_n   ( sound_on_n      ),
    .o_data_n       ( data_n          ),
    .o_sound_db     ( sound_din       ),

    // Video
    .o_addr         ( video_addr      ),
    .i_cd           ( pal_addr        ),
    .i_data_bus_in  ( video_dout      ),
    .o_data_bus_out ( video_din       ),

    .o_red          ( red5            ),
    .o_green        ( green5          ),
    .o_blue         ( blue5           ),

    // NOT inverted: the upstream hand-written MRA stored the DIPs inverted
    // (default 00,A4,00) and the HDL undid it. jtframe's generated MRA carries
    // the true PCB port values (default ff,5b,ff = ~00,~A4,~00), which the
    // 68000 reads directly.
    .i_dip1         ( dipsw[ 7: 0]    ),
    .i_dip2         ( dipsw[15: 8]    ),
    .i_dip3         ( dipsw[23:16]    ),

    // PS2401_4 @ 2E, 2F, 2G, 2H, 2J
    .i_coin1        ( coin[0]                 ),
    .i_coin2        ( coin[1]                 ),
    .i_1p_right     ( joystick1[ dir_right ]  ),
    .i_1p_left      ( joystick1[ dir_left  ]  ),
    .i_1p_down      ( joystick1[ dir_down  ]  ),
    .i_1p_up        ( joystick1[ dir_up    ]  ),
    .i_1p_start     ( cab_1p[0]               ),
    .i_1p_sp_pow    ( joystick1[ btn_option ] ),
    .i_1p_shoot     ( joystick1[ btn_fire   ] ),
    .i_1p_missile   ( joystick1[ btn_bomb   ] ),
    .i_2p_right     ( joystick2[ dir_right ]  ),
    .i_2p_left      ( joystick2[ dir_left  ]  ),
    .i_2p_down      ( joystick2[ dir_down  ]  ),
    .i_2p_up        ( joystick2[ dir_up    ]  ),
    .i_2p_start     ( cab_1p[1]               ),
    .i_2p_sp_pow    ( joystick2[ btn_option ] ),
    .i_2p_shoot     ( joystick2[ btn_fire   ] ),
    .i_2p_missile   ( joystick2[ btn_bomb   ] ),
    .i_service      ( service                 ),
    .i_pause        ( dip_pause               )
);

// ---------------------------------------------------------------------------
// Colour mixing
// ---------------------------------------------------------------------------
assign rgb = { red5, green5, blue5 };
assign { red5_blk, green5_blk, blue5_blk } = rgb_blk;

jtframe_blank #( .DLY(0), .DW(15) ) u_blank(
    .clk      ( clk      ),
    .pxl_cen  ( cen6     ),
    .preLHBL  ( preLHBL  ),
    .preLVBL  ( preLVBL  ),
    .LHBL     ( LHBL     ),
    .LVBL     ( LVBL     ),
    .preLBL   (          ),
    .rgb_in   ( rgb      ),
    .rgb_out  ( rgb_blk  )
);

// Resistor-ladder lookup at the output of the 2128-15 palette RAMs @ 14K, 15K.
// Table generated from MAME's resnet with the Nemesis network values.
colour_lut #( .pw(5), .cw(8), .synfile("nemesis_colmix.hex") ) u_colour_lut(
    .clk       ( clk        ),
    .in_red    ( red5_blk   ),
    .in_green  ( green5_blk ),
    .in_blue   ( blue5_blk  ),
    .out_red   ( red        ),
    .out_green ( green      ),
    .out_blue  ( blue       )
);

// ---------------------------------------------------------------------------
// Video board
// ---------------------------------------------------------------------------
assign preLVBL = ~preLVBL_n;

GX400A_VIDEO u_video(
    .i_MCLK     ( clk              ),
    .i_RESET    ( rst              ),
    .i_HFLIP    ( hflip            ),
    .i_VFLIP    ( vflip            ),
    .i_INTER_NON( 1'b0             ),
    .i_288_256  ( 1'b0             ),

    .i_cen6     ( cen6             ),
    .i_cen6b    ( cen6b            ),
    .i_clk6     ( clk6             ),

    .o_HS       ( HS               ),
    .o_VS       ( VS               ),
    .o_HBL      ( preLHBL          ),
    .o_VBL      ( preLVBL_n        ),

    .o_1h_n     ( video_1h_n       ),
    .o_2h       ( video_2h         ),
    .o_256v     ( video_256v       ),

    .i_addr         ( video_addr   ),
    .i_data_bus_in  ( video_din    ),
    .o_data_bus_out ( video_dout   ),

    .i_uds_n    ( main_uds_n       ),
    .i_lds_n    ( main_lds_n       ),
    .i_RnW      ( main_rw_n        ),
    .i_chacs_n  ( chacs_n          ),
    .i_objram_n ( objram_n         ),
    .i_vcs1     ( vcs1             ),
    .i_vcs2     ( vcs2             ),
    .i_vzcs     ( vzcs             ),

    .o_pal_addr ( pal_addr         )
);

// ---------------------------------------------------------------------------
// Sound board. Volume constants were tuned by the original authors against a
// real PCB; nemesis_sound mixes internally and hands jtframe one channel.
// ---------------------------------------------------------------------------
nemesis_sound u_sound(
    .i_clk            ( clk               ),
    .i_cen3p5         ( cen3p5            ),
    .i_cen1p7         ( cen1p7            ),
    .i_cen_clk_div    ( cen_audio_clk_div ),

    .i_rst            ( rst               ),
    .i_main_db        ( sound_din         ),
    .i_data_n         ( data_n            ),
    .i_sound_on_n     ( sound_on_n        ),

    .i_cpu_start      ( cpu_start         ),
    .o_z80_cs         ( z80_cs            ),
    .o_z80_addr       ( z80_addr          ),
    .i_z80_data       ( snd_data          ),
    .i_z80_ok         ( snd_ok            ),

    .o_wav1_addr      ( wav1_addr         ),
    .o_wav1_vol_addr  ( wav1_vol_addr     ),
    .o_wav2_addr      ( wav2_addr         ),
    .o_wav2_vol_addr  ( wav2_vol_addr     ),
    .i_wav1_data      ( wav1_data         ),
    .i_wav1_vol_data  ( wav1_vol_data     ),
    .i_wav2_data      ( wav2_data         ),
    .i_wav2_vol_data  ( wav2_vol_data     ),

    .o_sound          ( sound             ),

    .i_prom1_on       ( 1'b1              ),
    .i_prom2_on       ( 1'b1              ),
    .i_ay7_on         ( 1'b1              ),
    .i_ay8_on         ( 1'b1              ),
    .i_vol_prom       ( 8'd104            ),
    .i_vol_ay7        ( 8'd102            ), // AY2 music
    .i_vol_ay8        ( 8'd138            )  // AY1 SFX
);

endmodule
