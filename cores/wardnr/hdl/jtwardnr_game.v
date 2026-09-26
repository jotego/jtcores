/* SPDX-FileCopyrightText: 2026 Marc Emmerson / Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Wardner (Toaplan TP-009 / Taito B25, 1987): main Z80, TMS320C10, sound Z80
 * with YM3812, and the video. See cfg/macros.def for the clocking.
 */

module jtwardnr_game(
    `include "jtframe_game_ports.inc"
);

wire [15:0] txoffs, bgoffs, fgoffs;
wire [15:0] dsp_dout, dsp_din, fg_full_addr;
wire [13:1] dsp_addr;
wire [11:0] dsp_rom_addr;
wire [ 1:0] dsp_sel;
wire [ 2:0] scr_cs, scr_addr;
wire        dsp_on, dsp_halt, dsp_we;
wire        flip, bg_bank, fg_bank, video_on;

assign dip_flip    = flip;
assign pxl_cen     = cen7;
assign pxl2_cen    = cen14;
// the mask ROM holds 2048 words, and the foreground ROM has no second bank
assign dsprom_addr = dsp_rom_addr[10:0];
assign fg_addr     = fg_full_addr[14:0];
assign debug_view  = { 4'd0, dsp_halt, dsp_on, flip, video_on };

/* verilator tracing_off */
jtwardnr_main u_main(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .cen6       ( cen6              ),
    .LVBL       ( LVBL              ),

    .rom_addr   ( main_addr         ),
    .rom_data   ( main_data         ),
    .rom_cs     ( main_cs           ),
    .rom_ok     ( main_ok           ),

    .dsp_on     ( dsp_on            ),
    .dsp_halt   ( dsp_halt          ),
    .dsp_addr   ( dsp_addr          ),
    .dsp_sel    ( dsp_sel           ),
    .dsp_dout   ( dsp_dout          ),
    .dsp_din    ( dsp_din           ),
    .dsp_we     ( dsp_we            ),

    .sh_addr    ( sh_addr           ),
    .sh_din     ( sh_din            ),
    .work_bwe   ( work_bwe          ),
    .obj_bwe    ( obj_bwe           ),
    .pal_bwe    ( pal_bwe           ),
    .work_dout  ( work_dout         ),
    .objram_dout( objram_dout       ),
    .palram_dout( palram_dout       ),

    .mshr_addr  ( mshr_addr         ),
    .mshr_we    ( mshr_we           ),
    .shared_dout( shared_dout       ),

    .scr_cs     ( scr_cs            ),
    .scr_addr   ( scr_addr          ),
    .txoffs     ( txoffs            ),
    .bgoffs     ( bgoffs            ),
    .fgoffs     ( fgoffs            ),
    .flip       ( flip              ),
    .bg_bank    ( bg_bank           ),
    .fg_bank    ( fg_bank           ),
    .video_on   ( video_on          ),

    .cpu16      ( cpu16             ),
    .tx_a       ( tx_a              ),
    .bg_a       ( bg_a              ),
    .fg_a       ( fg_a              ),
    .tx_bwe     ( tx_bwe            ),
    .bg_bwe     ( bg_bwe            ),
    .fg_bwe     ( fg_bwe            ),
    .txram_dout ( txram_dout        ),
    .bgram_dout ( bgram_dout        ),
    .fgram_dout ( fgram_dout        ),

    .cpu_dout   ( cpu_dout          ),

    .dipsw      ( dipsw[15:0]       ),
    .joystick1  ( joystick1[5:0]    ),
    .joystick2  ( joystick2[5:0]    ),
    .cab_1p     ( cab_1p[1:0]       ),
    .coin       ( coin[1:0]         ),
    .service    ( service           ),
    .tilt       ( tilt              ),
    .dip_test   ( dip_test          ),
    .dip_pause  ( dip_pause         )
);

/* verilator tracing_off */
jttoaplan1_dsp #(.TWINCOBR(0)) u_dsp(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .cen        ( cen14             ),
    .dsp_on     ( dsp_on            ),
    .halt_main  ( dsp_halt          ),
    .host_addr  ( dsp_addr          ),
    .host_sel   ( dsp_sel           ),
    .host_dout  ( dsp_dout          ),
    .host_din   ( dsp_din           ),
    .host_we    ( dsp_we            ),
    .rom_addr   ( dsp_rom_addr      ),
    .rom_data   ( dsprom_data       )
);

/* verilator tracing_off */
jtwardnr_sound u_sound(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .cen3p5     ( cen3p5            ),

    .rom_addr   ( snd_addr          ),
    .rom_data   ( snd_data          ),
    .rom_cs     ( snd_cs            ),
    .rom_ok     ( snd_ok            ),

    .shr_addr   ( shr_addr          ),
    .shr_dout   ( shr_dout          ),
    .shr_din    ( shr_din           ),
    .shr_we     ( shr_we            ),

    .ram_addr   ( sndram_addr       ),
    .ram_we     ( sndram_we         ),
    .ram_dout   ( sndram_dout       ),

    .snd        ( fm                )
);

/* verilator tracing_on */
jtwardnr_video u_video(
    .rst        ( rst               ),
    .clk        ( clk               ),
    .pxl_cen    ( pxl_cen           ),

    .scr_cs     ( scr_cs            ),
    .scr_addr   ( scr_addr          ),
    .scr_din    ( cpu_dout          ),
    .txoffs     ( txoffs            ),
    .bgoffs     ( bgoffs            ),
    .fgoffs     ( fgoffs            ),
    .flip       ( flip              ),
    .bg_bank    ( bg_bank           ),
    .fg_bank    ( fg_bank           ),
    .video_on   ( video_on          ),
    .gfx_en     ( gfx_en            ),

    .tx_vaddr   ( tx_vaddr          ),
    .tx_dout    ( tx_dout           ),
    .bg_vaddr   ( bg_vaddr          ),
    .bg_dout    ( bg_dout           ),
    .fg_vaddr   ( fg_vaddr          ),
    .fg_dout    ( fg_dout           ),
    .pal_vaddr  ( pal_vaddr         ),
    .pal_dout   ( pal_dout          ),
    .obj_vaddr  ( obj_vaddr         ),
    .obj_dout   ( obj_dout          ),
    .objcpy_addr( objcpy_addr       ),
    .objcpy_we  ( objcpy_we         ),
    .objscan_addr( objscan_addr     ),
    .objscan_dout( objscan_dout      ),

    .char_addr  ( char_addr         ),
    .char_data  ( char_data         ),
    .char_cs    ( char_cs           ),
    .char_ok    ( char_ok           ),
    .fg_addr    ( fg_full_addr      ),
    .fg_data    ( fg_data           ),
    .fg_cs      ( fg_cs             ),
    .fg_ok      ( fg_ok             ),
    .bg_addr    ( bg_addr           ),
    .bg_data    ( bg_data           ),
    .bg_cs      ( bg_cs             ),
    .bg_ok      ( bg_ok             ),
    .obj_addr   ( obj_addr          ),
    .obj_data   ( obj_data          ),
    .obj_cs     ( obj_cs            ),
    .obj_ok     ( obj_ok            ),

    .LVBL       ( LVBL              ),
    .LHBL       ( LHBL              ),
    .HS         ( HS                ),
    .VS         ( VS                ),
    .red        ( red               ),
    .green      ( green             ),
    .blue       ( blue              )
);

endmodule
