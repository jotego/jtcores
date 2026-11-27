/* SPDX-FileCopyrightText: 2026 JOTEGO
 * SPDX-License-Identifier: GPL-3.0-or-later */

// Seicro applies only its variant opcode-bit permutation and Frisky raw-$FC
// dispatch. Unspecified opcode behavior is left to the selected CPU profile.
module jtseicro_opcode(
    input            nsc8105,
    input            frisky,
    input      [7:0] opcode_raw,
    output reg [7:0] opcode
);

wire [7:0] nsc_opcode = {opcode_raw[6],opcode_raw[7],opcode_raw[5:2],opcode_raw[0],opcode_raw[1]};
always @* begin
    if(!nsc8105 && frisky && opcode_raw==8'hfc) begin
        // Private compatibility dispatch ID. Its public raw slot remains FC.
        opcode = 8'h13;
    end else begin
        opcode = nsc8105 ? nsc_opcode : opcode_raw;
    end
end

endmodule
