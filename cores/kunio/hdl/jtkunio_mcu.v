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
    Date: 7-12-2023 */

module jtkunio_mcu(
    input            rst,
    input            clk,
    input            cen,
    input            rd,
    input            wr,
    input            clr,
    input      [7:0] cpu_dout,
    output reg [7:0] dout,
    output reg       stn,
    output           irqn,
    // ROM
    output    [10:0] rom_addr,
    input     [ 7:0] rom_data
);

reg  [7:0] din;
reg        irq, mcu_wrnl;

/* verilator tracing_on */
wire [7:0] pa_out, pb_out;
wire mcu_wrn = pb_out[2];
wire mcu_rdn = pb_out[1];

assign irqn = ~irq;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        dout     <= 0;
        din      <= 0;
        stn      <= 1;
        irq      <= 0;
        mcu_wrnl <= 0;
    end else begin
        mcu_wrnl <= mcu_wrn;
        if( !mcu_wrn && mcu_wrnl ) begin
            dout <= pa_out;
            stn  <= 0; // MCU semaphore in MAME jargon
        end
        if( wr ) begin
            irq <= 1;
            din <= cpu_dout;
            // if(!irq) $display("Wr %X to MCU",cpu_dout);
        end
        if( !mcu_rdn || clr ) begin
            irq <= 0;
        end
        if( clr | rd ) stn <= 1;
    end
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
    .pa_in      ( din           ),
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

endmodule