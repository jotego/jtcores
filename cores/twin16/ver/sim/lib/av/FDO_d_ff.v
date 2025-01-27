module FDO_d_ff (
    input d,
    input clk,
    input reset_n,
    output reg q,
    output reg q_bar
);

parameter TUP_CK_TO_Q = 3;   // Rising edge delay for Q
parameter TDN_CK_TO_Q = 5;   // Falling edge delay for Q
parameter TUP_CK_TO_XQ = 6;  // Rising edge delay for Q_bar
parameter TDN_CK_TO_XQ = 4;  // Falling edge delay for Q_bar

// Internal signals for the state of the flip-flop
reg q_internal, q_bar_internal;

// Flip-flop behavior: Updates on clock edge or reset
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        q_internal <= 0;
        q_bar_internal <= 1;
    end else begin
        q_internal <= d;
        q_bar_internal <= ~d;
    end
end

// Combinational logic to apply delays
always @(*) begin
    if (!reset_n) begin
        q <= #TDN_CK_TO_Q 0;
        q_bar <= #TUP_CK_TO_XQ 1;
    end else begin
        if (q_internal) begin
            q <= #TUP_CK_TO_Q q_internal;
            q_bar <= #TUP_CK_TO_XQ q_bar_internal;
        end else begin
            q <= #TDN_CK_TO_Q q_internal;
            q_bar <= #TDN_CK_TO_XQ q_bar_internal;
        end
    end
end

endmodule
