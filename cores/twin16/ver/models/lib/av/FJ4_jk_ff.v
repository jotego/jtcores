module FJ4_jk_ff (
    input wire j,              // J input
    input wire k,              // K input
    input wire clk,            // Clock signal
    input wire reset_n,        // Active-low reset
    output wire q,             // Q output as a wire
    output wire q_bar          // Inverted Q output as a wire
);

    // Declare intermediate signals for master and slave states
    reg master_q;
    reg master_q_bar;
    reg slave_q;
    reg slave_q_bar;

    // Local parameters for delays
    localparam HIGH_DELAY = 6;  // Delay when output is going high (6ns)
    localparam LOW_DELAY = 4;   // Delay when output is going low (4ns)
    localparam RESET_DELAY = 4; // Delay for reset operation

    // Master latch: operates on the positive edge of the clock
    always @(posedge clk or negedge reset_n or posedge reset_n) begin
        if (!reset_n) begin
            #(RESET_DELAY) master_q <= 1'b0;       // Reset master_q with delay
            #(RESET_DELAY) master_q_bar <= 1'b1;  // Reset master_q_bar with delay
        end else if (reset_n) begin
            case ({j, k})
                2'b11: begin 
                    // Hold state
                    master_q <= master_q;
                    master_q_bar <= master_q_bar;
                end
                2'b10: begin 
                    // Reset state (Q = 0, Q_bar = 1)
                    master_q <= 1'b0;
                    master_q_bar <= 1'b1;
                end
                2'b01: begin 
                    // Set state (Q = 1, Q_bar = 0)
                    master_q <= 1'b1;
                    master_q_bar <= 1'b0;
                end
                2'b00: begin 
                    // Toggle state
                    master_q <= ~master_q;
                    master_q_bar <= ~master_q_bar;
                end
            endcase
        end
    end

    // Slave latch: operates on the negative edge of the clock
    always @(negedge clk or negedge reset_n or posedge reset_n) begin
        if (!reset_n) begin
            #(RESET_DELAY) slave_q <= 1'b0;       // Reset slave_q with delay
            #(RESET_DELAY) slave_q_bar <= 1'b1;  // Reset slave_q_bar with delay
        end else if (reset_n) begin
            #(HIGH_DELAY) slave_q <= master_q;       // Transfer master to slave with delay
            #(HIGH_DELAY) slave_q_bar <= master_q_bar; // Transfer master to slave with delay
        end
    end

    // Delayed output assignment
    assign #((slave_q == 1) ? HIGH_DELAY : LOW_DELAY) q = slave_q;
    assign #((slave_q_bar == 1) ? HIGH_DELAY : LOW_DELAY) q_bar = slave_q_bar;

endmodule
