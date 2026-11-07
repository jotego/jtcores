/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 2-1-2025 */

// jtframe_framebuf copies the contents of a memory, normally an object LUT,
// at each vertical blank. It provides access to the data copied during the
// previous frame.
module jtframe_framebuf #(parameter AW=10,DW=8)(
    input               clk,
    input               lvbl,
    output reg [AW-1:0] dma_addr,
    input      [DW-1:0] dma_data,
    output reg          busy=0,

    input      [AW-1:0] rd_addr,
    output     [DW-1:0] rd_data
);

reg  lvbl_l=0, odd=0, even=0, cen=0;
wire [AW:0] nx_addr;
wire we;

assign nx_addr = {1'b1,dma_addr}+1'd1;
assign we = busy & cen;

always @(posedge clk) begin
    cen <= ~cen;
end

always @(posedge clk) if(cen) begin
    lvbl_l <= lvbl;
    if( !lvbl && lvbl_l ) begin
        busy      <= 1;
        dma_addr <= 0;
        odd      <= ~odd;
        even     <=  odd;
    end
    if( busy ) begin
        {busy,dma_addr}<=nx_addr;
    end
end

jtframe_dual_ram #(.DW(DW),.AW(AW+1))u_buffer(
    // Port 0 - writes
    .clk0   ( clk       ),
    .data0  ( dma_data  ),
    .addr0  ({odd,dma_addr}),
    .we0    ( we        ),
    .q0     (           ),
    // Port 1 - reads
    .clk1   ( clk       ),
    .data1  ( {DW{1'b0}}),
    .addr1  ({even,rd_addr}),
    .we1    ( 1'b0      ),
    .q1     ( rd_data   )
);

endmodule
