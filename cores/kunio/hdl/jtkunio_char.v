/*  This file is part of JTKUNIO.
    JTKUNIO program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTKUNIO program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTKUNIO.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 30-7-2022 */

module jtkunio_char(
    input              rst,
    input              clk_cpu,
    input              clk,
    input              pxl_cen,

    input              flip,
    input      [ 7:0]  h,
    input      [ 7:0]  v,

    input      [12:0]  cpu_addr,
    input              ram_cs,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    output     [ 7:0]  cpu_din,
    // ROM access
    output     [14:2]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,
    output     [ 4:0]  pxl
);

wire [15:0] scan_dout, ram_dout;
wire [ 1:0] ram_we;
reg  [ 9:0] code;
wire [ 9:0] scan_addr;
reg  [23:0] pxl_data;
reg  [ 1:0] pal, cur_pal;
wire [11:0] shf_addr = { cpu_addr[12:11], cpu_addr[9:0] };

assign ram_we    = { cpu_addr[10], ~cpu_addr[10] } & {2{ram_cs & ~cpu_wrn}};
assign cpu_din   = cpu_addr[10] ? ram_dout[15:8] : ram_dout[7:0];
assign scan_addr = { v[7:3], h[7:3] };
assign rom_addr  = { code, v[2:0] }; // 10+3 = 13
assign pxl       = { cur_pal, flip ? { pxl_data[16], pxl_data[8], pxl_data[0] } : { pxl_data[23], pxl_data[15], pxl_data[7] } };

always @(posedge clk) if(pxl_cen) begin
    if( h[2:0]==0 ) begin
        code <= scan_dout[9:0];
        pal  <= scan_dout[15:14];
        cur_pal <= pal;
        pxl_data <= {
            rom_data[4], rom_data[5], rom_data[4+8], rom_data[5+8], rom_data[4+8*2], rom_data[5+8*2], rom_data[4+8*3], rom_data[5+8*3],
            rom_data[2], rom_data[3], rom_data[2+8], rom_data[3+8], rom_data[2+8*2], rom_data[3+8*2], rom_data[2+8*3], rom_data[3+8*3],
            rom_data[0], rom_data[1], rom_data[0+8], rom_data[1+8], rom_data[0+8*2], rom_data[1+8*2], rom_data[0+8*3], rom_data[1+8*3]
        };
    end else begin
        pxl_data <= flip ? pxl_data >> 1 : pxl_data << 1;
    end
end

jtframe_dual_ram16 #(
    .AW           ( 12          )
    // .SIMFILE_LO   ("char_lo.bin"),
    // .SIMFILE_HI   ("char_hi.bin")
) u_ram( // 2kB
    .clk0   ( clk_cpu       ),
    .data0  ({2{cpu_dout}}  ),
    .addr0  ( shf_addr      ),
    .we0    ( ram_we        ),
    .q0     ( ram_dout      ),

    .clk1   ( clk           ),
    .data1  ( 16'd0         ),
    .addr1  ({2'b11,scan_addr}),
    .we1    ( 2'b0          ),
    .q1     ( scan_dout     )
);

endmodule