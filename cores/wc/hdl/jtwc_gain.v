/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 26-10-2024 */

module jtwc_gain(
	input					 clk,
	input	          [ 3:0] ctl,
	input      signed [11:0] raw,
	output reg signed [11:0] amp	// amplified
);

localparam [7:0] NORM=8'd3;

reg signed [ 7:0] gain;
reg signed [19:0] mul;

// the gain is not sorted with the control bits
// the ctl bit order should be swap to make it
// fall in order. But the board is hooked up this way
// When a goal is scored, ctl values vary between 7 and 15
// which signal the highest gains. So the software uses
// the gains in a consistent way with the hardware
always @(posedge clk) begin
	case( ctl )
		15:	gain = NORM*8'd41;
		7:	gain = NORM*8'd40;
		11:	gain = NORM*8'd39;
		3:	gain = NORM*8'd38;
		13:	gain = NORM*8'd36;
		5:	gain = NORM*8'd35;
		9:	gain = NORM*8'd34;
		1:	gain = NORM*8'd32;
		14:	gain = NORM*8'd28;
		6:	gain = NORM*8'd26;
		10:	gain = NORM*8'd23;
		2:	gain = NORM*8'd20;
		12:	gain = NORM*8'd15;
		4:	gain = NORM*8'd11;
		8:	gain = NORM*8'd6;
		0:	gain = NORM*8'd0;
	endcase
	mul <= gain*raw;
	amp <= mul[19-:12];
end

endmodule