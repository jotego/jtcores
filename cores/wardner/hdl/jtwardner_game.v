/* SPDX-FileCopyrightText: 2026 Marc Emmerson
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Wardner (Toaplan TP-009 / Taito B25, 1987) top level.
 *
 * Four subsystems, wired the way the board is:
 *
 *   jtwardner_main    Z80 at 6 MHz (24 MHz crystal / 4). Owns every RAM the
 *                     video reads - work, sprite, palette and the three tile
 *                     maps - and exports a read port of each.
 *   jttoaplan1_dsp    TMS320C10 at 14 MHz. Setting the run bit halts the main
 *                     Z80 and hands the DSP a window into its RAMs; it drives
 *                     gameplay, not just protection.
 *   jtwardner_sound   Z80 and YM3812 at 3.5 MHz, talking to the main CPU
 *                     through 2 kB of shared RAM.
 *   jtwardner_video   446x286 raster at 7 MHz, three tile maps, sprite line
 *                     buffer and the priority mixer.
 *
 * Clocking: 6 MHz is an exact divide of the 48 MHz clock, and the second
 * crystal is one fractional chain (48 * 7/24 = 14 MHz) halved twice to give
 * the 7 MHz pixel clock and the 3.5 MHz audio clock, which is how the board
 * derives them. See cfg/mem.yaml.
 */

module jtwardner_game(
    `include "jtframe_game_ports.inc"
);

// ---- main CPU to DSP
wire        dsp_on, dsp_halt, dsp_we;
wire [12:0] dsp_addr;
wire [ 1:0] dsp_sel;
wire [15:0] dsp_dout, dsp_din;

// ---- main CPU to video
wire [15:0] tx_scrx, tx_scry, bg_scrx, bg_scry, fg_scrx, fg_scry;
wire        flip, bg_bank, fg_bank, video_on;

// Palette readback. With JTFRAME_IOCTL_RD set, the OSD's save writes
// JTFRAME_IOCTL_RD bytes to the SD card; pointing that at the palette gives the
// exact contents the hardware is using, which a photograph cannot. While the
// dump runs the video is not being displayed, so borrowing its read port costs
// nothing.
wire [10:0] pal_vaddr_vid;

wire [ 7:0] dipsw_a, dipsw_b, cab_sys, cab_joy1, cab_joy2;
// the DSP addresses 4096 words; the mask ROM region holds 2048
wire [11:0] dsp_rom_addr;
wire        obj_ovf, sample;

// the sprite generator asks for a 16-pixel row as two 32-bit halves, so the
// bus address is {sprite, row, half}; the tile maps ask for {tile, row}
wire [15:0] fg_full_addr;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
`ifdef JTFRAME_IOCTL_RD
    assign pal_vaddr = ioctl_ram ? ioctl_addr[11:1] : pal_vaddr_vid;
    assign ioctl_din = ioctl_addr[0] ? pal_vq[15:8] : pal_vq[7:0];
`else
    assign pal_vaddr = pal_vaddr_vid;
`endif
assign dip_flip = flip;
assign pxl_cen  = cen7;
assign pxl2_cen = cen14;

// The Toaplan cabinet ports read active high, JTFRAME's inputs are active low.
// SYSTEM (wardner.cpp): 0 service, 1 tilt, 2 test, 3 coin1, 4 coin2,
// 5 start1, 6 start2, 7 vertical blanking - and the main CPU substitutes
// blanking for bit 7 itself, so it is left at zero here.
//
// dip_test and tilt are active low like the rest: jtframe_dip.v says of
// dip_test "assumes it is always active low" and drives it to zero to assert
// test in simulation, and the CPS cores tie an unused tilt to 1'b1. Passing
// either through uninverted asserts TEST and TILT on the board permanently.
assign cab_sys = { 1'b0, ~cab_1p[1], ~cab_1p[0], ~coin[1], ~coin[0],
                   ~dip_test, ~tilt, ~service };

// Toaplan player ports read active high: 0 up, 1 down, 2 left, 3 right,
// 4 button 1, 5 button 2, 6 skip video RAM tests - left inactive so they run.
// jtframe supplies up, down, left, right in bits 3 down to 0, so the direction
// nibble is reversed. The buttons line up as they are.
assign cab_joy1 = { 2'b00, ~joystick1[5], ~joystick1[4],
                    ~joystick1[0], ~joystick1[1], ~joystick1[2], ~joystick1[3] };
assign cab_joy2 = { 2'b00, ~joystick2[5], ~joystick2[4],
                    ~joystick2[0], ~joystick2[1], ~joystick2[2], ~joystick2[3] };

// Both memory ports are one bit narrower than what drives them. dsprom_addr is
// [11:1] because the DSP addresses 4096 words and the mask ROM holds 2048.
// fg_addr is [16:2] because the tile engine prepends a bank bit selecting tiles
// 4096-8191, which Wardner's foreground ROM does not have; dropping it is what
// MAME's code % total does. Twin Cobra has twice the ROM and would use it.
assign fg_addr     = fg_full_addr[14:0];
assign dsprom_addr = dsp_rom_addr[10:0];

assign debug_view = { 3'd0, obj_ovf, dsp_halt, dsp_on, flip, video_on };

/* verilator tracing_off */
jtwardner_main u_main(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen6       ( cen6          ),
    .LVBL       ( LVBL          ),

    .rom_addr   ( main_addr     ),
    .rom_data   ( main_data     ),
    .rom_cs     ( main_cs       ),
    .rom_ok     ( main_ok       ),

    .dsp_on     ( dsp_on        ),
    .dsp_halt   ( dsp_halt      ),
    .dsp_addr   ( dsp_addr      ),
    .dsp_sel    ( dsp_sel       ),
    .dsp_dout   ( dsp_dout      ),
    .dsp_din    ( dsp_din       ),
    .dsp_we     ( dsp_we        ),

    .sh_addr    ( sh_addr       ),
    .sh_din     ( sh_din        ),
    .work_bwe   ( work_bwe      ),
    .work_dout  ( work_dout     ),
    .obj_bwe    ( obj_bwe       ),
    .pal_bwe    ( pal_bwe       ),
    .objram_dout( objram_dout   ),
    .pal_dout   ( pal_dout      ),
    .mshr_addr  ( mshr_addr     ),
    .mshr_we    ( mshr_we       ),
    .shared_dout( shared_dout   ),
    .cpu16      ( cpu16         ),
    .cpu_dout   ( cpu_dout      ),
    .tx_a       ( tx_a          ),
    .bg_a       ( bg_a          ),
    .fg_a       ( fg_a          ),
    .tx_bwe     ( tx_bwe        ),
    .bg_bwe     ( bg_bwe        ),
    .fg_bwe     ( fg_bwe        ),
    .txram_dout ( txram_dout    ),
    .bgram_dout ( bgram_dout    ),
    .fgram_dout ( fgram_dout    ),


    .tx_scrx    ( tx_scrx       ),  .tx_scry ( tx_scry ),
    .bg_scrx    ( bg_scrx       ),  .bg_scry ( bg_scry ),
    .fg_scrx    ( fg_scrx       ),  .fg_scry ( fg_scry ),
    .flip       ( flip          ),
    .bg_bank    ( bg_bank       ),
    .fg_bank    ( fg_bank       ),
    .video_on   ( video_on      ),


    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .joy1       ( cab_joy1      ),
    .joy2       ( cab_joy2      ),
    .cab_sys    ( cab_sys       ),

    .dbg_iowr   (               ),
    .dbg_iord   (               ),
    .dbg_port   (               ),
    .dbg_data   (               ),
    .dbg_pc_addr(               ),
    .dbg_m1     (               )
);

/* verilator tracing_off */
jttoaplan1_dsp #(.TWINCOBR(0)) u_dsp(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen14         ),

    .dsp_on     ( dsp_on        ),
    .halt_main  ( dsp_halt      ),

    .host_addr  ( dsp_addr      ),
    .host_sel   ( dsp_sel       ),
    .host_dout  ( dsp_dout      ),
    .host_din   ( dsp_din       ),
    .host_we    ( dsp_we        ),

    .rom_addr   ( dsp_rom_addr  ),
    .rom_data   ( dsprom_data   ),

    .dbg_bio    (               ),  .dbg_exec   (   ),
    .dbg_rd     (               ),  .dbg_wr     (   ),
    .dbg_p0     (               ),  .dbg_p3     (   ),
    .dbg_pdout  (               ),  .dbg_pwr    (   ),
    .dbg_sel_new(               ),  .dbg_addr_new(  ),
    .dbg_fetch  (               ),  .dbg_pc     (   ),
    .dbg_str    (               ),  .dbg_acc    (   ),
    .dbg_preg   (               ),  .dbg_treg   (   ),
    .dbg_ar0    (               ),  .dbg_ar1    (   ),
    .dbg_stk0   (               ),  .dbg_stk1   (   ),
    .dbg_stk2   (               ),  .dbg_stk3   (   ),
    .dbg_romdata(               )
);

/* verilator tracing_off */
jtwardner_sound u_sound(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen3p5     ( cen3p5        ),

    .rom_addr   ( snd_addr      ),
    .rom_data   ( snd_data      ),
    .rom_cs     ( snd_cs        ),
    .rom_ok     ( snd_ok        ),

    .shr_addr   ( shr_addr      ),
    .shr_dout   ( shr_dout      ),
    .shr_din    ( shr_din       ),
    .shr_we     ( shr_we        ),

    .snd        ( fm            ),
    .sample     ( sample        ),

    .dbg_fmwr   (               ),
    .dbg_fmdata (               ),
    .dbg_fmaddr (               ),
    .dbg_pc_addr(               ),
    .dbg_m1     (               )
);

/* verilator tracing_on */
jtwardner_video u_video(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .pxl_cen    ( pxl_cen       ),

    .tx_scrx    ( tx_scrx       ),  .tx_scry ( tx_scry ),
    .bg_scrx    ( bg_scrx       ),  .bg_scry ( bg_scry ),
    .fg_scrx    ( fg_scrx       ),  .fg_scry ( fg_scry ),
    .flip       ( flip          ),
    .bg_bank    ( bg_bank       ),
    .fg_bank    ( fg_bank       ),
    .video_on   ( video_on      ),
    .gfx_en     ( gfx_en        ),

    .tx_vaddr   ( tx_vaddr      ),  .tx_vq  ( tx_vq  ),
    .bg_vaddr   ( bg_vaddr      ),  .bg_vq  ( bg_vq  ),
    .fg_vaddr   ( fg_vaddr      ),  .fg_vq  ( fg_vq  ),
    .pal_vaddr  ( pal_vaddr_vid ),  .pal_vq ( pal_vq ),
    .obj_vaddr  ( obj_vaddr     ),  .obj_vq ( obj_vq ),

    .char_addr  ( char_addr     ),
    .char_data  ( char_data     ),
    .char_cs    ( char_cs       ),
    .char_ok    ( char_ok       ),

    .fg_addr    ( fg_full_addr  ),
    .fg_data    ( fg_data       ),
    .fg_cs      ( fg_cs         ),
    .fg_ok      ( fg_ok         ),

    .bg_addr    ( bg_addr       ),
    .bg_data    ( bg_data       ),
    .bg_cs      ( bg_cs         ),
    .bg_ok      ( bg_ok         ),

    .obj_addr   ( obj_addr      ),
    .obj_data   ( obj_data      ),
    .obj_cs     ( obj_cs        ),
    .obj_ok     ( obj_ok        ),

    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .hdump      (               ),
    .vdump      (               ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .obj_ovf    ( obj_ovf       )
);

endmodule
