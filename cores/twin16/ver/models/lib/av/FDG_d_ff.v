module FDG_d_ff(
    input d,       // Data input
    input ck,      // Clock input
    input cl_n,    // Active-low clear
    output reg q,  // Q output
    output reg q_bar // Q-bar output
);

    // Define delays in nanoseconds
    localparam CK_TO_Q_DELAY = 5;      // Clock to Q delay
    localparam CK_TO_Q_BAR_DELAY = 5; // Clock to Q-bar delay
    localparam CLN_TO_Q_DELAY = 4;    // CL_N to Q delay (both edges)
    localparam CLN_TO_Q_BAR_DELAY = 4; // CL_N to Q-bar delay (both edges)

    // Flip-flop logic
    always @(posedge ck or negedge cl_n) begin
        if (!cl_n) begin
            // Asynchronous clear
            #(CLN_TO_Q_DELAY) q <= 0;          // Clear Q with delay
            #(CLN_TO_Q_BAR_DELAY) q_bar <= 1; // Set Q-bar with delay
        end else begin
            // Synchronous clock-triggered behavior
            #(CK_TO_Q_DELAY) q <= d;           // Clock to Q delay
            #(CK_TO_Q_BAR_DELAY) q_bar <= ~d;  // Clock to Q-bar delay
        end
    end

endmodule
