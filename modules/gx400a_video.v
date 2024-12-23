/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2023.

Support the authors:

       Raki: https://www.patreon.com/ikamusume
    LMN-san: https://ko-fi.com/lmnsan
  OScherler: https://ko-fi.com/oscherler

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  GX400A_VIDEO: Nemesis video module
//================================================================================

`default_nettype none
`timescale 1ns/1ps

module GX400A_VIDEO
(
	input               i_MCLK,     // Main clock 48 MHz
	input               i_RESET,    // RESET signal

	input               i_cen6,    // Pixel Clock Enable at  6 MHz
	input               i_cen6b,   // Pixel Clock Enable at  6 MHz
	input               i_clk6,    // Pixel Clock at  6 MHz

	input               i_HFLIP,    // Horizontal Flip
	input               i_VFLIP,    // Vertical Flip
	input               i_INTER_NON, // Interlaced/Non-Interlaced
	input               i_288_256,   // 288 vs. 256 columns

	output              o_HS,       // out          - Horizontal sync (VGA_HS)
	output              o_VS,       // out          - Vertiacl sync (VGA_VS)
	output              o_HBL,      // out          - Horizontal BLANK
	output              o_VBL,      // out          - Vertical BLANK

	output     [10:0]   o_pal_addr,
	
	output              o_1h_n,
	output              o_2h,
	output              o_256v,

	input      [15:1]   i_addr,
	input      [15:0]   i_data_bus_in,
	output reg [15:0]   o_data_bus_out,

	input               i_uds_n,
	input               i_lds_n,
	input               i_RnW,
	input               i_chacs_n,
	input               i_objram_n,
	input               i_vcs1,
	input               i_vcs2,
	input               i_vzcs
);

////////////////////////////////////////////////////////////////////////////////////////////////////

`ifndef NOVIDEO

wire          w_clk_6MHz;

wire          w_VBL_n, w_VBL_xx_n, w_HBL_n, w_HS_n, w_VS_n, w_BLK;

wire          w_256h, w_128h, w_64h, w_32h, w_16h, w_8h, w_4h, w_2h, w_1h, w_1h_n;
wire          w_128h_x, w_64h_x, w_32h_x, w_16h_x, w_8h_x, w_4h_x, w_2h_x, w_1h_x;
wire          vclk, w_256v, w_128v, w_64v, w_32v, w_16v, w_8v, w_4v, w_2v, w_1v;
wire          w_128v_x, w_64v_x, w_32v_x, w_16v_x, w_8v_x, w_4v_x, w_2v_x, w_1v_x;
wire          w_128ha, w_1hf, w_256h_n, w_256h_x;

wire          chacs1, chacs2;

wire [7:0]    scroll_ram_cpu_dout, scroll_ram_gfx_dout,
              objram_cpu_dout, objram_gfx_dout,
              video_ram1_lo_cpu_dout, video_ram1_lo_gfx_dout,
              video_ram1_hi_cpu_dout, video_ram1_hi_gfx_dout,
              video_ram2_cpu_dout, video_ram2_gfx_dout,
              charram_1_lo_cpu_dout, charram_1_lo_gfx_dout,
              charram_1_hi_cpu_dout, charram_1_hi_gfx_dout,
              charram_2_lo_cpu_dout, charram_2_lo_gfx_dout,
              charram_2_hi_cpu_dout, charram_2_hi_gfx_dout;

reg  [10:0]   scrollram_gfx_addr;
wire [10:0]   objram_gfx_addr;
wire [11:0]   vram_gfx_addr;
wire [ 2:0]   tile_va;
wire          tile_shift_a1, tile_shift_a2, tile_shift_b, vhff, vvff;
// Skip two LSBs because there are 4 8-bit RAMs.
wire [15:2]   charram_gfx_addr, vca, oca;
wire [ 3:0]   tile_pr;
wire [ 6:0]   tile_color;

wire          dma_n, orinc, obj_wr, obj_clr, cha_ov, wrtime2,
              xa7, xb7, obj_pixel_latch, oc_latch, obj_xpos_d0, obj_latch_a_d2;
wire [ 7:0]   obj_cntr, obj_buff_a_din, obj_buff_a_dout, obj_buff_b_din, obj_buff_b_dout;
wire [15:0]   obj_buff_a_addr, obj_buff_b_addr;
wire [ 2:0]   ora;

////////////////////////////////////////////////////////////////////////////////////////////////////


wire cen6, cen6b, clk6;
reg  cen6_dly, cen6_dly2;

assign cen6  = i_cen6;
assign cen6b = i_cen6b;
assign clk6  = i_clk6;

always @( posedge i_MCLK ) begin
	cen6_dly  <= cen6;
	cen6_dly2 <= cen6_dly;
end

// TODO: check what delayed clocks are needed
assign w_clk_6MHz = cen6;

///////////////////
// K005292: Video Timings Generator
///////////////////

// k5292 outputs active low HS and VS
assign o_HS = ~w_HS_n;
assign o_VS = ~w_VS_n;

assign o_HBL = w_BLK;
assign o_VBL = ~w_VBL_n;

wire CSYNC_n;

wire orinc_mod;

// ** Dual 4-Input NAND Gate    **
// ** [LS20] @ 16C              **
// ** Quad 2-Input AND Gate     **
// ** [LS08] @ 21H (9, 10 -> 8) **
assign orinc_mod = orinc & ~&obj_cntr[7:4];

// ** Custom Chip Konami Video Timings Generator **
// ** [K0005292] @ 20B                           **
K005292 u_5292(
	.i_MCLK        ( i_MCLK     ),
	.i_CEN6        ( w_clk_6MHz ),
	.i_RST_n       ( ~i_RESET   ),

	.i_VFLP        ( i_VFLIP    ),
	.i_HFLP        ( i_HFLIP    ),
	.i_INTER       ( 1'b0       ),
	.i_288_256     ( 1'b0       ),

	.i_DMA_n       ( dma_n      ),
	.i_ORINC       ( orinc_mod  ),

	.o_VBLANK_xx_n ( w_VBL_xx_n ),
	.o_VBLANK_n    ( w_VBL_n    ),
	.o_HBLANK_n    ( w_HBL_n    ),
	.o_CSYNC_n     ( CSYNC_n    ),
	.o_VSYNC_n     ( w_VS_n     ),

	.o_256H_1H     ( { w_256h,   w_128h,  w_64h,   w_32h,   w_16h,  w_8h,   w_4h,   w_2h,   w_1h } ),
	.o_128H_1H_x   ( { w_128h_x, w_64h_x, w_32h_x, w_16h_x, w_8h_x, w_4h_x, w_2h_x, w_1h_x       } ),
	.o_1H_n        ( w_1h_n     ),

	.o_VCLK        ( vclk       ),
	.o_128V_1V     ( { w_128v,   w_64v,   w_32v,   w_16v,   w_8v,   w_4v,   w_2v,   w_1v         } ),
	.o_128V_1V_x   ( { w_128v_x, w_64v_x, w_32v_x, w_16v_x, w_8v_x, w_4v_x, w_2v_x, w_1v_x       } ),
	.o_256V        ( w_256v     ),

	.o_OBJ_CNTR    ( obj_cntr   )
);

assign o_1h_n = w_1h_n;

`ifdef SIMULATION

// Debugging signals fot GTKWave

wire [8:0] X_POS;
wire [7:0] Y_POS;
	
assign X_POS = { 1'b0, w_128h, w_64h, w_32h, w_16h, w_8h, w_4h, w_2h, w_1h };
assign Y_POS = { w_128v, w_64v, w_32v, w_16v, w_8v, w_4v, w_2v, w_1v };

reg  wait_hbl, frame_start, draw_start;

assign frame_start = X_POS == 9'd0 && Y_POS == 8'd16;

always @( posedge o_VBL )
	wait_hbl <= 1'b1;

always @( posedge w_BLK ) begin
	if( wait_hbl ) begin
		draw_start <= 1'b1;
		wait_hbl <= 1'b0;
	end else begin
		draw_start <= 1'b0;
	end
end

wire        db_vram_vvff       = video_ram1_hi_gfx_dout[3];
wire [10:0] db_vram_char_index = { video_ram1_hi_gfx_dout[2:0], video_ram1_lo_gfx_dout };

`endif

assign o_2h     = w_2h;
assign o_256v   = w_256v;

// ** Hex Inverters **
// ** [LS04] @ 17C  **
assign w_256h_n = ~w_256h;

// ** Quad 2-Input XOR Gate **
// ** [LS86] @ 16A          **
assign w_256h_x = ~w_256h ^ i_HFLIP;

// ** Quad 2-Input AND Gate **
// ** [LS08] @ 17B          **
// ** Quad 2-Input OR Gate  **
// ** [LS32] @ 16B          **
assign w_128ha  = ( w_256h && w_128h ) || (w_256h_n && w_32h );

// TODO: figure out the delay
// Raki has 4HD = /4H
// LS244 says 12ns propagation delay (inverting), that’s 83 MHz
//
// ** Octal Buffer  **
// ** [LS244] @ 25E **
reg w_2hd, w_4hd;

always @( posedge i_MCLK ) begin
	w_2hd <= w_2h;
	w_4hd <= w_4h;
end

// the FF generates a signal which is NOT /1H synced on the pixel clock
// NOT /1H is a bit delayed wrt 1H, therefore 1HF is 1H delayed by one pixel clock
// which is /1H
// 1HF is unused at the moment, but appears in the VRAM write-enable on the actual hardware.
// TODO: Except clk0 is delayed by a capacitor, so we should delay it more.
//
// ** Hex Inverter            **
// ** [LS04] @ 14G (5 -> 6)   **
// ** Dual D Flip-Flop        **
// ** [LS74] @ 17H (top left) **
assign w_1hf = w_1h_n;

wire blank_16h, blank_4h, blank_clk_n;

// ** Dual D Flip-Flop            **
// ** [LS74] @ 19H left           **
// ** Quad 2-Input NAND Gate      **
// ** [LS00] @ 15G (12, 13 -> 11) **
jtframe_ff u_19h_left_ff(
	.rst     ( i_RESET                   ),
	.clk     ( i_MCLK                    ),
	.cen     ( 1'b1                      ),
	.sigedge ( w_16h                     ),
	.set     ( 1'b0                      ),
	.clr     ( 1'b0                      ),
	.din     ( ~&{ w_VBL_xx_n, w_HBL_n } ),
	.q       ( blank_16h                 ),
	.qn      (                           )
);

// ** Dual D Flip-Flop   **
// ** [LS74] @ 19H right **
jtframe_ff u_19h_right_ff(
	.rst     ( i_RESET                   ),
	.clk     ( i_MCLK                    ),
	.cen     ( 1'b1                      ),
	.sigedge ( ~champx                   ),
	.set     ( 1'b0                      ),
	.clr     ( 1'b0                      ),
	.din     ( blank_16h                 ),
	.q       ( obj_wr                    ),
	.qn      ( obj_clr                   )
);

// ** Dual D Flip-Flop **
// ** [LS74] @ 17A top **
jtframe_ff u_17a_top_ff(
	.rst     ( i_RESET ),
	.clk     ( i_MCLK  ),
	.cen     ( 1'b1    ),
	.sigedge ( w_4h    ),
	.set     ( 1'b0    ),
	.clr     ( 1'b0    ),
	.din     ( CSYNC_n ),
	.q       ( w_HS_n  ),
	.qn      (         )
);

// These flip-flops delay HBLANK by 22 pixels and stop HBLANK and HSYNC during VBLANK, which
// apparently does not suit the HDMI output, so we just delay HBLANK by 22 pixels instead.
//
// ** 2 x Dual D Flip-Flop        **
// ** [LS74] @ 20H, 17A bottom    **
// ** Quad 2-Input AND Gate       **
// ** [LS08] @ 21H (12, 13 -> 11) **
jtframe_sh #( .width( 1 ), .stages( 22 ) )
u_blk_dly(
	.clk    ( i_MCLK     ),
	.clk_en ( w_clk_6MHz ),
	.din    ( w_HBL_n    ),
	.drop   ( w_BLK      )
);

///////////////////
// Scroll RAM Address MUXes
///////////////////

// ** 3 x Quad 2-Input Multiplexer **
// ** [LS157] @ 22A, 22B, 22C      **
// ** Hex Inverter                 **
// ** [LS04] @ 22E (3 -> 4)        **
always @(*) begin
	case( { ~vclk } )
		1'b0:   scrollram_gfx_addr <= { 1'b0, w_4hd, w_2h, w_128v_x, w_64v_x, w_32v_x, w_16v_x, w_8v_x, w_4v_x, w_2v_x, w_1v_x };
		1'b1:   scrollram_gfx_addr <= { {4{1'b1}}, w_4hd, w_256h_x, w_128h_x, w_64h_x, w_32h_x, w_16h_x, w_8h_x };
	endcase
end

///////////////////
// K005291: Tile Address Generator
///////////////////

// ** Custom Chip Konami Tile Address Generator **
// ** [K0005291] @ 20D                          **
K005291 u_5291(
	.i_MCLK               ( i_MCLK              ),

	// inputs
	.i_HFLIP              ( i_HFLIP             ),
	.i_VFLIP              ( i_VFLIP             ), 
	.i_VCLK               ( vclk                ),
	.i_HCNTR_BUS          ( { w_64h, w_32h, w_16h, w_8h, w_4h, w_2h, w_1h }         ),
	.i_VCNTR_BUS          ( { w_128v, w_64v, w_32v, w_16v, w_8v, w_4v, w_2v, w_1v } ),
    .i_256H_n             ( ~w_256h             ),
    .i_128HA              ( w_128ha             ),

	.i_CPU_ADDR_BUS       ( i_addr[12:1]        ),
	.i_SCROLL_DATA_BUS    ( scroll_ram_gfx_dout ),

	// outputs
	.o_TILE_LINE_ADDR_BUS ( tile_va             ),
	.o_VRAM_ADDR_BUS      ( vram_gfx_addr       ),
	.o_SHIFT_A1           ( tile_shift_a1       ),
	.o_SHIFT_A2           ( tile_shift_a2       ),
	.o_SHIFT_B            ( tile_shift_b        )
);

wire [10:0] vram1_latched_dout;
wire [ 6:0] vram2_latched_dout;

// ** Hex Inverters           **
// ** [LS04] @ 13F (13 -> 12) **
wire w_2h_n = ~w_2h;

// ** Octal D Flip-Flop With Reset **
// ** [LS273] @ 12B                **
// ** Hex D Flip-Flop              **
// ** [LS174] @ 13C                **
bus_ff #( .W( 12 ) )
u_tile_addr_ff(
	.rst     ( i_RESET         ),
	.clk     ( i_MCLK          ),
	.trig    ( w_2h_n          ),
	.d       ( { video_ram1_hi_gfx_dout[3:0], video_ram1_lo_gfx_dout } ),
	.q       ( { vvff, vram1_latched_dout                            } ),
	.q_n     (                 )
);

assign tile_pr    = video_ram1_hi_gfx_dout[7:4];
assign vhff       = video_ram2_gfx_dout[7];
assign tile_color = video_ram2_gfx_dout[6:0];

// No MUX because we use RAMs with a wide address bus, no need for RAS/CAS.
//
// ** 2 x Quad 2-Input Multiplexer **
// ** [LS157] @ 12A, 13B           **
// ** Quad 2-Input XOR Gate        **
// ** [LS86] @ 16A                 **
assign vca = { vram1_latched_dout, {3{vvff}} ^ tile_va };

// Implement RAS/CAS on CHARRAM with external flip-flop on CAS,
// otherwise the K5294 latches the next tile line before it’s done
// displaying the previous one, and the last pixel of each group
// of 8 is wrong.
//
// Select bewteen vca and oca based on cha_ov (MUX).
//
// ** 2 x Quad 2-Input Multiplexer **
// ** [LS157] @ 11A–B              **
bus_ff #( .W( 14 ) )
u_oca_ras_cas_ff(
	.rst     ( i_RESET        ),
	.clk     ( i_MCLK         ),
	.trig    ( champx2        ), // cas_n = ~CHAMPX delayed -> cas = CHAMPX delayed
	.d       ( { cha_ov ? vca : oca } ),
	.q       ( charram_gfx_addr[15:2] ),
	.q_n     (                )
);

///////////////////
// K005290
///////////////////

wire       tm_a_hflip, tm_b_hflip, aff, bff,
           tm_a_shift_L_n, tm_a_shift_R_n, tm_b_shift_L_n, tm_b_shift_R_n,
           tm_a_px_trans, tm_b_px_trans;
wire [3:0] tm_a_px_data, tm_b_px_data;

// Bit order for A-H is in the opposite direction than charram_X_gfx_dout
wire [0:3] A, B, C, D, E, F, G, H;

assign A[0:3] = charram_1_hi_gfx_dout[7:4];
assign B[0:3] = charram_1_hi_gfx_dout[3:0];
assign C[0:3] = charram_1_lo_gfx_dout[7:4];
assign D[0:3] = charram_1_lo_gfx_dout[3:0];
assign E[0:3] = charram_2_hi_gfx_dout[7:4];
assign F[0:3] = charram_2_hi_gfx_dout[3:0];
assign G[0:3] = charram_2_lo_gfx_dout[7:4];
assign H[0:3] = charram_2_lo_gfx_dout[3:0];

// ** Quad 2-Input XOR Gate **
// ** [LS86] @ 9D           **
assign aff = tm_a_hflip ^ i_HFLIP; // output 6
assign bff = tm_b_hflip ^ i_HFLIP; // output 8

reg asl, asr, bsl, bsr;

// I don’t remember why it’s synchronous

// ** Hex Inverters        **
// ** [LS04] @ 10C         **
// ** Quad 2-Input OR Gate **
// ** [LS32] @ 9E          **
always @( posedge i_MCLK ) begin
	asl <= |{  aff, ~tile_shift_a1 }; // output 3
	asr <= |{ ~aff, ~tile_shift_a1 }; // output 11
	bsl <= |{  bff, ~tile_shift_b };  // output 6
	bsr <= |{ ~bff, ~tile_shift_b };  // output 8
end

assign tm_a_shift_L_n = asl; // output 3
assign tm_a_shift_R_n = asr; // output 11
assign tm_b_shift_L_n = bsl; // output 6
assign tm_b_shift_R_n = bsr; // output 8

// ** Custom chip Konami Tile Shifter **
// ** [K0005290] @ 7D                 **
K005290 u_5290
(
	.i_MCLK          ( i_MCLK                     ),  // Main clock 48 MHz
	.i_RST           ( i_RESET                    ),  // RESET signal on pos edge
	.i_CLK_px6       ( w_clk_6MHz                 ),  // clock Pixel 6MHz
	.i_AFF           ( aff                        ),  // Tile A Flip
	.i_BFF           ( bff                        ),  // Tile B Flip
	.i_9E_pin3       ( tm_a_shift_L_n             ),  // Tile A shift left  if 0
	.i_9E_pin11      ( tm_a_shift_R_n             ),  // Tile A shift right if 0
	.i_9E_pin6       ( tm_b_shift_L_n             ),  // Tile B shift left  if 0
	.i_9E_pin8       ( tm_b_shift_R_n             ),  // Tile B shift right if 0
	.i_A             ( A[0:3]                     ),  // Input 4bit data from char ram
	.i_B             ( B[0:3]                     ),  // Input 4bit data from char ram
	.i_C             ( C[0:3]                     ),  // Input 4bit data from char ram
	.i_D             ( D[0:3]                     ),  // Input 4bit data from char ram
	.i_E             ( E[0:3]                     ),  // Input 4bit data from char ram
	.i_F             ( F[0:3]                     ),  // Input 4bit data from char ram
	.i_G             ( G[0:3]                     ),  // Input 4bit data from char ram
	.i_H             ( H[0:3]                     ),  // Input 4bit data from char ram
	.i_2HD           ( w_2hd                      ),  // Horizontal Pixel (counter bus)
	.i_4HD_n         ( ~w_4hd                     ),  // Horizontal Pixel (counter bus)
	.o_TM_A_px_trans ( tm_a_px_trans              ),  // output pixel data
	.o_TM_A_pixels   ( tm_a_px_data               ),  // output pixel data
	.o_TM_B_px_trans ( tm_b_px_trans              ),  // output pixel data
	.o_TM_B_pixels   ( tm_b_px_data               )   // output pixel data
);

///////////////////
// K005293
///////////////////

wire  w_4hd_n, w_4hd_clkd, w_2hd_clkd, shift_a1_clkd, shift_a2_clkd, shift_b_clkd;

// ** Hex Inverters               **
// ** [LS04] @ 10C (11 -> 10)     **
// ** Quad 2-Input NAND Gate      **
// ** [LS00] @ 10D (12, 13 -> 11) **
assign w_4hd_clkd    = ~&{ ~w_4hd, w_2hd };
// ** Quad 2-Input NAND Gate      **
// ** [LS00] @ 10D (1, 2 -> 3)    **
assign w_2hd_clkd    = ~&{  w_4hd, w_2hd };
// ** Quad 2-Input OR Gate        **
// ** [LS32] @ 11C                **
assign shift_a1_clkd = |{ tile_shift_a1, clk6 }; // output 3
assign shift_a2_clkd = |{ tile_shift_a2, clk6 }; // output 11
assign shift_b_clkd  = |{ tile_shift_b,  clk6 }; // output 8

wire [15:0] obj_px_data = { obj_buff_b_dout_dly, obj_buff_a_dout_dly };

// ** Custom Chip Konami Priority Processor **
// ** [K0005293] @ 11D                      **
K005293 u_5293(
	.i_RST            ( i_RESET                     ),
	.i_CLK            ( i_MCLK                      ), // Pin 23
	.i_CEN6           ( w_clk_6MHz                  ), // |
	.i_SHIFT_A1_CLKD  ( shift_a1_clkd               ), // Pin 18
	.i_SHIFT_A2_CLKD  ( shift_a2_clkd               ), // Pin 17
	.i_SHIFT_B_CLKD   ( shift_b_clkd                ), // Pin 19
	.i_2HD_CLKD       ( w_2hd_clkd                  ), // Pin 21
	.i_4HD_CLKD       ( w_4hd_clkd                  ), // Pin 20
	.o_TM_A_HFLIP     ( tm_a_hflip                  ), // Pin 36
	.o_TM_B_HFLIP     ( tm_b_hflip                  ), // Pin 37
	.i_TM_A_PX_DATA   ( tm_a_px_data                ), // Pins 3–10, 15–16
	.i_TM_A_PX_TRANS  ( tm_a_px_trans               ), // |
	.i_TM_B_PX_DATA   ( tm_b_px_data                ), // |
	.i_TM_B_PX_TRANS  ( tm_b_px_trans               ), // |
	.i_HFLIP          ( i_HFLIP                     ), // Pin 56
	.i_TILE_PRIORITY  ( tile_pr                     ), // PR, Pins 11–14
	.i_VHFF           ( vhff                        ), // Pin 57
	.i_VRAM2_DATA     ( tile_color                  ), // VC
	.i_OBJ_PX_DATA    ( obj_px_data                 ), // DQ
	.o_COLOR_RAM_ADDR ( o_pal_addr                  ), // CD
	.i_1H_n           ( w_1h_n                      )  // Pin 22
);

///////////////////
// OBJRAM Peripherals
///////////////////

wire [ 7:0] obj_pri, obj_table_din, obj_table_dout;
wire [10:0] obj_table_addr;
wire        obj_table_we_n, obj_buf_wr, obj_buf_ras;

// ** 3 x Quad 2-Input Multiplexer **
// ** [LS157] @ 25A–C              **
assign objram_gfx_addr = { w_8v, w_4v, w_2v, w_1v, w_128h, w_64h, w_32h, w_16h, w_8h, w_4h, w_2hd };

/*
	Timing Diagram 1 (Raki)

    CLK18M  _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|
    CLK9M   ¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|¯¯¯|___|
    CLK6M   ¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯|___|
            ---(511)---|----(0)----|----(1)----|----(2)----|
    
    TIME1   ___________________|¯¯¯|___________________|¯¯¯|
    TIME2   ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|
    CHAMPX  ¯¯¯¯¯¯¯¯¯¯¯|_______|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_______|¯¯¯¯
    VRTIME  ¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯
    OBJCLRWE¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯
    
    BUFWE   ¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|___|¯¯¯¯¯¯¯¯¯¯¯¯
    BUFRAS  ___________|¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯|____
    dl-ras  ____________|¯¯¯¯¯¯¯|_______________|¯¯¯¯¯¯¯|___
*/

/*
Timing Diagram 2 (Olivier)

{signal: [
  {name: 'clk18',      wave: 'p............................................'},
  {name: 'clk6',       wave: '01.01.01.01.01.01.01.01.01.01.01.01.01.01.01.'},
  {},
  {name: '1hf',        wave: '01..0..1..0..1..0..1..0..1..0..1..0..1..0..1.'},
  {name: '1hf1',       wave: '0.1..0..1..0..1..0..1..0..1..0..1..0..1..0..1'},
  {name: '1hf2',       wave: '0..1..0..1..0..1..0..1..0..1..0..1..0..1..0..'},
  {name: '1hf3',       wave: '10..1..0..1..0..1..0..1..0..1..0..1..0..1..0.'},
  {},
  {name: 'champx',     wave: '10.1...0.1...0.1...0.1...0.1...0.1...0.1...0.'},
  {name: 'obj_clr_we', wave: '01....01....01....01....01....01....01....01.'},
]}
*/

// Build champx according to timing diagrams, to avoid the need for
// the 18 MHz clock, that has too much jitter when generated from
// the 48 MHz master clock.
//
// ** 8-Bit POSI Shift Register  **
// ** [LS164] @ 15H              **
// ** Quad 2-Input OR Gate       **
// ** [LS32] @ 14H (12,13 -> 11) **
wire champx = ~clk6 | w_1h;

wire champx2;

// ** Hex Schmitt-Trigger Inverter      **
// ** [LS14] @ 10E (13 -> 12, 11 -> 10) **
jtframe_sh #( .width( 1 ), .stages( 3 ) )
u_champx2_dly(
	.clk    ( i_MCLK  ),
	.clk_en ( 1'b1    ),
	.din    ( champx  ),
	.drop   ( champx2 )
);

// WRTIME2 Delay

reg  wrtime2_d1, wrtime2_d1_5, wrtime2_d2, clk6_d1, clk6_d2;

wire wrtime2_delay_cen, wrtime2_buf_we_or;

always @( posedge i_MCLK ) begin
	clk6_d1 <= clk6;
	clk6_d2 <= clk6_d1;
end

// seems correct here for wrtime2_buf_we_n, which is the low part of clk6
// on the cycle after wetime2_buf_ras_n
// clk6:              --_--_--_--_--_--_--_--_--_--_--_--_
// wrtime2_buf_ras_n: ______--____--____--____--__________
// wrtime2_buf_we_n:  ___________-_____-_____-_____-______
assign wrtime2_delay_cen = cen6_dly2;
assign wrtime2_buf_we_or = clk6_d2;

// ** Dual D flip-flop              **
// ** [LS74] @ 18H left, 17H bottom **
always @( posedge i_MCLK ) if( wrtime2_delay_cen ) begin
	wrtime2_d1 <= wrtime2;
	wrtime2_d2 <= wrtime2_d1;
end

// ** Dual D Flip-Flop   **
// ** [LS74] @ 18H right **
always @( posedge i_MCLK ) if( cen6b ) begin
	wrtime2_d1_5 <= wrtime2_d1;
end

// wrtime2_buf_ras_n

wire wrtime2_buf_ras_n;

// This one seems fine: it’s synchronised with positive or negative edges of 2H, like in Raki’s core
// could be longer: takes 2/3 of wrtime2 in Raki’s core, and 1/2 here with a duration of 4 mclk
// could be like the active part of clk6, so 5 mclk, like in Raki’s core
// tried active part of clk6, it’s really, really bad
//
// ** Quad 2-Input AND Gate    **
// ** [LS08] @ 21H (1, 2 -> 3) **
os_pulse_gen #( .DELAY( 0 ), .DURATION( 4 ) )
wrtime2_buf_ras_n_gen
(
	.clk     ( i_MCLK            ),
	.trig    ( ~wrtime2          ),
	.trig_en ( 1'b1              ),
	.pulse   ( wrtime2_buf_ras_n )
);

// ** Quad 2-Input Multiplexer **
// ** [LS157] @ 13H            **
wire  obj_buf_ras_n = obj_wr ? wrtime2_buf_ras_n : ~champx;

// TODO: check = or <=

// Delay because of capacitor.
//
// ** Capacitor             **
// ** [470 pF]              **
// ** Hex Inverter          **
// ** [LS04] @ 13F (3 -> 4) **
always @( posedge i_MCLK ) begin
	obj_hl = ~obj_buf_ras_n;
end

wire obj_clr_we, wrtime2_buf_we_n;
wire obj_clr_we_pulse;

// Build obj_clr_we according to timing diagrams, by looking at the effect
// of shift register 15H on 1HF.
// I would have thought it would be clk6 | w_1h_n, but it doesn’t work

// ** Quad 2-Input OR Gate **
// ** [LS32] @ 14H         **
os_pulse_gen #( .DELAY( 0 ), .DURATION( 2 ) )
obj_clr_we_gen
(
	.clk     ( i_MCLK            ),
	.trig    ( cen6              ),
	.trig_en ( w_1h              ),
	.pulse   ( obj_clr_we_pulse  )
);

assign obj_clr_we = ~obj_clr_we_pulse;

// ** Quad 2-Input OR Gate      **
// ** [LS32] @ 14H (9, 10 -> 8) **
assign wrtime2_buf_we_n = ~wrtime2_d2 | wrtime2_buf_we_or;

// wrtime2_buf_we_n | ~cen6_dly2 simulates a clock-enable but only during obj_wr
// it reduces wrtime2_buf_we_n to a duration one i_MCLK cycle on its rising edge
// to avoid multiple writes while it is asserted
//
// ** Quad 2-Input Multiplexer **
// ** [LS157] @ 13H            **
assign obj_buf_wr = obj_wr ? wrtime2_buf_we_n | ~cen6_dly2 : obj_clr_we;

// ** Hex Inverter           **
// ** [LS04] @ 17C           **
// ** Dual 4-Input NAND Gate **
// ** [LS20] @ 16C           **
assign dma_n = ~&{ w_128v, w_64v, w_32v, ~w_16v };

// ** Triple 3-Input NOR Gate **
// ** [LS27] @ 22F            **
// ** Hex Inverter            **
// ** [LS04] @ 22E            **
wire u19g_clk = |{ w_8h, w_4h, w_2h };

// ** Octal D Flip-Flop With Clear **
// ** [LS374] @ 19G                **
bus_ff #( .W( 8 ) )
u_obj_pri_ff(
	.rst     ( i_RESET                   ),
	.clk     ( i_MCLK                    ),
	.trig    ( u19g_clk                  ),
	.d       ( objram_gfx_dout           ),
	.q       ( obj_pri                   ),
	.q_n     (                           )
);

// ** 3 x Quad 2-Input Multiplexer **
// ** [LS157] @ 16F, 17F, 19F      **
assign obj_table_addr = dma_n
	? { obj_cntr, ora }
	: { obj_pri, w_8h, w_4h, w_2hd };

// ** Hex inverters          **
// ** [LS04] @ 14G           **
// ** Quad 2-Input NAND Gate **
// ** [LS00] @ 15G           **
assign obj_table_we_n = |{ dma_n, w_1h_n };

// ** Octal D flip-flop **
// ** [LS374] @ 17G     **
bus_ff #( .W( 8 ) )
u_obj_din_ff(
	.rst     ( i_RESET                   ),
	.clk     ( i_MCLK                    ),
	.trig    ( w_1h_n                    ),
	.d       ( objram_gfx_dout           ),
	.q       ( obj_table_din             ),
	.q_n     (                           )
);

// ** 2k x 8bit Static RAM **
// ** [2128] @ 16G         **
jtframe_ram #(
	.AW(11),
	.DW(8)
)
u_obj_table(
	.clk     ( i_MCLK          ),
	.cen     ( 1'b1            ),
	.addr    ( obj_table_addr  ),
	.data    ( obj_table_din   ),
	.we      ( ~obj_table_we_n ),
	.q       ( obj_table_dout  )
);

///////////////////
// K5295
///////////////////

wire        obj_px_blank_n, obj_buff_cas;
reg         obj_hl;
wire [ 2:0] obj_pix_sel;

// ** Custom chip Konami Sprite Drawer **
// ** [K0005295] @ 11G                 **
K005295 u_5295
(
	.i_EMU_MCLK             ( i_MCLK          ), // Main clock 48 MHz
	// clock 0 input but has a delay on the circuit with a capacitor to gnd
	// chosen empirically as cen6 with a delay by 2*i_MCLK because it syncs nicely with 1H/2H/4H.
	.i_EMU_CLK6MPCEN_n      ( ~cen6           ),

	.i_FLIP                 ( i_HFLIP         ), //
	.i_ABS_1H               ( w_1h            ), //
	.i_ABS_2H               ( w_2h            ), //
	.i_ABS_4H               ( w_4h            ), //
	.i_HBLANK_n             ( w_HBL_n         ), //
	.i_VBLANK_n             ( w_VBL_n         ), //
	.i_VBLANKH_n            ( w_VBL_xx_n      ), //
	.i_DMA_n                ( dma_n           ), //
	.i_OBJHL                ( obj_hl          ), // wired to o_CAS
	.i_OBJWR                ( obj_wr          ), //
	.i_CHAMPX               (                 ), // Input CHAMPX, unused as we have wide address RAMs

	.i_OBJDATA              ( obj_table_dout  ), // Input 8bit Object RAM Data Bus

	.o_ORINC                ( orinc           ), // output Object Tick counter (ORINC)
	.o_ORA                  ( ora             ), // output Object Read Address ?
	.o_WRTIME2              ( wrtime2         ), // output Write Time 2
	.o_XA7                  ( xa7             ), // output X address 7
	.o_XB7                  ( xb7             ), // output X address 7
	.o_PIXELSEL             ( obj_pix_sel     ), // output Horizontal Tile Pixel Select
	.o_CHAOV                ( cha_ov          ), // output Character Object/Video (not CHA O/A on 11B!!)
	.o_FA                   ( obj_buff_a_addr ), // output pixel address evenbuff
	.o_FB                   ( obj_buff_b_addr ), // output pixel address oddbuff
	.o_OCA                  ( oca             ), // output Object Code Bus A
	.o_COLORLATCH_n         ( oc_latch        ), // output Latch to 5294
	.o_XPOS_D0              ( obj_xpos_d0     ), // OBJ_XPOS_D0 to 5294
	.o_LATCH_A_D2           ( obj_latch_a_d2  ), // SIZELATCH_UNKNOWN_D2 to 5294
	.o_CAS                  ( obj_buff_cas    ), // object buffer CAS
	.o_PIXELLATCH_WAIT_n    ( obj_px_blank_n  )  // to k5294 LS175
);

///////////////////
// K5294
///////////////////

wire [7:0] k5294_da, k5294_db;

// ** Quad 2-Input AND Gate **
// ** [LS08] @ 17B          **
// ** Hex Inverter          **
// ** [LS04] @ 17C          **
// ** Quad 2-Input OR Gate  **
// ** [LS32] @ 16B          **
assign obj_pixel_latch = clk6 | ~&{ w_1h, w_2h };

// TODO: jtframe_sh
//
// Delay obj_pixel_latch, otherwise K5292 latches object pixels
// too early when OCA  changes, causing a vertical line in sprites.
// Probably justified by the fact that on the schematics, K5295 operates
// with a delayed clock (CLK0 with a capacitor.)
reg obj_pixel_latch_dly_1, obj_pixel_latch_dly;

always @( posedge i_MCLK ) begin
	obj_pixel_latch_dly_1 <= obj_pixel_latch;
	obj_pixel_latch_dly   <= obj_pixel_latch_dly_1;
end

// ** Custom chip Konami Sprite Pixel Latch **
// ** [K0005294] @ 3E                       **
K005294 u_5294
(
	.i_EMU_MCLK           ( i_MCLK             ), // Main clock 48 MHz
	.i_EMU_CLK6MPCEN_n    ( ~cen6          ), // clock enable 6MHz

	.i_GFXDATA            ( { A[0:3], B[0:3], C[0:3], D[0:3], E[0:3], F[0:3], G[0:3], H[0:3] } ),
	.i_WRTIME2            (wrtime2             ),
	.i_COLORLATCH_n       (oc_latch            ),
	.i_XPOS_D0            (obj_xpos_d0         ),
	.i_PIXELLATCH_WAIT_n  (obj_px_blank_n  ),
	.i_LATCH_A_D2         (obj_latch_a_d2      ),
	.i_PIXELSEL           (obj_pix_sel         ),

	.i_OC                 (obj_table_dout[4:1] ),

	.i_TILELINELATCH_n    (obj_pixel_latch_dly ),
	
	.o_DA                 ( k5294_da           ), // output pixel data evenbuff
	.o_DB                 ( k5294_db           )  // output pixel data oddbuff
);

wire k5294_da_trans, k5294_db_trans, obj_buff_a_s, obj_buff_b_s;

// Note: XA7 and XB7 are swapped in the Konami schematic. It’s obvious, because XA7 goes to the
// object buffer that takes FB as its address, and XB7 to the one that takes FA. The mistake is
// corrected in the K5295, so we must correct it here too. Therefore, obj_buff_a_s takes xa7,
// instead of xb7 like on the schematic.
//
// ** Quad 2-Input NOR Gate  **
// ** [LS02] @ 3F            **
// ** Quad 2-Input NAND Gate **
// ** [LS00] @ 4F            **
assign k5294_da_trans = ~|k5294_da[3:0];
assign obj_buff_a_s   = xa7 | k5294_da_trans;
assign k5294_db_trans = ~|k5294_db[3:0];
assign obj_buff_b_s   = xb7 | k5294_db_trans;

// ** 2 x Quad 2-Input Multiplexer **
// ** [LS157] @ 5F, 6F             **
assign obj_buff_a_din = obj_clr ? 8'h0 : ( obj_buff_a_s ? obj_buff_a_dout_dly : k5294_da ); 

// ** 2 x Quad 2-Input Multiplexer **
// ** [LS157] @ 1F, 2F             **
assign obj_buff_b_din = obj_clr ? 8'h0 : ( obj_buff_b_s ? obj_buff_b_dout_dly : k5294_db ); 

wire [15:0] obj_buff_a_addr_cas_ed, obj_buff_b_addr_cas_ed;

// Implement RAS/CAS on object buffers with external flip-flop on CAS.

bus_ff #( .W( 32 ) )
u_obj_buffer_ras_cas_ff(
	.rst     ( i_RESET        ),
	.clk     ( i_MCLK         ),
	.trig    ( obj_buff_cas   ),
	.d       ( { obj_buff_a_addr,        obj_buff_b_addr        } ),
	.q       ( { obj_buff_a_addr_cas_ed, obj_buff_b_addr_cas_ed } ),
	.q_n     (                )
);

// ** 8 x 64k x 1bit Dynamic RAM              **
// ** [4164] @ 2A, 2B, 6A, 6B, 4A, 4B, 7A, 7B **
// evenbuff
jtframe_ram #(
	.DW(  8 ),
	.AW( 16 )
)
obj_buffer_a(
	.clk  ( i_MCLK                 ),
	.cen  ( 1'b1                   ),
	.data ( obj_buff_a_din         ),
	.addr ( obj_buff_a_addr_cas_ed ),
	.we   ( ~obj_buf_wr            ),
	.q    ( obj_buff_a_dout        )
);

// ** 8 x 64k x 1bit Dynamic RAM **
// ** [4164] @ 1H–8H             **
// oddbuff
jtframe_ram #(
	.DW(  8 ),
	.AW( 16 )
)
obj_buffer_b(
	.clk  ( i_MCLK                 ),
	.cen  ( 1'b1                   ),
	.data ( obj_buff_b_din         ),
	.addr ( obj_buff_b_addr_cas_ed ),
	.we   ( ~obj_buf_wr            ),
	.q    ( obj_buff_b_dout        )
);

reg  [7:0] obj_buff_a_dout_dly_1, obj_buff_b_dout_dly_1, obj_buff_a_dout_dly, obj_buff_b_dout_dly;

// RAM access time, otherwise it changes before the right value being latched
always @( posedge i_MCLK ) begin
	{ obj_buff_a_dout_dly_1, obj_buff_b_dout_dly_1 } <= { obj_buff_a_dout,       obj_buff_b_dout       };
	{ obj_buff_a_dout_dly,   obj_buff_b_dout_dly   } <= { obj_buff_a_dout_dly_1, obj_buff_b_dout_dly_1 };
end

///////////////////
// CPU Data Bus Input
///////////////////

always @(*) begin
	case( 1'b0 )
		i_vzcs:     o_data_bus_out <= { 8'h00, scroll_ram_cpu_dout };
		i_objram_n: o_data_bus_out <= { 8'h00, objram_cpu_dout };
		i_vcs1:     o_data_bus_out <= { video_ram1_hi_cpu_dout, video_ram1_lo_cpu_dout };
		i_vcs2:     o_data_bus_out <= { 8'h00, video_ram2_cpu_dout };
		chacs1:     o_data_bus_out <= { charram_1_hi_cpu_dout, charram_1_lo_cpu_dout };
		chacs2:     o_data_bus_out <= { charram_2_hi_cpu_dout, charram_2_lo_cpu_dout };
		default:    o_data_bus_out <= 16'hffff;
	endcase
end

///////////////////
// SCROLL RAM
///////////////////

// 2048 bytes, 0x000–0x7FF
// 0x000–0x0FF (256 bytes): low byte of X scroll, one per line, tilemap A
// 0x100–0x1FF (256 bytes): high bit of X scroll, one per line, tilemap A
// 0x200–0x2FF (256 bytes): low byte of X scroll, one per line, tilemap B
// 0x300–0x3FF (256 bytes): high bit of X scroll, one per line, tilemap B
// 0x400–0x500 ( 64 bytes): byte of Y scroll, one per column of tiles, tilemap ?
// 0x600–0x700 ( 64 bytes): byte of Y scroll, one per column of tiles, tilemap ?

// MUXes replaced by dual-port RAM
//
// ** 3 x Quad 2-Input Multiplexer **
// ** [LS157] @ 23A, 23B, 23C      **
// ** 2k x 8bit Static RAM **
// ** [2128] @ 22D         **
`ifdef SIM_DEMO_SCROLL
fake_scroll_ram  #(
	.AW(11),
	.DW(8),
	.SIMHEXFILE("scrollram.hex")
)
u_scroll_ram(
	.frame   ( mist_test.frame_cnt - 32'd1    ),
`else
jtframe_dual_ram #(
	.AW(11),
	.DW(8),
	.SIMHEXFILE("scrollram.hex")
)
u_scroll_ram(
`endif
	.clk0    ( i_MCLK                         ),
	.addr0   ( i_addr[11:1]                   ),
	.data0   ( i_data_bus_in[ 7:0]            ),
	.we0     ( &{ ~i_vzcs, ~i_RnW, ~i_lds_n } ),
	.q0      ( scroll_ram_cpu_dout            ),

	.clk1    ( i_MCLK                         ),
	.addr1   ( scrollram_gfx_addr             ),
	.data1   (                                ),
	.we1     ( 1'b0                           ),
	.q1      ( scroll_ram_gfx_dout            )
);

///////////////////
// OBJRAM
///////////////////

// ** 2k x 8bit Static RAM **
// ** [2128] @ 25D         **
jtframe_dual_ram #(
	.AW(11),
	.DW(8),
	.SIMHEXFILE("objram.hex")
)
u_objram(
	.clk0    ( i_MCLK                             ),
	.addr0   ( i_addr[11:1]                       ),
	.data0   ( i_data_bus_in[ 7:0]                ),
	.we0     ( &{ ~i_objram_n, ~i_RnW, ~i_lds_n } ),
	.q0      ( objram_cpu_dout                    ),

	.clk1    ( i_MCLK                             ),
	.addr1   ( objram_gfx_addr                    ),
	.data1   (                                    ),
	.we1     ( 1'b0                               ),
	.q1      ( objram_gfx_dout                    )
);

///////////////////
// VIDEO RAM 1
///////////////////

// TODO: dependency on VRTIME

// ** 4k x 8bit Static RAM      **
// ** [TC-5533P-A] @ 15B        **
// ** Quad 2-Input OR Gate      **
// ** [LS32] @ 13E (9, 10 -> 8) **
// ** Quad 2-Input OR Gate      **
// ** [LS32] @ 16B (1, 2 -> 3)  **
jtframe_dual_ram #(
	.AW(12),
	.DW(8),
	.SIMHEXFILE("vram1_lo.hex")
)
u_video_ram1_lo(
	.clk0   ( i_MCLK                         ),
	.addr0  ( i_addr[12:1]                   ),
	.data0  ( i_data_bus_in[ 7:0]            ),
	.we0    ( &{ ~i_vcs1, ~i_RnW, ~i_lds_n } ), // TODO: dependency on 1HF and /2H
	.q0     ( video_ram1_lo_cpu_dout         ),

	.clk1   ( i_MCLK                         ),
	.addr1  ( vram_gfx_addr                  ),
	.data1  (                                ),
	.we1    ( 1'b0                           ),
	.q1     ( video_ram1_lo_gfx_dout         )
);

// TODO: dependency on VRTIME

// ** 4k x 8bit Static RAM      **
// ** [TC-5533P-A] @ 15C        **
// ** Quad 2-Input OR Gate      **
// ** [LS32] @ 15F (9, 10 -> 8) **
// ** Quad 2-Input OR Gate      **
// ** [LS32] @ 15F (1, 2 -> 3)  **
jtframe_dual_ram #(
	.AW(12),
	.DW(8),
	.SIMHEXFILE("vram1_hi.hex")
)
u_video_ram1_hi(
	.clk0   ( i_MCLK                         ),
	.addr0  ( i_addr[12:1]                   ),
	.data0  ( i_data_bus_in[15:8]            ),
	.we0    ( &{ ~i_vcs1, ~i_RnW, ~i_uds_n } ), // TODO: dependency on 1HF and /2H
	.q0     ( video_ram1_hi_cpu_dout         ),

	.clk1   ( i_MCLK                         ),
	.addr1  ( vram_gfx_addr                  ),
	.data1  (                                ),
	.we1    ( 1'b0                           ),
	.q1     ( video_ram1_hi_gfx_dout         )
);

///////////////////
// VIDEO RAM 2
///////////////////

// TODO: dependency on VRTIME

// ** 4k x 8bit Static RAM      **
// ** [TC-5533P-A] @ 15D        **
// ** Quad 2-Input OR Gate      **
// ** [LS32] @ 15E (9, 10 -> 8) **
// ** Quad 2-Input OR Gate      **
// ** [LS32] @ 15E (1, 2 -> 3)  **
jtframe_dual_ram #(
	.AW(12),
	.DW(8),
	.SIMHEXFILE("vram2.hex")
)
u_video_ram2(
	.clk0   ( i_MCLK                         ),
	.addr0  ( i_addr[12:1]                   ),
	.data0  ( i_data_bus_in[ 7:0]            ),
	.we0    ( &{ ~i_vcs2, ~i_RnW, ~i_lds_n } ), // TODO: dependency on 1HF and /2H
	.q0     ( video_ram2_cpu_dout            ),

	.clk1   ( i_MCLK                         ),
	.addr1  ( vram_gfx_addr                  ),
	.data1  (                                ),
	.we1    ( 1'b0                           ),
	.q1     ( video_ram2_gfx_dout            )
);

///////////////////
// CHAR RAM
///////////////////


// TODO: add 2HD

// ** Quad 2-Input OR Gate     **
// ** [LS32] @ 23F (4, 5 -> 6) **
assign chacs1    = |{  i_addr[1], i_chacs_n };

// ** Hex Inverter             **
// ** [LS04] @ 22E             **
// ** Quad 2-Input OR Gate     **
// ** [LS32] @ 23F (1, 2 -> 3) **
assign chacs2    = |{ ~i_addr[1], i_chacs_n };

// MUXes 16D, 16E, 17D, 17E, 10A, 10B used for DRAM refreshing,
// not needed. 

// ** 2 x 16k x 4bit Dynamic NMOS RAM **
// ** [4416] @ 2A, 2B                 **
// ** Quad 2-Input OR Gate            **
// ** [LS32] @ 13E (1, 2 -> 3)        **
// ** Quad 2-Input OR Gate            **
// ** [LS32] @ 11F (1, 2 -> 3)        **
jtframe_dual_ram #(
	.AW(14),
	.DW(8),
	.SIMHEXFILE("charram1_lo.hex")
)
u_charram_1_lo(
	.clk0   ( i_MCLK                         ),
	.addr0  ( i_addr[15:2]                   ),
	.data0  ( i_data_bus_in[ 7:0]            ),
	.we0    ( &{ ~chacs1, ~i_RnW, ~i_lds_n } ), // &{ ~chacs1, ~i_RnW, ~cha_lds_n }
	.q0     ( charram_1_lo_cpu_dout          ),

	.clk1   ( i_MCLK                         ),
	.addr1  ( charram_gfx_addr[15:2]         ),
	.data1  (                                ),
	.we1    ( 1'b0                           ),
	.q1     ( charram_1_lo_gfx_dout          )
);

// ** 2 x 16k x 4bit Dynamic NMOS RAM **
// ** [4416] @ 6A, 6B                 **
// ** Quad 2-Input OR Gate            **
// ** [LS32] @ 13E (1, 2 -> 3)        **
// ** Quad 2-Input OR Gate            **
// ** [LS32] @ 11F (12, 13 -> 11)     **
jtframe_dual_ram #(
	.AW(14),
	.DW(8),
	.SIMHEXFILE("charram1_hi.hex")
)
u_charram_1_hi(
	.clk0   ( i_MCLK                         ),
	.addr0  ( i_addr[15:2]                   ),
	.data0  ( i_data_bus_in[15:8]            ),
	.we0    ( &{ ~chacs1, ~i_RnW, ~i_uds_n } ), // &{ ~chacs1, ~i_RnW, ~cha_uds_n }
	.q0     ( charram_1_hi_cpu_dout          ),

	.clk1   ( i_MCLK                         ),
	.addr1  ( charram_gfx_addr[15:2]         ),
	.data1  (                                ),
	.we1    ( 1'b0                           ),
	.q1     ( charram_1_hi_gfx_dout          )
);

// ** 2 x 16k x 4bit Dynamic NMOS RAM **
// ** [4416] @ 4A, 4B                 **
// ** Quad 2-Input OR Gate            **
// ** [LS32] @ 13E (12, 13 -> 11)     **
// ** Quad 2-Input OR Gate            **
// ** [LS32] @ 11F (4, 5 -> 6)        **
jtframe_dual_ram #(
	.AW(14),
	.DW(8),
	.SIMHEXFILE("charram2_lo.hex")
)
u_charram_2_lo(
	.clk0   ( i_MCLK                         ),
	.addr0  ( i_addr[15:2]                   ),
	.data0  ( i_data_bus_in[ 7:0]            ),
	.we0    ( &{ ~chacs2, ~i_RnW, ~i_lds_n } ),
	.q0     ( charram_2_lo_cpu_dout          ),

	.clk1   ( i_MCLK                         ),
	.addr1  ( charram_gfx_addr[15:2]         ),
	.data1  (                                ),
	.we1    ( 1'b0                           ),
	.q1     ( charram_2_lo_gfx_dout          )
);

// ** 2 x 16k x 4bit Dynamic NMOS RAM **
// ** [4416] @ 7A, 7B                 **
// ** Quad 2-Input OR Gate            **
// ** [LS32] @ 13E (12, 13 -> 11)     **
// ** Quad 2-Input OR Gate            **
// ** [LS32] @ 11F (9, 10 -> 8)       **
jtframe_dual_ram #(
	.AW(14),
	.DW(8),
	.SIMHEXFILE("charram2_hi.hex")
)
u_charram_2_hi(
	.clk0   ( i_MCLK                         ),
	.addr0  ( i_addr[15:2]                   ),
	.data0  ( i_data_bus_in[15:8]            ),
	.we0    ( &{ ~chacs2, ~i_RnW, ~i_uds_n } ),
	.q0     ( charram_2_hi_cpu_dout          ),

	.clk1   ( i_MCLK                         ),
	.addr1  ( charram_gfx_addr[15:2]         ),
	.data1  (                                ),
	.we1    ( 1'b0                           ),
	.q1     ( charram_2_hi_gfx_dout          )
);

`endif

endmodule
