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

module jtdcastl_adpcm
(
	input               clk,
	input               reset,
	input               pause,
	input               enabled,
	input               control_wr,
	input         [7:0] control_data,
	output        [7:0] status,

	input               cen_384k,

	output       [15:0] rom_addr,
	input         [7:0] rom_q,
	output              rom_cs,
	input               rom_ok,

	output signed [11:0] sound,
	output              busy_debug,
	output       [17:0] nibble_pos_debug,
	output              nibble_strobe_debug
);

reg [7:0] control;
reg idle;
reg [17:0] nibble_pos;
reg [17:0] nibble_end;

wire stop_edge = control_wr && control[7] && !control_data[7];
wire start_edge = control_wr && control[6] && !control_data[6];
wire [17:0] selected_start = {1'b0,control_data[1:0],15'b0};

assign status = idle ? 8'h00 : 8'h80;
assign busy_debug = !idle;
assign nibble_pos_debug = nibble_pos;
assign rom_addr = nibble_pos[16:1];
// The sample byte must be valid before a nibble is consumed: request while a
// sample is playing and hold the nibble counter until the slot answers.
assign rom_cs   = enabled & ~idle;

wire ce_384k = cen_384k && !pause && rom_ok;

wire [3:0] adpcm_din = nibble_pos[0] ? rom_q[3:0] : rom_q[7:4];
wire vclk_irq;
wire sample_unused;
wire vclk_unused;

jt5205 #(.INTERPOL(0), .VCLK_CEN(1)) decoder
(
	.rst(reset | idle | !enabled),
	.clk(clk),
	.cen(ce_384k),
	.sel(2'd2),
	.din(adpcm_din),
	.sound(sound),
	.sample(sample_unused),
	.irq(vclk_irq),
	.vclk_o(vclk_unused)
);

assign nibble_strobe_debug = vclk_irq && !idle && enabled;

always @(posedge clk) begin
	if (reset || !enabled) begin
		control <= 0;
		idle <= 1;
		nibble_pos <= 0;
		nibble_end <= 0;
	end else begin
		// Reset on the master clock immediately after the final valid nibble.
		if (!idle && (nibble_pos >= nibble_end))
			idle <= 1;

		if (vclk_irq && !idle && !pause && rom_ok)
			nibble_pos <= nibble_pos + 1'd1;

		if (control_wr) begin
			if (stop_edge)
				idle <= 1;

			// This is intentionally after stop so a simultaneous pair of
			// falling edges follows MAME's start-wins ordering.
			if (start_edge) begin
				nibble_pos <= selected_start;
				nibble_end <= selected_start + 18'h08000;
				idle <= 0;
			end

			control <= control_data;
		end
	end
end

wire _unused = sample_unused | vclk_unused;

endmodule
