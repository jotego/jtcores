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
    Date: 28-11-2025 */
/* verilator coverage_off */
module jt65c02_ctrl(
    input        rst,
    input        clk,
    input        cen,
    input [ 7:0] md,    // Instruction Register (from data sheet)
    output reg [7:0] ir,
    // interrupts
    input        i,
    input        irq,
    input        nmi,
    output reg [2:0] iv,
    // control
    input        brok, calt, d, pcpage,
    output       branch, branch_lo,
    output       brlatch,
    output       fetch,
    output       inc_pc,
    output       wr, ni,
    output       stcy, brcy,
    output [1:0] carry_sel,
    output [1:0] ea_sel,
    output [1:0] opnd_sel,
    output [3:0] ld_sel,
    output [3:0] alu_sel,
    output [3:0] cc_sel,
    output [3:0] rmux_sel,
    // simulation outputs
    output reg stack_busy
);

`include "65c02_param.vh"
`include "65c02.vh"

localparam [2:0] NMI_VECTOR   = 5,
                 RESET_VECTOR = 6,
                 BRK_VECTOR   = 7;

wire [4:0] jsr_sel;
reg  [2:0] iv_sel;
wire [1:0] bcd_sel;
reg        nmi_l, pendng;
wire       halt, swi, waiting;
wire [3:0] nx_ualo = uaddr[3:0] + 1'd1;
wire       wait4cy, nobr;

reg [2:0] waitcnt;
assign waiting = ~waitcnt[2];

always @(posedge clk) begin
    if( rst ) begin
        waitcnt <= 0;
    end else if(cen) begin
        if( waiting ) waitcnt <= waitcnt+1'd1;
        if( wait4cy & (branch ? pcpage : calt) ) begin
            waitcnt <= 0;
        end
    end
end

wire enable = cen && !halt && !waiting;
wire next_instruction = ni && !do_bcd;
wire do_bcd = bcd_sel!=0 && d;

always @(posedge clk) begin
    if(enable | rst) nmi_l <= nmi;
end

task jump_subroutine(input [11:0]jmp); begin
    uaddr        <= jmp;
    jsr_ret      <= uaddr;
    jsr_ret[3:0] <= nx_ualo;
end
endtask

always @(posedge clk) begin
    if( rst ) begin
        uaddr      <= IVRD_SEQA;
        jsr_ret    <= 0;
        iv         <= RESET_VECTOR;
        pendng     <= 0;
        ir         <= 0;
        stack_busy <= 0;
    end else if(enable) begin
        if( nmi & ~nmi_l ) pendng <= 1;
        uaddr[3:0] <= nx_ualo;
        if( swi ) iv <= BRK_VECTOR;
        if( next_instruction ) begin
            ir         <= md;
            uaddr      <= { md, 4'd0 };
            stack_busy <= 0;
            if( ~i & irq ) begin
                iv     <= BRK_VECTOR; // same one for IRQ and BRK
                uaddr  <= ISRV_SEQA; // irq service
                stack_busy <= 1;
            end
            if( pendng ) begin
                pendng <= 0;
                iv         <= NMI_VECTOR; // same one for IRQ and BRK
                uaddr      <= ISRV_SEQA; // irq service
                stack_busy <= 1;
            end
        end
        if( jsr_en ) begin
            jump_subroutine(jsr_ua);
        end
        if(d) case(bcd_sel)
            DAA_BCD: jump_subroutine(DAA_SEQA);
            DAS_BCD: jump_subroutine(DAS_SEQA);
            default:;
        endcase
        // special jumps to comply with extra clock cycles
        if( nobr && !brok ) begin
            uaddr <= NOBRANCH_SEQA;
        end
    end
end

endmodule