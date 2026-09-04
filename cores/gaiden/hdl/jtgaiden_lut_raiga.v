/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 1-1-2025 */

module jtgaiden_raiga_luts(
    input             clk,
    input      [ 7:0] addr,
    output reg [15:0] bootup, gameplay
);

localparam [15:0] UNKNOWN=16'hf0,SWITCH=-16'd2;

always @(posedge clk) begin
    // initial
    case(addr)
        8'o00: bootup <= 16'h6669;
        8'o16: bootup <= 16'h4A46;
        8'o21: bootup <= 16'h6704;
        8'o22: bootup <= SWITCH;
        8'o31: bootup <= SWITCH;
        8'o50: bootup <= SWITCH;
        8'o55: bootup <= 16'h4E75;
        8'o61: bootup <= SWITCH;
        8'o63: bootup <= 16'h4E71;
        8'o64: bootup <= 16'h60FC;
        8'o66: bootup <= 16'h7288;
        default: bootup <= UNKNOWN;
    endcase
    // gameplay
    case(addr)
        8'o00: gameplay <= 16'h5457;
        8'o01: gameplay <= 16'h494E;
        8'o02: gameplay <= 16'h5F4B;
        8'o03: gameplay <= 16'h4149;
        8'o04: gameplay <= 16'h5345;
        8'o05: gameplay <= 16'h525F;
        8'o06: gameplay <= 16'h4D49;
        8'o07: gameplay <= 16'h5941;
        8'o10: gameplay <= 16'h5241;
        8'o11: gameplay <= 16'h5349;
        8'o12: gameplay <= 16'h4D4F;
        8'o13: gameplay <= 16'h4A49;
        8'o22: gameplay <= SWITCH;
        8'o23: gameplay <= 16'h594F;
        8'o25: gameplay <= 16'h4E75;
        8'o31: gameplay <= SWITCH;
        8'o34: gameplay <= 16'h4E75;
        8'o36: gameplay <= 16'h5349;
        8'o43: gameplay <= 16'h4E75;
        8'o45: gameplay <= 16'h4849;
        8'o50: gameplay <= SWITCH;
        8'o53: gameplay <= 16'h524F;
        8'o61: gameplay <= SWITCH;
        default: gameplay <= UNKNOWN;
    endcase
end

endmodule