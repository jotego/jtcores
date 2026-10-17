/* SPDX-License-Identifier: GPL-3.0-or-later */
// TMS34010 REFCNT. Semantics follow TI User's Guide section 6 (REFCNT).
module jttms10_refresh #(
    parameter integer CLKS_PER_STATE=8
)(
    input clk, rst,
    input [1:0] rr,
    input load,
    input [15:0] wdata,
    output reg [15:0] refcnt,
    output [7:0] row,
    output reg req
);
    localparam integer PW = CLKS_PER_STATE>1 ? $clog2(CLKS_PER_STATE) : 1;
    reg [PW-1:0] phase;
    wire tick = CLKS_PER_STATE==1 || phase==PW'(CLKS_PER_STATE-1);
    wire [1:0] step = rr==0 ? 2'd2 : rr==1 ? 2'd1 : 2'd0;
    wire underflow = tick && step!=0 && refcnt[7:2]<{4'b0,step};
    assign row=refcnt[15:8];
    always @(posedge clk) begin
        if (rst) phase<=0;
        else if (tick) phase<=0;
        else phase<=phase+1'b1;
        if (rst) begin refcnt<=0; req<=0; end
        else if (load) begin refcnt<=wdata; req<=0; end
        else begin
            req<=underflow;
            if (tick && step!=0) refcnt[15:2]<=refcnt[15:2]-{12'b0,step};
        end
    end
endmodule
