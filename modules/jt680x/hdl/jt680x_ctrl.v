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
    input             rst,
    input             clk,
    input             cen,
    // registers
    input      [ 5:0] cc,
    // Bus
    input      [ 7:0] din,
    input             nmi_n, irq_n,
    // Control
    output reg [15:0] pc,
    output reg [ 2:0] iv,
);

`include "jt680x.vh"

wire dec_en;
wire dir2;
wire ext2;
wire ix_en;
wire load_sp;
wire memdec_en;
wire [2:0] acca_ctrl;
wire [1:0] accb_ctrl;
wire [2:0] bus_ctrl;
wire [1:0] cc_ctrl;
wire [2:0] dout_ctrl;
wire [2:0] ea_ctrl;
wire [2:0] ix_ctrl;
wire [2:0] md_ctrl;
wire [2:0] op0_ctrl;
wire [2:0] op1_ctrl;
wire op_ctrl;
wire [5:0] seqa;

reg  [15:0] tempof, temppc;
reg  [ 2:0] pc_ctrl;
reg  [ 7:0] op;
wire        branch_en;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        iv <= 7;
    end else if(cen) begin
        case (iv_ctrl)
            NMI_IV: iv <= 6;
            SWI_IV: iv <= 5;
            IRQ_IV: iv <= 4;
            ICF_IV: iv <= 3;
            OCF_IV: iv <= 2;
            TOF_IV: iv <= 1;
            SCI_IV: iv <= 0;
            default:;
        endcase
    end
end

always @(*) begin
  case (pc_ctrl)
    BRANCH_PC: tempof = branch_en ? { {8{md[7]}}, md[7:0] } : 16'd0;
    INC_PC:    tempof = 1;
    default:   tempof = 0;
  endcase

  case (pc_ctrl)
      LOAD_EA_PC: temppc = ea;
      PULL_LO_PC: temppc[15:8] = { pc[15:8], data_in };
      PULL_HI_PC: temppc[15:8] = { data_in, pc[7:0] };
      default:    temppc = pc;
  endcase
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        pc <= 16'hfffe;
        op <= 1;
    end else begin if( cen ) begin
        pc <= temppc + tempof;
        if( op_ctrl ) op <= din;
    end
end

reg [2:0] admode;
localparam [2:0] IMM_AD=0, DIR_AD=1, IDX_AD=2, EXT_AD=3, EXTOP_AD=4, IDXOP_AD=5, INH_AD=6;

always @* begin
    // addressing decoding
    casez( din )
        8'b0010_????, // branch
        8'b1?00_????: admode = IMM_AD;
        8'b1?01_????: admode = DIR_AD;
        8'b1?10_????,
        8'b0110_????: admode = IDX_AD;
        8'b0111_????,
        8'b1?11_????: admode = EXT_AD;
        8'b011?_0???,
        8'b011?_10??,
        8'b011?_110?,
        8'b011?_1111: admode = din[4] ? EXTOP_AD : IDXOP_AD;
        default: admode = INH_AD;
    endcase
    // operation decoding
    casez( din )
        // implied
        8'b0000_0001: opseq = FETCH_SEQA;  // NOP
        8'b0000_011?, // TAP, TPA
        8'b0000_101?, // CLV, SEV
        8'b0000_11??: // CLC, SEC, CLI, SEI
            opseq = INH_CC_SEQA;
        8'b0000_100?: // INX, DEX
            opseq = ALU_X_SEQA;
        8'b0001_0000, // SBA
        8'b0001_10?1: // ABA, DAA
            opseq = ALU_SBA_SEQA;
        8'b0001_0001: opseq = ALU_CBA_SEQA;  // CBA
        8'b0001_0110: opseq = ALU_TAB_SEQA;  // TAB
        8'b0001_0111: opseq = ALU_TBA_SEQA;  // TBA
        8'b0011_0000: opseq = TSX_SEQA;      // TSX
        8'b0011_0101: opseq = TXS_SEQA;      // TXS
        8'b0011_0010: opseq = ALU8A_SEQA;    // PULA
        8'b0011_0011: opseq = ALU8B_SEQA;    // PULB
        8'b0011_1000: opseq = PULX_SEQA;     // PULX
        // one operand:
        8'b010?_1101: // TST
            opseq = din[4] ? ALU_CC8B_SEQA : ALU_CC8A_SEQA;
        8'b010?_0???, 8'b010?_10??, 8'b010?_111?, 8'b010?_1100:
            opseq = din[4] ? ALU8B_SEQA : ALU8A_SEQA;
        // two operands:
        8'b1???_0?01: // SUB, BIT
            opseq = din[6] ? ALU_CC8B_SEQA : ALU_CC8B_SEQA;
        8'b1???_0000, // CMP
        8'b1???_001?, // SBC
        8'b1???_01?0, // AND, LDA
        8'b1???_10??: // EOR, ADC, OR, ADD
            opseq = din[6] ? ALU8B_SEQA : ALU8A_SEQA;
        8'b1???_0011: opseq = ALU_IMM16_SEQA;
        // operand and result in memory
        8'b011?_0000, // NEG
        8'b011?_0011, // COM
        8'b011?_0100, // LSR
        8'b011?_011?, // ROR, ASR
        8'b011?_100?, // ASL, ROL
        8'b011?_1010, // DEC
        8'b011?_110?, // INC, TST
        8'b011?_1111: // CLR
            opseq = ALU_MEM_SEQA;
        default: opseq = BERR_SEQA; // bus error
    endcase
end

// sequencer
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        seqa <= SERVE_INT_SEQA;
    end else begin
        case( seq_ctrl )
            FETCH_SEQ: seqa <= FETCH_SEQA;
            DEC_SEQ:
                case( admode )
                    DIR_AD:   begin seqa <=    DIRECT_SEQA; nx_ops <= opseq; end
                    IDX_AD:   begin seqa <=    EXTEND_SEQA; nx_ops <= opseq; end
                    EXT_AD:   begin seqa <=    INDEXD_SEQA; nx_ops <= opseq; end
                    IDXOP_AD: begin seqa <= INDEXD_WR_SEQA; nx_ops <= opseq; end
                    EXTOP_AD: begin seqa <= EXTEND_WR_SEQA; nx_ops <= opseq; end
                    default: seqa <= opseq;
                endcase
            EXEC_SEQ: seqa <= nx_ops;
            default: seqa <= seqa + 1'd1;
        endcase
    end
end

jt680x_branch u_branch(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .sel    ( op[3:0]   ),
    .cc     ( cc        ),
    .branch ( branch_en )
);

jt680x_ucode ucode(
    .dec_en   (dec_en   ),
    .dir2     (dir2     ),
    .ext2     (ext2     ),
    .ix_en    (ix_en    ),
    .load_sp  (load_sp  ),
    .memdec_en(memdec_en),
    .acca_ctrl(acca_ctrl),
    .accb_ctrl(accb_ctrl),
    .bus_ctrl (bus_ctrl ),
    .cc_ctrl  (cc_ctrl  ),
    .dout_ctrl(dout_ctrl),
    .ea_ctrl  (ea_ctrl  ),
    .ix_ctrl  (ix_ctrl  ),
    .md_ctrl  (md_ctrl  ),
    .op0_ctrl (op0_ctrl ),
    .op1_ctrl (op1_ctrl ),
    .op_ctrl  (op_ctrl  ),
    .pc_ctrl  (pc_ctrl  ),
    .seqa     (seqa     )
);

endmodule