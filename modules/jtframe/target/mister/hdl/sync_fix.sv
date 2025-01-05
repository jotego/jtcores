module sync_fix
(
    input clk,
    
    input sync_in,
    output sync_out
);

reg pol;
assign sync_out = sync_in ^ pol;

integer pos, neg, cnt;

`ifdef SIMULATION
initial begin
    pos = 0;
    neg = 0;
    cnt = 0;
end
`endif

always @(posedge clk) begin
    reg s1,s2;

    s1 <= sync_in;
    s2 <= s1;

    if(~s2 & s1) neg <= cnt;
    if(s2 & ~s1) pos <= cnt;

    cnt <= cnt + 1;
    if(s2 != s1) cnt <= 0;

    pol <= pos > neg;
end

endmodule