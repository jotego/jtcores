module C45_4bit_cnt(
    input [3:0] d,    // 4-bit input data
    input l_n,        // Active-low load signal
    input ck,         // Clock signal
    input en,         // Enable signal
    input ci,         // Carry-in signal (combinational)
    input cl_n,       // Active-low clear signal (synchronous)
    output reg [3:0] q,  // 4-bit output
    output reg co        // Carry-out
);

    // Define delays in nanoseconds
    localparam CK_TO_QA_DELAY = 8;    // Clock to QA delay
    localparam CK_TO_CO_DELAY = 10;  // Clock to CO delay
    localparam CLN_TO_CO_DELAY = 2; // Clear signal to CO delay

    // CK -> Q and synchronous CL_N -> Q delays
    always @(posedge ck) begin
        if (!cl_n) begin
            #(CK_TO_QA_DELAY) q <= 4'b0000; // Clear Q with delay
        end else if (!l_n) begin
            #(CK_TO_QA_DELAY) q <= d;      // Load D with delay
        end else if (en && ci) begin
            #(CK_TO_QA_DELAY) q <= q + 1'b1; // Increment Q with delay
        end
    end

    // Combinational CO logic with delay for both assertion and clearing
    always @(*) begin
        if (!cl_n) begin
            #(CLN_TO_CO_DELAY) co = 0; // Clear CO with delay
        end else begin
            #(CK_TO_CO_DELAY - CLN_TO_CO_DELAY) co = (ci && (q == 4'b1111)); // Combinational dependency with delay
        end
    end
endmodule