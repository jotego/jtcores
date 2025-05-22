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

    Author: Rafael Eduardo Paiva Feener. Copyright: Miki Saito
    Version: 1.0
    Date: 22-05-2025 */

// Generic 16-bit dual port RAM with clock enable
// parameters:
//      AW      => Address bit width, 10 for 2kB
//      SIMFILE => binary file to load during simulation
//      SIMHEXFILE => hexadecimal file to load during simulation

module jtframe_dual_ram16_gate #(parameter AW=10,
    DW1=8,  DW2=8, DW=DW1+DW2,
    SIMFILE_LO="", SIMHEXFILE_LO="",
    SIMFILE_HI="", SIMHEXFILE_HI="",
    VERBOSE=0,          // set to 1 to display memory writes
    VERBOSE_OFFSET=0    // value added to the address when displaying
)(
    // Port 0
    input            clk0,
    input   [DW-1:0] data0,
    input   [  AW:1] addr0,
    input   [   1:0] we0,
    output  [  15:0] q0_16,
    output  [DW-1:0] q0,
    // Port 1
    input            clk1,
    input   [DW-1:0] data1,
    input   [  AW:1] addr1,
    input   [   1:0] we1,
    output  [  15:0] q1_16,
    output  [DW-1:0] q1
);

wire [15:0] data0_16, data1_16;

assign data0_16 = {{8-DW2{1'b0}},data0[DW1+:DW2],{8-DW1{1'b0}},data0[0+:DW1]};
assign data1_16 = {{8-DW2{1'b0}},data1[DW1+:DW2],{8-DW1{1'b0}},data1[0+:DW1]};
assign q0       = {q0_16[8+:DW2],q0_16[0+:DW1]};
assign q1       = {q1_16[8+:DW2],q1_16[0+:DW1]};

jtframe_dual_ram16 #(
    .AW            ( AW             ),
    .SIMFILE_HI    ( SIMFILE_HI     ), .SIMFILE_LO    ( SIMFILE_LO     ),
    .SIMHEXFILE_HI ( SIMHEXFILE_HI  ), .SIMHEXFILE_LO ( SIMHEXFILE_LO  ),
    .VERBOSE       ( VERBOSE        ), .VERBOSE_OFFSET( VERBOSE_OFFSET )  )
u_ram(
    .clk0       ( clk0              ),
    .clk1       ( clk1              ),
    // Port 0
    .data0      ( data0_16          ), //
    .addr0      ( addr0             ),
    .we0        ( we0               ),
    .q0         ( q0_16             ), //
    // Port 1
    .data1      ( data1_16          ), //
    .addr1      ( addr1             ),
    .we1        ( we1               ),
    .q1         ( q1_16             )  //
);

endmodule