//Toki MiSTer
//Copyright (C) 2023 Solal Jacob 

//This program is free software: you can redistribute it and/or modify
//it under the terms of the GNU General Public License as published by
//the Free Software Foundation, either version 3 of the License, or
//(at your option) any later version.

//This program is distributed in the hope that it will be useful,
//but WITHOUT ANY WARRANTY; without even the implied warranty of
//MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//GNU General Public License for more details.

//You should have received a copy of the GNU General Public License
//along with this program.  If not, see <http://www.gnu.org/licenses/>.

////////// toki game main module /////////////////////
//
// This is Toki main module that init and wire :
//  - main module 
//  - video module
//  - sound module 
//
module jttoki_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
  );

wire hblank;
wire vblank;

assign LHBL = ~hblank;
assign LVBL = ~vblank;

wire  [8:0] hpos;
wire  [8:0] vpos;
wire [10:1] palette_addr;
wire [15:0] palette_out;

wire [10:1] vram_addr;
wire [15:0] vram_out;

wire [10:1] bg1_addr;
wire [15:0] bg1_out;

wire [10:1] bg2_addr;
wire [15:0] bg2_out;

wire [10:1] sprite_addr;
wire [15:0] sprite_out;

wire  [6:1] scroll_addr;
wire [15:0] scroll_out;

wire [8:0]  bg1_scroll_x;
wire [8:0]  bg1_scroll_y;
wire [8:0]  bg2_scroll_x;
wire [8:0]  bg2_scroll_y;
wire        bg_order;

wire m68k_sound_cs_2;
wire m68k_sound_cs_4;
wire m68k_sound_cs_6;

wire [15:0] m68k_sound_latch_0;
wire [15:0] m68k_sound_latch_1;
wire [15:0] z80_sound_latch_0; 
wire [15:0] z80_sound_latch_1;
wire [15:0] z80_sound_latch_2;

assign debug_view = 0;
assign sample     = 0;
assign dip_flip   = 0;

//////// MAIN ////////////
//
// main module 
// - 68k cpu
// - cpu ram & video ram
// - scroll latch
// - sound latch
//
toki_main  u_main(
  .rst(rst),

  // Clock
  .clk(clk),
  .clk48(clk48),
  .pxl_cen(pxl_cen),
  .pxl2_cen(pxl2_cen),

  // Video 
  .hsync(HS),
  .vsync(VS),
  .vblank(vblank),
  .hpos(hpos),
  .vpos(vpos),

  // Input
  .start_button(cab_1p[1:0]),
  .joystick1(joystick1),
  .joystick2(joystick2),

  // DIP switches
  .dipsw(dipsw),
  .dip_pause(dip_pause),
  .service(service),

  // 68K rom
  .cpu_rom_addr(cpu_rom_addr),
  .cpu_rom_cs(cpu_rom_cs),
  .cpu_rom_ok(cpu_rom_ok),
  .cpu_rom_data(cpu_rom_data),

  //Shared video RAM 
  .palette_addr(palette_addr),
  .palette_out(palette_out),

  .vram_addr(vram_addr),
  .vram_out(vram_out),

  .bg1_addr(bg1_addr),
  .bg1_out(bg1_out),

  .bg2_addr(bg2_addr),
  .bg2_out(bg2_out),

  .sprite_addr(sprite_addr),
  .sprite_out(sprite_out),

  //Scroll latch
  .bg1_scroll_x(bg1_scroll_x),
  .bg1_scroll_y(bg1_scroll_y),
  .bg2_scroll_x(bg2_scroll_x),
  .bg2_scroll_y(bg2_scroll_y),
  .bg_order(bg_order),

  //Sound latch
  .sound_cs_2(m68k_sound_cs_2),
  .sound_cs_4(m68k_sound_cs_4),
  .sound_cs_6(m68k_sound_cs_6),

  .m68k_sound_latch_0(m68k_sound_latch_0),
  .m68k_sound_latch_1(m68k_sound_latch_1),

  //Sound input from z80
  .z80_sound_latch_0(z80_sound_latch_0),
  .z80_sound_latch_1(z80_sound_latch_1),
  .z80_sound_latch_2(z80_sound_latch_2)
);

//////// VIDEO ////////////
//
// video module 
// - char, tile & sprite drawing 
// - vga sync 
//
toki_video u_video(
  .rst(rst),
  .clk(clk),
  .pxl_cen(pxl_cen),
  .pxl2_cen(pxl2_cen),

  // Video signal
  .hsync(HS),
  .vsync(VS),
  .hblank(hblank),
  .vblank(vblank),
  .hpos(hpos),
  .vpos(vpos),
  .gfx_en(gfx_en),

  .r(red),
  .g(green),
  .b(blue),

  //Shared video RAM
  .palette_addr(palette_addr),
  .palette_out(palette_out),

  .vram_addr(vram_addr),
  .vram_out(vram_out),

  .bg1_addr(bg1_addr),
  .bg1_out(bg1_out),

  .bg2_addr(bg2_addr),
  .bg2_out(bg2_out),

  .sprite_addr(sprite_addr),
  .sprite_out(sprite_out),

  //GFX ROM 
  .gfx1_rom_data(gfx1_rom_data),
  .gfx1_rom_ok(gfx1_rom_ok),
  .gfx1_rom_addr(gfx1_rom_addr),
  .gfx1_rom_cs(gfx1_rom_cs),

  .gfx2_rom_data(gfx2_rom_data),
  .gfx2_rom_ok(gfx2_rom_ok),
  .gfx2_rom_addr(gfx2_rom_addr),
  .gfx2_rom_cs(gfx2_rom_cs),

  .gfx3_rom_data(gfx3_rom_data),
  .gfx3_rom_ok(gfx3_rom_ok),
  .gfx3_rom_addr(gfx3_rom_addr),
  .gfx3_rom_cs(gfx3_rom_cs),

  .gfx4_rom_data(gfx4_rom_data),
  .gfx4_rom_ok(gfx4_rom_ok),
  .gfx4_rom_addr(gfx4_rom_addr),
  .gfx4_rom_cs(gfx4_rom_cs),

  // scroll latch
  .bg1_scroll_x(bg1_scroll_x),
  .bg1_scroll_y(bg1_scroll_y),
  .bg2_scroll_x(bg2_scroll_x),
  .bg2_scroll_y(bg2_scroll_y),
  .bg_order(bg_order)
);

//////// SOUND ////////////
//
// sound module
// seibu sound system: 
// - z80 
// - sei80bu z80 rom decypher
// - oki6295 / pcm 
// - ym3812 / fm 
// - coin input 
// 
toki_sound u_sound(
  .rst(rst),
  .clk(clk),
  .clk48(clk48),

  .oki_cen(oki_cen),

  .coin_input(coin[1:0]),

  .snd(snd),
  .fxlevel(dip_fxlevel),
  .enable_fm(enable_fm),
  .enable_psg(enable_psg),

  .z80_rom_addr(z80_rom_addr),
  .z80_rom_data(z80_rom_data),
  .z80_rom_ok(z80_rom_ok),
  .z80_rom_cs(z80_rom_cs),

  .bank_rom_addr(bank_rom_addr),
  .bank_rom_data(bank_rom_data),
  .bank_rom_ok(bank_rom_ok),
  .bank_rom_cs(bank_rom_cs),

  .pcm_rom_addr(pcm_rom_addr),
  .pcm_rom_data(pcm_rom_data),
  .pcm_rom_ok(pcm_rom_ok),
  .pcm_rom_cs(pcm_rom_cs),

  .m68k_sound_cs_2(m68k_sound_cs_2),
  .m68k_sound_cs_4(m68k_sound_cs_4),
  .m68k_sound_cs_6(m68k_sound_cs_6),

  .m68k_sound_latch_0(m68k_sound_latch_0),
  .m68k_sound_latch_1(m68k_sound_latch_1),
  .z80_sound_latch_0(z80_sound_latch_0),
  .z80_sound_latch_1(z80_sound_latch_1),
  .z80_sound_latch_2(z80_sound_latch_2)
);

endmodule
