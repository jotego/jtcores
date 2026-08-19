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

module jtdcastl_cf37201
(
	input clk, input reset, input ce_mclk,
	input bus_we, input [1:0] bus_addr, input [7:0] bus_data,
	input frame_parity, input irq_ack,
	output reg irq_req,
	output [7:0] dram_addr,
	output [15:0] dram_address,
	output dram_strobe, output dram_column,
	output [7:0] dram_y, output [7:0] dram_x,
	output [4:0] palette,
	output flip_x, output flip_y, output plus_one, output serial_invert,
	output busy, output reg overrun, output [7:0] reg2_debug
);

reg [7:0] reg0, reg1, reg1b, reg2;
reg [7:0] y_count;
reg [6:0] x_count;
reg [6:0] pl_count;
reg [1:0] h0_phase;
reg [2:0] pair_in_line;
reg blit_busy;
reg [4:0] palette_latch;
reg flip_x_latch, flip_y_latch;

assign busy = blit_busy;
assign reg2_debug = reg2;
assign palette = palette_latch;
assign flip_x = flip_x_latch;
assign flip_y = flip_y_latch;

// Pin 36 selects the row or column half of the shared eight-bit DRAM bus.
// FYYYYYYY is emitted on one phase and V0XXXXXXX on the other.
assign dram_addr = h0_phase[1]
	? {frame_parity,y_count[7:1]} : {y_count[0],x_count};
// The chip presents F+Y and Y0+X on alternating phases. Keep the assembled
// byte address available to the external DRAM model as well.
assign dram_address = {frame_parity,y_count,x_count};
assign dram_y = y_count;
assign dram_x = {x_count,1'b0};
assign dram_column = h0_phase[1];
assign dram_strobe = ce_mclk && blit_busy && (h0_phase == 2'b11);
assign plus_one = reg1b[0] & blit_busy & h0_phase[1];
assign serial_invert = reg1b[0] ^ reg2[6];

always @(posedge clk) begin
	if (reset) begin
		reg0 <= 0; reg1 <= 0; reg1b <= 0; reg2 <= 0;
		y_count <= 0; x_count <= 0; pl_count <= 0;
		h0_phase <= 0; pair_in_line <= 0; blit_busy <= 0;
		palette_latch <= 0; flip_x_latch <= 0; flip_y_latch <= 0;
		irq_req <= 0; overrun <= 0;
	end else begin
		// PACC is the Z80 /IORQ interrupt-acknowledge phase.  REG2 bit 5
		// also disables and releases PINT exactly as on the gate array.
		if (irq_ack || reg2[5]) irq_req <= 0;
		if (irq_ack && !reg2[5] && !blit_busy) begin
			reg1b <= reg1;
			y_count <= reg0;
			x_count <= reg1[7:1];
			flip_y_latch <= ~reg2[7];
			flip_x_latch <= ~reg2[6];
			pl_count <= 0;
			h0_phase <= 0;
			pair_in_line <= 0;
			blit_busy <= 1;
		end

		if (bus_we) begin
			case (bus_addr)
				2'd0: reg0 <= bus_data;
				2'd1: reg1 <= bus_data;
				2'd2: begin
					reg2 <= bus_data;
					if (bus_data[5]) irq_req <= 0;
					if (reg2[5] && !bus_data[5]) begin
						if (blit_busy) overrun <= 1;
						reg1b <= reg1;
						y_count <= reg0;
						x_count <= reg1[7:1];
						flip_y_latch <= ~bus_data[7];
						flip_x_latch <= ~bus_data[6];
						pl_count <= 0;
						h0_phase <= 0;
						pair_in_line <= 0;
						blit_busy <= 1;
					end
				end
				// A3 is deliberately not decoded by the TAL004.
				default: ;
			endcase
		end

		if (ce_mclk && blit_busy) begin
			h0_phase <= h0_phase + 1'd1;
			// H0 rises once per four master clocks.  Eight byte/pair
			// addresses make one 16-pixel sprite line.
			if (h0_phase == 2'b11) begin
				if (pair_in_line == 3'd7) begin
					pair_in_line <= 0;
					y_count <= y_count + 1'd1;
					x_count <= reg1b[7:1];
				end else begin
					pair_in_line <= pair_in_line + 1'd1;
					x_count <= x_count + 1'd1;
				end
			end

			if (pl_count == 7'd125) begin
				pl_count <= 0;
				blit_busy <= 0;
				palette_latch <= reg2[4:0];
				if (!reg2[5]) irq_req <= 1;
			end else pl_count <= pl_count + 1'd1;
		end
	end
end
endmodule
