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

    Author: aCORES
    Version: 1.0
    Date: 18-8-2026 */

//============================================================================
// Board-relevant HD6845S model for the Universal Do! Castle hardware family.
//
// The CRTC runs at one character clock per eight pixels.  Vertical total,
// total-adjust, maximum raster, displayed rows, sync position, start
// address, MA/RA and CURSOR all come from the programmed registers.  The
// default register image is the measured 312x264, 240x192 board mode, so
// reset never emits a malformed partial frame.
//
// Ported from the standalone MiSTer Universal_DoCastle core this core derives
// from, using jtframe's video-signal convention -- see jtdcastl_video.v's
// header for the LHBL/LVBL polarity note.
//============================================================================
module jtdcastl_crtc
(
    input             clk,
    input             reset,
    input             ce_pix,
    input             cursor_irq_mode,

    // Register file access (frame-shadowed: writes land in `pending` and
    // only take effect at the next vertical-total/adjust boundary)
    input      [ 4:0] reg_sel,
    input      [ 7:0] reg_data,
    input             reg_we,

    // Raster position, blanking and sync
    output     [ 8:0] h_count,
    output     [ 8:0] v_count,
    output            HS,
    output            VS,
    output            LHBL,           // active low, per jtframe convention
    output            LVBL,           // active low, per jtframe convention
    output            cursor,

    // CRTC address outputs
    output     [13:0] ma,
    output     [ 4:0] ra,

    // Interrupts
    output            main_irq_n,
    output reg        sub_irq_req,
    output reg        sprite_nmi_req
);

reg [7:0] crtc [0:17];
reg [7:0] pending [0:17];
integer ri;
reg [8:0] h_ctr, v_ctr;
reg [6:0] row_ctr;
reg [4:0] ra_ctr, adjust_ctr;
reg in_adjust;
reg [5:0] frame_ctr;
reg [13:0] ma_row_addr;
reg timing_ready;
reg vs_active;
reg [4:0] vs_count;

assign h_count = h_ctr;
assign v_count = v_ctr;
assign ra = ra_ctr;

wire [9:0] h_total = ({2'b00,crtc[0]} + 10'd1) << 3;
wire [9:0] h_display = {2'b00,crtc[1]} << 3;
wire [9:0] h_sync_start = {2'b00,crtc[2]} << 3;
wire [7:0] h_sync_width = (crtc[3][3:0] != 0)
	? ({4'b0000,crtc[3][3:0]} << 3) : 8'd128;
wire [9:0] h_sync_end = h_sync_start + {2'b00,h_sync_width};
wire [8:0] raster_height = {4'b0000,crtc[9][4:0]} + 9'd1;
wire [8:0] v_sync_start = {2'b00,crtc[7][6:0]} * raster_height;
wire [4:0] v_sync_width = (crtc[3][7:4] != 0)
	? {1'b0,crtc[3][7:4]} : 5'd16;
wire [9:0] h_active_end = (h_display > 10'd8) ? h_display - 10'd8 : 10'd0;

assign HS = ({1'b0,h_ctr} >= h_sync_start) &&
	({1'b0,h_ctr} < h_sync_end);
assign VS = vs_active;

// The board blanks one character around the CRTC's 32-character display.
// This produces the documented x=8..247 aperture while still following R1.
// LHBL/LVBL are jtframe's active-low blanking convention (1 = active
// display, 0 = blanked -- see modules/jtframe/hdl/video/jtframe_vtimer.v),
// the exact inverse electrical sense of the source core's active-high
// hblank/vblank. The blanking WINDOW below (start/end compare terms) is
// unchanged; only the final polarity is flipped to match the convention.
assign LHBL = !((h_ctr < 9'd8) || ({1'b0,h_ctr} >= h_active_end));
assign LVBL = !(in_adjust || (row_ctr >= crtc[6][6:0]));

wire [13:0] pending_start_addr = {pending[12][5:0],pending[13]};
wire pending_mode_valid = (pending[0] != 0) && (pending[1] != 0) &&
	(pending[4] != 0) && (pending[6] != 0);
wire [13:0] cursor_addr = {crtc[14][5:0],crtc[15]};
assign ma = ma_row_addr + {8'd0,h_ctr[8:3]};
// The proven board-family cadence observes MA6 across total-adjust as though
// the address row continues from the raw scan count.  Keep that behaviour for
// the release VSYNC path; the fully programmed MA is retained in CURSOR
// research mode where it can be compared independently.
wire [13:0] compatibility_row_offset = v_ctr[8:3] * crtc[1];
wire [13:0] compatibility_ma = {crtc[12][5:0],crtc[13]} +
	compatibility_row_offset + {8'd0,h_ctr[8:3]};
wire sampled_ma6 = cursor_irq_mode ? ma[6] : compatibility_ma[6];

reg cursor_blink;
always @(*) begin
	case (crtc[10][6:5])
		2'b00: cursor_blink = 1'b1;
		2'b01: cursor_blink = 1'b0;
		2'b10: cursor_blink = ~frame_ctr[4];
		default: cursor_blink = ~frame_ctr[5];
	endcase
end

// R8 cursor skew value 3 disables CURSOR on the HD6845 family.  Values 1/2
// delay it by characters; no supported game programs a non-zero delay.
wire [1:0] cursor_skew = crtc[8][7:6];
wire [13:0] cursor_compare_ma = ma - {12'd0,cursor_skew};
assign cursor = !in_adjust && (cursor_skew != 2'b11) &&
	(row_ctr < crtc[6][6:0]) && ({1'b0,h_ctr} < h_display) &&
	(cursor_compare_ma == cursor_addr) &&
	(ra_ctr >= crtc[10][4:0]) && (ra_ctr <= crtc[11][4:0]) &&
	cursor_blink;

// The physical CRTC powers up unprogrammed.  Do not expose the reset-image
// cursor as an interrupt until software's first complete register frame has
// been sampled; otherwise an impossible scanline-zero IRQ races Z80 startup.
wire interrupt_level = cursor_irq_mode ? (cursor & timing_ready) : VS;
assign main_irq_n = ~interrupt_level;
reg prev_ma6, prev_interrupt;

always @(posedge clk) begin
	if (reset) begin
		crtc[0] <= 8'h26; crtc[1] <= 8'h20; crtc[2] <= 8'h22;
		crtc[3] <= 8'h62; crtc[4] <= 8'h1f; crtc[5] <= 8'h08;
		crtc[6] <= 8'h18; crtc[7] <= 8'h1c; crtc[8] <= 8'h00;
		crtc[9] <= 8'h07; crtc[10] <= 8'h00; crtc[11] <= 8'h00;
		crtc[12] <= 8'h00; crtc[13] <= 8'h80; crtc[14] <= 8'h00;
		crtc[15] <= 8'h82; crtc[16] <= 8'h00; crtc[17] <= 8'h00;
		pending[0] <= 8'h26; pending[1] <= 8'h20; pending[2] <= 8'h22;
		pending[3] <= 8'h62; pending[4] <= 8'h1f; pending[5] <= 8'h08;
		pending[6] <= 8'h18; pending[7] <= 8'h1c; pending[8] <= 8'h00;
		pending[9] <= 8'h07; pending[10] <= 8'h00; pending[11] <= 8'h00;
		pending[12] <= 8'h00; pending[13] <= 8'h80; pending[14] <= 8'h00;
		pending[15] <= 8'h82; pending[16] <= 8'h00; pending[17] <= 8'h00;
		h_ctr <= 0; v_ctr <= 0; row_ctr <= 0; ra_ctr <= 0;
		adjust_ctr <= 0; in_adjust <= 0; frame_ctr <= 0;
		ma_row_addr <= 14'h0080;
		timing_ready <= 0;
		vs_active <= 0; vs_count <= 0;
		prev_ma6 <= 0; prev_interrupt <= 0;
		sub_irq_req <= 0; sprite_nmi_req <= 0;
	end else begin
		// The HD6845 timing/start registers are sampled for the next frame.
		// This prevents a software register burst during active display from
		// creating a physically impossible partial raster.
		if (reg_we && (reg_sel < 18)) pending[reg_sel] <= reg_data;
		sub_irq_req <= 0;
		sprite_nmi_req <= 0;

		if (ce_pix) begin
			prev_interrupt <= interrupt_level;
			if (interrupt_level && !prev_interrupt) sprite_nmi_req <= 1;
			if ({1'b0,h_ctr} == h_sync_start) begin
				if (sampled_ma6 && !prev_ma6) sub_irq_req <= 1;
				prev_ma6 <= sampled_ma6;
			end

			if ((h_total <= 10'd1) || ({1'b0,h_ctr} == (h_total - 1'd1))) begin
				h_ctr <= 0;
				// VSYNC is a scanline-width monostable in the HD6845, not a
				// simple vertical-address comparison.  This matters while the
				// game intentionally clears the timing registers: a short frame
				// must not leave VSYNC permanently asserted.
				if (vs_active) begin
					if (vs_count >= v_sync_width) begin
						vs_active <= 0;
						vs_count <= 0;
					end else vs_count <= vs_count + 1'd1;
				end else if (((in_adjust && ((crtc[5][4:0] == 0) ||
					(adjust_ctr + 1'd1 >= crtc[5][4:0]))) ||
					(!in_adjust && (ra_ctr >= crtc[9][4:0]) &&
					(row_ctr >= crtc[4][6:0]) && (crtc[5][4:0] == 0)))
					? (v_sync_start == 0) : (v_ctr + 1'd1 == v_sync_start)) begin
					vs_active <= 1;
					vs_count <= 1;
				end
				if (in_adjust) begin
					if ((crtc[5][4:0] == 0) ||
						(adjust_ctr + 1'd1 >= crtc[5][4:0])) begin
						v_ctr <= 0; row_ctr <= 0; ra_ctr <= 0;
						adjust_ctr <= 0; in_adjust <= 0;
						ma_row_addr <= pending_mode_valid ? pending_start_addr
							: {crtc[12][5:0],crtc[13]};
						if (pending_mode_valid)
							for (ri=0; ri<18; ri=ri+1) crtc[ri] <= pending[ri];
						frame_ctr <= frame_ctr + 1'd1;
						timing_ready <= 1;
					end else begin
						v_ctr <= v_ctr + 1'd1;
						adjust_ctr <= adjust_ctr + 1'd1;
					end
				end else if (ra_ctr >= crtc[9][4:0]) begin
					ra_ctr <= 0;
					if (row_ctr >= crtc[4][6:0]) begin
						if (crtc[5][4:0] != 0) begin
							v_ctr <= v_ctr + 1'd1;
							in_adjust <= 1;
							adjust_ctr <= 0;
						end else begin
							v_ctr <= 0; row_ctr <= 0;
							ma_row_addr <= pending_mode_valid ? pending_start_addr
								: {crtc[12][5:0],crtc[13]};
							if (pending_mode_valid)
								for (ri=0; ri<18; ri=ri+1) crtc[ri] <= pending[ri];
							frame_ctr <= frame_ctr + 1'd1;
							timing_ready <= 1;
						end
					end else begin
						v_ctr <= v_ctr + 1'd1;
						row_ctr <= row_ctr + 1'd1;
						ma_row_addr <= ma_row_addr + {6'd0,crtc[1]};
					end
				end else begin
					v_ctr <= v_ctr + 1'd1;
					ra_ctr <= ra_ctr + 1'd1;
				end
			end else h_ctr <= h_ctr + 1'd1;
		end
	end
end

wire _unused = &{1'b0,crtc[16],crtc[17]};
endmodule
