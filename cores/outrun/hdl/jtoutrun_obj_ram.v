/*  This file is part of JTS16.
    JTS16 program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTS16 program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTS16.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 12-3-2021 */

module jtoutrun_obj_ram(
    input              rst,
    input              clk,

    input              swap,
    // CPU interface
    input              obj_cs,
    input      [10:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dswn,
    output     [15:0]  cpu_din,

    // Object scan
    input      [10:1]  tbl_addr,
    output     [15:0]  tbl_dout,
    input              tbl_we,
    input      [15:0]  tbl_din,

    // SD dump
    input      [11:0]  ioctl_addr,
    output     [ 7:0]  ioctl_din
);

wire [1:0] cpu_we = ~dswn & {2{obj_cs}};
reg  half, swap_l;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        swap_l <= 0;
        half   <= 1;
    end else begin
        swap_l <= swap;
        if ( swap && !swap_l )
            half <= ~half;
    end
end

jtframe_dual_ram16 #(
    .AW(11),
    .SIMFILE_LO("obj_lo.bin"),
    .SIMFILE_HI("obj_hi.bin")
) u_ram(
    .clk0   ( clk       ),
    .clk1   ( clk       ),

    // CPU writes
    .addr0  ( { half, cpu_addr } ),
    .data0  ( cpu_dout  ),
    .we0    ( cpu_we    ),
    .q0     ( cpu_din   ),

    // Video reads
    .addr1  ( {~half, tbl_addr } ),
    .data1  ( tbl_din   ),
    .we1    ({2{tbl_we}}),
    .q1     ( tbl_dout  )
);

// Dump OBJ RAM for debugging
`ifndef JTFRAME_RELEASE
    wire [15:0] sd_dout;
    assign ioctl_din = !ioctl_addr[0] ? sd_dout[15:8] : sd_dout[7:0]; // MSB first

    jtframe_dual_ram16 #(
        .AW(11)
    ) u_sdram(
        .clk0   ( clk       ),
        .clk1   ( clk       ),

        // CPU writes
        .addr0  ( { half, cpu_addr } ),
        .data0  ( cpu_dout  ),
        .we0    ( cpu_we    ),
        .q0     (           ),

        // Video reads
        .addr1  ( ioctl_addr[11:1] ),
        .data1  (           ),
        .we1    ( 2'd0      ),
        .q1     ( sd_dout   )
    );
`else
    assign ioctl_din=0;
`endif

endmodule