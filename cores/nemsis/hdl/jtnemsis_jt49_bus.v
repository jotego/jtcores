/*  This file is part of JT49.

    JT49 is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JT49 is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JT49.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 28-Jan-2019

    Core-local Nemesis copy of JT49; upstream authorship and implementation retained.

    Based on sqmusic, by the same author

    */

// This is a wrapper with the BDIR/BC1 pins
/* verilator coverage_off */
module jtnemsis_jt49_bus ( // note that input ports are not multiplexed
    input            rst_n,
    input            clk,    // signal on positive edge
    input            clk_en /* synthesis direct_enable = 1 */,
    // bus control pins of original chip
    input            bdir,
    input            bc1,
    input  [7:0]     din,

    input            sel, // if sel is low, the clock is divided by 2
    output     [7:0] dout,
    output     [9:0] sound,  // combined channel output
    output     [7:0] A,      // linearised channel output
    output     [7:0] B,
    output     [7:0] C,
    output           sample,

    input      [7:0] IOA_in,
    output     [7:0] IOA_out,
    output           IOA_oe,

    input      [7:0] IOB_in,
    output     [7:0] IOB_out,
    output           IOB_oe
);

parameter [2:0] COMP=3'b000;
parameter       MUTE_NULL_PERIOD=1;

reg wr_n, cs_n;
reg [3:0] addr;
reg addr_ok;
reg [7:0] din_latch;

always @(posedge clk)
    if( !rst_n ) begin
        wr_n    <= 1'b1;
        cs_n    <= 1'b1;
        addr    <= 4'd0;
        addr_ok <= 1'b1;
    end else begin // I/O cannot use clk_en
        // addr must be
        case( {bdir,bc1} )
            2'b00: { wr_n, cs_n } <= 2'b11;
            2'b01: { wr_n, cs_n } <= addr_ok ? 2'b10 : 2'b11;
            2'b10: begin
                { wr_n, cs_n } <= addr_ok ? 2'b00 : 2'b11;
                din_latch <= din;
            end
            2'b11: begin
                { wr_n, cs_n } <= 2'b11;
                addr    <= din[3:0];
                addr_ok <= din[7:4] == 4'd0;
            end
        endcase // {bdir,bc1}
    end

jtnemsis_jt49 #(
    .COMP             ( COMP             ),
    .MUTE_NULL_PERIOD ( MUTE_NULL_PERIOD )
) u_jt49( // note that input ports are not multiplexed
    .rst_n  (  rst_n     ),
    .clk    (  clk       ),    // signal on positive edge
    .clk_en (  clk_en    ),    // clock enable on negative edge
    .addr   (  addr[3:0] ),
    .cs_n   (  cs_n      ),
    .wr_n   (  wr_n      ),  // write
    .din    (  din_latch ),
    .sel    (  sel       ), // if sel is low, the clock is divided by 2
    .dout   (  dout      ),
    .sound  (  sound     ),  // combined channel output
    .sample (  sample    ),
    .A      (  A         ),      // linearised channel output
    .B      (  B         ),
    .C      (  C         ),
    .IOA_in (  IOA_in    ),
    .IOA_out(  IOA_out   ),
    .IOA_oe (  IOA_oe    ),
    .IOB_in (  IOB_in    ),
    .IOB_out(  IOB_out   ),
    .IOB_oe (  IOB_oe    )
);

endmodule // jtnemsis_jt49_bus
