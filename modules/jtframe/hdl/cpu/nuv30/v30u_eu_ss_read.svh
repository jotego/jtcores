//==========================================================================
//  v30u_eu_ss_read.svh -- save-state READ mux (arm #2)
//  GENERATED SECTION -- see sw/gen_ucore_ss.py note in
//  docs/notes/ucore_provenance.md.  Each SSA_E_* appears EXACTLY TWICE
//  in v30u_eu.sv: one write-decode arm and one read-mux arm.
//==========================================================================
    case (ss_addr)
        SSA_E_AX:                  ss_rdata <= gpr[0];
        SSA_E_CX:                  ss_rdata <= gpr[1];
        SSA_E_DX:                  ss_rdata <= gpr[2];
        SSA_E_BX:                  ss_rdata <= gpr[3];
        SSA_E_SP:                  ss_rdata <= gpr[4];
        SSA_E_BP:                  ss_rdata <= gpr[5];
        SSA_E_IX:                  ss_rdata <= gpr[6];
        SSA_E_IY:                  ss_rdata <= gpr[7];
        SSA_E_ES:                  ss_rdata <= sreg[0];
        SSA_E_CS:                  ss_rdata <= sreg[1];
        SSA_E_SS:                  ss_rdata <= sreg[2];
        SSA_E_DS:                  ss_rdata <= sreg[3];
        SSA_E_PC:                  ss_rdata <= pc;
        SSA_E_PSW:                 ss_rdata <= psw;
        SSA_E_TMPA:                ss_rdata <= tmpa;
        SSA_E_TMPB:                ss_rdata <= tmpb;
        SSA_E_TMPC:                ss_rdata <= tmpc;
        SSA_E_OPR:                 ss_rdata <= opr;
        SSA_E_IND:                 ss_rdata <= ind;
        SSA_E_COUNT:               ss_rdata <= count;
        SSA_E_PFXCNT:              ss_rdata <= {8'b0, pfxcnt};
        SSA_E_STAT:                ss_rdata <= stat;
        SSA_E_SIGN_NEG:            ss_rdata <= {15'b0, sign_neg};
        SSA_E_BIT_N:               ss_rdata <= {12'b0, bit_n};
        SSA_E_AL_OP:               ss_rdata <= {11'b0, al_op};
        SSA_E_AL_TMP:              ss_rdata <= {14'b0, al_tmp};
        SSA_E_AL_EACONST:          ss_rdata <= {15'b0, al_eaconst};
        SSA_E_AL_EAVAL:            ss_rdata <= al_eaval;
        SSA_E_AL_ADJUST:           ss_rdata <= {14'b0, al_adjust};
        SSA_E_AL_ADJTMP:           ss_rdata <= {14'b0, al_adjtmp};
        SSA_E_AL_BITARM:           ss_rdata <= {15'b0, al_bitarm};
        SSA_E_AL_BITN:             ss_rdata <= {12'b0, al_bitn};
        SSA_E_AL_SPENT:            ss_rdata <= {15'b0, al_spent};
        SSA_E_UPC_PAGE:            ss_rdata <= {13'b0, upc_page};
        SSA_E_UPC_OPC:             ss_rdata <= {8'b0, upc_opc};
        SSA_E_UPC_LOC:             ss_rdata <= {12'b0, upc_loc};
        SSA_E_SEG_OVR_EN:          ss_rdata <= {15'b0, seg_override};
        SSA_E_SEG_OVR:             ss_rdata <= {14'b0, seg_ovr};
        SSA_E_REP_KIND:            ss_rdata <= {13'b0, rep_kind};
        SSA_E_LOCK:                ss_rdata <= {15'b0, lock_pfx};
        SSA_E_OPC_REG:             ss_rdata <= {8'b0, opc_reg};
        SSA_E_OP8:                 ss_rdata <= {15'b0, op8};
        SSA_E_IMM8:                ss_rdata <= {15'b0, imm8};
        SSA_E_OPC_BASE:            ss_rdata <= {11'b0, opc_base};
        SSA_E_OPC_FROM_RM:         ss_rdata <= {15'b0, opc_from_modrm};
        SSA_E_MODRM_REG:           ss_rdata <= {13'b0, modrm_reg};
        SSA_E_XOP:                 ss_rdata <= {12'b0, xop};
        SSA_E_REP_TEST:            ss_rdata <= {14'b0, rep_test};
        SSA_E_REP_POL:             ss_rdata <= {15'b0, rep_pol};
        SSA_E_BUS_WORD:            ss_rdata <= {15'b0, bus_word};
        SSA_E_OPC8080:             ss_rdata <= {15'b0, opc8080};
        SSA_E_MODE8080:            ss_rdata <= {15'b0, mode8080};
        SSA_E_INTR_PEND:           ss_rdata <= {15'b0, intr_pending};
        SSA_E_HALTED:              ss_rdata <= {15'b0, eu_halted};
        SSA_E_M_KIND:              ss_rdata <= {14'b0, m_kind};
        SSA_E_M_IDX:               ss_rdata <= {13'b0, m_idx};
        SSA_E_M_EA:                ss_rdata <= m_ea;
        SSA_E_M_SEG:               ss_rdata <= {13'b0, m_seg};
        SSA_E_M_BYTE:              ss_rdata <= {15'b0, m_byte};
        SSA_E_R_KIND:              ss_rdata <= {14'b0, r_kind};
        SSA_E_R_IDX:               ss_rdata <= {13'b0, r_idx};
        SSA_E_R_EA:                ss_rdata <= r_ea;
        SSA_E_R_SEG:               ss_rdata <= {13'b0, r_seg};
        SSA_E_R_BYTE:              ss_rdata <= {15'b0, r_byte};
        SSA_E_WB_KIND:             ss_rdata <= {14'b0, wb_kind};
        SSA_E_WB_IDX:              ss_rdata <= {13'b0, wb_idx};
        SSA_E_WB_EA:               ss_rdata <= wb_ea;
        SSA_E_WB_SEG:              ss_rdata <= {13'b0, wb_seg};
        SSA_E_WB_BYTE:             ss_rdata <= {15'b0, wb_byte};
        SSA_E_PEND_ACT:            ss_rdata <= {15'b0, pend_active};
        SSA_E_PEND_OFF:            ss_rdata <= pend_off;
        SSA_E_PEND_SEG:            ss_rdata <= {13'b0, pend_seg};
        SSA_E_PEND_BYTE:           ss_rdata <= {15'b0, pend_byte};
        SSA_E_PEND_IO:             ss_rdata <= {15'b0, pend_io};
        SSA_E_OPR_FRESH:           ss_rdata <= {15'b0, opr_fresh};
        SSA_E_OPR_LOADED:          ss_rdata <= {15'b0, opr_loaded};
        SSA_E_WIDTH_TAGS:          ss_rdata <= {8'b0, rdq1_byte, rdq0_byte,
                                                rdp1_byte, rdp0_byte, opr_byte,
                                                tmpc_byte, tmpb_byte, tmpa_byte};
        SSA_E_GHOST_DISCARD:       ss_rdata <= {15'b0, ghost_rd_discard};
        SSA_E_EA_RESIDUE:          ss_rdata <= ea_residue;
        SSA_E_EA_PAIR_RHS:         ss_rdata <= ea_pair_rhs;
        SSA_E_EA_PAIR_VALID:       ss_rdata <= {15'b0, ea_pair_valid};
        SSA_E_RDQ0:                ss_rdata <= rdq0;
        SSA_E_RDQ1:                ss_rdata <= rdq1;
        SSA_E_RDQ_N:               ss_rdata <= {14'b0, rdq_n};
        SSA_E_RD_PENDING:          ss_rdata <= {14'b0, rd_pending};
        SSA_E_RD_DONE_CNT:         ss_rdata <= {14'b0, rd_done_cnt};
        SSA_E_RD_AGE0:             ss_rdata <= {15'b0, rd_age0};
        SSA_E_WR_OUT:              ss_rdata <= {14'b0, wr_out};
        SSA_E_OPC_VALID:           ss_rdata <= {15'b0, opc_valid};
        SSA_E_OPC_BYTE:            ss_rdata <= {8'b0, opc_byte};
        SSA_E_POP_IS_FIRST:        ss_rdata <= {15'b0, pop_is_first};
        SSA_E_LD_B:                ss_rdata <= {8'b0, ld_b};
        SSA_E_LD_PLA:              ss_rdata <= {2'b0, ld_pla};
        SSA_E_LD_EXT:              ss_rdata <= {15'b0, ld_ext};
        SSA_E_LD_PAGE:             ss_rdata <= {13'b0, ld_page};
        SSA_E_LD_HASRM:            ss_rdata <= {15'b0, ld_hasrm};
        SSA_E_LD_RM:               ss_rdata <= {8'b0, ld_rm};
        SSA_E_LD_DISP:             ss_rdata <= ld_disp;
        SSA_E_LD_DLO:              ss_rdata <= {8'b0, ld_dlo};
        SSA_E_LD_GRPD:             ss_rdata <= {15'b0, ld_grpd};
        SSA_E_LD_BYTE:             ss_rdata <= {15'b0, ld_byte};
        SSA_E_LD_PRERD:            ss_rdata <= {15'b0, ld_preread};
        SSA_E_LD_RIPE_PREV:        ss_rdata <= {15'b0, ld_ripe_prev};
        SSA_E_ST:                  ss_rdata <= {10'b0, st};
        SSA_E_CHG:                 ss_rdata <= {14'b0, chg};
        SSA_E_POSTE:               ss_rdata <= {15'b0, poste};
        SSA_E_ROWQ:                ss_rdata <= {14'b0, rowq};
        SSA_E_ROW_POSTED:          ss_rdata <= {15'b0, row_posted};
        SSA_E_ROW_PAIRED:          ss_rdata <= {15'b0, row_paired};
        SSA_E_RLOOP_N:             ss_rdata <= rloop_n;
        SSA_E_SUPPRESS:            ss_rdata <= {15'b0, suppress_commit};
        SSA_E_FIRST_POP:           ss_rdata <= {15'b0, first_pop_seen};
        SSA_E_ROWB0:               ss_rdata <= {8'b0, rowb0};
        SSA_E_ROWB1:               ss_rdata <= {8'b0, rowb1};
        SSA_E_POLL_PIPE:           ss_rdata <= {13'b0, poll_pipe};
        SSA_E_PE_OPC_REG:          ss_rdata <= {8'b0, pe_opc_reg};
        SSA_E_PE_PFXCNT:           ss_rdata <= {8'b0, pe_pfxcnt};
        SSA_E_PE_FLAGS:            ss_rdata <= {13'b0, iend_owed, pe_op8,
                                                pe_opc8080};
        SSA_E_PIN_PIPE:            ss_rdata <= {3'b0, ie_p, nmi_p, int_p};
        SSA_E_IRQ_LATCH:           ss_rdata <= {8'b0, irq_halt_entry,
                                                irq_fast_inta,
                                                rep_chain, unhalt_pend,
                                                irq_sel_nmi,
                                                bnd_armed, irq_shadow,
                                                nmi_latch};
        // §86: the single-step arm, all of it, in one word -- the TF pipeline
        // `brk_p`, the ARM, the sample-instant pulse and the trap's kind bit.
        SSA_E_BRK:                 ss_rdata <= {9'b0, irq_sel_brk, brk_smp,
                                                brk_arm, 4'(brk_p)};
        // F49 (U4): F25's four-clock reset march position.
        SSA_E_RST_CTR:             ss_rdata <= {13'b0, rst_ctr};
        default: ss_rdata <= 16'h0000;
    endcase
