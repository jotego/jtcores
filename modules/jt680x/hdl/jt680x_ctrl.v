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

// always @* begin
//     case (iv_sel)
//         NMI_IV: iv = 6;
//         SWI_IV: iv = 5;
//         IRQ_IV: iv = 4;
//         ICF_IV: iv = 3;
//         OCF_IV: iv = 2;
//         TOF_IV: iv = 1;
//         SCI_IV: iv = 0;
//         default:iv = 7; // reset
//     endcase
// end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        uaddr   <= 0;
        jsr_ret <= 0;
        iv      <= 7;
    end else if(cen) begin
        if(!halt) uaddr[3:0] <= nx_ualo;
        if( swi ) iv <= 5;
        if( ni | halt ) begin
            nmi_l <= nmi;
            uaddr <= { md[7:0], 4'd0 };
            if( irq & ~i ) begin
                iv <= 4;
                uaddr <= 'hc70; // irq service
            end
            if( nmi & ~nmi_l ) begin
                iv <= 6;
                uaddr <= 'hc70;
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