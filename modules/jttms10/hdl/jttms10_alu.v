/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Shared 32-bit TMS34010 ALU. Binary operations use b as the destination
 * operand and a as the source; unary operations and shifts operate on a.
 * C is carry on addition and borrow on subtraction. The control unit selects
 * which flags each instruction actually writes.
 */
module jttms10_alu(
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  op,
    input             cin,
    output reg [31:0] result,
    output            n,
    output            z,
    output reg        c,
    output reg        v
);

localparam [3:0]
    PASSA = 4'd0,
    ADD   = 4'd1,
    ADDC  = 4'd2,
    SUB   = 4'd3,
    SUBB  = 4'd4,
    AND   = 4'd5,
    ANDN  = 4'd6,
    OR    = 4'd7,
    XOR   = 4'd8,
    NOTA  = 4'd9,
    NEG   = 4'd10,
    ABS   = 4'd11,
    SHL1  = 4'd12,
    SHR1  = 4'd13,
    SAR1  = 4'd14,
    ROL1  = 4'd15;

wire sub = (op == SUB) || (op == SUBB) || (op == NEG) || (op == ABS);
wire neg = (op == NEG) || (op == ABS);
wire [31:0] lhs = neg ? 32'd0 : b;
wire [31:0] rhs = sub ? ~a : a;
wire carry_in = sub ? ((op == SUBB) ? ~cin : 1'b1)
                    : ((op == ADDC) ? cin : 1'b0);
// The low bit injects carry_in into one 34-bit addition. Bits [33:1]
// contain the 33-bit arithmetic sum; bit 0 is discarded.
/* verilator lint_off UNUSEDSIGNAL */
wire [33:0] sum_with_cin = {1'b0, lhs, 1'b1} + {1'b0, rhs, carry_in};
/* verilator lint_on UNUSEDSIGNAL */
wire [32:0] sum = sum_with_cin[33:1];
wire [31:0] arithmetic_result = sum[31:0];

assign n = result[31];
assign z = (result == 32'd0);

always @* begin
    result = a;
    c = 1'b0;
    v = 1'b0;
    case (op)
        PASSA: result = a;
        ADD, ADDC: begin
            result = arithmetic_result;
            c = sum[32];
            v = (b[31] == a[31]) && (result[31] != b[31]);
        end
        SUB, SUBB: begin
            result = arithmetic_result;
            c = ~sum[32];
            v = (b[31] != a[31]) && (result[31] != b[31]);
        end
        AND:  result = b & a;
        ANDN: result = b & ~a;
        OR:   result = b | a;
        XOR:  result = b ^ a;
        NOTA: result = ~a;
        NEG: begin
            result = arithmetic_result;
            c = ~sum[32];
            v = a[31] && result[31];
        end
        ABS: begin
            result = a[31] ? arithmetic_result : a;
            v = (a == 32'h8000_0000);
        end
        SHL1: begin
            result = {a[30:0], 1'b0};
            c = a[31];
        end
        SHR1: begin
            result = {1'b0, a[31:1]};
            c = a[0];
        end
        SAR1: begin
            result = {a[31], a[31:1]};
            c = a[0];
        end
        ROL1: begin
            result = {a[30:0], a[31]};
            c = a[31];
        end
        default: result = a;
    endcase
end

endmodule
