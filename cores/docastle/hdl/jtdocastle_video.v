// UNVERIFIED DRAFT -- ported from mrdo/rtl/docastle_{video,crtc}.sv, not yet compiled or simulated against real jtframe tooling.
//
//============================================================================
// Mr. Do's Castle video pipeline.
//
// Native raster: 4.914 MHz, 312 x 264 total, 240 x 192 visible after the
// schematic's 8-pixel left/right blanking. Tile/sprite priority follows the
// two-pass MAME model: sprite pens 8-14 are visible, pen 15 is an invisible
// mask which blocks following sprites, and tile pens 8-15 are foreground.
//
// Ported from docastle_video.sv (mrdo repo). This is a PURE RENAME/REWRAP
// pass: no timing value, register behaviour, raster geometry (312x264
// total / 240x192 visible / HD6845S@9.828MHz/16 / pixel clock 9.828MHz/2)
// or the frame-shadowed-register-write protection logic changed. Only the
// video-timing/blanking signal names moved to jtframe's convention:
//
//   docastle_video.sv / docastle_crtc.sv  ->  jtdocastle_video.v / jtdocastle_crtc.v
//   ------------------------------------------------------------------------
//   hs      (active-high sync pulse)      ->  HS      (same polarity, pure rename)
//   vs      (active-high sync pulse)      ->  VS      (same polarity, pure rename)
//   hblank  (active-HIGH: 1 = blanked)    ->  LHBL    (active-LOW: 0 = blanked;
//                                                       jtframe convention --
//                                                       see jtframe_vtimer.v.
//                                                       Rename + polarity
//                                                       invert. Blanking
//                                                       WINDOW timing is
//                                                       byte-for-byte
//                                                       unchanged.)
//   vblank  (active-HIGH: 1 = blanked)    ->  LVBL    (same as hblank->LHBL
//                                                       above)
//
// Everything else (r/g/b resistor-DAC output, CPU/tile/colour/sprite RAM
// ports, the CF37201 pin-level PCB-write interface, ce_pix, crtc_reg/data/we,
// main_irq_n, sub_irq_req, sprite_nmi_req, debug outputs) is OUT OF SCOPE for
// this rename pass and is carried over with identical names and behaviour --
// see the porting report for the full signal table and what was flagged.
//
// KNOWN GAP: this module instantiates jtdocastle_pcb_sprite, mirroring this
// core's jtdocastle_* naming convention, but that submodule (the port of
// docastle_pcb_sprite.sv) is OUT OF SCOPE for this task and has not been
// written yet. This file will not elaborate standalone until
// jtdocastle_pcb_sprite.v also exists.
//============================================================================
module jtdocastle_video
(
	input         clk,
	input         reset,
	input         ce_pix,
	input         cursor_irq_mode,
	input         pcb_framebuffer,
	input         flipscreen,
	input         low_pen_priority,
	input         soccer_sprites,

	// CPU-side tile, colour and sprite RAM ports
	input   [9:0] video_cpu_addr,
	input   [7:0] video_cpu_din,
	input         video_cpu_we,
	output  [7:0] video_cpu_q,
	input   [9:0] color_cpu_addr,
	input   [7:0] color_cpu_din,
	input         color_cpu_we,
	output  [7:0] color_cpu_q,
	input   [8:0] sprite_cpu_addr,
	input   [7:0] sprite_cpu_din,
	input         sprite_cpu_we,
	input   [8:0] pcb_sprite_addr,
	input   [7:0] pcb_sprite_din,
	input         pcb_sprite_we,
	// Pin-level CF37201 external-DRAM interface kept in the PCB write path.
	input  [15:0] cf_dram_address,
	input         cf_dram_strobe,
	input         cf_dram_column,
	input   [7:0] cf_dram_y,
	input   [7:0] cf_dram_x,
	input   [4:0] cf_palette,
	input         cf_flip_x,
	input         cf_flip_y,
	input         cf_plus_one,
	input         cf_serial_invert,

	// Graphics ROM / colour PROM ports
	output [13:0] char_addr,
	input   [7:0] char_q,
	output [16:0] sprite_gfx_addr,
	input   [7:0] sprite_gfx_q,
	output  [7:0] prom_addr,
	input   [7:0] prom_q,

	// CRTC register access
	input   [4:0] crtc_reg,
	input   [7:0] crtc_data,
	input         crtc_we,

	// Video output
	output  [7:0] r,
	output  [7:0] g,
	output  [7:0] b,
	output        HS,
	output        VS,
	output        LHBL,               // active low, per jtframe convention
	output        LVBL,               // active low, per jtframe convention

	// Colour-mix taps (NEW, 2nd pass -- purely additive, ZERO behavioural
	// change). jtdocastle_colmix.v needs the pre-PROM tile pen / tile colour /
	// sprite pixel that this module already computes internally but never
	// exported. Exposing them lets jtdocastle_game.v use jtdocastle_colmix.v as
	// the single RGB source instead of this module's own duplicated copy of the
	// same priority mux + resistor-DAC maths (r/g/b/prom_addr below are left in
	// place, unchanged, but are dead in the jtframe integration -- see
	// jtdocastle_game.v's flagged list, item V1).
	output  [3:0] mix_tile_pen,
	output  [4:0] mix_tile_color,
	output  [9:0] mix_sprite_pixel,

	// Interrupts
	output        main_irq_n,
	output        sub_irq_req,     // was `output reg` -- ILLEGAL, it is driven by
	output        sprite_nmi_req,  // the jtdocastle_crtc instance below, not by an
	                               // always block in this file. Fixed in the 2nd
	                               // pass; no behavioural change.

	// Debug
	output  [8:0] h_count_debug,
	output  [8:0] v_count_debug,
	output        cursor_debug,
	output        renderer_busy_debug,
	output        renderer_overrun_debug
);

wire [8:0] h_count;
wire [8:0] v_count;
assign h_count_debug = h_count;
assign v_count_debug = v_count;

wire crtc_cursor;
assign cursor_debug = crtc_cursor;
wire [13:0] crtc_ma;
wire [4:0] crtc_ra;
jtdocastle_crtc crtc
(
	.clk(clk), .reset(reset), .ce_pix(ce_pix), .cursor_irq_mode(cursor_irq_mode),
	.reg_sel(crtc_reg), .reg_data(crtc_data), .reg_we(crtc_we),
	.h_count(h_count), .v_count(v_count), .HS(HS), .VS(VS),
	.LHBL(LHBL), .LVBL(LVBL), .cursor(crtc_cursor),
	.ma(crtc_ma), .ra(crtc_ra), .main_irq_n(main_irq_n),
	.sub_irq_req(sub_irq_req), .sprite_nmi_req(sprite_nmi_req)
);

// CPU-visible tile, colour and sprite RAM.
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] video_ram [0:1023];
(* ramstyle = "M10K, no_rw_check" *) reg [7:0] color_ram [0:1023];
(* ramstyle = "MLAB, no_rw_check" *) reg [31:0] sprite_ram[0:127];

reg [7:0] video_cpu_q_r, color_cpu_q_r;
reg [7:0] video_scan_q, color_scan_q;
assign video_cpu_q = video_cpu_q_r;
assign color_cpu_q = color_cpu_q_r;

wire [7:0] bitmap_x = flipscreen ? (8'd255 - h_count[7:0])
	                              : h_count[7:0];
wire [7:0] source_y = flipscreen ? (8'd191 - v_count[7:0])
	                              : v_count[7:0];
wire [7:0] map_y = source_y + 8'd32;
wire [9:0] tile_addr = {map_y[7:3], bitmap_x[7:3]};

always @(posedge clk) begin
	video_cpu_q_r <= video_ram[video_cpu_addr];
	color_cpu_q_r <= color_ram[color_cpu_addr];
	video_scan_q <= video_ram[tile_addr];
	color_scan_q <= color_ram[tile_addr];
	if (video_cpu_we)  video_ram[video_cpu_addr] <= video_cpu_din;
	if (color_cpu_we)  color_ram[color_cpu_addr] <= color_cpu_din;
	if (sprite_cpu_we) begin
		case (sprite_cpu_addr[1:0])
			2'd0: sprite_ram[sprite_cpu_addr[8:2]][7:0]   <= sprite_cpu_din;
			2'd1: sprite_ram[sprite_cpu_addr[8:2]][15:8]  <= sprite_cpu_din;
			2'd2: sprite_ram[sprite_cpu_addr[8:2]][23:16] <= sprite_cpu_din;
			2'd3: sprite_ram[sprite_cpu_addr[8:2]][31:24] <= sprite_cpu_din;
		endcase
	end
end

// Pixel-space mapping uses the board's raw x coordinate.  Only x=8..247 is
// visible; flip-screen mirrors the full 256-pixel tile/sprite coordinate.
// The RAM scan ports are registered at the 49.152 MHz master rate, leaving
// ample settling time before the next 4.9152 MHz pixel enable.
wire [7:0] tile_number = video_scan_q;
wire [7:0] tile_attr   = color_scan_q;
wire [8:0] tile_code   = {tile_attr[5], tile_number};
wire [13:0] char_base  = {tile_code,5'b00000};
assign char_addr = char_base + {9'd0,map_y[2:0],2'b00} + {12'd0,bitmap_x[2:1]};
wire [3:0] tile_pen = bitmap_x[0] ? char_q[3:0] : char_q[7:4];

// Two alternating sprite line buffers.  Even/odd pixel banks allow the two
// pixels decoded from each ROM byte to be written concurrently with only one
// write per physical memory. occupied=1 blocks every lower-priority sprite;
// visible=0 represents MAME's invisible pen-15 masking pass.
(* ramstyle = "MLAB, no_rw_check" *) reg [9:0] line0_even [0:127];
(* ramstyle = "MLAB, no_rw_check" *) reg [9:0] line0_odd  [0:127];
(* ramstyle = "MLAB, no_rw_check" *) reg [9:0] line1_even [0:127];
(* ramstyle = "MLAB, no_rw_check" *) reg [9:0] line1_odd  [0:127];

localparam ST_IDLE  = 3'd0;
localparam ST_CLEAR = 3'd1;
localparam ST_SCAN  = 3'd2;
localparam ST_GREQ  = 3'd3;
localparam ST_GWAIT = 3'd4;
localparam ST_GUSE  = 3'd5;
reg [2:0] render_state;
wire line_busy = render_state != ST_IDLE;
reg line_overrun;
reg [16:0] line_gfx_addr;
reg prep_bank;
reg [8:0] target_y;
reg [6:0] clear_x;
reg [6:0] scan_index;
reg [2:0] byte_index;
reg [9:0] active_code;
reg [4:0] active_color;
reg [3:0] active_row;
reg       active_flipx;
reg signed [9:0] active_sx;

wire [31:0] entry_data = sprite_ram[scan_index];
wire [7:0] entry_y    = entry_data[7:0];
wire [7:0] entry_x    = entry_data[15:8];
wire [7:0] entry_attr = entry_data[23:16];
wire [7:0] entry_code = entry_data[31:24];
wire [9:0] entry_code_full = soccer_sprites
	? {entry_attr[7],entry_attr[4],entry_code}
	: {2'b00,entry_code};
wire [4:0] entry_color = soccer_sprites
	? {1'b0,entry_attr[3:0]}
	: entry_attr[4:0];
wire entry_flipy = soccer_sprites
	? flipscreen
	: (entry_attr[7] ^ flipscreen);
wire signed [9:0] sx_normal = (entry_x >= 8'd248)
	? $signed({2'b11,entry_x}) : $signed({2'b00,entry_x});
wire signed [9:0] sy_normal = $signed({2'b00,entry_y}) - 10'sd32;
wire signed [9:0] entry_sx = flipscreen ? (10'sd240 - sx_normal) : sx_normal;
wire signed [9:0] entry_sy = flipscreen ? (10'sd176 - sy_normal) : sy_normal;
wire signed [9:0] entry_dy = $signed({1'b0,target_y}) - entry_sy;
wire entry_on_line = (target_y < 9'd192) && (entry_dy >= 0) && (entry_dy < 16);

wire [3:0] px_even = {byte_index,1'b0};
wire [3:0] px_odd  = {byte_index,1'b0} + 1'd1;
wire [3:0] local_x0 = active_flipx ? (4'd15 - px_even) : px_even;
wire [3:0] local_x1 = active_flipx ? (4'd15 - px_odd)  : px_odd;
wire signed [10:0] dst_x0 = $signed({active_sx[9],active_sx}) + $signed({7'b0,local_x0});
wire signed [10:0] dst_x1 = $signed({active_sx[9],active_sx}) + $signed({7'b0,local_x1});
wire [3:0] spr_pen0 = sprite_gfx_q[7:4];
wire [3:0] spr_pen1 = sprite_gfx_q[3:0];
wire write_pixel0 = (dst_x0 >= 0) && (dst_x0 < 256) && spr_pen0[3];
wire write_pixel1 = (dst_x1 >= 0) && (dst_x1 < 256) && spr_pen1[3];
wire choose0_even = write_pixel0 && !dst_x0[0];
wire choose0_odd  = write_pixel0 &&  dst_x0[0];
wire even_we = choose0_even || (write_pixel1 && !dst_x1[0]);
wire odd_we  = choose0_odd  || (write_pixel1 &&  dst_x1[0]);
wire [6:0] even_wr_addr = choose0_even ? dst_x0[7:1] : dst_x1[7:1];
wire [6:0] odd_wr_addr  = choose0_odd  ? dst_x0[7:1] : dst_x1[7:1];
wire [9:0] pixel_word0 = {1'b1,(spr_pen0 != 4'hf),active_color,spr_pen0[2:0]};
wire [9:0] pixel_word1 = {1'b1,(spr_pen1 != 4'hf),active_color,spr_pen1[2:0]};
wire [9:0] even_wr_data = choose0_even ? pixel_word0 : pixel_word1;
wire [9:0] odd_wr_data  = choose0_odd  ? pixel_word0 : pixel_word1;

// A bank is either displayed or prepared, never both.  Muxing the address
// before each array gives Quartus one asynchronous read and one write port.
wire [6:0] display_addr = bitmap_x[7:1];
wire [6:0] line0_even_addr = prep_bank ? display_addr : even_wr_addr;
wire [6:0] line0_odd_addr  = prep_bank ? display_addr : odd_wr_addr;
wire [6:0] line1_even_addr = prep_bank ? even_wr_addr : display_addr;
wire [6:0] line1_odd_addr  = prep_bank ? odd_wr_addr : display_addr;
wire [9:0] line0_even_q = line0_even[line0_even_addr];
wire [9:0] line0_odd_q  = line0_odd[line0_odd_addr];
wire [9:0] line1_even_q = line1_even[line1_even_addr];
wire [9:0] line1_odd_q  = line1_odd[line1_odd_addr];
wire [9:0] line_sprite_pixel = v_count[0]
	? (bitmap_x[0] ? line1_odd_q : line1_even_q)
	: (bitmap_x[0] ? line0_odd_q : line0_even_q);

wire [16:0] pcb_gfx_addr;
wire [9:0] pcb_sprite_pixel;
wire pcb_busy, pcb_overrun, pcb_frame_ready;
// NOTE: jtdocastle_pcb_sprite.v does not exist yet in this repo -- porting
// docastle_pcb_sprite.sv is out of scope for this task (see file header).
// Its .vblank port is untouched, active-high, matching docastle_pcb_sprite.sv
// exactly; since LVBL is now active-low, it is fed the inverted signal
// (~LVBL) here to reproduce the exact same electrical value that
// docastle_video.sv passed it, with zero behavioural change.
jtdocastle_pcb_sprite pcb_sprite
(
	.clk(clk), .reset(reset), .ce_pix(ce_pix), .enable(pcb_framebuffer),
	.h_count(h_count), .v_count(v_count), .vblank(~LVBL),
	.flipscreen(flipscreen), .soccer_sprites(soccer_sprites),
	.cpu_addr(pcb_sprite_addr), .cpu_data(pcb_sprite_din), .cpu_we(pcb_sprite_we),
	.cf_dram_address(cf_dram_address), .cf_dram_strobe(cf_dram_strobe),
	.cf_dram_column(cf_dram_column), .cf_dram_y(cf_dram_y), .cf_dram_x(cf_dram_x),
	.cf_palette(cf_palette), .cf_flip_x(cf_flip_x), .cf_flip_y(cf_flip_y),
	.cf_plus_one(cf_plus_one), .cf_serial_invert(cf_serial_invert),
	.gfx_addr(pcb_gfx_addr), .gfx_q(sprite_gfx_q), .pixel(pcb_sprite_pixel),
	.busy(pcb_busy), .overrun(pcb_overrun), .frame_ready(pcb_frame_ready)
);
assign sprite_gfx_addr = pcb_framebuffer ? pcb_gfx_addr : line_gfx_addr;
assign renderer_busy_debug = pcb_framebuffer ? pcb_busy : line_busy;
assign renderer_overrun_debug = pcb_framebuffer ? pcb_overrun : line_overrun;
wire [9:0] sprite_pixel = pcb_framebuffer ? pcb_sprite_pixel : line_sprite_pixel;

always @(posedge clk) begin
	if (reset) begin
		render_state <= ST_IDLE;
		line_overrun <= 0;
		prep_bank <= 0;
		target_y <= 0;
		clear_x <= 0;
		scan_index <= 0;
		byte_index <= 0;
		line_gfx_addr <= 0;
	end else begin
		if (!pcb_framebuffer && ce_pix && (h_count == 0) && (render_state != ST_IDLE))
			line_overrun <= 1;

		// Begin rendering line N+1 as line N starts. 3120 master-clock
		// slots are available, enough for clear + all 128 sprite entries.
		if (!pcb_framebuffer && ce_pix && (h_count == 0)) begin
			prep_bank <= ~v_count[0];
			target_y <= (v_count == 9'd263) ? 9'd0 : v_count + 1'd1;
			clear_x <= 0;
			render_state <= ST_CLEAR;
		end else begin
			case (render_state)
			ST_IDLE: ;
			ST_CLEAR: begin
				if (prep_bank) begin
					line1_even[clear_x] <= 10'd0;
					line1_odd[clear_x] <= 10'd0;
				end else begin
					line0_even[clear_x] <= 10'd0;
					line0_odd[clear_x] <= 10'd0;
				end
				if (clear_x == 7'h7f) begin
					scan_index <= 7'd127;
					render_state <= ST_SCAN;
				end else clear_x <= clear_x + 1'd1;
			end
			ST_SCAN: begin
				if (entry_on_line) begin
					active_code <= entry_code_full;
					active_color <= entry_color;
					active_flipx <= entry_attr[6] ^ flipscreen;
					active_sx <= entry_sx;
					active_row <= entry_flipy
						? (4'd15 - entry_dy[3:0]) : entry_dy[3:0];
					byte_index <= 0;
					render_state <= ST_GREQ;
				end else if (scan_index == 0) render_state <= ST_IDLE;
				else scan_index <= scan_index - 1'd1;
			end
			ST_GREQ: begin
				line_gfx_addr <= {active_code,7'b0000000}
					+ {10'd0,active_row,3'b000} + {14'd0,byte_index};
				render_state <= ST_GWAIT;
			end
			ST_GWAIT: render_state <= ST_GUSE;
			ST_GUSE: begin
				if (prep_bank) begin
					if (even_we && !line1_even_q[9]) line1_even[even_wr_addr] <= even_wr_data;
					if (odd_we  && !line1_odd_q[9])  line1_odd[odd_wr_addr]   <= odd_wr_data;
				end else begin
					if (even_we && !line0_even_q[9]) line0_even[even_wr_addr] <= even_wr_data;
					if (odd_we  && !line0_odd_q[9])  line0_odd[odd_wr_addr]   <= odd_wr_data;
				end

				if (byte_index == 3'd7) begin
					if (scan_index == 0) render_state <= ST_IDLE;
					else begin
						scan_index <= scan_index - 1'd1;
						render_state <= ST_SCAN;
					end
				end else begin
					byte_index <= byte_index + 1'd1;
					// Request the next byte while committing this one. The
					// synchronous ROM updates during ST_GWAIT, reducing each
					// remaining byte from three master clocks to two. Even all
					// 128 sprites on one line now finish well before the next line.
					line_gfx_addr <= {active_code,7'b0000000}
						+ {10'd0,active_row,3'b000}
						+ {14'd0,byte_index} + 17'd1;
					render_state <= ST_GWAIT;
				end
			end
			default: render_state <= ST_IDLE;
			endcase
		end
	end
end

// Colour-mix taps for jtdocastle_colmix.v (see port list note). These are the
// exact same three signals this module feeds into its own priority mux below.
assign mix_tile_pen     = tile_pen;
assign mix_tile_color   = tile_attr[4:0];
assign mix_sprite_pixel = sprite_pixel;

wire tile_front = low_pen_priority ? ~tile_pen[3] : tile_pen[3];
wire use_sprite = !tile_front && sprite_pixel[9] && sprite_pixel[8];
wire [4:0] final_color = use_sprite ? sprite_pixel[7:3] : tile_attr[4:0];
wire [2:0] final_pen   = use_sprite ? sprite_pixel[2:0] : tile_pen[2:0];
assign prom_addr = {final_color,final_pen};

// PROM resistor network, matching MAME's 0x23/0x4b/0x91 and 0x52/0xad.
assign r = (prom_q[5] ? 8'h23 : 8'h00) + (prom_q[6] ? 8'h4b : 8'h00) + (prom_q[7] ? 8'h91 : 8'h00);
assign g = (prom_q[2] ? 8'h23 : 8'h00) + (prom_q[3] ? 8'h4b : 8'h00) + (prom_q[4] ? 8'h91 : 8'h00);
assign b = (prom_q[0] ? 8'h52 : 8'h00) + (prom_q[1] ? 8'had : 8'h00);

endmodule
