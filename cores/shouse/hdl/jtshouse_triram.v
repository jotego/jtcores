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
    input             snd_cs, snd_sel,

    input             brnw,
    input             mcu_rnw,
    input             srnw,

    input      [ 7:0] bdout,
    input      [ 7:0] mcu_dout,
    input      [ 7:0] sdout,

    output     [ 7:0] bdin,
    output     [ 7:0] mcu_din,
    output     [ 7:0] snd_din,

    input      [ 7:0] debug_bus
);

wire [ 7:0] xdout, alt_din, p_alt_din, p_bdin;
wire [10:0] xaddr;
wire        xwe;
wire        xsel;
reg         ssel_l;

assign xsel  = snd_sel & ~ssel_l;
assign xwe   = xsel ? snd_cs & ~srnw : mcu_cs & ~mcu_rnw;
assign xaddr = xsel ? saddr : mcu_addr;
assign xdout = xsel ? sdout : mcu_dout;

assign mcu_din = alt_din;
assign snd_din = alt_din;

// Needed to boot up
assign alt_din = xaddr==0 /*&& !debug_bus[0]*/ ? 8'ha6 : p_alt_din;
assign bdin    = baddr==0 /*&& !debug_bus[1]*/ ? 8'ha6 : p_bdin;

`ifdef SIMULATION
wire flag_cs  = bus_cs && baddr==0;
wire reply_cs = bus_cs && baddr=='h2f && !brnw;
reg [7:0] flag;
always @(posedge clk) begin
    ssel_l <= snd_sel & ~ssel_l;
    if( baddr==0 && ~brnw && bus_cs ) flag <= bdout;
    if( xaddr==0 && xwe ) flag <= xdout;
end
`endif

reg [1:0] mcu_cnt=0;

always @(posedge clk) begin
    if( snd_cen ) begin
        mcu_cnt <= 0;
    end
    if( mcu_cen ) begin
        mcu_cnt <= { mcu_cnt[0], 1'd1 };
    end
end

/* verilator tracing_off */
jtframe_dual_ram #(.AW(11)) u_ram(
    // Port 0: main and sub CPUs
    .clk0   ( clk   ),
    .data0  ( bdout ),
    .addr0  ( baddr ),
    .we0    ( bus_cs & ~brnw ),
    .q0     ( p_bdin  ),
    // Port 1
    .clk1   ( clk   ),
    .data1  ( xdout ),
    .addr1  ( xaddr ),
    .we1    ( xwe   ),
    .q1     (p_alt_din)
);

endmodule