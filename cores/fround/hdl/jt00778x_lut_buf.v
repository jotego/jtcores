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
    Date: 30-12-2024 */

module jt00778x_lut_buf#(parameter PW=10)(
    input             rst,
    input             clk,
    input             pxl_cen,
    input             objbufinit,

    input      [10:1] lut_addr,
    input      [15:0] lut_din,
    input             lut_we,

    input      [10:1] scan_addr,
    output     [15:0] scan_dout
);

reg half=0, obi_l=0;

always @(posedge clk) begin
    obi_l <= objbufinit;
    if( objbufinit && !obi_l ) begin
        half    <= ~half;
    end
end

jtframe_dual_ram16  #(.AW(11)) u_framebuffer(
    // Port 0: LUT writting
    .clk0   ( clk            ),
    .data0  ( lut_din        ),
    .addr0  ({half,lut_addr} ),
    .we0    ( {2{lut_we}}    ),
    .q0     (                ),
    // Port 1: scan
    .clk1   ( clk            ),
    .data1  ( 16'd0          ),
    .addr1  ({~half,scan_addr}),
    .we1    ( 2'b0           ),
    .q1     ( scan_dout      )
);

endmodule