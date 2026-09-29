/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
   SPDX-License-Identifier: GPL-3.0-or-later */

// Shared texel cache pool for the two C169 fetch buses: one 4kB pool
// (1024 x 32-bit lines) instead of a 2kB cache per bus, so a word cached
// through one bus hits on the other. Each drawer port keeps a dedicated
// SDRAM channel; the drawer never issues the same word on both at once.
module jtsysfl_rozcache(
    input             rst,
    input             clk,
    // drawer side, romrq protocol
    input             a_cs,
    input      [20:2] a_addr,
    output            a_ok,
    output     [31:0] a_dout,
    input             b_cs,
    input      [20:2] b_addr,
    output            b_ok,
    output     [31:0] b_dout,
    // SDRAM side, one raw slot per port
    output reg        sa_cs,
    output reg [20:2] sa_addr,
    input             sa_ok,
    input      [31:0] sa_data,
    output reg        sb_cs,
    output reg [20:2] sb_addr,
    input             sb_ok,
    input      [31:0] sb_data
);

localparam AW=10, TW=19-AW; // 1024 lines, 9-bit tag

(* ramstyle = "M10K" *) reg [TW:0]  tags [0:(1<<AW)-1]; // {valid, tag}
(* ramstyle = "M10K" *) reg [31:0]  data [0:(1<<AW)-1];
reg  [AW-1:0] flush;
reg           init;

// port state: captured request + result
reg         a_vld, b_vld, a_mis, b_mis;
reg  [20:2] a_cap, b_cap;
reg  [31:0] a_q,   b_q;
reg  [TW:0] t_rd;
reg  [31:0] d_rd;
reg  [ 1:0] lu;    // lookup pipeline owner: 0=none, 1=A, 2=B
reg         rr;    // round robin

assign a_ok   = a_vld && a_cap==a_addr && a_cs;
assign b_ok   = b_vld && b_cap==b_addr && b_cs;
assign a_dout = a_q;
assign b_dout = b_q;

wire a_req = a_cs && !a_ok && !a_mis && !(lu==1);
wire b_req = b_cs && !b_ok && !b_mis && !(lu==2);
wire a_go  = a_req && (!b_req ||  rr);
wire b_go  = b_req && (!a_req || !rr);
wire [AW-1:0] lu_a = a_go ? a_addr[2+:AW] : b_addr[2+:AW];

wire a_fill = a_mis && sa_ok;
wire b_fill = b_mis && sb_ok && !a_fill; // one fill per cycle

always @(posedge clk) begin
    if( rst ) begin
        init  <= 1;
        flush <= 0;
        lu    <= 0;
        a_vld <= 0; b_vld <= 0;
        a_mis <= 0; b_mis <= 0;
        sa_cs <= 0; sb_cs <= 0;
        rr    <= 0;
    end else if( init ) begin
        tags[flush] <= 0;
        flush <= flush + 1'd1;
        if( &flush ) init <= 0;
    end else begin
        // lookup: one port per cycle, result checked the next
        if( a_go || b_go ) begin
            t_rd <= tags[lu_a];
            d_rd <= data[lu_a];
            lu   <= a_go ? 2'd1 : 2'd2;
            if( a_go ) begin a_cap <= a_addr; a_vld <= 0; end
            else       begin b_cap <= b_addr; b_vld <= 0; end
            rr   <= ~(a_go);
        end else lu <= 0;
        if( lu==1 ) begin
            if( t_rd == {1'b1, a_cap[20-:TW]} ) begin
                a_q <= d_rd; a_vld <= 1;
            end else begin
                sa_addr <= a_cap; sa_cs <= 1; a_mis <= 1;
            end
        end
        if( lu==2 ) begin
            if( t_rd == {1'b1, b_cap[20-:TW]} ) begin
                b_q <= d_rd; b_vld <= 1;
            end else begin
                sb_addr <= b_cap; sb_cs <= 1; b_mis <= 1;
            end
        end
        // fills: write the pool and serve
        if( a_fill ) begin
            tags[a_cap[2+:AW]] <= {1'b1, a_cap[20-:TW]};
            data[a_cap[2+:AW]] <= sa_data;
            a_q <= sa_data; a_vld <= 1; a_mis <= 0; sa_cs <= 0;
        end
        if( b_fill ) begin
            tags[b_cap[2+:AW]] <= {1'b1, b_cap[20-:TW]};
            data[b_cap[2+:AW]] <= sb_data;
            b_q <= sb_data; b_vld <= 1; b_mis <= 0; sb_cs <= 0;
        end
    end
end

endmodule
