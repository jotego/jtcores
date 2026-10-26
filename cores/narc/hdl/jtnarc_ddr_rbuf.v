/* SPDX-FileCopyrightText: 2026 Chris Watson
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-10-2026 */

module jtnarc_ddr_rbuf #(parameter OW=4)(
    input              rst,
    input              clk,
    input       [19:4] addr,
    input              rd,
    output     [127:0] dout,
    output reg         ok,
    output             miss,
    input              wr,
    input       [19:4] wr_addr,
    input              fill_start,
    input              fill_we,
    input     [OW-1:0] fill_a,
    input      [127:0] fill_d,
    input              fill_done
);

reg  [19:4+OW] tag;
reg            valid=0, filling=0, stale=0, fresh=0, kept=0;
wire           tag_hit = tag==addr[19:4+OW];
wire           hit     = rd && !ok && tag_hit && (valid || fresh) && !filling;
wire           snoop   = wr && wr_addr[19:4+OW]==tag;

assign miss = rd && !ok && !hit && !filling;

always @(posedge clk) begin
    ok <= hit;
    if( fill_start ) begin
        tag     <= addr[19:4+OW];
        filling <= 1;
        valid   <= 0;
        stale   <= 0;
        fresh   <= 0;
        kept    <= 1;
    end else begin
        if( filling && (!rd || rst) ) kept <= 0;
        if( fill_done ) begin
            filling <= 0;
            valid   <= !stale && !snoop && !rst;
            fresh   <= kept && rd && !rst;
        end else begin
            if( snoop ) begin
                valid <= 0;
                if( filling ) stale <= 1;
            end
            if( ok || !rd ) fresh <= 0;
        end
        if( rst ) begin
            valid <= 0;
            fresh <= 0;
            if( filling ) stale <= 1;
        end
    end
end

jtframe_dual_ram #(.DW(128),.AW(OW)) u_ram(
    .clk0  ( clk            ),
    .data0 ( fill_d         ),
    .addr0 ( fill_a         ),
    .we0   ( fill_we        ),
    .q0    (                ),
    .clk1  ( clk            ),
    .data1 ( 128'd0         ),
    .addr1 ( addr[4+OW-1:4] ),
    .we1   ( 1'b0           ),
    .q1    ( dout           )
);

endmodule
