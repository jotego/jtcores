/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 20-12-2019 */

// Adds channel enable signals to jtframe_mixer

module jtframe_mixer_en #(parameter W0=16,W1=16,W2=16,W3=16,WOUT=16)(
    input                    rst,
    input                    clk,
    input                    cen,
    // input signals
    input  signed [W0-1:0]   ch0,
    input  signed [W1-1:0]   ch1,
    input  signed [W2-1:0]   ch2,
    input  signed [W3-1:0]   ch3,
    // gain for each channel in 4.4 fixed point format
    input  [7:0]             gain0,
    input  [7:0]             gain1,
    input  [7:0]             gain2,
    input  [7:0]             gain3,
    input  [3:0]             ch_en,
    output signed [WOUT-1:0] mixed,
    output                   peak   // overflow signal (time enlarged)
);

reg [7:0] g0, g1, g2, g3;

always @(posedge clk) begin
    if( rst ) begin
        g0 <= 0;
        g1 <= 0;
        g2 <= 0;
        g3 <= 0;
    end else begin
        g0 <= ch_en[0] ? gain0 : 8'd0;
        g1 <= ch_en[1] ? gain1 : 8'd0;
        g2 <= ch_en[2] ? gain2 : 8'd0;
        g3 <= ch_en[3] ? gain3 : 8'd0;
    end    
end

jtframe_mixer #(
    .W0   ( W0   ),
    .W1   ( W1   ),
    .W2   ( W2   ),
    .W3   ( W3   ),
    .WOUT ( WOUT )
)u_mix(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .ch0    ( ch0       ),
    .ch1    ( ch1       ),
    .ch2    ( ch2       ),
    .ch3    ( ch3       ),
    .gain0  ( g0        ),
    .gain1  ( g1        ),
    .gain2  ( g2        ),
    .gain3  ( g3        ),
    .mixed  ( mixed     ),
    .peak   ( peak      )
);

endmodule