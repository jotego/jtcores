module C41_4bit_async_cnt (
    input ck,            // Clock signal
    input cl_n,          // Active-low clear signal
    output reg [3:0] q   // 4-bit counter output
);

    // Internal register to hold the raw counter value
    reg [3:0] raw_q;

    // Delays in nanoseconds for clock-to-output transitions
    parameter TUP_CK_TO_Q0 = 4;
    parameter TDN_CK_TO_Q0 = 5;
    parameter TUP_CK_TO_Q1 = 9;
    parameter TDN_CK_TO_Q1 = 11;
    parameter TUP_CK_TO_Q2 = 15;
    parameter TDN_CK_TO_Q2 = 17;
    parameter TUP_CK_TO_Q3 = 21;
    parameter TDN_CK_TO_Q3 = 22;

    // Delay for cl_n to output transition
    parameter T_CLN_TO_Q = 5;

    // Counter logic (raw updates without delay)
    always @(posedge ck or negedge cl_n) begin
        if (!cl_n) begin
            raw_q <= 4'b0000; // Asynchronous clear
        end else begin
            raw_q <= raw_q + 1'b1; // Increment counter
        end
    end

    // Apply delays to each bit of q
    always @(*) begin
        if (!cl_n) begin
            q[0] <= #T_CLN_TO_Q 0;
            q[1] <= #T_CLN_TO_Q 0;
            q[2] <= #T_CLN_TO_Q 0;
            q[3] <= #T_CLN_TO_Q 0;
        end else begin
            // Apply delays for each output bit
            if (raw_q[0]) q[0] <= #TUP_CK_TO_Q0 1; else q[0] <= #TDN_CK_TO_Q0 0;
            if (raw_q[1]) q[1] <= #TUP_CK_TO_Q1 1; else q[1] <= #TDN_CK_TO_Q1 0;
            if (raw_q[2]) q[2] <= #TUP_CK_TO_Q2 1; else q[2] <= #TDN_CK_TO_Q2 0;
            if (raw_q[3]) q[3] <= #TUP_CK_TO_Q3 1; else q[3] <= #TDN_CK_TO_Q3 0;
        end
    end

endmodule
