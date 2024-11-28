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
    Date: 20-11-2024 */

module jtflstory_mcu(
    input             rst,
    input             clk,
    input             cen,
    output            rd_n,
    output            wr_n,
    input      [ 7:0] cpu_dout,
    output reg [ 7:0] dout,
    output reg        stn,
    output            irqn,
    // bus sharing
    output reg [15:0] baddr,
    // ROM
    output     [10:0] rom_addr,
    input      [ 7:0] rom_data
);
`ifndef NOMAIN
reg  [7:0] pb_l;
wire [7:0] pa_out, pb_out, pa_in;
wire       ash_n, asl_n, clr_n, clrn_l;
reg        irq;

// communication to sub CPU not implemented
assign pa_in = cpu_dout;
assign ash_n = pb_out[7];
assign asl_n = pb_out[6];
assign m2sub = pb_out[5]; // 1 if main drives sub, 0 otherwise
assign tosub = pb_out[4]; // 1 if PA drives SDB, 0 otherwise
assign clr_n = pb_out[1];

assign clrn_l = pb_l[1];
// mcu2sub = pb_out[2];

// m2sub is expected to be always high as sub CPU is not connected
// PB4 then acts as an active high write signal (PA to global data bus)

assign irqn = ~irq;

always @(posedge clk) begin
    pb_l <= pb_out;
    if( !ash_n ) baddr[15:8]<=pa_out;
    if( !asl_n ) baddr[ 7:0]<=pa_out;
    if( clr_n && !clrn_l ) irq <= 0;
end

jtframe_6805mcu  u_mcu (
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),
    .wr         (               ),
    .addr       (               ),
    .dout       (               ),
    .irq        ( irq           ), // active high
    .timer      ( 1'b0          ),
    // Ports
    .pa_in      ( pa_in         ),
    .pa_out     ( pa_out        ),
    .pb_in      ( pb_out        ),
    .pb_out     ( pb_out        ),
    .pc_in      ({2'b11,stn,irq}),
    .pc_out     (               ),
    // ROM interface
    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      ),
    .rom_cs     (               )
);
`else
assign  rd_n     = 0;
assign  wr_n     = 0;
assign  irqn     = 0;
assign  rom_addr = 0;
initial dout     = 0;
initial stn      = 0;
initial baddr    = 0;
`endif
endmodule