module test #(parameter
    WS=16,      // Assuming that the signal is fixed point
    WA=WS/2     // WA is only the decimal part
)(
    // variables from Verilator
    input             [31:0]  cutoff,
    input             [31:0]  freq,
    input           [WS-1:0]  amplitude,
    // UUT
    input                      rst,
    input                      clk,
    input                      sample,
    input      signed [WS-1:0] sin,
    input             [WA-1:0] a,    // coefficient, unsigned
    output reg signed [WS-1:0] sout
);

jtframe_pole #(.WS(WS),.WA(WA)) u_pole(
    .rst    ( rst   ),
    .clk    ( clk   ),
    .sample ( sample),
    .sin    ( sin   ),
    .a      ( a     ),
    .sout   ( sout  )
);

endmodule

