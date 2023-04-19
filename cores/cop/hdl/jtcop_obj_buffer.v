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
    Date: 4-10-2021 */


// The DMA circuit doesn't stop the CPU. The CPU is free to access the
// memory at any time. Once the data is in place, the CPU enables the DMA
// writting (reading is always done while the CPU isn't acting). Writting
// is automatically turned off at the end of the blanking period

// The mixpsel signal is used to copy the sprite RAM to the frame buffer
// in a different way. If mixpsel is high, the sprite RAM contains the
// destination address to where the data is to be sent, giving more control
// to the CPU. This rather obscure mode doesn't seem to be used by the
// software and is not fully implemented here

// The way the sprite RAM is scanned uses the vertical counter in the
// original too. The specific signals used for the scan are only relevant
// if mixpsel is implemented, because the address latch has to be exercised
// in that case. Otherwise, the scan can be done in any order as it won't
// affect the result

module jtcop_obj_buffer(
    input              rst,
    input              clk,
    input              clk_cpu,
    input              pxl_cen,

    input              LVBL,
    input              vload,       // second last line during V blank
    input              hinit,       // called vcunt in schematics
    input      [ 7:0]  hdump,

    // SD dump
    input              ioctl_ram,
    input      [10:0]  ioctl_addr,
    output     [ 7:0]  ioctl_din,
    // CPU interface
    input      [10:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    output     [15:0]  obj_dout,
    input      [ 1:0]  cpu_dsn,
    input              cpu_rnw,
    input              objram_cs,

    // Object engine
    input      [ 9:0]  tbl_addr,
    output     [15:0]  tbl_dout,

    // DMA trigger
    input              obj_copy,
    input              mixpsel
);

wire [ 1:0] cpu_we = ~({2{cpu_rnw}} | cpu_dsn) & {2{objram_cs}};
wire [15:0] buf_dout;
wire [ 9:0] buf_scan;
wire [ 7:0] dmapdb;
wire [ 9:0] copy_addr;
reg  [ 3:0] v14;
// reg  [ 7:0] buf_latch;
reg         dma_on, dma_charged, v14l;
wire        dma_we;

assign buf_scan = { v14, hdump[7:4], ~hdump[3:2] };
assign dmapdb   = /*mixpsel ? buf_latch :*/ buf_scan[9:2];
assign copy_addr= { dmapdb, ~hdump[3:2] };
assign dma_we   = dma_on && hdump[1:0]==1;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dma_on      <= 0;
        dma_charged <= 0;
        v14         <= 0;
        // buf_latch   <= 0;
        v14l        <= 0;
    end else begin
        v14l  <= v14[3];
        dma_charged <= dma_on ? 1'b0 : (obj_copy ? 1'b1 : dma_charged);
        dma_on <= (vload && v14==8) ? 1'b0 : (!LVBL && v14==8 && !v14l ? dma_charged : dma_on);
        v14    <= hinit & pxl_cen ? (v14+1'd1) : v14;
        // if( pxl_cen ) buf_latch <= buf_dout[7:0];
    end
end


jtframe_dual_nvram16 #(.AW(10),
    .SIMFILE_LO("obj_lo.bin"),
    .SIMFILE_HI("obj_hi.bin")
) u_buffer(
    // Port 0: CPU
    .clk0   ( clk_cpu   ),
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( cpu_we    ),
    .q0     ( obj_dout  ),
    // Port 1
    .clk1   ( clk       ),
    .addr1a ( buf_scan  ),
    .q1a    ( buf_dout  ),
    // dump
    .sel_b  ( ioctl_ram ),
    .we1b   ( 1'd0      ),
    .addr1b ( ioctl_addr),
    .data1  (           ),
    .q1b    ( ioctl_din )
);

jtframe_dual_ram16 #(.AW(10)/*,
    .SIMFILE_LO("obj_lo.bin"),
    .SIMFILE_HI("obj_hi.bin")*/
) u_copy(
    // Port 0: DMA
    .clk0   ( clk       ),
    .data0  ( buf_dout  ),
    .addr0  ( copy_addr ),
    .we0    ({2{dma_we}}),
    .q0     (           ),
    // Port 1
    .clk1   ( clk       ),
    .data1  (           ),
    .addr1  ( tbl_addr  ),
    .we1    ( 2'd0      ),
    .q1     ( tbl_dout  )
);

endmodule