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
    Date: 24-9-2023 */

// Implementation of Namco's CUS30 - 8-channel stereo DAC
// Based on MAME's namco_snd.cpp information and Atari's schematics

module jtcus30(
    input               rst,
    input               clk,
    input               bsel,

    output       [ 7:0] xdin,
    // main/sub bus
    input               bcs,
    input               brnw,
    input        [ 9:0] baddr,
    input        [ 7:0] bdout,

    // sound CPU
    input               scs,
    input               srnw,
    input        [15:0] saddr,
    input        [ 7:0] sdout
);

wire [ 7:0] xdout = bsel ? bdout : sdout;
wire [15:0] xaddr = bsel ? {6'd0, baddr } : saddr;
wire        xcs   = bsel ? bcs  : scs;
wire        xwe   = xcs & ~(bsel ? brnw : srnw);

jtframe_dual_ram u_wave(
    // Port 0 - CPUs
    .clk0   ( clk        ),
    .data0  ( xdout      ),
    .addr0  ( xaddr[9:0] ),
    .we0    ( xwe        ),
    .q0     ( xdin       ),
    // Port 1 - Waveform reading
    .clk1   ( clk        ),
    .data1  (  8'd0      ),
    .addr1  ( 10'd0      ),
    .we1    ( 1'b0       ),
    .q1     (            )
);

endmodule