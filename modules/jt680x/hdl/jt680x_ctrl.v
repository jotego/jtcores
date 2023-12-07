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
    Date: 22-11-2023 */

module jt680x_ctrl(
    input        rst,
    input        clk,
    input        cen,
    input [15:0] md,
    // interrupts
    input        i,
    input        irq,
    input        nmi,
    input        irq_icf,
    input        irq_ocf,
    input        irq_tof,
    input        irq_sci,
    output reg [2:0] iv,
    // control
    output       alu16,
    output       branch,
    output       brlatch,
    output       fetch,
    output       inc_pc,
    output       md_shift,
    output       op0inv,
    output       wr,
    output [1:0] carry_sel,
    output [1:0] ea_sel,
    output [1:0] opnd_sel,
    output [3:0] alu_sel,
    output [3:0] ld_sel,
    output [3:0] rmux_sel,
    output [4:0] cc_sel
);

`include "6801_param.vh"
`include "6801.vh"

wire [4:0] jsr_sel;
reg  [2:0] iv_sel;
wire       halt, swi, ni;
reg        nmi_l;
wire [3:0] nx_ualo = uaddr[3:0] + 1'd1;

localparam INTSRV = 12'hc70;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        uaddr   <= 0;
        jsr_ret <= 0;
        iv      <= 7; // reset vector
    end else if(cen) begin
        if(!halt) uaddr[3:0] <= nx_ualo;
        if( swi ) iv <= 5; // lowest priority
        if( ni | halt ) begin
            nmi_l <= nmi;
            uaddr <= { md[7:0], 4'd0 };
            if( ~i ) begin // maskable interrupts by priority
                if( irq_sci) begin iv <= 0; uaddr <= INTSRV; end // lowest priority
                if( irq_tof) begin iv <= 1; uaddr <= INTSRV; end
                if( irq_ocf) begin iv <= 2; uaddr <= INTSRV; end
                if( irq_icf) begin iv <= 3; uaddr <= INTSRV; end
                if( irq    ) begin iv <= 4; uaddr <= INTSRV; end // highest priority
            end
            if( nmi & ~nmi_l ) begin
                iv <= 6;
                uaddr <= INTSRV;
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