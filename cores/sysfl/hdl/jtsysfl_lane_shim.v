/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later */

// romrq-style client on a cache-lane port: re-edges rd per address, serves
// from a two-entry buffer (interleaved fetch streams, like romrq_bcache) and
// follows the romrq ok contract (ok drops the moment the address moves)
module jtsysfl_lane_shim #(parameter AW=20, DW=32, WR=0)(
    input             rst,
    input             clk,
    // client, classic slot contract
    input             cs,
    input    [AW-1:0] addr,
    input             we,
    input    [DW-1:0] din,
    input  [DW/8-1:0] dsn,
    output   [DW-1:0] dout,
    output            ok,
    // cache lane
    output reg        ln_rd,
    output reg        ln_we,
    output reg [AW-1:0] ln_addr,
    output reg [DW-1:0] ln_din,
    output reg [DW/8-1:0] ln_dsn,
    input    [DW-1:0] ln_data,
    input             ln_ok
);

reg  [AW-1:0] a0, a1, req_a;
reg  [DW-1:0] d0, d1;
reg  [ 1:0]   v;
reg           lru, busy, req_wr, wok;

wire hit0 = v[0] && a0==addr;
wire hit1 = v[1] && a1==addr;
wire rd_req = cs && !we;
wire wr_req = WR!=0 && cs && we;

assign dout = hit0 ? d0 : d1;
assign ok   = wr_req ? wok : rd_req && (hit0 || hit1);

wire new_rd = rd_req && !busy && !hit0 && !hit1;
wire new_wr = wr_req && !busy && !wok;

always @(posedge clk) begin
    if( rst ) begin
        ln_rd <= 0; ln_we <= 0; busy <= 0; v <= 0; lru <= 0; wok <= 0;
        ln_addr <= 0; ln_din <= 0; ln_dsn <= {DW/8{1'b1}};
        a0 <= 0; a1 <= 0; d0 <= 0; d1 <= 0; req_a <= 0; req_wr <= 0;
    end else begin
        if( new_wr ) begin
            ln_rd   <= 0;
            ln_we   <= 1;
            ln_addr <= addr;
            ln_din  <= din;
            ln_dsn  <= dsn;
            req_wr  <= 1;
            busy    <= 1;
            v       <= 0;       // reads after a write refetch through the lane
        end else if( new_rd ) begin
            ln_rd   <= 1;
            ln_we   <= 0;
            ln_addr <= addr;
            req_a   <= addr;
            req_wr  <= 0;
            busy    <= 1;
        end else if( busy && ln_ok ) begin
            ln_rd  <= 0;
            ln_we  <= 0;
            busy   <= 0;
            if( req_wr ) begin
                wok <= 1;
            end else begin
                if( lru ) begin a1 <= req_a; d1 <= ln_data; v[1] <= 1; end
                else      begin a0 <= req_a; d0 <= ln_data; v[0] <= 1; end
                lru <= ~lru;
            end
        end
        if( !cs ) wok <= 0;
    end
end

endmodule
