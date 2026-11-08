/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2026.
// SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
// JTCORES project edits: 2026-11-08.

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  jtnemsis_gx400a_video: Nemesis video module
//================================================================================

`default_nettype none
`timescale 1ns/1ps

module jtnemsis_gx400a_video
(
	input               rst,
	input               clk,
	input               pxl_cen,
	input               pxl_cenb,
	input               clk6,

	input               hflip,
	input               vflip,
	input               inter_non,
	input               resolution_288_256,

	output              HS,
	output              VS,
	output              preLHBL,
	output              vblank,
	output     [10:0]   pal_addr,
	output     [ 1:0]   color_source,
	output              h1_n,
	output              h2,
	output              v256,

	input      [15:1]   cpu_addr,
	input      [15:0]   cpu_din,
	output     [15:0]   cpu_dout,
	input               uds_n,
	input               lds_n,
	input               rnw,
	input               chacs_n,
	input               objram_n,
	input               vcs1,
	input               vcs2,
	input               vzcs,

	output     [10:0]   scroll_cpu_addr,
	output     [ 7:0]   scroll_cpu_din,
	output              scroll_cpu_we,
	input      [ 7:0]   scroll_cpu_dout,
	output reg [10:0]   scroll_gfx_addr,
	input      [ 7:0]   scroll_gfx_dout,

	output     [10:0]   obj_cpu_addr,
	output     [ 7:0]   obj_cpu_din,
	output              obj_cpu_we,
	input      [ 7:0]   obj_cpu_dout,
	output     [10:0]   obj_gfx_addr,
	input      [ 7:0]   obj_gfx_dout,

	output     [12:1]   vram1_cpu_addr,
	output     [15:0]   vram1_cpu_din,
	output     [ 1:0]   vram1_cpu_we,
	input      [15:0]   vram1_cpu_dout,
	output     [12:1]   vram_gfx_addr,
	input      [15:0]   vram1_gfx_dout,

	output     [11:0]   vram2_cpu_addr,
	output     [ 7:0]   vram2_cpu_din,
	output              vram2_cpu_we,
	input      [ 7:0]   vram2_cpu_dout,
	input      [ 7:0]   vram2_gfx_dout,
	output     [11:0]   vram2_gfx_addr,

	output     [15:2]   char_cpu_addr,
	output     [31:0]   char_cpu_din,
	output     [ 3:0]   char_cpu_we,
	input      [31:0]   char_cpu_dout,
	output     [15:2]   char_gfx_addr,
	input      [31:0]   char_gfx_dout,

	input      [ 3:0]   gfx_en
);

// ---------------------------------------------------------------------------

`ifndef NOVIDEO

// Module-scope signal declarations.

wire          vblank_n, vblank_xx_n, hblank_n, hs_n, vs_n;

wire          h256, h128, h64, h32, h16, h8, h4, h1;
wire          h128_x, h64_x, h32_x, h16_x, h8_x, h4_x, h2_x, h1_x;
wire          vclk, v128, v64, v32, v16, v8, v4, v2, v1;
wire          v128_x, v64_x, v32_x, v16_x, v8_x, v4_x, v2_x, v1_x;
wire          h128a, h256_n, h256_x;

wire [ 2:0]   tile_va;
wire          tile_shift_a1, tile_shift_a2, tile_shift_b, vhff, vvff;
// Skip two LSBs because there are 4 8-bit RAMs.
wire [15:2]   vca, oca;
wire [ 3:0]   tile_pr;
wire [ 6:0]   tile_color;
wire          tm_a_visible, tm_b_visible;
wire [10:0]   color_index;

wire          dma_n, orinc, obj_wr, obj_clr, cha_ov, wrtime2,
              xa7, xb7, obj_pixel_latch, oc_latch, obj_xpos_d0, obj_latch_a_d2;
wire [ 7:0]   obj_cntr, obj_buff_a_din, obj_buff_a_dout, obj_buff_b_din, obj_buff_b_dout;
wire [15:0]   obj_buff_a_addr, obj_buff_b_addr;
wire [ 2:0]   ora;
wire          rst_n, blank_16h_din, champx_n, wrtime2_n, obj_table_we;
wire          pxl_cen_n, obj_buffer_we_n;
wire [ 8:0]   h256_h1;
wire [ 7:0]   h128_h1_x, v128_v1, v128_v1_x;
wire [ 6:0]   tile_hcntr_bus;
wire [ 7:0]   tile_vcntr_bus;
wire [11:0]   tile_addr_d, tile_addr_q;
wire [13:0]   char_addr_mux;
wire [31:0]   char_gfx_lanes, obj_buffer_addr_d, obj_buffer_addr_q;

// ---------------------------------------------------------------------------

reg pxl_cen_dly, pxl_cen_dly2;

wire CSYNC_n;

wire orinc_mod;

// TODO: figure out the delay
// Raki has 4HD = /4H
// LS244 says 12ns propagation delay (inverting), that’s 83 MHz
//
// ** Octal Buffer  **
// ** [LS244] @ 25E **
reg h2d, h4d;

wire blank_16h, blank_4h, blank_clk_n;

wire [10:0] vram1_latched_dout;
wire [ 6:0] vram2_latched_dout;

// ** Hex Inverters           **
// ** [LS04] @ 13F (13 -> 12) **
wire h2_n;

// ---------------------------------------------------------------------------
// jtnemsis_k5290
// ---------------------------------------------------------------------------

wire       tm_a_hflip, tm_b_hflip, aff, bff,
           tm_a_shift_L_n, tm_a_shift_R_n, tm_b_shift_L_n, tm_b_shift_R_n,
           tm_a_px_trans, tm_b_px_trans;
wire [3:0] tm_a_px_data, tm_b_px_data;

// Bit order for A-H is in the opposite direction than charram_X_gfx_dout
// Preserve the GX400 source's physical nibble bit order on these buses.
/* verilator lint_off ASCRANGE */
wire [0:3] A, B, C, D, E, F, G, H;

reg asl, asr, bsl, bsr;

// ---------------------------------------------------------------------------
// jtnemsis_k5293
// ---------------------------------------------------------------------------

wire  h4d_n, h4d_clkd, h2d_clkd, shift_a1_clkd, shift_a2_clkd, shift_b_clkd;

wire [15:0] obj_px_data;

// ---------------------------------------------------------------------------
// OBJRAM Peripherals
// ---------------------------------------------------------------------------

wire [ 7:0] obj_pri, obj_table_din, obj_table_dout;
wire [10:0] obj_table_addr;
wire        obj_buf_wr, obj_buf_ras;

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
wire champx;

wire champx2;

// WRTIME2 Delay

reg  wrtime2_d1, wrtime2_d1_5, wrtime2_d2, clk6_d1, clk6_d2;

wire wrtime2_delay_cen, wrtime2_buf_we_or;

// wrtime2_buf_ras_n

wire wrtime2_buf_ras_n;

// ** Quad 2-Input Multiplexer **
// ** [LS157] @ 13H            **
wire obj_buf_ras_n;

wire obj_clr_we, wrtime2_buf_we_n;
wire obj_clr_we_pulse;

// ** Triple 3-Input NOR Gate **
// ** [LS27] @ 22F            **
// ** Hex Inverter            **
// ** [LS04] @ 22E            **
wire u19g_clk;

// ---------------------------------------------------------------------------
// K5295
// ---------------------------------------------------------------------------

wire        obj_px_blank_n, obj_buff_cas;
reg         obj_hl;
wire [ 2:0] obj_pix_sel;

// ---------------------------------------------------------------------------
// K5294
// ---------------------------------------------------------------------------

wire [7:0] k5294_da, k5294_db;

// TODO: jtframe_sh
//
// Delay obj_pixel_latch, otherwise K5292 latches object pixels
// too early when OCA  changes, causing a vertical line in sprites.
// Probably justified by the fact that on the schematics, K5295 operates
// with a delayed clock (CLK0 with a capacitor.)
reg obj_pixel_latch_dly_1, obj_pixel_latch_dly;

wire k5294_da_trans, k5294_db_trans, obj_buff_a_s, obj_buff_b_s;

wire [15:0] obj_buff_a_addr_cas_ed, obj_buff_b_addr_cas_ed;

reg  [7:0] obj_buff_a_dout_dly_1, obj_buff_b_dout_dly_1, obj_buff_a_dout_dly, obj_buff_b_dout_dly;

`ifdef SIMULATION

// Debugging signals fot GTKWave

wire [8:0] X_POS;
wire [7:0] Y_POS;

wire        db_vram_vvff;
wire [10:0] db_vram_char_index;
`endif

// Continuous signal equations.

// There are two tilemaps and one object layer on this board. The conventional
// JTFRAME fixed-layer bit [0] has no corresponding independent GX400 source.
assign tm_a_visible = tm_a_px_trans & gfx_en[1];
assign tm_b_visible = tm_b_px_trans & gfx_en[2];
assign rst_n = ~rst;
assign blank_16h_din = ~&{ vblank_xx_n, hblank_n };
assign h2_n = ~h2;
assign champx_n = ~champx;
assign wrtime2_n = ~wrtime2;
assign pxl_cen_n = ~pxl_cen;
assign obj_buffer_we_n = ~obj_buf_wr;
assign obj_table_we = ~|{ dma_n, h1_n };
assign tile_hcntr_bus = { h64, h32, h16, h8, h4, h2, h1 };
assign tile_vcntr_bus = { v128, v64, v32, v16, v8, v4, v2, v1 };
assign tile_addr_d = { vram1_gfx_dout[11:8], vram1_gfx_dout[7:0] };
assign { vvff, vram1_latched_dout } = tile_addr_q;
assign char_addr_mux = cha_ov ? vca : oca;
assign h4d_n = ~h4d;
assign char_gfx_lanes = { A[0:3], B[0:3], C[0:3], D[0:3],
                          E[0:3], F[0:3], G[0:3], H[0:3] };
assign obj_buffer_addr_d = { obj_buff_a_addr, obj_buff_b_addr };
assign { obj_buff_a_addr_cas_ed, obj_buff_b_addr_cas_ed } = obj_buffer_addr_q;
assign { h256, h128, h64, h32, h16, h8, h4, h2, h1 } = h256_h1;
assign { h128_x, h64_x, h32_x, h16_x, h8_x, h4_x, h2_x, h1_x } = h128_h1_x;
assign { v128, v64, v32, v16, v8, v4, v2, v1 } = v128_v1;
assign { v128_x, v64_x, v32_x, v16_x, v8_x, v4_x, v2_x, v1_x } = v128_v1_x;

// ---------------------------------------------------------------------------
// jtnemsis_k5292: Video Timings Generator
// ---------------------------------------------------------------------------

// jtnemsis_k5292 outputs active low HS and VS
assign HS = ~hs_n;
assign VS = ~vs_n;

assign vblank = ~vblank_n;

// ** Dual 4-Input NAND Gate    **
// ** [LS20] @ 16C              **
// ** Quad 2-Input AND Gate     **
// ** [LS08] @ 21H (9, 10 -> 8) **
assign orinc_mod = orinc & ~&obj_cntr[7:4];


// ** Hex Inverters **
// ** [LS04] @ 17C  **
assign h256_n = ~h256;

// ** Quad 2-Input XOR Gate **
// ** [LS86] @ 16A          **
assign h256_x = ~h256 ^ hflip;

// ** Quad 2-Input AND Gate **
// ** [LS08] @ 17B          **
// ** Quad 2-Input OR Gate  **
// ** [LS32] @ 16B          **
assign h128a  = ( h256 && h128 ) || (h256_n && h32 );

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
assign tile_pr    = vram1_gfx_dout[15:12];
assign vhff       = vram2_gfx_dout[7];
assign tile_color = vram2_gfx_dout[6:0];
assign vram2_gfx_addr = vram_gfx_addr;
assign pal_addr = ( (color_source == 2'd1 && !gfx_en[1]) ||
                      (color_source == 2'd2 && !gfx_en[2]) ||
                      (color_source == 2'd0 && !gfx_en[3]) ) ?
                     11'd0 : color_index;

// No MUX because we use RAMs with a wide address bus, no need for RAS/CAS.
//
// ** 2 x Quad 2-Input Multiplexer **
// ** [LS157] @ 12A, 13B           **
// ** Quad 2-Input XOR Gate        **
// ** [LS86] @ 16A                 **
assign vca = { vram1_latched_dout, {3{vvff}} ^ tile_va };
/* verilator lint_on ASCRANGE */

assign A[0:3] = char_gfx_dout[15:12];
assign B[0:3] = char_gfx_dout[11:8];
assign C[0:3] = char_gfx_dout[7:4];
assign D[0:3] = char_gfx_dout[3:0];
assign E[0:3] = char_gfx_dout[31:28];
assign F[0:3] = char_gfx_dout[27:24];
assign G[0:3] = char_gfx_dout[23:20];
assign H[0:3] = char_gfx_dout[19:16];

// ** Quad 2-Input XOR Gate **
// ** [LS86] @ 9D           **
assign aff = tm_a_hflip ^ hflip; // output 6
assign bff = tm_b_hflip ^ hflip; // output 8

assign tm_a_shift_L_n = asl; // output 3
assign tm_a_shift_R_n = asr; // output 11
assign tm_b_shift_L_n = bsl; // output 6
assign tm_b_shift_R_n = bsr; // output 8

// ** Hex Inverters               **
// ** [LS04] @ 10C (11 -> 10)     **
// ** Quad 2-Input NAND Gate      **
// ** [LS00] @ 10D (12, 13 -> 11) **
assign h4d_clkd    = ~&{ ~h4d, h2d };
// ** Quad 2-Input NAND Gate      **
// ** [LS00] @ 10D (1, 2 -> 3)    **
assign h2d_clkd    = ~&{  h4d, h2d };
// ** Quad 2-Input OR Gate        **
// ** [LS32] @ 11C                **
assign shift_a1_clkd = |{ tile_shift_a1, clk6 }; // output 3
assign shift_a2_clkd = |{ tile_shift_a2, clk6 }; // output 11
assign shift_b_clkd  = |{ tile_shift_b,  clk6 }; // output 8
assign obj_px_data = gfx_en[3] ?
                     { obj_buff_b_dout_dly, obj_buff_a_dout_dly } : 16'd0;

// ** 3 x Quad 2-Input Multiplexer **
// ** [LS157] @ 25A–C              **
assign obj_gfx_addr = { v8, v4, v2, v1, h128, h64, h32, h16, h8, h4, h2d };
assign champx = ~clk6 | h1;

// seems correct here for wrtime2_buf_we_n, which is the low part of clk6
// on the cycle after wetime2_buf_ras_n
// clk6:              --_--_--_--_--_--_--_--_--_--_--_--_
// wrtime2_buf_ras_n: ______--____--____--____--__________
// wrtime2_buf_we_n:  ___________-_____-_____-_____-______
assign wrtime2_delay_cen = pxl_cen_dly2;
assign wrtime2_buf_we_or = clk6_d2;
assign obj_buf_ras_n = obj_wr ? wrtime2_buf_ras_n : ~champx;

assign obj_clr_we = ~obj_clr_we_pulse;

// ** Quad 2-Input OR Gate      **
// ** [LS32] @ 14H (9, 10 -> 8) **
assign wrtime2_buf_we_n = ~wrtime2_d2 | wrtime2_buf_we_or;

// wrtime2_buf_we_n | ~pxl_cen_dly2 simulates a clock-enable but only during obj_wr
// it reduces wrtime2_buf_we_n to a duration one clk cycle on its rising edge
// to avoid multiple writes while it is asserted
//
// ** Quad 2-Input Multiplexer **
// ** [LS157] @ 13H            **
assign obj_buf_wr = obj_wr ? wrtime2_buf_we_n | ~pxl_cen_dly2 : obj_clr_we;

// ** Hex Inverter           **
// ** [LS04] @ 17C           **
// ** Dual 4-Input NAND Gate **
// ** [LS20] @ 16C           **
assign dma_n = ~&{ v128, v64, v32, ~v16 };
assign u19g_clk = |{ h8, h4, h2 };

// ** 3 x Quad 2-Input Multiplexer **
// ** [LS157] @ 16F, 17F, 19F      **
assign obj_table_addr = dma_n
	? { obj_cntr, ora }
	: { obj_pri, h8, h4, h2d };

// ** Hex inverters          **
// ** [LS04] @ 14G           **
// ** Quad 2-Input NAND Gate **
// ** [LS00] @ 15G           **

// ** Quad 2-Input AND Gate **
// ** [LS08] @ 17B          **
// ** Hex Inverter          **
// ** [LS04] @ 17C          **
// ** Quad 2-Input OR Gate  **
// ** [LS32] @ 16B          **
assign obj_pixel_latch = clk6 | ~&{ h1, h2 };

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

`ifdef SIMULATION

assign X_POS = { 1'b0, h128, h64, h32, h16, h8, h4, h2, h1 };
assign Y_POS = { v128, v64, v32, v16, v8, v4, v2, v1 };

assign db_vram_vvff       = vram1_gfx_dout[11];
assign db_vram_char_index = { vram1_gfx_dout[10:8], vram1_gfx_dout[7:0] };
`endif

// Sequential and combinational processes.
always @( posedge clk ) begin
	pxl_cen_dly  <= pxl_cen;
	pxl_cen_dly2 <= pxl_cen_dly;
end

always @( posedge clk ) begin
	h2d <= h2;
	h4d <= h4;
end

// ---------------------------------------------------------------------------
// Scroll RAM Address MUXes
// ---------------------------------------------------------------------------

// ** 3 x Quad 2-Input Multiplexer **
// ** [LS157] @ 22A, 22B, 22C      **
// ** Hex Inverter                 **
// ** [LS04] @ 22E (3 -> 4)        **
always @(*) begin
	case( { ~vclk } )
		1'b0:   scroll_gfx_addr = { 1'b0, h4d, h2, v128_x, v64_x, v32_x, v16_x, v8_x, v4_x, v2_x, v1_x };
		1'b1:   scroll_gfx_addr = { {4{1'b1}}, h4d, h256_x, h128_x, h64_x, h32_x, h16_x, h8_x };
	endcase
end

// I don’t remember why it’s synchronous

// ** Hex Inverters        **
// ** [LS04] @ 10C         **
// ** Quad 2-Input OR Gate **
// ** [LS32] @ 9E          **
always @( posedge clk ) begin
	asl <= |{  aff, ~tile_shift_a1 }; // output 3
	asr <= |{ ~aff, ~tile_shift_a1 }; // output 11
	bsl <= |{  bff, ~tile_shift_b  }; // output 6
	bsr <= |{ ~bff, ~tile_shift_b  }; // output 8
end

always @( posedge clk ) begin
	clk6_d1 <= clk6;
	clk6_d2 <= clk6_d1;
end

// ** Dual D flip-flop              **
// ** [LS74] @ 18H left, 17H bottom **
always @( posedge clk ) if( wrtime2_delay_cen ) begin
	wrtime2_d1 <= wrtime2;
	wrtime2_d2 <= wrtime2_d1;
end

// ** Dual D Flip-Flop   **
// ** [LS74] @ 18H right **
always @( posedge clk ) if( pxl_cenb ) begin
	wrtime2_d1_5 <= wrtime2_d1;
end

// TODO: check = or <=

// Delay because of capacitor.
//
// ** Capacitor             **
// ** [470 pF]              **
// ** Hex Inverter          **
// ** [LS04] @ 13F (3 -> 4) **
always @( posedge clk ) begin
	obj_hl = ~obj_buf_ras_n;
end

always @( posedge clk ) begin
	obj_pixel_latch_dly_1 <= obj_pixel_latch;
	obj_pixel_latch_dly   <= obj_pixel_latch_dly_1;
end

// RAM access time, otherwise it changes before the right value being latched
always @( posedge clk ) begin
	{ obj_buff_a_dout_dly_1, obj_buff_b_dout_dly_1 } <= { obj_buff_a_dout,       obj_buff_b_dout       };
	{ obj_buff_a_dout_dly,   obj_buff_b_dout_dly   } <= { obj_buff_a_dout_dly_1, obj_buff_b_dout_dly_1 };
end

// Chip and framework instances.

// ** Custom Chip Konami Video Timings Generator **
// ** [K0005292] @ 20B                           **
jtnemsis_k5292 u_5292(
	.clk        ( clk     ),
	.pxl_cen        ( pxl_cen ),
	.rst_n       ( rst_n   ),

	.vflp        ( vflip    ),
	.hflp        ( hflip    ),
	.inter       ( 1'b0       ),
	.resolution_288_256     ( 1'b0       ),

	.dma_n       ( dma_n      ),
	.orinc       ( orinc_mod  ),

	.vblank_xx_n ( vblank_xx_n ),
	.vblank_n    ( vblank_n    ),
	.hblank_n    ( hblank_n    ),
	.csync_n     ( CSYNC_n    ),
	.vsync_n     ( vs_n     ),

	.h256_h1     ( h256_h1     ),
	.h128_h1_x   ( h128_h1_x   ),
	.h1_n        ( h1_n     ),

	.vclk        ( vclk       ),
	.v128_v1     ( v128_v1     ),
	.v128_v1_x   ( v128_v1_x   ),
	.v256        ( v256     ),

	.obj_cntr    ( obj_cntr   )
);

// ** Dual D Flip-Flop            **
// ** [LS74] @ 19H left           **
// ** Quad 2-Input NAND Gate      **
// ** [LS00] @ 15G (12, 13 -> 11) **
jtframe_ff u_19h_left_ff(
	.rst     ( rst                   ),
	.clk     ( clk                    ),
	.cen     ( 1'b1                      ),
	.sigedge ( h16                     ),
	.set     ( 1'b0                      ),
	.clr     ( 1'b0                      ),
	.din     ( blank_16h_din             ),
	.q       ( blank_16h                 ),
	.qn      (                           )
);

// ** Dual D Flip-Flop   **
// ** [LS74] @ 19H right **
jtframe_ff u_19h_right_ff(
	.rst     ( rst                   ),
	.clk     ( clk                    ),
	.cen     ( 1'b1                      ),
	.sigedge ( champx_n                  ),
	.set     ( 1'b0                      ),
	.clr     ( 1'b0                      ),
	.din     ( blank_16h                 ),
	.q       ( obj_wr                    ),
	.qn      ( obj_clr                   )
);

// ** Dual D Flip-Flop **
// ** [LS74] @ 17A top **
jtframe_ff u_17a_top_ff(
	.rst     ( rst ),
	.clk     ( clk  ),
	.cen     ( 1'b1    ),
	.sigedge ( h4    ),
	.set     ( 1'b0    ),
	.clr     ( 1'b0    ),
	.din     ( CSYNC_n ),
	.q       ( hs_n  ),
	.qn      (         )
);

// These flip-flops delay HBLANK by 22 pixels and stop HBLANK and HSYNC during VBLANK, which
// apparently does not suit the HDMI output, so we just delay HBLANK by 22 pixels instead.
//
// ** 2 x Dual D Flip-Flop        **
// ** [LS74] @ 20H, 17A bottom    **
// ** Quad 2-Input AND Gate       **
// ** [LS08] @ 21H (12, 13 -> 11) **
jtframe_sh #( .W( 1 ), .L( 22 ) )
u_blk_dly(
	.clk    ( clk     ),
	.clk_en ( pxl_cen ),
	.din    ( hblank_n    ),
	.drop   ( preLHBL      )
);

// ---------------------------------------------------------------------------
// jtnemsis_k5291: Tile Address Generator
// ---------------------------------------------------------------------------

// ** Custom Chip Konami Tile Address Generator **
// ** [K0005291] @ 20D                          **
jtnemsis_k5291 u_5291(
	.clk               ( clk              ),

	// inputs
	.hflip              ( hflip             ),
	.vflip              ( vflip             ),
	.pxl_cen               ( vclk                ),
	.hcntr_bus          ( tile_hcntr_bus     ),
	.vcntr_bus          ( tile_vcntr_bus     ),
    .h256_n             ( h256_n             ),
    .h128a              ( h128a             ),

	.cpu_addr_bus       ( cpu_addr[12:1]        ),
	.scroll_data_bus    ( scroll_gfx_dout ),

	// outputs
	.tile_line_addr_bus ( tile_va             ),
	.vram_addr_bus      ( vram_gfx_addr       ),
	.shift_a1           ( tile_shift_a1       ),
	.shift_a2           ( tile_shift_a2       ),
	.shift_b            ( tile_shift_b        )
);

// ** Octal D Flip-Flop With Reset **
// ** [LS273] @ 12B                **
// ** Hex D Flip-Flop              **
// ** [LS174] @ 13C                **
jtnemsis_bus_ff #( .W( 12 ) )
u_tile_addr_ff(
	.rst     ( rst         ),
	.clk     ( clk          ),
	.trig    ( h2_n          ),
	.d       ( tile_addr_d ),
	.q       ( tile_addr_q ),
	.q_n     (                 )
);

// Implement RAS/CAS on CHARRAM with external flip-flop on CAS,
// otherwise the K5294 latches the next tile line before it’s done
// displaying the previous one, and the last pixel of each group
// of 8 is wrong.
//
// Select bewteen vca and oca based on cha_ov (MUX).
//
// ** 2 x Quad 2-Input Multiplexer **
// ** [LS157] @ 11A–B              **
jtnemsis_bus_ff #( .W( 14 ) )
u_oca_ras_cas_ff(
	.rst     ( rst        ),
	.clk     ( clk         ),
	.trig    ( champx2        ), // cas_n = ~CHAMPX delayed -> cas = CHAMPX delayed
	.d       ( char_addr_mux ),
	.q       ( char_gfx_addr[15:2] ),
	.q_n     (                )
);

// ** Custom chip Konami Tile Shifter **
// ** [K0005290] @ 7D                 **
jtnemsis_k5290 u_5290
(
	.clk          ( clk            ),  // Master clock 49.152 MHz
	.rst           ( rst           ),  // RESET signal on pos edge
	.pxl_cen       ( pxl_cen        ),  // 6.144 MHz pixel enable
	.aff           ( aff               ),  // Tile A Flip
	.bff           ( bff               ),  // Tile B Flip
	.u9e_pin3       ( tm_a_shift_L_n    ),  // Tile A shift left  if 0
	.u9e_pin11      ( tm_a_shift_R_n    ),  // Tile A shift right if 0
	.u9e_pin6       ( tm_b_shift_L_n    ),  // Tile B shift left  if 0
	.u9e_pin8       ( tm_b_shift_R_n    ),  // Tile B shift right if 0
	.a             ( A[0:3]            ),  // Input 4bit data from char ram
	.b             ( B[0:3]            ),  // Input 4bit data from char ram
	.c             ( C[0:3]            ),  // Input 4bit data from char ram
	.d             ( D[0:3]            ),  // Input 4bit data from char ram
	.e             ( E[0:3]            ),  // Input 4bit data from char ram
	.f             ( F[0:3]            ),  // Input 4bit data from char ram
	.g             ( G[0:3]            ),  // Input 4bit data from char ram
	.h             ( H[0:3]            ),  // Input 4bit data from char ram
	.hd2           ( h2d             ),  // Horizontal Pixel (counter bus)
	.hd4_n         ( h4d_n            ),  // Horizontal Pixel (counter bus)
	.tm_a_px_trans ( tm_a_px_trans     ),  // output pixel data
	.tm_a_pixels   ( tm_a_px_data      ),  // output pixel data
	.tm_b_px_trans ( tm_b_px_trans     ),  // output pixel data
	.tm_b_pixels   ( tm_b_px_data      )   // output pixel data
);

// ** Custom Chip Konami Priority Processor **
// ** [K0005293] @ 11D                      **
jtnemsis_k5293 u_5293(
	.rst            ( rst          ),
	.clk            ( clk           ), // Pin 23
	.pxl_cen           ( pxl_cen       ), // |
	.shift_a1_clkd  ( shift_a1_clkd    ), // Pin 18
	.shift_a2_clkd  ( shift_a2_clkd    ), // Pin 17
	.shift_b_clkd   ( shift_b_clkd     ), // Pin 19
	.h2_clkd       ( h2d_clkd       ), // Pin 21
	.h4_clkd       ( h4d_clkd       ), // Pin 20
	.tm_a_hflip     ( tm_a_hflip       ), // Pin 36
	.tm_b_hflip     ( tm_b_hflip       ), // Pin 37
	.tm_a_px_data   ( tm_a_px_data     ), // Pins 3–10, 15–16
	.tm_a_px_trans  ( tm_a_visible     ), // |
	.tm_b_px_data   ( tm_b_px_data     ), // |
	.tm_b_px_trans  ( tm_b_visible     ), // |
	.hflip          ( hflip          ), // Pin 56
	.tile_priority  ( tile_pr          ), // PR, Pins 11–14
	.vhff           ( vhff             ), // Pin 57
	.vram2_data     ( tile_color       ), // VC
	.obj_px_data    ( obj_px_data      ), // DQ
	.color_ram_addr ( color_index      ), // CD
	.color_source   ( color_source     ),
	.h1_n           ( h1_n           )  // Pin 22
);

// ** Hex Schmitt-Trigger Inverter      **
// ** [LS14] @ 10E (13 -> 12, 11 -> 10) **
jtframe_sh #( .W( 1 ), .L( 3 ) )
u_champx2_dly(
	.clk    ( clk  ),
	.clk_en ( 1'b1    ),
	.din    ( champx  ),
	.drop   ( champx2 )
);

// This one seems fine: it’s synchronised with positive or negative edges of 2H, like in Raki’s core
// could be longer: takes 2/3 of wrtime2 in Raki’s core, and 1/2 here with a duration of 4 mclk
// could be like the active part of clk6, so 5 mclk, like in Raki’s core
// tried active part of clk6, it’s really, really bad
//
// ** Quad 2-Input AND Gate    **
// ** [LS08] @ 21H (1, 2 -> 3) **
jtnemsis_os_pulse_gen #( .DURATION( 4 ) )
wrtime2_buf_ras_n_gen
(
	.clk     ( clk            ),
	.trig    ( wrtime2_n           ),
	.trig_en ( 1'b1              ),
	.pulse   ( wrtime2_buf_ras_n ),
	.dl      (                  )
);

// Build obj_clr_we according to timing diagrams, by looking at the effect
// of shift register 15H on 1HF.
// I would have thought it would be clk6 | h1_n, but it doesn’t work

// ** Quad 2-Input OR Gate **
// ** [LS32] @ 14H         **
jtnemsis_os_pulse_gen #( .DURATION( 2 ) )
obj_clr_we_gen
(
	.clk     ( clk            ),
	.trig    ( pxl_cen              ),
	.trig_en ( h1              ),
	.pulse   ( obj_clr_we_pulse  ),
	.dl      (                  )
);

// ** Octal D Flip-Flop With Clear **
// ** [LS374] @ 19G                **
jtnemsis_bus_ff #( .W( 8 ) )
u_obj_pri_ff(
	.rst     ( rst          ),
	.clk     ( clk           ),
	.trig    ( u19g_clk         ),
	.d       ( obj_gfx_dout  ),
	.q       ( obj_pri          ),
	.q_n     (                  )
);

// ** Octal D flip-flop **
// ** [LS374] @ 17G     **
jtnemsis_bus_ff #( .W( 8 ) )
u_obj_din_ff(
	.rst     ( rst          ),
	.clk     ( clk           ),
	.trig    ( h1_n           ),
	.d       ( obj_gfx_dout  ),
	.q       ( obj_table_din    ),
	.q_n     (                  )
);

// ** 2k x 8bit Static RAM **
// ** [2128] @ 16G         **
jtframe_ram #(
	.AW(11)
)
u_obj_table(
	.clk     ( clk           ),
	.cen     ( 1'b1             ),
	.addr    ( obj_table_addr   ),
	.data    ( obj_table_din    ),
	.we      ( obj_table_we      ),
	.q       ( obj_table_dout   )
);

// ** Custom chip Konami Sprite Drawer **
// ** [K0005295] @ 11G                 **
jtnemsis_k5295 u_5295
(
	.clk             ( clk          ), // Master clock 49.152 MHz
	// clock 0 input but has a delay on the circuit with a capacitor to gnd
	// chosen empirically as pxl_cen with a delay by 2*clk because it syncs nicely with 1H/2H/4H.
	.pxl_cen_n      ( pxl_cen_n           ),

	.flip                 ( hflip         ), //
	.abs_1h               ( h1            ), //
	.abs_2h               ( h2            ), //
	.abs_4h               ( h4            ), //
	.hblank_n             ( hblank_n         ), //
	.vblank_n             ( vblank_n         ), //
	.vblankh_n            ( vblank_xx_n      ), //
	.dma_n                ( dma_n           ), //
	.objhl                ( obj_hl          ), // wired to o_CAS
	.objwr                ( obj_wr          ), //
	.champx               (                 ), // Input CHAMPX, unused as we have wide address RAMs

	.objdata              ( obj_table_dout  ), // Input 8bit Object RAM Data Bus

	.orinc                ( orinc           ), // output Object Tick counter (ORINC)
	.ora                  ( ora             ), // output Object Read Address ?
	.wrtime2              ( wrtime2         ), // output Write Time 2
	.xa7                  ( xa7             ), // output X address 7
	.xb7                  ( xb7             ), // output X address 7
	.pixelsel             ( obj_pix_sel     ), // output Horizontal Tile Pixel Select
	.chaov                ( cha_ov          ), // output Character Object/Video (not CHA O/A on 11B!!)
	.fa                   ( obj_buff_a_addr ), // output pixel address evenbuff
	.fb                   ( obj_buff_b_addr ), // output pixel address oddbuff
	.oca                  ( oca             ), // output Object Code Bus A
	.colorlatch_n         ( oc_latch        ), // output Latch to 5294
	.xpos_d0              ( obj_xpos_d0     ), // OBJ_XPOS_D0 to 5294
	.latch_a_d2           ( obj_latch_a_d2  ), // SIZELATCH_UNKNOWN_D2 to 5294
	.cas                  ( obj_buff_cas    ), // object buffer CAS
	.pixellatch_wait_dly_n    ( obj_px_blank_n  )  // to jtnemsis_k5294 LS175
);

// ** Custom chip Konami Sprite Pixel Latch **
// ** [K0005294] @ 3E                       **
jtnemsis_k5294 u_5294
(
	.clk           ( clk             ), // Master clock 49.152 MHz
	.pxl_cen_n    ( pxl_cen_n              ), // Inverted pixel-clock enable

	.gfxdata            ( char_gfx_lanes ),
	.wrtime2            (wrtime2             ),
	.colorlatch_n       (oc_latch            ),
	.xpos_d0            (obj_xpos_d0         ),
	.pixellatch_wait_n  (obj_px_blank_n  ),
	.latch_a_d2         (obj_latch_a_d2      ),
	.pixelsel           (obj_pix_sel         ),

	.oc                 (obj_table_dout[4:1] ),

	.tilelinelatch_n    (obj_pixel_latch_dly ),

	.da                 ( k5294_da           ), // output pixel data evenbuff
	.db                 ( k5294_db           )  // output pixel data oddbuff
);

// Implement RAS/CAS on object buffers with external flip-flop on CAS.

jtnemsis_bus_ff #( .W( 32 ) )
u_obj_buffer_ras_cas_ff(
	.rst     ( rst        ),
	.clk     ( clk         ),
	.trig    ( obj_buff_cas   ),
	.d       ( obj_buffer_addr_d ),
	.q       ( obj_buffer_addr_q ),
	.q_n     (                )
);

// ** 8 x 64k x 1bit Dynamic RAM              **
// ** [4164] @ 2A, 2B, 6A, 6B, 4A, 4B, 7A, 7B **
// evenbuff
jtframe_ram #(
	.AW( 16 )
)
obj_buffer_a(
	.clk  ( clk                 ),
	.cen  ( 1'b1                   ),
	.data ( obj_buff_a_din         ),
	.addr ( obj_buff_a_addr_cas_ed ),
	.we   ( obj_buffer_we_n       ),
	.q    ( obj_buff_a_dout        )
);

// ** 8 x 64k x 1bit Dynamic RAM **
// ** [4164] @ 1H–8H             **
// oddbuff
jtframe_ram #(
	.AW( 16 )
)
obj_buffer_b(
	.clk  ( clk                 ),
	.cen  ( 1'b1                   ),
	.data ( obj_buff_b_din         ),
	.addr ( obj_buff_b_addr_cas_ed ),
	.we   ( obj_buffer_we_n       ),
	.q    ( obj_buff_b_dout        )
);

// ---------------------------------------------------------------------------
// CPU Data Bus Input
// ---------------------------------------------------------------------------

 jtnemsis_video_bram_if u_video_bram_if(
	.cpu_addr        ( cpu_addr           ),
	.cpu_din         ( cpu_din    ),
	.uds_n           ( uds_n          ),
	.lds_n           ( lds_n          ),
	.rnw             ( rnw            ),
	.chacs_n         ( chacs_n        ),
	.objram_n        ( objram_n       ),
	.vcs1            ( vcs1           ),
	.vcs2            ( vcs2           ),
	.vzcs            ( vzcs           ),
	.scroll_cpu_addr ( scroll_cpu_addr  ),
	.scroll_cpu_din  ( scroll_cpu_din   ),
	.scroll_cpu_we   ( scroll_cpu_we    ),
	.scroll_cpu_dout ( scroll_cpu_dout  ),
	.obj_cpu_addr    ( obj_cpu_addr     ),
	.obj_cpu_din     ( obj_cpu_din      ),
	.obj_cpu_we      ( obj_cpu_we       ),
	.obj_cpu_dout    ( obj_cpu_dout     ),
	.vram1_cpu_addr  ( vram1_cpu_addr   ),
	.vram1_cpu_din   ( vram1_cpu_din    ),
	.vram1_cpu_we    ( vram1_cpu_we     ),
	.vram1_cpu_dout  ( vram1_cpu_dout   ),
	.vram2_cpu_addr  ( vram2_cpu_addr   ),
	.vram2_cpu_din   ( vram2_cpu_din    ),
	.vram2_cpu_we    ( vram2_cpu_we     ),
	.vram2_cpu_dout  ( vram2_cpu_dout   ),
	.char_cpu_addr   ( char_cpu_addr    ),
	.char_cpu_din    ( char_cpu_din     ),
	.char_cpu_we     ( char_cpu_we      ),
	.char_cpu_dout   ( char_cpu_dout    ),
	.cpu_dout        ( cpu_dout   )
);

// ---------------------------------------------------------------------------
// External BRAM interface
//
// Each port below is the original synchronous dual-port RAM interface. The
// generated wrapper owns the storage; port 0 remains CPU-visible and port 1
// remains the renderer read path.
// ---------------------------------------------------------------------------

`endif


endmodule
