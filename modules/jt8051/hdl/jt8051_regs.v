/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

module jt8051_regs(
    input             rst,
    input             clk,
    input             cen,
    input      [ 4:0] src_sel,
    input      [ 4:0] dst_sel,
    input      [ 2:0] addr_sel,
    input      [ 3:0] pc_sel,
    input      [ 3:0] cond_sel,
    input      [ 2:0] flag_sel,
    input             wr,
    input             sp_inc,
    input             sp_dec,
    input      [ 1:0] code_sel,
    input      [ 1:0] x_sel,
    input             x_acc_i,
    input      [ 1:0] x_wr_i,
    input      [15:0] irq_vec,
    input      [ 7:0] rom_data,
    output reg [15:0] rom_addr,
    input      [ 7:0] ram_din,
    output reg [ 7:0] ram_dout,
    output reg [ 6:0] ram_addr,
    output reg        ram_we,
    input      [ 7:0] x_din,
    output reg [ 7:0] x_dout,
    output reg [15:0] x_addr,
    output reg        x_wr,
    output reg        x_acc,
    input      [ 7:0] sfr_dout,
    output reg [ 7:0] sfr_addr,
    output reg [ 7:0] sfr_din,
    output reg        sfr_we,
    input             latch_read,
    output            sfr_latch,
    input      [ 7:0] p2_latch,
    input      [ 7:0] alu_result,
    input      [ 7:0] alu_aux,
    input             alu_cy,
    input             alu_ac,
    input             alu_ov,
    input             alu_neq,
    output reg [ 7:0] lhs,
    output reg [ 7:0] rhs,
    output reg [ 2:0] bitno,
    output reg [ 7:0] ir,
    output reg [ 7:0] a,
    output reg [ 7:0] b,
    output reg [ 7:0] psw,
    output reg [ 7:0] sp,
    output reg [15:0] dptr,
    output reg [15:0] pc,
    output reg        cond
);

`include "jt8051_param.vh"

reg  [ 7:0] op1, op2, md, ea;
reg  [ 7:0] src;
reg  [ 7:0] direct_q;
reg  [ 7:0] bit_q;
reg  [ 7:0] addr8, bit_dout;
reg         dst_we;
wire [ 7:0] bit_addr = op1[7] ? {op1[7:3],3'b000} : 8'h20+{4'd0,op1[6:3]};
wire [ 6:0] reg_addr = {2'b00,psw[4:3],ir[2:0]};
wire [ 6:0] ri_addr  = {2'b00,psw[4:3],2'b00,ir[0]};
wire [15:0] isr_pc;
wire        sfr_sel = addr8[7];

assign sfr_latch = latch_read;
assign isr_pc    = pc-1'd1;

function [7:0] sfr_q;
    input [7:0] addr;
begin
    case (addr)
        8'h81:  sfr_q = sp;
        8'h82:  sfr_q = dptr[7:0];
        8'h83:  sfr_q = dptr[15:8];
        8'hd0:  sfr_q = psw;
        8'he0:  sfr_q = a;
        8'hf0:  sfr_q = b;
        default: sfr_q = sfr_dout;
    endcase
end
endfunction

always @* begin
    addr8 = 8'd0;
    case (addr_sel)
        REG_ADDR:    addr8 = {1'b0,reg_addr};
        RI_ADDR:     addr8 = {1'b0,ri_addr};
        DIRECT_ADDR: addr8 = op1;
        BIT_ADDR:    addr8 = bit_addr;
        STACK_ADDR:  addr8 = sp;
        STACKP_ADDR: addr8 = sp+1'd1;
        EA_ADDR:     addr8 = ea;
        default: ;
    endcase
    case (dst_sel)
        RN_DST:     addr8 = {1'b0,reg_addr};
        RI_DST,
        EAW_DST:    addr8 = ea;
        DIRECT_DST: addr8 = op1;
        BIT_DST,
        BITC_DST:   addr8 = bit_addr;
        default: ;
    endcase
    if (src_sel==DIRECT_SRC) addr8 = op1;
    if (src_sel==BIT_SRC || src_sel==BITQ_SRC) addr8 = bit_addr;
    dst_we = dst_sel==RN_DST || dst_sel==RI_DST || dst_sel==EAW_DST ||
             dst_sel==DIRECT_DST || dst_sel==BIT_DST || dst_sel==BITC_DST;
    ram_addr = addr8[6:0];
    sfr_addr = addr8;
    direct_q = op1[7] ? sfr_q(op1) : ram_din;
    bit_q    = bit_addr[7] ? sfr_q(bit_addr) : ram_din;
    bitno    = op1[2:0];
    case (src_sel)
        A_SRC:      src = a;
        B_SRC:      src = b;
        OP1_SRC:    src = op1;
        OP2_SRC:    src = op2;
        MD_SRC:     src = md;
        RAM_SRC:    src = ram_din;
        DIRECT_SRC: src = direct_q;
        BIT_SRC:    src = {7'd0,md[op1[2:0]]};
        NBIT_SRC:   src = {7'd0,!md[op1[2:0]]};
        BITQ_SRC:   src = bit_q;
        ALU_SRC:    src = alu_result;
        AUX_SRC:    src = alu_aux;
        CARRY_SRC:  src = {7'd0,psw[7]};
        ZERO_SRC:   src = 8'd0;
        ONE_SRC:    src = 8'd1;
        CODE_SRC:   src = rom_data;
        X_SRC:      src = x_din;
        PCLO_SRC:   src = pc[7:0];
        PCHI_SRC:   src = pc[15:8];
        ISRPCLO_SRC:src = isr_pc[7:0];
        ISRPCHI_SRC:src = isr_pc[15:8];
        DPTR_SRC:   src = dptr[7:0];
        ABS_SRC:    src = op2;
        default:    src = md;
    endcase
    bit_dout = src[0] ? (md | (8'h01 << bitno)) : (md & ~(8'h01 << bitno));
    ram_dout = (dst_sel==BIT_DST || dst_sel==BITC_DST) ? bit_dout : src;
    sfr_din  = (dst_sel==BIT_DST || dst_sel==BITC_DST) ? bit_dout : src;
    case (code_sel)
        DPTRA_CODE: rom_addr = dptr+{8'd0,a};
        APC_CODE:   rom_addr = pc+{8'd0,a};
        PC_CODE:    rom_addr = pc;
        default:    rom_addr = pc;
    endcase
    case (x_sel)
        DPTR_X: x_addr = dptr;
        RI_X:   x_addr = {p2_latch,ea};
        default:x_addr = dptr;
    endcase
    x_dout = a;
    x_acc  = x_acc_i;
    x_wr   = x_wr_i==ON_XWR;
    case (cond_sel)
        C_COND:    cond = psw[7];
        NC_COND:   cond = !psw[7];
        Z_COND:    cond = a==0;
        NZ_COND:   cond = a!=0;
        BIT_COND:  cond = md[op1[2:0]];
        NBIT_COND: cond = !md[op1[2:0]];
        NEQ_COND:  cond = alu_neq;
        NZALU_COND:cond = alu_result!=0;
        default:   cond = 1'b1;
    endcase
    ram_we   = (wr || dst_we) && !(dst_sel==BITC_DST && !cond) && !sfr_sel;
    sfr_we   = (wr || dst_we) && !(dst_sel==BITC_DST && !cond) && sfr_sel &&
               addr8!=8'h81 && addr8!=8'h82 && addr8!=8'h83 && addr8!=8'hd0 &&
               addr8!=8'he0 && addr8!=8'hf0;
end

always @(posedge clk) begin
    if (rst) begin
        a<=0; b<=0; psw<=0; sp<=8'h07; dptr<=0; pc<=0; ir<=0;
        op1<=0; op2<=0; md<=0; ea<=0; lhs<=0; rhs<=0;
    end else if (cen) begin
        if ((wr || dst_we) && sfr_sel) begin
            case (addr8)
                8'h81: sp          <= src;
                8'h82: dptr[7:0]   <= src;
                8'h83: dptr[15:8]  <= src;
                8'hd0: psw         <= {src[7:1],psw[0]};
                8'he0: begin a<=src; psw[0]<=^src; end
                8'hf0: b           <= src;
                default: ;
            endcase
        end
        if (sp_inc) sp <= sp+1'd1;
        if (sp_dec) sp <= sp-1'd1;
        case (dst_sel)
            A_DST:   begin a<=src; psw[0]<=^src; end
            B_DST:   b<=src;
            OP1_DST: op1<=src;
            OP2_DST: op2<=src;
            MD_DST:  md<=src;
            EA_DST:  ea<=src;
            LHS_DST: lhs<=src;
            RHS_DST: rhs<=src;
            DPTR_DST:dptr<={op1,op2};
            DPTRI_DST:dptr<=dptr+1'd1;
            CARRY_DST: psw[7]<=src[0];
            IR_DST:  ir<=src;
            default: ;
        endcase
        case (flag_sel)
            ADD_FLAG: begin psw[7]<=alu_cy; psw[6]<=alu_ac; psw[2]<=alu_ov; end
            CMP_FLAG: psw[7] <= alu_cy;
            CYA_FLAG: psw[7] <= alu_cy;
            MUL_FLAG: begin psw[7]<=0; psw[2]<=alu_ov; end
            default: ;
        endcase
        case (pc_sel)
            INC_PC:   pc <= pc+1'd1;
            REL_PC:   pc <= pc+{{8{op1[7]}},op1};
            RELC_PC:  if (cond) pc <= pc+{{8{op1[7]}},op1};
            REL2C_PC: if (cond) pc <= pc+{{8{op2[7]}},op2};
            ABS11_PC: pc <= {pc[15:11],ir[7:5],op1};
            ABS16_PC: pc <= {op1,op2};
            DPTRA_PC: pc <= dptr+{8'd0,a};
            IRQ_PC:   pc <= irq_vec;
            RET_PC:   pc <= {op1,op2};
            default: ;
        endcase
    end
end

endmodule
