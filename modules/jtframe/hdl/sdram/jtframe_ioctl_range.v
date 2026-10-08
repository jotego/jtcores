/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 16-3-2025 */

module jtframe_ioctl_range #( parameter
    SDRAMW = 22,
    DW     =  8,
    AW     =  8,
    OFFSET =  22'h10_0000
)(
    input              clk,
    input [SDRAMW-1:0] addr,
    output reg[AW-1:0] addr_rel=0,
    input              en,
    output reg         inrange=0,
    input     [DW-1:0] din,
    output reg[DW-1:0] dout=0
);

localparam END=OFFSET+(1<<AW);

wire is_inrange = addr>=OFFSET[SDRAMW-1:0] && addr<END[SDRAMW-1:0];
wire [SDRAMW-1:0] rel = addr-OFFSET[SDRAMW-1:0];

always @(posedge clk) begin
    inrange <= is_inrange && en;
    if(is_inrange) begin
        dout    <= din;
        addr_rel<= rel[AW-1:0];
    end
end

endmodule