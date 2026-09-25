/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// direct-mapped read cache in front of a cache-lane port: one-clock hits
// (the romrq slot contract the video fetchers were built against), lane
// round trips on misses only
module jtsysfl_lane_cache #(parameter AW=20, DW=64, IDXW=9)(
    input             rst,
    input             clk,
    // client, classic slot contract
    input             cs,
    input    [AW-1:0] addr,
    output   [DW-1:0] dout,
    output            ok,
    // cache lane
    output reg        ln_rd,
    output reg [AW-1:0] ln_addr,
    input    [DW-1:0] ln_data,
    input             ln_ok
);

localparam TAGW = AW-IDXW;

reg [DW+TAGW-1:0] mem[0:(1<<IDXW)-1];
reg [(1<<IDXW)-1:0] valid;
reg [DW+TAGW-1:0] q;
reg [AW-1:0]      addr_l, req_a;
reg               vq, busy;

wire [IDXW-1:0] idx   = addr[IDXW-1:0];
wire            match = vq && q[DW+:TAGW]==addr_l[AW-1:IDXW];
wire            cur   = cs && addr==addr_l;

assign dout = q[DW-1:0];
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
            ln_addr <= addr;
            req_a   <= addr;
            busy    <= 1;
        end else if( busy && ln_ok ) begin
            ln_rd <= 0;
            busy  <= 0;
            mem[req_a[IDXW-1:0]]   <= { req_a[AW-1:IDXW], ln_data };
            valid[req_a[IDXW-1:0]] <= 1;
            // forward the fill so the held address matches next clock,
            // closing the stale-q re-miss window (ghost double fills)
            if( addr==req_a ) begin
                q  <= { req_a[AW-1:IDXW], ln_data };
                vq <= 1;
            end
        end
    end
end

`ifdef SIMULATION
integer lc_lat=0, lc_latsum=0, lc_latmax=0, lc_n=0;
always @(posedge clk) begin
    if( busy ) lc_lat <= lc_lat+1;
    if( busy && ln_ok ) begin
        lc_latsum <= lc_latsum+lc_lat+1;
        if( lc_lat+1 > lc_latmax ) lc_latmax <= lc_lat+1;
        lc_n <= lc_n+1; lc_lat <= 0;
    end
end
integer lc_hit=0, lc_miss=0, lc_clk=0;
reg lc_okl=0;
always @(posedge clk) begin
    lc_okl <= ok;
    if( ok && !lc_okl ) lc_hit  <= lc_hit+1;
    if( miss          ) lc_miss <= lc_miss+1;
    lc_clk <= lc_clk+1;
    if( lc_clk==32'd800_000 ) begin  // ~once per frame at 48 MHz
        $display("LANECACHE %m hits=%0d misses=%0d fills=%0d avglat=%0d maxlat=%0d", lc_hit, lc_miss, lc_n, lc_n>0 ? lc_latsum/lc_n : 0, lc_latmax);
        lc_hit<=0; lc_miss<=0; lc_clk<=0;
    end
end
`endif

endmodule
