/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 30-10-2026 */
module jtapach3_objcache #(
    parameter AW=11
)(
    input             rst,
    input             clk,
    input      [17:0] addr,
    input      [17:0] next_addr,
    input             fill,
    input      [17:0] fill_addr,
    input      [63:0] fill_data,
    output            hit,
    output     [63:0] data
);
reg [(1<<AW)-1:0] valid;
reg [17:AW] tags [0:(1<<AW)-1];
reg [17:0] read_addr;
reg [17:AW] read_tag;
reg read_valid;
assign hit = read_addr == addr && read_valid && read_tag == addr[17:AW];
always @(posedge clk) begin
    read_addr <= next_addr;
    read_tag <= tags[next_addr[AW-1:0]];
    read_valid <= !rst && valid[next_addr[AW-1:0]];
    if (rst) valid <= 0;
    else if (fill) begin
        valid[fill_addr[AW-1:0]] <= 1;
        tags[fill_addr[AW-1:0]] <= fill_addr[17:AW];
    end
end
jtframe_dual_ram #(
    .DW    ( 64 ),
    .AW    ( AW )
) u_data (
    .clk0  ( clk                   ),
    .data0 ( 64'd0                 ),
    .addr0 ( next_addr[AW-1:0]      ),
    .we0   ( 1'b0                  ),
    .q0    ( data                  ),
    .clk1  ( clk                   ),
    .data1 ( fill_data             ),
    .addr1 ( fill_addr[AW-1:0]      ),
    .we1   ( fill                  ),
    .q1    (                       )
);
endmodule
