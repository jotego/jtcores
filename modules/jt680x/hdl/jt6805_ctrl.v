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
    Date: 4-12-2023 */
/* verilator coverage_off */
module jt6805_ctrl(
    input        rst,
    input        clk,
    input        cen,
    input [12:0] md,
    // interrupts
    input        i,
    input        irq,
    input        tirq,
    output reg [2:0] iv,
    // control
    output       branch,
    output       brlatch,
    output       fetch,
    output       inc_pc,
    output       md_shift,
    output       op0inv,
    output       stop,
    output       wr,
    output [1:0] brt_sel,
    output [1:0] carry_sel,
    output [1:0] ea_sel,
    output [1:0] opnd_sel,
    output [2:0] ld_sel,
    output [3:0] alu_sel,
    output [3:0] cc_sel,
    output [3:0] rmux_sel
);

`include "6805_param.vh"
`include "6805.vh"

wire [4:0] jsr_sel;
reg  [2:0] iv_sel;
reg        irq_l, pendng;
wire       halt, swi, ni;
wire [3:0] nx_ualo = uaddr[3:0] + 1'd1;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        uaddr   <= IVRD_SEQA;
        jsr_ret <= 0;
        iv      <= 7;
        pendng  <= 0;
    end else if(cen) begin
        irq_l <= irq;
        if( irq & ~irq_l ) pendng <= 1;
        if(~halt&~stop) uaddr[3:0] <= nx_ualo;
        if( swi ) iv <= 6;
        if( ni | halt | stop) begin
            uaddr <= { md[7:0], 4'd0 };
            if( ~i ) begin
                if( pendng ) begin
                    iv     <= 5;
                    pendng <= 0;
                    uaddr  <= ISRV_SEQA; // irq service
                end else if( tirq ) begin
                    iv    <= 4;
                    uaddr <= ISRV_SEQA;
                end
            end
        end
        if( jsr_en ) begin
            jsr_ret <= uaddr;
            jsr_ret[3:0] <= nx_ualo;
            uaddr   <= jsr_ua;
        end
    end
end

endmodule