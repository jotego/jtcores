// The divider runs at the system clock; done stays high until the next start
// so the CPU can sample it on its slower E-cycle enable.
module jtframe_hd6309_arith(
    input             clk,
    input             rst,
    input             start,
    input      [1:0]  op,
    input      [31:0] lhs,
    input      [15:0] rhs,
    output reg [31:0] result,
    output reg [7:0]  cc_flags,
    output reg        divide_by_zero,
    output reg        range_overflow,
    output reg        busy,
    output reg        done
);

localparam [1:0] OP_MULD = 2'd0;
localparam [1:0] OP_DIVD = 2'd1;
localparam [1:0] OP_DIVQ = 2'd2;

reg [31:0] dividend_shift;
reg [15:0] divisor_magnitude;
reg [16:0] remainder_work;
reg [15:0] quotient_work;
reg [4:0]  steps_remaining;
reg        lhs_negative;
reg        quotient_negative;
reg        divd_mode;
reg [31:0] lhs_magnitude_start;
reg [15:0] rhs_magnitude_start;
reg [31:0] hard_limit_start;
reg        lhs_negative_start;
reg        rhs_negative_start;
reg [16:0] remainder_step;
reg [15:0] quotient_step;
reg [15:0] quotient_code;
reg [15:0] remainder_code;
reg [31:0] quotient_negated;
reg signed [31:0] product_start;
reg [15:0] remainder_negated;
reg        signed_overflow;

always @* begin
    remainder_step = {remainder_work[15:0], dividend_shift[31]};
    quotient_step = {quotient_work[14:0], 1'b0};
    if (remainder_step >= {1'b0, divisor_magnitude}) begin
        remainder_step = remainder_step - {1'b0, divisor_magnitude};
        quotient_step[0] = 1'b1;
    end
end

always @(posedge clk) begin
    if (rst) begin
        result          <= 32'h0000_0000;
        cc_flags        <= 8'h00;
        divide_by_zero  <= 1'b0;
        range_overflow  <= 1'b0;
        busy            <= 1'b0;
        done            <= 1'b0;
        dividend_shift  <= 32'h0000_0000;
        divisor_magnitude <= 16'h0000;
        remainder_work  <= 17'h00000;
        quotient_work   <= 16'h0000;
        steps_remaining <= 5'd0;
        lhs_negative    <= 1'b0;
        quotient_negative <= 1'b0;
        divd_mode       <= 1'b0;
    end else if (busy) begin
        dividend_shift <= {dividend_shift[30:0], 1'b0};
        remainder_work <= remainder_step;
        quotient_work  <= quotient_step;
        steps_remaining <= steps_remaining - 5'd1;

        if (steps_remaining == 5'd1) begin
            quotient_code = quotient_step;
            quotient_negated = ~{16'h0000, quotient_step} + 32'd1;
            if (quotient_negative)
                quotient_code = quotient_negated[15:0];

            remainder_negated = ~remainder_step[15:0] + 16'd1;
            remainder_code = lhs_negative ? remainder_negated :
                                               remainder_step[15:0];

            if (divd_mode) begin
                signed_overflow = quotient_step > 16'd127;
                if (signed_overflow) begin
                    // The original 6309 reports the quotient magnitude on
                    // two's-complement overflow. Remainder keeps dividend sign.
                    result <= {16'h0000, remainder_code[7:0], quotient_step[7:0]};
                    cc_flags <= {4'b0000, 1'b1, 1'b0, 1'b1, quotient_step[0]};
                end else begin
                    result <= {16'h0000, remainder_code[7:0], quotient_code[7:0]};
                    cc_flags <= {4'b0000, quotient_code[7],
                                 (quotient_code[7:0] == 8'h00), 1'b0,
                                 quotient_code[0]};
                end
            end else begin
                signed_overflow = quotient_step > 16'd32767;
                if (signed_overflow) begin
                    result <= {remainder_code[15:0], quotient_step[15:0]};
                    cc_flags <= {4'b0000, 1'b0, 1'b0, 1'b1, quotient_step[0]};
                end else begin
                    result <= {remainder_code[15:0], quotient_code[15:0]};
                    cc_flags <= {4'b0000, quotient_code[15],
                                 (quotient_code[15:0] == 16'h0000), 1'b0,
                                 quotient_code[0]};
                end
            end

            busy <= 1'b0;
            done <= 1'b1;
        end
    end else if (start) begin
        done           <= 1'b0;
        result         <= 32'h0000_0000;
        cc_flags       <= 8'h00;
        divide_by_zero <= 1'b0;
        range_overflow <= 1'b0;

        if (op == OP_MULD) begin
            product_start = $signed(lhs[15:0]) * $signed(rhs);
            result <= product_start;
            cc_flags[3] <= product_start[31];
            cc_flags[2] <= (product_start[31:16] == 16'h0000);
            // MULD reports N/Z only; the CPU preserves V and C.
            cc_flags[0] <= 1'b0;
            busy <= 1'b0;
            done <= 1'b1;
        end else if ((op == OP_DIVD) || (op == OP_DIVQ)) begin
            divd_mode <= (op == OP_DIVD);
            lhs_negative_start = (op == OP_DIVD) ? lhs[15] : lhs[31];
            rhs_negative_start = (op == OP_DIVD) ? rhs[7] : rhs[15];
            lhs_negative <= lhs_negative_start;
            if (op == OP_DIVD)
                lhs_magnitude_start = lhs[15] ?
                    {16'h0000, (~lhs[15:0] + 16'd1)} :
                    {16'h0000, lhs[15:0]};
            else
                lhs_magnitude_start = lhs[31] ? (~lhs + 32'd1) : lhs;

            if (op == OP_DIVD) begin
                rhs_magnitude_start = rhs[7] ? {8'h00, (~rhs[7:0] + 8'd1)} :
                                               {8'h00, rhs[7:0]};
                hard_limit_start = {16'h0000, rhs_magnitude_start[7:0], 8'h00};
            end else begin
                rhs_magnitude_start = rhs[15] ? (~rhs + 16'd1) : rhs;
                hard_limit_start = {rhs_magnitude_start, 16'h0000};
            end

            if (((op == OP_DIVD) && rhs[7:0] == 8'h00) ||
                ((op == OP_DIVQ) && rhs == 16'h0000)) begin
                divide_by_zero <= 1'b1;
                busy <= 1'b0;
                done <= 1'b1;
            end else if (lhs_magnitude_start >= hard_limit_start) begin
                range_overflow <= 1'b1;
                result <= lhs_magnitude_start;
                cc_flags[3] <= lhs_negative_start;
                cc_flags[2] <= 1'b0;
                cc_flags[1] <= 1'b1;
                cc_flags[0] <= 1'b0;
                busy <= 1'b0;
                done <= 1'b1;
            end else begin
                divisor_magnitude <= rhs_magnitude_start;
                quotient_negative <= lhs_negative_start ^ rhs_negative_start;
                quotient_work <= 16'h0000;
                if (op == OP_DIVD) begin
                    dividend_shift <= {lhs_magnitude_start[7:0], 24'h000000};
                    remainder_work <= {9'h000, lhs_magnitude_start[15:8]};
                    steps_remaining <= 5'd8;
                end else begin
                    dividend_shift <= {lhs_magnitude_start[15:0], 16'h0000};
                    remainder_work <= {1'b0, lhs_magnitude_start[31:16]};
                    steps_remaining <= 5'd16;
                end
                busy <= 1'b1;
            end
        end else begin
            busy <= 1'b0;
            done <= 1'b1;
        end
    end
end

endmodule
