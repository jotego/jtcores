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

// ---- main CPU to sound CPU
wire [10:0] shr_addr;
wire [ 7:0] shr_dout, shr_din;
wire        shr_we;

// ---- main CPU to video
wire [15:0] tx_scrx, tx_scry, bg_scrx, bg_scry, fg_scrx, fg_scry;
wire        flip, bg_bank, fg_bank, video_on;
wire [10:0] tx_vaddr, pal_vaddr, obj_vaddr;
// Palette readback. With JTFRAME_IOCTL_RD set, the OSD's save writes
// JTFRAME_IOCTL_RD bytes to the SD card; pointing that at the palette gives the
// exact contents the hardware is using, which a photograph cannot. While the
// dump runs the video is not being displayed, so borrowing its read port costs
// nothing.
wire [10:0] pal_rdaddr;
wire [12:0] bg_vaddr;
wire [11:0] fg_vaddr;
wire [15:0] tx_vq, bg_vq, fg_vq, pal_vq, obj_vq;

wire [ 7:0] dipsw_a, dipsw_b, cab_sys;
// the DSP addresses 4096 words; the mask ROM region holds 2048
wire [11:0] dsp_rom_addr;
wire        obj_ovf, sample;

// the sprite generator asks for a 16-pixel row as two 32-bit halves, so the
// bus address is {sprite, row, half}; the tile maps ask for {tile, row}
wire [15:0] fg_full_addr;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
`ifdef JTFRAME_IOCTL_RD
    assign pal_rdaddr = ioctl_ram ? ioctl_addr[11:1] : pal_vaddr;
    assign ioctl_din  = ioctl_addr[0] ? pal_vq[15:8] : pal_vq[7:0];
`else
    assign pal_rdaddr = pal_vaddr;
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

// Player ports, active high, read from MAME 0.289's own machine rather than
// guessed from the name of the TOAPLAN_JOY_UDLR_2_BUTTONS macro:
//
//   0 up  1 down  2 left  3 right  4 button 1  5 button 2
//   6 "Skip Video RAM Tests", P1 only, left inactive here so the tests run
//
// jtframe numbers its bits the other way up. jtframe_joysticks.v's comment
// "default order up, down, left, right" lists them MSB first, which its own
// permutations prove: JTFRAME_JOY_LRUD is {joy_in[1:0], joy_in[3:2]}, and for
// that to read left, right, up, down from bit 3 down, joy_in[3] must be up and
// joy_in[0] right. So jtframe gives up, down, left, right in bits 3 to 0 while
// the board wants them in bits 0 to 3, and the direction nibble is reversed.
// Buttons are in the same place in both.
//
//   j[3] up    -> bit 0        j[1] left  -> bit 2
//   j[2] down  -> bit 1        j[0] right -> bit 3
function [7:0] toaplan_joy(input [5:0] j);
    toaplan_joy = { 2'b00, ~j[5], ~j[4], ~j[0], ~j[1], ~j[2], ~j[3] };
endfunction

// The foreground bank bit selects tiles 4096-8191. Wardner's foreground ROM
// holds exactly 4096 tiles, and MAME wraps the code with code % total, so
// dropping the bit is what the reference does. Twin Cobra has twice the ROM
// and would use it, which is why the video module keeps the bit.
assign fg_addr = fg_full_addr[14:0];
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

    .snd_addr   ( shr_addr      ),
    .snd_dout   ( shr_dout      ),
    .snd_din    ( shr_din       ),
    .snd_we     ( shr_we        ),

    .tx_scrx    ( tx_scrx       ),  .tx_scry ( tx_scry ),
    .bg_scrx    ( bg_scrx       ),  .bg_scry ( bg_scry ),
    .fg_scrx    ( fg_scrx       ),  .fg_scry ( fg_scry ),
    .flip       ( flip          ),
    .bg_bank    ( bg_bank       ),
    .fg_bank    ( fg_bank       ),
    .video_on   ( video_on      ),

    .tx_vaddr   ( tx_vaddr      ),  .tx_vq  ( tx_vq  ),
    .bg_vaddr   ( bg_vaddr      ),  .bg_vq  ( bg_vq  ),
    .fg_vaddr   ( fg_vaddr      ),  .fg_vq  ( fg_vq  ),
    .pal_vaddr  ( pal_rdaddr    ),  .pal_vq ( pal_vq ),
    .obj_vaddr  ( obj_vaddr     ),  .obj_vq ( obj_vq ),

    .dipsw_a    ( dipsw_a       ),
    .dipsw_b    ( dipsw_b       ),
    .joy1       ( toaplan_joy(joystick1[5:0]) ),
    .joy2       ( toaplan_joy(joystick2[5:0]) ),
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
    .pal_vaddr  ( pal_vaddr     ),  .pal_vq ( pal_vq ),
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
