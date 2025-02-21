module FJ5_jk_ff (
    input j_n,       // Active-low J input
    input k_n,       // Active-low K input
    input ck,        // Clock signal
    input pr_n,      // Active-low preset
    input cl_n,      // Active-low clear
    output reg q,    // Q output
    output reg q_bar // Q-bar output
);

    // Internal signals for the master stage
    reg master_q;
    reg master_q_bar;

    // Define delays in nanoseconds
    localparam HIGH_DELAY = 7;  // Delay when output goes high
    localparam LOW_DELAY = 4;   // Delay when output goes low

    // Master Stage: Latches inputs on the rising edge of the clock
    always @(posedge ck) begin
        case ({j_n, k_n})
            2'b11: begin
                master_q <= master_q;       // Hold state
                master_q_bar <= master_q_bar;
            end
            2'b10: begin
                master_q <= 1'b0;           // Reset state
                master_q_bar <= 1'b1;
            end
            2'b01: begin
                master_q <= 1'b1;           // Set state
                master_q_bar <= 1'b0;
            end
            2'b00: begin
                master_q <= ~master_q;      // Toggle state
                master_q_bar <= ~master_q_bar;
            end
        endcase
    end

    // Slave Stage: Transfers master state on the falling edge of the clock
    always @(negedge ck) begin
        q <= #(master_q ? HIGH_DELAY : LOW_DELAY) master_q;       // Transfer master state with delay
        q_bar <= #(master_q_bar ? HIGH_DELAY : LOW_DELAY) master_q_bar;
    end

    // Asynchronous Preset and Clear with delays
    always @(*) begin
        if (!pr_n) begin
            q <= #HIGH_DELAY 1'b1;        // Preset with high delay
            q_bar <= #LOW_DELAY 1'b0;     // Clear with low delay
        end else if (!cl_n) begin
            q <= #LOW_DELAY 1'b0;         // Clear with low delay
            q_bar <= #HIGH_DELAY 1'b1;    // Preset with high delay
        end
    end

endmodule