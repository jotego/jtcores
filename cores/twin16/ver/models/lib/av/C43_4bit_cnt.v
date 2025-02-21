module C43_4bit_cnt(
    input [3:0] d,    // 4-bit input data
    input l_n,        // Active-low load signal
    input ck,         // Clock signal
    input en,         // Enable signal
    input ci,         // Carry-in signal
    input cl_n,       // Active-low clear signal
    output reg [3:0] q,  // 4-bit output
    output reg co        // Carry-out
);

    // Define delays in nanoseconds
    localparam CK_TO_Q_DELAY = 7;      // Clock to Q delay
    localparam CK_TO_CO_DELAY = 13;   // Clock to CO delay
    localparam CI_TO_CO_DELAY = 3;    // Carry-in to CO delay
    localparam CLN_TO_Q_DELAY = 6;    // Clear to Q delay
    localparam CLN_TO_CO_DELAY = 10;  // Clear to CO delay

    // CK -> Q and synchronous CL_N -> Q delays
    always @(posedge ck) begin
        if (!cl_n) begin
            #(CLN_TO_Q_DELAY) q <= 4'b0000; // Synchronous clear with delay
        end else if (!l_n) begin
            #(CK_TO_Q_DELAY) q <= d; // Synchronous load with delay
        end else if (en && ci) begin
            #(CK_TO_Q_DELAY) q <= q + 1'b1; // Increment Q with delay
        end
    end

    // Combinational CO logic
    always @(*) begin
        if (!cl_n) begin
            #(CLN_TO_CO_DELAY) co = 0; // Clear CO with delay
        end else begin
            // CI-to-CO dependency with 3ns delay
            #(CI_TO_CO_DELAY) co = (ci && (q == 4'b1111)); 
        end
    end
endmodule
