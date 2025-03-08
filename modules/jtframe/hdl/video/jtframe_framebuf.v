/*  This file is part of JTCORES.
    JTCORES program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCORES program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 2-1-2025 */

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
