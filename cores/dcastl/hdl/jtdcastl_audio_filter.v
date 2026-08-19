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

module jtdcastl_audio_filter
(
	input clk, input reset, input enable,
	input cen_48k,
	input signed [15:0] sample_in,
	output signed [15:0] sample_out
);

wire ce_audio = cen_48k;
reg signed [31:0] x_prev, hp_state, lp_state;
reg signed [15:0] result;
wire signed [31:0] x_extended = {{16{sample_in[15]}},sample_in};
reg [2:0] filter_step;
reg signed [31:0] hp_delta_pipe, hp_next_pipe, lp_delta_pipe, lp_next_pipe;
reg signed [63:0] hp_product_pipe, lp_product_pipe;

always @(posedge clk) begin
	if (reset) begin
		filter_step <= 0;
		x_prev <= 0; hp_state <= 0; lp_state <= 0; result <= 0;
		hp_delta_pipe <= 0; hp_product_pipe <= 0; hp_next_pipe <= 0;
		lp_delta_pipe <= 0; lp_product_pipe <= 0; lp_next_pipe <= 0;
	end else begin
		if (ce_audio && filter_step == 0) begin
			x_prev <= x_extended;
			hp_delta_pipe <= x_extended - x_prev;
			hp_product_pipe <= hp_state * 32'sd65523; // 1.5 Hz HP pole, Q16
			filter_step <= 1;
		end else begin
			case (filter_step)
			3'd1: begin
				hp_next_pipe <= hp_delta_pipe + $signed(hp_product_pipe[47:16]);
				filter_step <= 2;
			end
			3'd2: begin
				lp_delta_pipe <= hp_next_pipe - lp_state;
				filter_step <= 3;
			end
			3'd3: begin
				lp_product_pipe <= lp_delta_pipe * 32'sd51911; // about 12 kHz LP, Q16
				filter_step <= 4;
			end
			3'd4: begin
				lp_next_pipe <= lp_state + $signed(lp_product_pipe[47:16]);
				hp_state <= hp_next_pipe;
				filter_step <= 5;
			end
			3'd5: begin
				lp_state <= lp_next_pipe;
				if (lp_next_pipe > 32'sd32767) result <= 16'sh7fff;
				else if (lp_next_pipe < -32'sd32768) result <= -16'sd32768;
				else result <= lp_next_pipe[15:0];
				filter_step <= 0;
			end
			default: filter_step <= 0;
			endcase
		end
	end
end
assign sample_out = enable ? result : sample_in;
endmodule
