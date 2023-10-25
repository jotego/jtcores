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
    Date: 25-9-2023 */

// Tri-port RAM. All CPUs can access it

module jtshouse_triram(
    input             rst,
    input             clk,

    input             snd_cen,
    input             mcu_cen,

    input      [10:0] baddr,        // main and sub CPUs
    input      [10:0] mcu_addr,     // MCU
    input      [10:0] saddr,        // sound CPU

    // CS to the tri RAM from each subsystem
    input             bus_cs,
    input             mcu_cs,
    input             snd_cs,

    input             brnw,
    input             mcu_rnw,
    input             srnw,

    input      [ 7:0] bdout,
    input      [ 7:0] mcu_dout,
    input      [ 7:0] sdout,

    output     [ 7:0] bdin,
    output reg [ 7:0] mcu_din,
    output reg [ 7:0] snd_din
);

wire [ 7:0] xdout, alt_din;
wire [10:0] xaddr;
wire        xwe;
reg         xsel;

assign xwe   = xsel ? mcu_cs & ~mcu_rnw : snd_cs & ~srnw;
assign xaddr = xsel ? mcu_addr : saddr;
assign xdout = xsel ? mcu_dout : sdout;

always @(posedge clk) begin
    if( snd_cen ) xsel <= 1;
    if( mcu_cen ) xsel <= 0;
    if( xsel    )
        mcu_din <= alt_din;
    else
        snd_din <= alt_din;
end

/* verilator tracing_off */
jtframe_dual_ram #(.AW(11)) u_ram(
    // Port 0: main and sub CPUs
    .clk0   ( clk   ),
    .data0  ( bdout ),
    .addr0  ( baddr ),
    .we0    ( bus_cs & ~brnw ),
    .q0     ( bdin  ),
    // Port 1
    .clk1   ( clk   ),
    .data1  ( xdout ),
    .addr1  ( xaddr ),
    .we1    ( xwe   ),
    .q1     (alt_din)
);

endmodule