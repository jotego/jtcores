// SPDX-License-Identifier: GPL-3.0-or-later
module object_rom(
    input clk,rst,cs,
    input [12:0] addr,
    input [15:0] latency,
    output reg [31:0] data=0,
    output ok
);
`include "patterns.vh"
reg active=0,ready=0;
reg [12:0] pending;
integer wait_count=0;
integer requests=0,stalls=0;

assign ok=cs && active && pending==addr && ready;

always @(posedge clk) begin
    if(rst || !cs) begin active<=0;ready<=0;end
    else if(!active || pending!=addr) begin
        if(active && !ready) $fatal(1,"object ROM request changed while waiting");
        active<=1;pending<=addr;wait_count<=latency;
        requests<=requests+1;
        data<=graphics(addr);ready<=latency==0;
    end else begin
        if(wait_count>0) begin
            stalls<=stalls+1;wait_count<=wait_count-1;
            ready<=wait_count==1;
        end
    end
end
endmodule
