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

    Author: meathax
    Version: 1.0
    Date: 18-8-2026 */

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
    output reg        sprite_nmi_req,

    // Scene IOCTL dump of the MMR register file (18 bytes, mmr.yaml `crtc`).
    // Driven by/exposed to jtdcastl_game, which muxes it into the aggregate
    // IOCTL_RD aux tap alongside the mem.yaml BRAM blocks.
    input      [ 4:0] ioctl_addr,
    output     [ 7:0] ioctl_din
);

reg [7:0] crtc [0:17];
wire [7:0] pending [0:17];
wire [7:0] r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14,r15,r16,r17;

jtdcastl_crtc_mmr #(.INIT(144'h000082008000000007001c18081f62222026)) u_mmr(
	.rst(reset), .clk(clk),
	.cs(reg_we), .addr(reg_sel[4:0]), .rnw(1'b0), .din(reg_data), .dout(),
	.r0(r0),.r1(r1),.r2(r2),.r3(r3),.r4(r4),.r5(r5),.r6(r6),.r7(r7),.r8(r8),
	.r9(r9),.r10(r10),.r11(r11),.r12(r12),.r13(r13),.r14(r14),.r15(r15),
	.r16(r16),.r17(r17),
	.ioctl_addr(ioctl_addr), .ioctl_din(ioctl_din), .debug_bus(8'd0), .st_dout()
);

assign pending[0]=r0;   assign pending[1]=r1;   assign pending[2]=r2;
assign pending[3]=r3;   assign pending[4]=r4;   assign pending[5]=r5;
assign pending[6]=r6;   assign pending[7]=r7;   assign pending[8]=r8;
assign pending[9]=r9;   assign pending[10]=r10; assign pending[11]=r11;
assign pending[12]=r12; assign pending[13]=r13; assign pending[14]=r14;
assign pending[15]=r15; assign pending[16]=r16; assign pending[17]=r17;
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

assign LHBL = !((h_ctr < 9'd8) || ({1'b0,h_ctr} >= h_active_end));
assign LVBL = !(in_adjust || (row_ctr >= crtc[6][6:0]));

wire [13:0] pending_start_addr = {pending[12][5:0],pending[13]};
wire pending_mode_valid = (pending[0] != 0) && (pending[1] != 0) &&
	(pending[4] != 0) && (pending[6] != 0);
wire [13:0] cursor_addr = {crtc[14][5:0],crtc[15]};
assign ma = ma_row_addr + {8'd0,h_ctr[8:3]};
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
		h_ctr <= 0; v_ctr <= 0; row_ctr <= 0; ra_ctr <= 0;
		adjust_ctr <= 0; in_adjust <= 0; frame_ctr <= 0;
		ma_row_addr <= 14'h0080;
		timing_ready <= 0;
		vs_active <= 0; vs_count <= 0;
		prev_ma6 <= 0; prev_interrupt <= 0;
		sub_irq_req <= 0; sprite_nmi_req <= 0;
	end else begin
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
