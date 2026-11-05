/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 28-11-2025 */
/* verilator coverage_off */
module jt65c02_ctrl #(parameter DECO222=0)(
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
    input        brok, calt, d, pcpage, ea_ff,
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

localparam [2:0] NMI_VECTOR   = 5,
                 RESET_VECTOR = 6,
                 BRK_VECTOR   = 7;

wire [4:0] jsr_sel;
reg  [2:0] iv_sel;
wire [1:0] bcd_sel;
reg        nmi_l, nmi_pnd, nmi_served;
wire       halt, swi, waiting;
wire       wait4cy, nobr;

	`include "65c02.vh"

wire [3:0] nx_ualo = uaddr[3:0] + 1'd1;

function reserved_nop(input [7:0] opcode);
    begin
        case(opcode)
            8'h02,8'h03,8'h0b,8'h13,8'h1b,8'h22,8'h23,8'h2b,8'h33,8'h3b,
            8'h42,8'h43,8'h44,8'h4b,8'h53,8'h54,8'h5b,8'h5c,8'h62,8'h63,
            8'h6b,8'h73,8'h7b,8'h82,8'h83,8'h8b,8'h93,8'h9b,8'ha3,8'hab,
            8'hb3,8'hbb,8'hc2,8'hc3,8'hcb,8'hd3,8'hd4,8'hdb,8'hdc,8'he2,
            8'he3,8'heb,8'hf3,8'hf4,8'hfb,8'hfc: reserved_nop=1'b1;
            default: reserved_nop=1'b0;
        endcase
    end
endfunction

function deco222_nop(input [7:0] opcode);
    begin
        case(opcode)
            8'h02,8'h22,8'h42,8'h62,8'h82,8'hc2,8'he2,
            8'h44,8'h54,8'hd4,8'hf4,8'h5c,8'hdc,8'hfc: deco222_nop=1'b1;
            default: deco222_nop=1'b0;
        endcase
    end
endfunction

function is_branch_opcode(input [7:0] opcode);
    begin
        // BBR/BBS occupy every xF slot; the other relative branches use the
        // listed opcodes. A taken backward same-page branch can have calt=1
        // from the low-byte subtraction while pcpage remains zero.
        if(opcode[3:0]==4'hf) is_branch_opcode=1'b1;
        else case(opcode)
            8'h80,8'h90,8'hb0,8'hd0,8'hf0,
            8'h10,8'h30,8'h50,8'h70: is_branch_opcode=1'b1;
            default: is_branch_opcode=1'b0;
        endcase
    end
endfunction

reg [2:0] waitcnt;
assign waiting = ~waitcnt[2];

always @(posedge clk) begin
    if( rst ) begin
        waitcnt <= 0;
    end else if(cen) begin
        if( waiting ) waitcnt <= waitcnt+1'd1;
        // Branch page crossing is registered by the high-byte PC write, so
        // its wait occurs in the following microstep with branch deasserted.
        // Branch waits use the actual high-byte page change. calt is only a
        // low-byte carry and also goes high for backward same-page offsets.
        // Indexed-address waits still use calt; JMP ($xxFF) has its own gate.
        if( wait4cy & (pcpage | (calt & !is_branch_opcode(ir)) |
                       ((ir==8'h6c) & ea_ff)) ) begin
            waitcnt <= 0;
        end
    end
end

wire enable = cen && !halt && !waiting;
wire do_bcd = bcd_sel!=0 && d;
wire next_instruction = ni && !do_bcd;

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
        nmi_pnd <= 0;
    end else begin
        if( nmi & ~nmi_l ) nmi_pnd <= 1;
        if( nmi_served   ) nmi_pnd <= 0;
    end
end

always @(posedge clk) begin
    if( rst ) begin
        uaddr      <= IVRD_SEQA;
        jsr_ret    <= 0;
        iv         <= RESET_VECTOR;
        ir         <= 0;
        stack_busy <= 0;
        nmi_served <= 0;
    end else if(enable) begin
        nmi_served <= 0;
        uaddr[3:0] <= nx_ualo;
        if( swi ) iv <= BRK_VECTOR;
        if( next_instruction ) begin
            ir         <= md;
            // Rockwell Table 4 says every undefined encoding is a NOP. Decode
            // these through the defined NOP microcode entry, without assigning
            // undocumented timing or giving WDC WAI/STP their modern meaning.
            // DECO222 assigns instruction lengths/paths to 14 original
            // reserved bytes. Let its selected profile decode those entries;
            // all remaining Rockwell-reserved bytes still take generic NOP.
            uaddr      <= (reserved_nop(md) && !(DECO222 && deco222_nop(md))) ?
                          { 8'hEA, 4'd0 } : { md, 4'd0 };
            stack_busy <= 0;
            if( ~i & irq ) begin
                iv     <= BRK_VECTOR; // same one for IRQ and BRK
                uaddr  <= ISRV_SEQA; // irq service
                stack_busy <= 1;
            end
            if( nmi_pnd ) begin
                nmi_served <= 1;
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
