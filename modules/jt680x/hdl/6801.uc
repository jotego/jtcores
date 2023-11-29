#    This file is part of JTCORES.
#    JTCORES program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    JTCORES program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with JTCORES.  If not, see <http://www.gnu.org/licenses/>.
#
#    Author: Jose Tejada Gomez. Twitter: @topapate
#    Version: 1.0
#    Date: 22-11-2023

config:
  seq_len: 4
control:
  # all bus names get _ctrl attached to them
  # all value names get the bus name attached, like ADD_EA_PC
  pc:   [ "0", BRANCH, INC, LOAD_EA, PULL_LO, PULL_HI ]
  bus:  [ "0", READ, WRITE, PUSH, PULL, INT_HI, INT_LO ]
  dout: [ MD_HI, MD_LO, ACCA, ACCB, IX_LO, IX_HI, CC ]
  op:   [ "0", FETCH ]
  op0:  [ "0", ACCA, ACCB, ACCD, IX, SP ]
  op1:  [ "0", ZERO, ONE, ACCB, MDHI ]
  acca: [ "0", LOAD, LOAD_HI, XCG, PULL ]
  md:   [ "0", LOAD, FETCH_LO, SH_FETCH, SHIFTL ]
  acca: [ "0", LOAD, LOAD_HI, XCG, PULL ]
  accb: [ "0", LOAD, XCG, PULL ]
  ix:   [ "0", LOAD, XCG, PULL_HI, PULL_LO ]
  cc:   [ "0", LOAD, PULL ]
  ea:   [ "0", LOAD_ACCB, ADD_IX, FETCH_FIRST, FETCH_NEXT ]
  seq:  [ FETCH, BERR ]
  # entries with no values key are considered 1-bit signals
  load_sp:
  dir2:
  ext2:
  ix_en:
  berr:
  # signals starting with / will be inverted
  "/ima":  // Invalid memory address, ima = /vma
  # set signals get set with name_set
sequence:
  # The sequence must use the value full name
  # Reset starts here too
  - id: serve_int
    seq:
      - PULL_HI_PC, INT_HI_BUS
      - PULL_LO_PC, INT_LO_BUS, FETCH_SEQ
  - id: fetch
    seq:
      - FETCH_OP, FETCH_LO_MD, INC_PC, DEC_SEQ
  # Execution
  - id: inh_cc
    seq:
      - FETCH_OP, FETCH_LO_MD, INC_PC, DEC_SEQ, LOAD_CC
  - id: alu8a
    seq:
      - ACCA_OP0, LOAD_ACCA, LOAD_CC, FETCH_OP, INC_PC, DEC_SEQ
  - id: alu8b
    seq:
      - ACCB_OP0, LOAD_ACCB, LOAD_CC, FETCH_OP, INC_PC, DEC_SEQ
  - id: alu_cc8a
    seq:
      - ACCA_OP0, LOAD_CC, FETCH_OP, INC_PC, DEC_SEQ
  - id: alu_cc8b
    seq:
      - ACCB_OP0, LOAD_CC, FETCH_OP, INC_PC, DEC_SEQ
  - id: alu_x # 3 cycles in 6801, 1 in 6301
      - IX_OP0, ONE_OP1, LOAD_CC, INC_PC, IMA
      - FETCH_SEQ
  - id: alu_s # 3 cycles in 6801, 1 in 6301
      - S_OP0,  ONE_OP1, LOAD_CC, INC_PC, IMA
      - FETCH_SEQ
  # Execution on memory operand and result
  - id: alu_mem
    seq:
      - ALU_CC, LOAD_MD, WRITE_BUS
      - FETCH_SEQ
  # Instructions using both A and B
  - id: alu_sba
    seq:
      - ACCA_OP0, ACCB_OP1, LOAD_ACCA, LOAD_CC, FETCH_SEQ
  - id: alu_cba
    seq:
      - ACCA_OP0, ACCB_OP1,            LOAD_CC, FETCH_SEQ
  - id: alu_tba
    seq:
      - ACCB_OP0, LOAD_ACCA, LOAD_CC, FETCH_SEQ
  - id: alu_tab
    seq:
      - ACCA_OP0, LOAD_ACCB, LOAD_CC, FETCH_SEQ
  # Transfers
  - id: tsx
    seq:
      - SP_OP0, LOAD_X, LOAD_EA, IMA
      - FETCH_SEQ
  - id: txs
    seq:
      - IX_OP0, LOAD_SP, IMA
      - FETCH_SEQ
  # 16-bit loads
  - id: ldx
    seq:
      - SH_FETCH_MD, READ_BUS, INC_PC
      - LOAD_IX, READ_BUS, INC_PC
  - id: lds
    seq:
      - SH_FETCH_MD, READ_BUS, INC_PC
      - LOAD_SP, READ_BUS, INC_PC
  - id: alu_imm16
    seq: # 1 cycle shorter in 6301
      - FETCH_LO_MD, READ_BUS, INC_PC
      - SH_FETCH_MD, READ_BUS, INC_PC, IMA,
      - LOAD_HI_ACCA, LOAD_ACCB, LOAD_CC, FETCH_SEQ
  - id: alu_cmp16
    seq:
      - FETCH_LO_MD, READ_BUS, INC_PC
      - SH_FETCH_MD, READ_BUS,
      - LOAD_CC, INC_PC
  - id: staa
    seq:
      - ACCA_DOUT, WRITE_BUS
  - id: stab
    seq:
      - ACCB_DOUT, WRITE_BUS
  # Stack
  - id: pulab
    seq:
      - SP_OP0, ZERO_OP1, LOAD_SP, LOAD_EA
      - SP_OP0, ONE_OP1,  LOAD_SP, LOAD_EA
      - FETCH_LO_MD, EXEC_SEQ
  - id: pulx
    seq:
      - SP_OP0, ZERO_OP1, LOAD_SP, LOAD_EA
      - SP_OP0, ONE_OP1,  LOAD_SP, LOAD_EA
      - SP_OP0, ONE_OP1,  LOAD_SP, LOAD_EA, FETCH_LO_MD
      - SH_FETCH_MD
      - LOAD_X, FETCH_OP, INC_PC, DEC_SEQ
  # Branching
  - id: branch
    seq:
      - INC_PC, IMA
      - BRANCH_PC, IMA
      - FETCH_SEQ
  # Addressing modes
  - id: imm
    seq:
      - FETCH_LO_MD, INC_PC, EXEC_SEQ
  - id: direct
    seq:
      - FETCH_FIRST_EA, READ_BUS, INC_PC, EXEC_SEQ
  - id: extend
    seq:
      - FETCH_FIRST_EA, INC_PC
      - FETCH_NEXT_EA,  INC_PC, READ_BUS
      - FETCH_LO_MD, EXEC_SEQ
  - id: extend_wr
    seq:
      - FETCH_FIRST_EA, INC_PC
      - FETCH_NEXT_EA,  INC_PC, READ_BUS
      - FETCH_LO_MD, EXEC_SEQ, IMA
  - id: indexd
    seq:
      - FETCH_LO_MD, INC_PC, IMA
      - IX_OP0, LOAD_EA, READ_BUS
      - FETCH_LO_MD, EXEC_SEQ
  - id: indexd_wr
    seq:
      - FETCH_LO_MD, INC_PC, IMA
      - IX_OP0, LOAD_EA, READ_BUS
      - FETCH_LO_MD, EXEC_SEQ, IMA
  - id: berr
    seq:
      - BERR, HALT_SEQ