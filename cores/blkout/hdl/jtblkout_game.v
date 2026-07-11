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
*/

module jtblkout_game(
    `include "jtframe_game_ports.inc"
);

wire [ 1:0] main_dsn;
wire        main_rnw;
wire        work_cs, work2_cs, work3_cs, fvram_cs, pal_cs, fb_cs, frontcol_cs;
wire [11:0] frontcol;
wire [ 7:0] snd_latch;
wire        snd_irq;

assign dip_flip   = 0;
assign debug_view = 0;

// BRAM write strobes / addresses (framework-wired via mem.yaml)
assign work_addr = main_addr[15:1];
assign work_we   = {2{work_cs  & ~main_rnw}} & ~main_dsn;
assign work2_addr= main_addr[15:1];
assign work2_we  = {2{work2_cs & ~main_rnw}} & ~main_dsn;
assign fvram_we  = {2{fvram_cs & ~main_rnw}} & ~main_dsn;
// palette pen = (A-0x280200)>>1 = {A[10],A[8:1]} (A[9] is the base bit)
assign pal_addr  = {main_addr[10], main_addr[8:1]};
assign pal_we    = {2{pal_cs   & ~main_rnw}} & ~main_dsn;

// Back framebuffer (SDRAM bank 2): CPU R/W straight-through, video read is fbrd.
// A write must wait for a valid byte strobe: fb_cs asserts at ASn but the 68k
// drives UDSn/LDSn later, so issuing at ASn with dsn=11 would mask the byte.
wire fb_wr = fb_cs & ~main_rnw;
assign fbram_sel = main_rnw ? fb_cs : (fb_wr & main_dsn!=2'b11);
assign fbram_addr= main_addr[17:1];
assign fbram_dsn = main_dsn;
assign fbram_we  = fb_wr & main_dsn!=2'b11;
assign fb_wdata  = cpu_dout;

// Work RAM 0x208000-0x21ffff (SDRAM bank 3): CPU R/W straight-through, same
// byte-strobe handling as the framebuffer. No video read -> single rw bus.
wire work3_wr = work3_cs & ~main_rnw;
assign work3_sel  = main_rnw ? work3_cs : (work3_wr & main_dsn!=2'b11);
assign work3_addr = main_addr[16:1];
assign work3_dsn  = main_dsn;
assign work3_we   = work3_wr & main_dsn!=2'b11;
assign work3_wdata= cpu_dout;

jtblkout_main u_main(
    .rst        ( rst24     ),
    .clk        ( clk24     ),
    .LVBL       ( LVBL      ),

    .main_addr  ( main_addr ),
    .main_dout  ( cpu_dout  ),
    .main_dsn   ( main_dsn  ),
    .main_rnw   ( main_rnw  ),
    .rom_cs     ( main_cs   ),
    .work_cs    ( work_cs   ),
    .work2_cs   ( work2_cs  ),
    .work3_cs   ( work3_cs  ),
    .fvram_cs   ( fvram_cs  ),
    .pal_cs     ( pal_cs    ),
    .fb_cs      ( fb_cs     ),
    .frontcol_cs( frontcol_cs ),
    .frontcol   ( frontcol  ),

    .work_dout  ( work_dout ),
    .work2_dout ( work2_dout),
    .work3_dout ( work3_data),
    .work3_ok   ( work3_ok  ),
    .fvram_dout ( fvram_dout),
    .pal_dout   ( pal_dout  ),
    .fb_dout    ( fbram_data),
    .fb_ok      ( fbram_ok  ),
    .rom_data   ( main_data ),
    .rom_ok     ( main_ok   ),

    .snd_irq    ( snd_irq   ),
    .snd_latch  ( snd_latch ),

    .joystick1  ( joystick1 ),
    .joystick2  ( joystick2 ),
    .cab_1p     ( cab_1p    ),
    .coin       ( coin      ),
    .service    ( service   ),
    .tilt       ( tilt      ),
    .dip_pause  ( dip_pause ),
    .dipsw_a    ( dipsw[ 7:0] ),
    .dipsw_b    ( dipsw[15:8] )
);

jtblkout_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),

    .LHBL       ( LHBL      ),
    .LVBL       ( LVBL      ),
    .HS         ( HS        ),
    .VS         ( VS        ),

    .frontcol   ( frontcol  ),

    .fbrd_addr  ( fbrd_addr ),
    .fbrd_cs    ( fbrd_cs   ),
    .fbrd_data  ( fbrd_data ),
    .fbrd_ok    ( fbrd_ok   ),

    .palrd_addr ( palrd_addr),
    .pal_data   ( pal_data  ),

    .fvrd_addr  ( fvrd_addr ),
    .fvram_data ( fvram_data),

    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
);

jtdd2_sound u_sound(
    .rst        ( rst24        ),
    .clk        ( clk24        ),
    .H8         ( 1'b0         ),
    .cen_snd    ( cen_snd      ),
    .cen_fm     ( cen_fm       ),
    .cen_fm2    ( cen_fm2      ),
    .cen_oki    ( cen_oki      ),

    .snd_irq    ( snd_irq      ),
    .snd_latch  ( snd_latch    ),

    .rom_addr   ( snd_addr     ),
    .rom_cs     ( snd_cs       ),
    .rom_data   ( snd_data     ),
    .rom_ok     ( snd_ok       ),

    .adpcm_addr ( pcm_addr     ),
    .adpcm_cs   ( pcm_cs       ),
    .adpcm_data ( pcm_data     ),
    .adpcm_ok   ( pcm_ok       ),

    .fm_l       ( fm_l         ),
    .fm_r       ( fm_r         ),
    .pcm        ( pcm          )
);

endmodule
