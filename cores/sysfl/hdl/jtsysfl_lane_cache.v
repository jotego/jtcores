/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// direct-mapped read cache in front of a cache-lane port: one-clock hits
// (the romrq slot contract the video fetchers were built against), lane
// round trips on misses only
module jtsysfl_lane_cache #(parameter AW=20, DW=64, IDXW=9, LINE2X=0,
    localparam LW   = DW<<LINE2X,       // line = one lane word
    localparam LAW  = AW-LINE2X,        // lane address bits
    localparam TAGW = LAW-IDXW
)(
    input             rst,
    input             clk,
    // client, classic slot contract
    input             cs,
    input    [AW-1:0] addr,
    output   [DW-1:0] dout,
    output            ok,
    // cache lane
    output reg        ln_rd,
    output reg [LAW-1:0] ln_addr,
    input    [LW-1:0] ln_data,
    input             ln_ok
);

reg [LW+TAGW-1:0] mem[0:(1<<IDXW)-1];
reg [(1<<IDXW)-1:0] valid;
reg [LW+TAGW-1:0] q;
reg [AW-1:0]      addr_l;
reg [LAW-1:0]     req_a;
reg               vq, busy;

wire [LAW-1:0]  la    = addr[AW-1:LINE2X];
wire [IDXW-1:0] idx   = la[IDXW-1:0];
wire            match = vq && q[LW+:TAGW]==addr_l[AW-1:LINE2X+IDXW];
wire            cur   = cs && addr==addr_l;

assign dout = LINE2X==0 ? q[DW-1:0] : (addr_l[0] ? q[LW-1:LW-DW] : q[DW-1:0]);
assign ok   = cur && match;

wire miss = cs && addr==addr_l && !match && !busy;

always @(posedge clk) begin
    // lookup runs every clock so hits resolve one clock after the address
    q      <= mem[idx];
    vq     <= valid[idx];
    addr_l <= addr;
    if( rst ) begin
        valid <= 0;
        busy  <= 0;
        ln_rd <= 0;
        ln_addr <= 0;
        req_a <= 0;
    end else begin
        if( miss ) begin
            ln_rd   <= 1;
            ln_addr <= la;
            req_a   <= la;
            busy    <= 1;
        end else if( busy && ln_ok ) begin
            ln_rd <= 0;
            busy  <= 0;
            mem[req_a[IDXW-1:0]]   <= { req_a[LAW-1:IDXW], ln_data };
            valid[req_a[IDXW-1:0]] <= 1;
        end
    end
end

endmodule
