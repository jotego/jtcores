/*  This file is part of JTFRAME.
    JTFRAME program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTFRAME program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTFRAME.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 25-1-2021 */

// Dual port 16-bit memory, where one port has full 16-bit RW access
// but the second is divided in a
// - 1A port, 16-bit read only
// - 1B port,  8-bit read/write

module jtframe_dual_nvram16 #(parameter AW=10,
    SIMFILE_LO="", SIMHEXFILE_LO="",
    SIMFILE_HI="", SIMHEXFILE_HI=""
)(
    // Port 0 - full RW, 16-bit access
    input          clk0,
    input   [15:0] data0,
    input   [AW:1] addr0,
    input   [ 1:0] we0,
    output  [15:0] q0,
    // Port 1 -- RO, 16-bit access AND RW, 8-bit access
    input          clk1,
    input   [AW:1] addr1a,
    output  [15:0] q1a,
    // 8-bit, RW access
    input   [ 7:0] data1,  // note it's only 8 bits
    input   [AW:0] addr1b, // note the extra bit
    input          we1b,   // note single bit
    input          sel_b,
    output  [ 7:0] q1b
);

wire [1:0] we1;

assign we1 = {2{we1b}} & { addr1b[0], ~addr1b[0]};
assign q1b = addr1b[0] ? q1a[15:8] : q1a[7:0];


jtframe_dual_nvram #(
    .DW        ( 8             ),
    .AW        ( AW            ),
    .SIMFILE   ( SIMFILE_LO    ),
    .SIMHEXFILE( SIMHEXFILE_LO )  )
u_lo(
    .clk0       ( clk0              ),
    .clk1       ( clk1              ),
    // Port 0
    .data0      ( data0[7:0]        ),
    .addr0      ( addr0             ),
    .we0        ( we0[0]            ),
    .q0         ( q0[7:0]           ),
    // Port 1
    .data1      ( data1             ),
    .addr1a     ( addr1a            ),
    .addr1b     ( addr1b[AW:1]      ),
    .sel_b      ( sel_b             ),
    .we_b       ( we1[0]            ),
    .q1         ( q1a[7:0]          )
);

jtframe_dual_nvram #(
    .DW        ( 8             ),
    .AW        ( AW            ),
    .SIMFILE   ( SIMFILE_HI    ),
    .SIMHEXFILE( SIMHEXFILE_HI )  )
u_hi(
    .clk0       ( clk0              ),
    .clk1       ( clk1              ),
    // Port 0
    .data0      ( data0[15:8]       ),
    .addr0      ( addr0             ),
    .we0        ( we0[1]            ),
    .q0         ( q0[15:8]          ),
    // Port 1
    .data1      ( data1             ),
    .addr1a     ( addr1a            ),
    .addr1b     ( addr1b[AW:1]      ),
    .sel_b      ( sel_b             ),
    .we_b       ( we1[1]            ),
    .q1         ( q1a[15:8]         )
);

endmodule