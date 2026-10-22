/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2026.

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  Nemesis Top-Level Module
//================================================================================

`default_nettype none

module jtnemesis_game(
/*
	// Clocks
	input           rst,
	input           clk,        // 48 MHz
	output          pxl2_cen,   // 12 MHz
	                pxl_cen,    // 6 MHz
	// Video
	output   [`JTFRAME_COLORW-1:0]  red, green, blue,
	output          LHBL,       // Horizontal Blank, possibly delayed
	                LVBL,       // Vertical Blank, possibly delayed
	                HS,         // Horizontal video sync output
	                VS,         // Vertical video sync output
	output          game_led,
	// Cabinet I/O
	input   [ 1:0]  cab_1p, coin,
	input   [`JTFRAME_BUTTONS+3:0] joystick1,
	                               joystick2, // 4 directions, 3 buttons, MSB unused
	// Sound control
	input           enable_fm, enable_psg,
	// DIP switches
	input   [31:0]  status, dipsw,
	// Not DIPs on the original PCB
	input           dip_pause, dip_test, service, tilt,
	output          dip_flip,
	input   [ 1:0]  dip_fxlevel,
	// Sound output
	output signed [15:0] snd,
	output          sample,
	// Debug
	input   [3:0]   gfx_en,
	input   [7:0]   debug_bus,
	output  [7:0]   debug_view,

	// ROM Download
	input   [25:0]  ioctl_addr,
	input   [ 7:0]  ioctl_dout,
	input           ioctl_wr,
	// SDRAM Interface
	input           ioctl_rom,
	output          dwnld_busy, // needs to be kept to 1 until finished downloading
	input   [15:0]  data_read,
	input           ioctl_cart,
	output          sdram_req,
	output [21:0]   sdram_addr,
	input           data_dst,
	input           data_rdy,
	input           sdram_ack,
	// ROM Download
	output [ 7:0]   prog_data,
	output          prog_we,
	output          prog_rd,
	output  [ 1:0]  prog_mask,
	                prog_addr   // no comma here, end of port list%
*/
	`include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

///////////////////
// Interconnection Signals
///////////////////

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
wire [ 7:0] red_lut, green_lut, blue_lut;
wire [14:0] rgb, rgb_blk;
wire        preLHBL, preLVBL;

// joystick indices
localparam  dir_right  = 0,
            dir_left   = 1,
            dir_down   = 2,
            dir_up     = 3,
            btn_option = 4,
            btn_fire   = 5,
            btn_bomb   = 6;

///////////////////
// Clock and Clock-Enable Generation
///////////////////

assign pxl_cen  = cen6;
assign pxl2_cen = cen12;

gx400_cen u_cen(
	.i_clk               ( clk               ), // in  48 MHz
	.i_vsync60           ( 1'b0              ),

	.o_cen12             ( cen12             ), // out 12 MHz
	.o_cen6              ( cen6              ), // out  6 MHz
	.o_cen6b             ( cen6b             ),
	.o_clk6              ( clk6              ), // out  6 MHz
	.o_cen9              ( cen9              ), // out  9 MHz
	.o_cen3p5            ( cen3p5            ), // out  3.57 MHz
	.o_cen1p7            ( cen1p7            ),
	.o_cen_audio_clk_div ( cen_audio_clk_div )
);

///////////////////
// ROM Download
///////////////////

// ROM data
wire [  3:0] wav1_data, wav2_data;
wire [  7:0] wav1_vol_data, wav2_vol_data;

// ROM address
wire [ 7:0] wav1_addr, wav1_vol_addr, wav2_addr, wav2_vol_addr;

// PROM signals
wire		prom_a01_we, prom_a02_we, prom_vol_we;

///// Download /////

// offsets (in bytes) where each of the PROMs starts
localparam [21:0] WAV1_OFFSET    = 22'h04_4000,
                  WAV2_OFFSET    = 22'h04_4100,
                  WAV_VOL_OFFSET = 22'h04_4200;

reg cpu_start;

// TODO: check if needed
always @(posedge clk, posedge rst) begin
	if( rst ) begin
		cpu_start <= 0;
	end else if( &{ audio_ok } ) begin
		cpu_start <= 1;
	end
end

///// SDRAM Data Debugging /////

// Define ROM_DEBUG_Z80 or ROM_DEBUG_MAIN to visualise the first 255 bytes
// of the respective ROM stored in SDRAM using the debug bus, to check
// the offsets and endianness. The corresponding CPU will not operate during
// this, as the ROM is disconnected from its address bus.
// If neither macro is defined, the nemesis_rom_debug module just passes the
// cs and addr signals through.

wire [16:0] req_main_addr;
wire [13:0] req_audio_addr;
wire        req_main_cs, req_audio_cs;

nemesis_rom_debug u_rom_debug(
	.i_clk             ( clk                       ),
	.i_cen             ( cen6                      ),

`ifndef JTFRAME_RELEASE
	.i_debug_bus       ( debug_bus                 ),
	.o_debug_view      ( debug_view                ),
`endif

	.i_z80_cs          ( req_audio_cs | ~cpu_start ),
	.i_z80_ok          ( audio_ok                  ),
	.i_z80_addr        ( req_audio_addr            ),
	.i_z80_data        ( audio_data                ),
	.o_z80_sdram_cs    ( audio_cs                  ),
	.o_z80_sdram_addr  ( audio_addr                ),
	
	.i_main_cs         ( req_main_cs | ~cpu_start  ),
	.i_main_ok         ( main_ok                   ),
	.i_main_addr       ( req_main_addr             ),
	.i_main_data       ( main_data                 ),
	.o_main_sdram_cs   ( main_cs                   ),
	.o_main_sdram_addr ( main_addr                 )
);

///// PROMs /////

// create PROM addresses from prog_addr, to start at 0 at the beginning of
// the PROM. It’s often not needed because the offset is usually larger than
// the width of the PROM address, but it can become an issue depending on the
// order of the ROMs, e.g. if you have a 1k ROM followed by a 2k ROM, prog_addr
// at the beginning of the second ROM will be 0x0400, and prog_addr[10:0] will
// be 0x0400 instead of 0x0000.
wire [7:0] prog_addr_wave1    = prog_addr[7:0] - WAV1_OFFSET[7:0],
           prog_addr_wave2    = prog_addr[7:0] - WAV2_OFFSET[7:0],
           prog_addr_wave_vol = prog_addr[7:0] - WAV_VOL_OFFSET[7:0];

// write-enable signals to select the PROMs to send data to, based on the offsets
assign prom_a01_we = prom_we && ( prog_addr >= WAV1_OFFSET    ) && ( prog_addr < WAV2_OFFSET    );
assign prom_a02_we = prom_we && ( prog_addr >= WAV2_OFFSET    ) && ( prog_addr < WAV_VOL_OFFSET );
assign prom_vol_we = prom_we && ( prog_addr >= WAV_VOL_OFFSET );

// ** 1K (256 x 4) NiCR PROM **
// ** [6301] @ 7A            **
jtframe_prom #(
	.AW      (  8              ),
	.DW      (  4              )
	`ifdef JTFRAME_PROM_DUMP
	, .dumpfile("dump_wav1.hex")
	`endif
)
u_wav1_rom(
	.clk     ( clk             ),
	.cen     ( 1'b1            ),
	.rd_addr ( wav1_addr[7:0]  ),
	.wr_addr ( prog_addr_wave1 ),
	.data    ( prog_data[3:0]  ),
	.we      ( prom_a01_we     ),
	.q       ( wav1_data       )
	`ifdef JTFRAME_PROM_DUMP
	, .dump  ( ~ioctl_rom )
	`endif
);

// ** 1K (256 x 4) NiCR PROM **
// ** [6301] @ 7B            **
jtframe_prom #(
	.AW      (  8              ),
	.DW      (  4              )
	`ifdef JTFRAME_PROM_DUMP
	, .dumpfile("dump_wav2.hex")
	`endif
)
u_wav2_rom(
	.clk     ( clk             ),
	.cen     ( 1'b1            ),
	.rd_addr ( wav2_addr[7:0]  ),
	.wr_addr ( prog_addr_wave2 ),
	.data    ( prog_data[3:0]  ),
	.we      ( prom_a02_we     ),
	.q       ( wav2_data       )
	`ifdef JTFRAME_PROM_DUMP
	, .dump  ( ~ioctl_rom      )
	`endif
);

// Volume table loaded from the MRA and that simulates the switched
// resistor ladders at the output of the 6301 PROMs @ 7A, 7B.

jtframe_prom #(
	.AW      (  8                 ),
	.DW      (  8                 ),
	.SYNHEX  ("../firmware/nemesis_prom_vol.hex")
	`ifdef JTFRAME_PROM_DUMP
	, .dumpfile("dump_wav1_vol.hex")
	`endif
)
u_wav1_vol_rom(
	.clk     ( clk                ),
	.cen     ( 1'b1               ),
	.rd_addr ( wav1_vol_addr[7:0] ),
	.wr_addr ( prog_addr_wave_vol ),
	.data    ( prog_data[7:0]     ),
	.we      ( prom_vol_we        ),
	.q       ( wav1_vol_data      )
	`ifdef JTFRAME_PROM_DUMP
	, .dump  ( ~ioctl_rom         )
	`endif
);

jtframe_prom #(
	.AW      (  8                 ),
	.DW      (  8                 ),
	.SYNHEX  ("../firmware/nemesis_prom_vol.hex")
	`ifdef JTFRAME_PROM_DUMP
	, .dumpfile("dump_wav2_vol.hex")
	`endif
)
u_wav2_vol_rom(
	.clk     ( clk                ),
	.cen     ( 1'b1               ),
	.rd_addr ( wav2_vol_addr[7:0] ),
	.wr_addr ( prog_addr_wave_vol ),
	.data    ( prog_data[7:0]     ),
	.we      ( prom_vol_we        ),
	.q       ( wav2_vol_data      )
	`ifdef JTFRAME_PROM_DUMP
	, .dump  ( ~ioctl_rom         )
	`endif
);

///////////////////
// Main Board
///////////////////

nemesis_main main(
	.i_clk          ( clk             ), // 48 MHz
	.i_rst          ( rst             ),

	// LS244 @ 18E (schematic bottom left)
	.i_cen9         ( cen9            ),
	.i_vblank       ( preLVBL_n       ),
	.i_256v         ( video_256v      ),
	.i_blk          (                 ),
	.i_cen6         ( cen6            ),
	.i_clk6         ( clk6            ),
	.i_1h_n         ( video_1h_n      ),
	.i_2h           ( video_2h        ),

	// LS244 @ 18G (schematic top centre)
	.i_vsinc        (                 ),
	.i_sync         (                 ),
	.o_chacs_n      ( chacs_n         ),
	.o_rw_n         ( main_rw_n       ),
	.o_uds_n        ( main_uds_n      ),
	.o_lds_n        ( main_lds_n      ),

	// LS244 @ 18J (schematic top right)
	.o_inter_non    (                 ),
	.o_288_256      (                 ),
	.o_vflip        ( vflip           ),
	.o_hflip        ( hflip           ),
	.o_objram_n     ( objram_n        ),
	.o_vcs2         ( vcs2            ),
	.o_vcs1         ( vcs1            ),
	.o_vzcs         ( vzcs            ),

	// ROM
	.o_rom_cs       ( req_main_cs     ),
	.o_rom_addr     ( req_main_addr   ),
	.i_rom_data     ( main_data       ), // 16 bits data in from PROM
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

	// DIP switches
	.i_dip1         ( dipsw[ 7: 0]    ),
	.i_dip2         ( dipsw[15: 8]    ),
	.i_dip3         ( dipsw[23:16]    ),

	// PS2401_4 @ 2E, 2F, 2G, 2H, 2J
	// A: solder side, B: parts side, cf. manual, page 4
	.i_coin1        ( coin[0]                 ), // Credit 1
	.i_coin2        ( coin[1]                 ), // Credit 2
	.i_1p_right     ( joystick1[ dir_right ]  ), // Joystick Player 1 Right
	.i_1p_left      ( joystick1[ dir_left  ]  ), // Joystick Player 1 Left
	.i_1p_down      ( joystick1[ dir_down  ]  ), // Joystick Player 1 Down
	.i_1p_up        ( joystick1[ dir_up    ]  ), // Joystick Player 1 Up
	.i_1p_start     ( cab_1p[0]               ), // Player 1 Start button
	.i_1p_sp_pow    ( joystick1[ btn_option ] ), // Player 1 Special Power
	.i_1p_shoot     ( joystick1[ btn_fire   ] ), // Player 1 Fire
	.i_1p_missile   ( joystick1[ btn_bomb   ] ), // Player 1 Missile
	.i_2p_right     ( joystick2[ dir_right ]  ), // Joystick Player 2 Right
	.i_2p_left      ( joystick2[ dir_left  ]  ), // Joystick Player 2 Left
	.i_2p_down      ( joystick2[ dir_down  ]  ), // Joystick Player 2 Down
	.i_2p_up        ( joystick2[ dir_up    ]  ), // Joystick Player 2 Up
	.i_2p_start     ( cab_1p[1]               ), // Player 2 Start button
	.i_2p_sp_pow    ( joystick2[ btn_option ] ), // Player 2 Special Power
	.i_2p_shoot     ( joystick2[ btn_fire   ] ), // Player 2 Fire
	.i_2p_missile   ( joystick2[ btn_bomb   ] ), // Player 2 Missile
	.i_service      ( 1'b1                    ), // Service button
	.i_pause        ( dip_pause               )  // Pause in OSD
);


assign rgb = { red5, green5, blue5 };
assign { red5_blk, green5_blk, blue5_blk } = rgb_blk;

jtframe_blank #( .DLY(0), .DW(15) ) u_blank(
	.clk      ( clk      ), // in
	.pxl_cen  ( cen6     ), // in
	.preLHBL  ( preLHBL  ), // in
	.preLVBL  ( preLVBL  ), // in
	.LHBL     ( LHBL     ), // out
	.LVBL     ( LVBL     ), // out
	.preLBL   (          ), // out
	.rgb_in   ( rgb      ), // in
	.rgb_out  ( rgb_blk  )  // out
);

// Lookup table generated by cpp/resnet.cp and that simulates the switched
// resistor ladders at the output of the 2128-15 RAMs @ 14K, 15K
colour_lut #( .pw(5), .cw(8), .synfile("../firmware/nemesis_colmix.hex") ) u_colour_lut(
	.clk       ( clk        ),
	.in_red    ( red5_blk   ),
	.in_green  ( green5_blk ),
	.in_blue   ( blue5_blk  ),
	.out_red   ( red_lut    ),
	.out_green ( green_lut  ),
	.out_blue  ( blue_lut   )
);

`ifdef TEST68K

assign red   = joystick1[ btn_option ] ? red_lut   : { red5_blk,   3'b0 };
assign green = joystick1[ btn_option ] ? green_lut : { green5_blk, 3'b0 };
assign blue  = joystick1[ btn_option ] ? blue_lut  : { blue5_blk,  3'b0 };

`else // TEST68K

assign red   = red_lut;
assign green = green_lut;
assign blue  = blue_lut;

`endif // TEST68K

///////////////////
// Video Board
///////////////////

wire preLVBL_n;

`ifdef NOVIDEO

jtframe_vtimer vtimer(
	.clk     ( clk     ),
	.pxl_cen ( pxl_cen ),
	.LHBL    ( preLHBL ),
	.LVBL    ( preLVBL ),
	.HS      ( HS      ),
	.VS      ( VS      )
);

`else // NOVIDEO

assign preLVBL = ~preLVBL_n;

GX400A_VIDEO video(
	.i_MCLK     ( clk              ),     // in             - (Main Clock)  48 MHz
	.i_RESET    ( rst              ),     // in             - RESET signal
	.i_HFLIP    ( hflip            ),     // in             - Horizontal Flip
	.i_VFLIP    ( vflip            ),     // in             - Vertical Flip
	.i_INTER_NON( 1'b0             ),     // in             - Interlaced/Non-Interlaced
	.i_288_256  ( 1'b0             ),     // in             - 288 vs. 256 columns

	.i_cen6     ( cen6             ),     // out            - Pixel Clock at 12 MHz
	.i_cen6b    ( cen6b            ),
	.i_clk6     ( clk6             ),     // out            - Pixel Clock at  6 MHz

	.o_HS       ( HS               ),     // out            - Horizontal sync (VGA_HS)
	.o_VS       ( VS               ),     // out            - Vertiacl sync (VGA_VS)
	.o_HBL      ( preLHBL          ),     // out            - Horizontal BLANK
	.o_VBL      ( preLVBL_n        ),     // out            - Vertical BLANK

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

`endif //NOVIDEO

///////////////////
// Sound Board
///////////////////

`ifndef NOSOUND

wire        prom1_on, prom2_on, ay7_on, ay8_on;
wire [ 7:0] bal_prom, bal_ay7, bal_ay8;
wire [ 7:0] m68k_data_bus;

nemesis_sound_debug u_sound_debug(
	.i_command    ( status[24:20] ),
	.i_channels   ( status[27:25] ),

	// debug mixer
	.i_vol_prom   ( 4'd0          ),
	.i_vol_ay7    ( 4'd0          ), // AY2 Music
	.i_vol_ay8    ( 4'd0          ), // AY1 SFX

	// sound command
	.o_sound_data ( m68k_data_bus ),
	
	// sound channels
	.o_prom1_on   ( prom1_on      ),
	.o_prom2_on   ( prom2_on      ),
	.o_ay7_on     ( ay7_on        ),
	.o_ay8_on     ( ay8_on        ),
	
	// balance
	.o_bal_prom   ( bal_prom      ),
	.o_bal_ay7    ( bal_ay7       ),
	.o_bal_ay8    ( bal_ay8       )
);

nemesis_sound u_sound(
	.i_clk            ( clk               ),
	.i_cen3p5         ( cen3p5            ),
	.i_cen1p7         ( cen1p7            ),
	.i_cen_clk_div    ( cen_audio_clk_div ),

`ifdef SOUND_TEST
	.i_rst            ( ~joystick1[ btn_fire ]  ),
	.i_main_db        ( m68k_data_bus           ),
	.i_data_n         ( ~joystick1[ dir_left ]  ),
	.i_sound_on_n     ( ~joystick1[ dir_right ] ), // sound starts on stick press
`else
	.i_rst            ( rst               ),
	.i_main_db        ( sound_din         ),
	.i_data_n         ( data_n            ),
	.i_sound_on_n     ( sound_on_n        ),
`endif
	.i_cpu_start      ( cpu_start         ),
	.o_z80_cs         ( req_audio_cs      ),
	.o_z80_addr       ( req_audio_addr    ),
	.i_z80_data       ( audio_data        ),
	.i_z80_ok         ( audio_ok          ),

	.o_wav1_addr      ( wav1_addr         ),
	.o_wav1_vol_addr  ( wav1_vol_addr     ),
	.o_wav2_addr      ( wav2_addr         ),
	.o_wav2_vol_addr  ( wav2_vol_addr     ),
	.i_wav1_data      ( wav1_data         ),
	.i_wav1_vol_data  ( wav1_vol_data     ),
	.i_wav2_data      ( wav2_data         ),
	.i_wav2_vol_data  ( wav2_vol_data     ),

	.o_sound          ( snd               ),

	.i_prom1_on       ( 1'b1              ),
	.i_prom2_on       ( 1'b1              ),
	.i_ay7_on         ( 1'b1              ),
	.i_ay8_on         ( 1'b1              ),
	.i_vol_prom       ( `VOLUME_PROMS /* bal_prom */ ),
	.i_vol_ay7        ( `VOLUME_AY2   /* bal_ay7 */  ), // AY2 Music
	.i_vol_ay8        ( `VOLUME_AY1   /* bal_ay8 */  )  // AY1 SFX
);

`endif // NOSOUND

endmodule
