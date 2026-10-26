`timescale 1ns / 1ps

module test;

reg clk;
reg rst;
reg start;
reg  [1:0]  op;
reg  [31:0] lhs;
reg  [15:0] rhs;
wire [31:0] result;
wire [7:0]  cc_flags;
wire        divide_by_zero;
wire        range_overflow;
wire        busy;
wire        done;

jtframe_hd6309_arith uut(
    .clk            (clk),
    .rst            (rst),
    .start          (start),
    .op             (op),
    .lhs            (lhs),
    .rhs            (rhs),
    .result         (result),
    .cc_flags       (cc_flags),
    .divide_by_zero (divide_by_zero),
    .range_overflow (range_overflow),
    .busy           (busy),
    .done            (done)
);

always #5 clk = ~clk;

task run_case;
    input [1:0]  test_op;
    input [31:0] test_lhs;
    input [15:0] test_rhs;
    input [31:0] expected_result;
    input [7:0]  expected_flags;
    input        expected_divzero;
    input        expected_range;
    integer      cycles;
    integer      expected_cycles;
    begin
        @(negedge clk);
        op = test_op;
        lhs = test_lhs;
        rhs = test_rhs;
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        cycles = 0;
        expected_cycles = (test_op == 2'd1 && !expected_divzero && !expected_range) ? 8 :
                          (test_op == 2'd2 && !expected_divzero && !expected_range) ? 16 : 0;
        while (!done && cycles < 40) begin
            if (!busy) begin
                $display("FAIL helper left busy before done for op=%0d", test_op);
                $finish;
            end
            @(negedge clk);
            cycles = cycles + 1;
        end
        #1;
        if (!done || busy || cycles != expected_cycles || result !== expected_result ||
            cc_flags !== expected_flags || divide_by_zero !== expected_divzero ||
            range_overflow !== expected_range) begin
            $display("FAIL op=%0d lhs=%h rhs=%h result=%h flags=%h div0=%b range=%b busy=%b done=%b cycles=%0d",
                     test_op, test_lhs, test_rhs, result, cc_flags,
                     divide_by_zero, range_overflow, busy, done, cycles);
            $finish;
        end
        @(negedge clk);
        #1;
        if (!done) begin
            $display("FAIL done did not remain asserted until the next start");
            $finish;
        end
    end
endtask

initial begin
    clk = 1'b0;
    rst = 1'b1;
    start = 1'b0;
    op = 2'd0;
    lhs = 32'h0;
    rhs = 16'h0;
    repeat (2) @(negedge clk);
    rst = 1'b0;

    // MULD: signed product and high-word-based Z flag.
    run_case(2'd0, 32'h0000_FFFE, 16'h0003,
             32'hFFFF_FFFA, 8'h08, 1'b0, 1'b0);
    run_case(2'd0, 32'h0000_0001, 16'h0001,
             32'h0000_0001, 8'h04, 1'b0, 1'b0);

    // DIVD signed quotient/remainder, including signed range boundaries.
    run_case(2'd1, 32'h0000_FFF9, 16'h0003,
             32'h0000_FFFE, 8'h08, 1'b0, 1'b0);
    run_case(2'd1, 32'h0000_0080, 16'h0001,
             32'h0000_0080, 8'h0A, 1'b0, 1'b0);
    run_case(2'd1, 32'h0000_FF80, 16'h0001,
             32'h0000_0080, 8'h0A, 1'b0, 1'b0);
    run_case(2'd1, 32'h0000_FF7F, 16'h0001,
             32'h0000_0081, 8'h0B, 1'b0, 1'b0);
    run_case(2'd1, 32'h0000_0007, 16'h00FD,
             32'h0000_01FE, 8'h08, 1'b0, 1'b0);
    run_case(2'd1, 32'h0000_FFF9, 16'h00FD,
             32'h0000_FF02, 8'h00, 1'b0, 1'b0);
    run_case(2'd1, 32'h0000_012C, 16'h0002,
             32'h0000_0096, 8'h0A, 1'b0, 1'b0);
    run_case(2'd1, 32'h0000_0384, 16'h0003,
             32'h0000_0384, 8'h02, 1'b0, 1'b1);
    run_case(2'd1, 32'h0000_FC7C, 16'h0003,
             32'h0000_0384, 8'h0A, 1'b0, 1'b1);
    run_case(2'd1, 32'h0000_FC7B, 16'h0003,
             32'h0000_0385, 8'h0A, 1'b0, 1'b1);
    run_case(2'd1, 32'h0000_0007, 16'h0000,
             32'h0000_0000, 8'h00, 1'b1, 1'b0);

    // DIVQ corresponding 16-bit quotient boundaries and error cases.
    run_case(2'd2, 32'hFFFF_D8F0, 16'h0002,
             32'h0000_EC78, 8'h08, 1'b0, 1'b0);
    run_case(2'd2, 32'h0000_8000, 16'h0001,
             32'h0000_8000, 8'h02, 1'b0, 1'b0);
    run_case(2'd2, 32'hFFFF_8000, 16'h0001,
             32'h0000_8000, 8'h02, 1'b0, 1'b0);
    run_case(2'd2, 32'hFFFF_7FFF, 16'h0001,
             32'h0000_8001, 8'h03, 1'b0, 1'b0);
    run_case(2'd2, 32'h0000_0007, 16'hFFFD,
             32'h0001_FFFE, 8'h08, 1'b0, 1'b0);
    run_case(2'd2, 32'hFFFF_FFF9, 16'hFFFD,
             32'hFFFF_0002, 8'h00, 1'b0, 1'b0);
    run_case(2'd2, 32'h0001_3880, 16'h0002,
             32'h0000_9C40, 8'h02, 1'b0, 1'b0);
    run_case(2'd2, 32'h0003_3450, 16'h0003,
             32'h0003_3450, 8'h02, 1'b0, 1'b1);
    run_case(2'd2, 32'hFFFC_CBB0, 16'h0003,
             32'h0003_3450, 8'h0A, 1'b0, 1'b1);
    run_case(2'd2, 32'hFFFC_CBAF, 16'h0003,
             32'h0003_3451, 8'h0A, 1'b0, 1'b1);
    run_case(2'd2, 32'h0000_0007, 16'h0000,
             32'h0000_0000, 8'h00, 1'b1, 1'b0);

    $display("PASS");
    $finish;
end

endmodule
