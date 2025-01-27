module ls7474_d_ff (
    input d,         // Data input
    input clk,       // Clock input
    input pre_n,     // Active-low preset
    input clr_n,     // Active-low clear
    output reg q,    // Q output
    output reg q_bar // Inverted Q output
);

    always @(posedge clk or negedge clr_n or negedge pre_n) begin
        if (!clr_n) begin
            q <= 1'b0;         // Asynchronous clear
            q_bar <= 1'b1;
        end else if (!pre_n) begin
            q <= 1'b1;         // Asynchronous preset
            q_bar <= 1'b0;
        end else begin
            q <= d;            // On clock edge, latch D
            q_bar <= ~d;
        end
    end

endmodule

