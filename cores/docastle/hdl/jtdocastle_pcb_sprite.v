// UNVERIFIED DRAFT -- ported from mrdo/rtl/docastle_pcb_sprite.sv, not yet compiled or simulated against real jtframe tooling.
//
//============================================================================
// PCB-style sprite framebuffer (CF37201-driven alternate renderer).
//
// The original board renders sprites into alternating 64Kx8 DRAM fields.
// Both complete 256x256 fields are retained here, including the hidden top 32
// lines used by the PCB coordinate system.  Rendering is confined to vertical
// blank and fields swap only at the following frame boundary.
//
// STATUS -- NOT YET HARDWARE-VERIFIED, NON-DEFAULT. Per mrdo's README.md
// ("PCB accuracy" section): "This is separate from the CF37201's decap-
// derived alternate framebuffer renderer, which remains off and unreachable
// from the OSD: like the rest of this core it is deterministic and
// regression-tested against MAME frame-by-frame across all nine sets, but has
// not yet been confirmed against a physical Do's Castle PCB, since no board
// has been available during development. The proven direct sprite renderer
// remains the only renderer shipped until that comparison exists." That
// caution applies unchanged to this port: this module exists here so
// jtdocastle_video.v elaborates (it already instantiates jtdocastle_pcb_sprite
// unconditionally), but it must stay non-default and not be exposed as a
// selectable OSD/DIP path until a later integration pass wires it behind
// jtframe's status-bit convention and it is confirmed against real hardware.
// jtdocastle_video.v currently ties this instance's `enable` straight to its
// own `pcb_framebuffer` input with no jtframe status-bit gating decided yet --
// that wiring/default is OUT OF SCOPE for this file and is flagged here for
// the later integration pass, exactly matching mrdo's own default-off
// caution.
//
// Ported from docastle_pcb_sprite.sv (mrdo repo). This is a PURE RELOCATION
// pass: no timing value, register/counter behaviour, DRAM field addressing,
// clear/scan/render state machine or CF-write interception logic changed.
//
//   docastle_pcb_sprite.sv  ->  jtdocastle_pcb_sprite.v
//   docastle_field_ram      ->  jtdocastle_field_ram      (pure rename, see
//                                                           note below)
//   ------------------------------------------------------------------------
//   vblank (active-HIGH: 1 = blanked, port name "vblank") -> UNCHANGED, on
//     purpose. jtdocastle_video.v already instantiates this module as
//     jtdocastle_pcb_sprite with a `.vblank` port in this exact original
//     name and polarity (fed `~LVBL` from the caller to reproduce the same
//     electrical value docastle_video.sv passed docastle_pcb_sprite.sv). Per
//     this task's instructions, that established caller-side interface is
//     matched from this file, not changed. This is the one port in this
//     port pass that is deliberately NOT aligned to jtframe's LHBL/LVBL
//     active-low convention (see modules/jtframe/doc/style.md) -- flagging
//     this explicitly rather than silently leaving it, since every other
//     video-timing signal touched elsewhere in this core's port (hs/vs/
//     hblank in jtdocastle_crtc.v/jtdocastle_video.v) was renamed+inverted.
//   All other ports/signals (h_count, v_count, ce_pix, enable, flipscreen,
//   soccer_sprites, cpu_addr/cpu_data/cpu_we, cf_dram_address/strobe/column/
//   y/x, cf_palette/flip_x/flip_y/plus_one/serial_invert, gfx_addr/gfx_q,
//   pixel, busy, overrun, frame_ready and all internal state) -> unchanged
//   names and behaviour, carried over verbatim.
//
// FLAGGED (structural, not behavioural): docastle_pcb_sprite.sv defines two
// modules in one file (docastle_pcb_sprite + docastle_field_ram). jtframe's
// style.md states "Each verilog file contains only one module". Splitting
// jtdocastle_field_ram into its own file was judged out of scope for a pure-
// relocation port -- it is a mechanical move, not a rename or behavioural
// change, but it was not requested and is flagged here for a later
// integration pass to decide (either split it out, or accept this file as a
// documented exception since jtdocastle_field_ram is private to this module
// and instantiated nowhere else).
//============================================================================
module jtdocastle_pcb_sprite
(
	input clk, input reset, input ce_pix, input enable,
	input [8:0] h_count, input [8:0] v_count, input vblank,
	input flipscreen, input soccer_sprites,
	input [8:0] cpu_addr, input [7:0] cpu_data, input cpu_we,
	input [15:0] cf_dram_address, input cf_dram_strobe, input cf_dram_column,
	input [7:0] cf_dram_y, input [7:0] cf_dram_x,
	input [4:0] cf_palette, input cf_flip_x, input cf_flip_y,
	input cf_plus_one, input cf_serial_invert,
	output reg [16:0] gfx_addr, input [7:0] gfx_q,
	output [9:0] pixel,
	output busy, output reg overrun, output reg frame_ready
);

(* ramstyle = "MLAB, no_rw_check" *) reg [31:0] sprite_ram [0:127];
always @(posedge clk) begin
	if (cpu_we) begin
		case (cpu_addr[1:0])
		2'd0: sprite_ram[cpu_addr[8:2]][7:0] <= cpu_data;
		2'd1: sprite_ram[cpu_addr[8:2]][15:8] <= cpu_data;
		2'd2: sprite_ram[cpu_addr[8:2]][23:16] <= cpu_data;
		2'd3: sprite_ram[cpu_addr[8:2]][31:24] <= cpu_data;
		endcase
	end
end

reg display_bank, display_valid;
reg [15:0] display_addr, build_addr;
// The three stored pen bits already distinguish a visible source pen (0-6)
// from pen 15's priority mask (7).  Keep one private occupancy bit plus the
// board's eight colour/pen bits; reconstruct the renderer's visible flag on
// read instead of spending a redundant RAM bit in both 64K fields.
wire [8:0] field0_q, field1_q;
wire [8:0] display_q = display_bank ? field1_q : field0_q;
wire [8:0] build_q = display_bank ? field0_q : field1_q;
reg fb_we;
reg [15:0] fb_addr;
reg [8:0] fb_data;
reg fb_field;
// A CF byte is a two-pixel external-DRAM location.  The renderer normally
// writes the descriptor-derived address, but a live CF transaction takes the
// TAL004's assembled address and field select all the way to the field RAM.
wire cf_bus_write = cf_dram_strobe && cf_dram_column;
wire [15:0] cf_pixel_addr = {cf_dram_y,cf_dram_x};
wire [15:0] cf_pixel_addr_plus = cf_pixel_addr + (cf_plus_one ? 16'd1 : 16'd0);
wire [15:0] write_addr0 = cf_bus_write ? cf_pixel_addr : p0_addr;
wire [15:0] write_addr1 = cf_bus_write ? cf_pixel_addr_plus : p1_addr;
wire write_field = cf_bus_write ? cf_dram_address[15] : fb_field;
wire [3:0] write_pen0 = cf_bus_write && cf_serial_invert ? ~pen0 : pen0;
wire [3:0] write_pen1 = cf_bus_write && cf_serial_invert ? ~pen1 : pen1;
wire [8:0] write_word0 = {1'b1,cf_bus_write ? cf_palette : active_color,write_pen0[2:0]};
wire [8:0] write_word1 = {1'b1,cf_bus_write ? cf_palette : active_color,write_pen1[2:0]};
wire [15:0] field0_rd_addr = display_bank ? build_addr : display_addr;
wire [15:0] field1_rd_addr = display_bank ? display_addr : build_addr;

jtdocastle_field_ram field0
(
	.clk(clk), .rd_addr(field0_rd_addr), .rd_data(field0_q),
	.wr_addr(fb_addr), .wr_data(fb_data), .wr_en(fb_we && !fb_field)
);
jtdocastle_field_ram field1
(
	.clk(clk), .rd_addr(field1_rd_addr), .rd_data(field1_q),
	.wr_addr(fb_addr), .wr_data(fb_data), .wr_en(fb_we && fb_field)
);

always @(posedge clk) begin
	if (h_count < 256 && v_count < 192)
		display_addr <= {v_count[7:0] + 8'd32,h_count[7:0]};
end
wire [9:0] display_pixel = {display_q[8],display_q[2:0] != 3'd7,display_q[7:0]};
assign pixel = (enable && display_valid && h_count < 256 && v_count < 192)
	? display_pixel : 10'd0;

localparam ST_IDLE  = 4'd0;
localparam ST_CLEAR = 4'd1;
localparam ST_SCAN  = 4'd2;
localparam ST_GREQ  = 4'd3;
localparam ST_GWAIT = 4'd4;
localparam ST_P0REQ = 4'd5;
localparam ST_P0WAIT= 4'd6;
localparam ST_P0USE = 4'd7;
localparam ST_P1REQ = 4'd8;
localparam ST_P1WAIT= 4'd9;
localparam ST_P1USE = 4'd10;
reg [3:0] state;
assign busy = state != ST_IDLE;

reg prev_vblank;
reg [15:0] clear_addr;
reg [6:0] scan_index;
reg [3:0] row_index;
reg [2:0] byte_index;
reg [9:0] active_code;
reg [4:0] active_color;
reg active_flipx, active_flipy;
reg signed [9:0] active_sx, active_sy;

wire [31:0] entry = sprite_ram[scan_index];
wire [9:0] entry_code = soccer_sprites
	? {entry[23],entry[20],entry[31:24]} : {2'b00,entry[31:24]};
wire [4:0] entry_color = soccer_sprites ? {1'b0,entry[19:16]} : entry[20:16];
wire signed [9:0] entry_x = (entry[15:8] >= 8'd248)
	? $signed({2'b11,entry[15:8]}) : $signed({2'b00,entry[15:8]});
wire signed [9:0] entry_sx = flipscreen ? (10'sd240 - entry_x) : entry_x;
wire signed [9:0] entry_sy = flipscreen
	? (10'sd240 - $signed({2'b00,entry[7:0]}))
	: $signed({2'b00,entry[7:0]});

wire render_flipy = cf_bus_write ? cf_flip_y : active_flipy;
wire render_flipx = cf_bus_write ? cf_flip_x : active_flipx;
wire [3:0] source_row = render_flipy ? (4'd15-row_index) : row_index;
wire [3:0] source_x0 = {byte_index,1'b0};
wire [3:0] source_x1 = {byte_index,1'b0} + 1'd1;
wire [3:0] local_x0 = render_flipx ? (4'd15-source_x0) : source_x0;
wire [3:0] local_x1 = render_flipx ? (4'd15-source_x1) : source_x1;
wire signed [10:0] dst_x0 = $signed({active_sx[9],active_sx}) + $signed({7'b0,local_x0});
wire signed [10:0] dst_x1 = $signed({active_sx[9],active_sx}) + $signed({7'b0,local_x1});
wire signed [10:0] dst_y = $signed({active_sy[9],active_sy}) + $signed({7'b0,row_index});
wire p0_in_range = dst_x0 >= 0 && dst_x0 < 256 && dst_y >= 0 && dst_y < 256;
wire p1_in_range = dst_x1 >= 0 && dst_x1 < 256 && dst_y >= 0 && dst_y < 256;
wire [15:0] p0_addr = {dst_y[7:0],dst_x0[7:0]};
wire [15:0] p1_addr = {dst_y[7:0],dst_x1[7:0]};
wire [3:0] pen0 = gfx_q[7:4];
wire [3:0] pen1 = gfx_q[3:0];
wire [8:0] word0 = {1'b1,active_color,pen0[2:0]};
wire [8:0] word1 = {1'b1,active_color,pen1[2:0]};

task automatic advance_pair;
	begin
		if (byte_index == 3'd7) begin
			byte_index <= 0;
			if (row_index == 4'd15) begin
				row_index <= 0;
				if (scan_index == 0) begin
					state <= ST_IDLE;
					frame_ready <= 1;
				end else begin
					scan_index <= scan_index - 1'd1;
					state <= ST_SCAN;
				end
			end else begin
				row_index <= row_index + 1'd1;
				state <= ST_GREQ;
			end
		end else begin
			byte_index <= byte_index + 1'd1;
			state <= ST_GREQ;
		end
	end
endtask

always @(posedge clk) begin
	prev_vblank <= vblank;
	fb_we <= 0;
	if (reset || !enable) begin
		state <= ST_IDLE; display_bank <= 0; display_valid <= 0;
		frame_ready <= 0; overrun <= 0; prev_vblank <= 0;
		clear_addr <= 0; scan_index <= 0; row_index <= 0; byte_index <= 0;
		gfx_addr <= 0; build_addr <= 0; fb_addr <= 0; fb_data <= 0; fb_field <= 0;
	end else begin
		if (ce_pix && h_count == 0 && v_count == 0) begin
			if (frame_ready) begin
				display_bank <= ~display_bank;
				display_valid <= 1;
				frame_ready <= 0;
			end else if (display_valid) overrun <= 1;
		end
		if (ce_pix && vblank && !prev_vblank) begin
			if (state != ST_IDLE) overrun <= 1;
			else begin
				clear_addr <= 0;
				state <= ST_CLEAR;
			end
		end else begin
			case (state)
			ST_IDLE: ;
			ST_CLEAR: begin
				fb_we <= 1; fb_addr <= clear_addr; fb_data <= 0;
				fb_field <= ~display_bank;
				if (clear_addr == 16'hffff) begin
					scan_index <= 7'd127; row_index <= 0; byte_index <= 0;
					state <= ST_SCAN;
				end else clear_addr <= clear_addr + 1'd1;
			end
			ST_SCAN: begin
				active_code <= entry_code;
				active_color <= entry_color;
				active_flipx <= entry[22] ^ flipscreen;
				active_flipy <= soccer_sprites ? flipscreen : (entry[23] ^ flipscreen);
				active_sx <= entry_sx; active_sy <= entry_sy;
				state <= ST_GREQ;
			end
			ST_GREQ: begin
				gfx_addr <= {active_code,7'b0000000} +
					{10'd0,source_row,3'b000} + {14'd0,byte_index};
				state <= ST_GWAIT;
			end
			ST_GWAIT: state <= ST_P0REQ;
			ST_P0REQ: begin
				if (pen0[3] && p0_in_range) begin
					build_addr <= p0_addr; state <= ST_P0WAIT;
				end else state <= ST_P1REQ;
			end
			ST_P0WAIT: state <= ST_P0USE;
			ST_P0USE: begin
				if (!build_q[8]) begin
					fb_we <= 1; fb_addr <= write_addr0; fb_data <= write_word0;
					fb_field <= cf_bus_write ? cf_dram_address[15] : ~display_bank;
				end
				state <= ST_P1REQ;
			end
			ST_P1REQ: begin
				if (pen1[3] && p1_in_range) begin
					build_addr <= p1_addr; state <= ST_P1WAIT;
				end else advance_pair();
			end
			ST_P1WAIT: state <= ST_P1USE;
			ST_P1USE: begin
				if (!build_q[8]) begin
					fb_we <= 1; fb_addr <= write_addr1; fb_data <= write_word1;
					fb_field <= cf_bus_write ? cf_dram_address[15] : ~display_bank;
				end
				advance_pair();
			end
			default: state <= ST_IDLE;
			endcase
		end
	end
end
endmodule

// Quartus 17 simple-dual-port inference template used for each physical field.
// Renamed only (docastle_field_ram -> jtdocastle_field_ram) for this port's
// jtdocastle_* naming convention; behaviour unchanged. See file header for the
// flagged one-module-per-file style.md deviation this second module causes.
module jtdocastle_field_ram
(
	input clk,
	input [15:0] rd_addr,
	output reg [8:0] rd_data,
	input [15:0] wr_addr,
	input [8:0] wr_data,
	input wr_en
);
(* ramstyle = "M10K, no_rw_check" *) reg [8:0] mem [0:65535];
always @(posedge clk) begin
	rd_data <= mem[rd_addr];
	if (wr_en) mem[wr_addr] <= wr_data;
end
endmodule
