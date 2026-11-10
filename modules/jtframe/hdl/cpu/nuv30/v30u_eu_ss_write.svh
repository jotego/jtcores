//==========================================================================
//  v30u_eu_ss_write.svh -- save-state WRITE decode (arm #1)
//  GENERATED SECTION -- see sw/gen_ucore_ss.py note in
//  docs/notes/ucore_provenance.md.  Each SSA_E_* appears EXACTLY TWICE
//  in v30u_eu.sv: one write-decode arm and one read-mux arm.
//==========================================================================
        case (ss_addr)
            SSA_E_AX:                  gpr_n[0] = ss_wdata;
            SSA_E_CX:                  gpr_n[1] = ss_wdata;
            SSA_E_DX:                  gpr_n[2] = ss_wdata;
            SSA_E_BX:                  gpr_n[3] = ss_wdata;
            SSA_E_SP:                  gpr_n[4] = ss_wdata;
            SSA_E_BP:                  gpr_n[5] = ss_wdata;
            SSA_E_IX:                  gpr_n[6] = ss_wdata;
            SSA_E_IY:                  gpr_n[7] = ss_wdata;
            SSA_E_ES:                  sreg_n[0] = ss_wdata;
            SSA_E_CS:                  sreg_n[1] = ss_wdata;
            SSA_E_SS:                  sreg_n[2] = ss_wdata;
            SSA_E_DS:                  sreg_n[3] = ss_wdata;
            SSA_E_PC:                  pc_n = ss_wdata;
            SSA_E_PSW:                 psw_n = ss_wdata;
            SSA_E_TMPA:                tmpa_n = ss_wdata;
            SSA_E_TMPB:                tmpb_n = ss_wdata;
            SSA_E_TMPC:                tmpc_n = ss_wdata;
            SSA_E_OPR:                 opr_n = ss_wdata;
            SSA_E_IND:                 ind_n = ss_wdata;
            SSA_E_COUNT:               count_n = ss_wdata;
            SSA_E_PFXCNT:              pfxcnt_n = ss_wdata[7:0];
            SSA_E_STAT:                stat_n = ss_wdata;
            SSA_E_SIGN_NEG:            sign_neg_n = ss_wdata[0];
            SSA_E_BIT_N:               bit_n_n = ss_wdata[3:0];
            SSA_E_AL_OP:               al_op_n = ss_wdata[4:0];
            SSA_E_AL_TMP:              al_tmp_n = ss_wdata[1:0];
            SSA_E_AL_EACONST:          al_eaconst_n = ss_wdata[0];
            SSA_E_AL_EAVAL:            al_eaval_n = ss_wdata;
            SSA_E_AL_ADJUST:           al_adjust_n = ss_wdata[1:0];
            SSA_E_AL_ADJTMP:           al_adjtmp_n = ss_wdata[1:0];
            SSA_E_AL_BITARM:           al_bitarm_n = ss_wdata[0];
            SSA_E_AL_BITN:             al_bitn_n = ss_wdata[3:0];
            SSA_E_AL_SPENT:            al_spent_n = ss_wdata[0];
            SSA_E_UPC_PAGE:            upc_page_n = ss_wdata[2:0];
            SSA_E_UPC_OPC:             upc_opc_n = ss_wdata[7:0];
            SSA_E_UPC_LOC:             upc_loc_n = ss_wdata[3:0];
            SSA_E_SEG_OVR_EN:          seg_override_n = ss_wdata[0];
            SSA_E_SEG_OVR:             seg_ovr_n = ss_wdata[1:0];
            SSA_E_REP_KIND:            rep_kind_n = ss_wdata[2:0];
            SSA_E_LOCK:                lock_pfx_n = ss_wdata[0];
            SSA_E_OPC_REG:             opc_reg_n = ss_wdata[7:0];
            SSA_E_OP8:                 op8_n = ss_wdata[0];
            SSA_E_IMM8:                imm8_n = ss_wdata[0];
            SSA_E_OPC_BASE:            opc_base_n = ss_wdata[4:0];
            SSA_E_OPC_FROM_RM:         opc_from_modrm_n = ss_wdata[0];
            SSA_E_MODRM_REG:           modrm_reg_n = ss_wdata[2:0];
            SSA_E_XOP:                 xop_n = ss_wdata[3:0];
            SSA_E_REP_TEST:            rep_test_n = ss_wdata[1:0];
            SSA_E_REP_POL:             rep_pol_n = ss_wdata[0];
            SSA_E_BUS_WORD:            bus_word_n = ss_wdata[0];
            SSA_E_OPC8080:             opc8080_n = ss_wdata[0];
            SSA_E_MODE8080:            mode8080_n = ss_wdata[0];
            SSA_E_INTR_PEND:           intr_pending_n = ss_wdata[0];
            SSA_E_HALTED:              eu_halted_n = ss_wdata[0];
            SSA_E_M_KIND:              m_kind_n = ss_wdata[1:0];
            SSA_E_M_IDX:               m_idx_n = ss_wdata[2:0];
            SSA_E_M_EA:                m_ea_n = ss_wdata;
            SSA_E_M_SEG:               m_seg_n = ss_wdata[2:0];
            SSA_E_M_BYTE:              m_byte_n = ss_wdata[0];
            SSA_E_R_KIND:              r_kind_n = ss_wdata[1:0];
            SSA_E_R_IDX:               r_idx_n = ss_wdata[2:0];
            SSA_E_R_EA:                r_ea_n = ss_wdata;
            SSA_E_R_SEG:               r_seg_n = ss_wdata[2:0];
            SSA_E_R_BYTE:              r_byte_n = ss_wdata[0];
            SSA_E_WB_KIND:             wb_kind_n = ss_wdata[1:0];
            SSA_E_WB_IDX:              wb_idx_n = ss_wdata[2:0];
            SSA_E_WB_EA:               wb_ea_n = ss_wdata;
            SSA_E_WB_SEG:              wb_seg_n = ss_wdata[2:0];
            SSA_E_WB_BYTE:             wb_byte_n = ss_wdata[0];
            SSA_E_PEND_ACT:            pend_active_n = ss_wdata[0];
            SSA_E_PEND_OFF:            pend_off_n = ss_wdata;
            SSA_E_PEND_SEG:            pend_seg_n = ss_wdata[2:0];
            SSA_E_PEND_BYTE:           pend_byte_n = ss_wdata[0];
            SSA_E_PEND_IO:             pend_io_n = ss_wdata[0];
            SSA_E_OPR_FRESH:           opr_fresh_n = ss_wdata[0];
            SSA_E_OPR_LOADED:          opr_loaded_n = ss_wdata[0];
            SSA_E_WIDTH_TAGS:          begin
                tmpa_byte_n = ss_wdata[0]; tmpb_byte_n = ss_wdata[1];
                tmpc_byte_n = ss_wdata[2]; opr_byte_n  = ss_wdata[3];
                rdp0_byte_n = ss_wdata[4]; rdp1_byte_n = ss_wdata[5];
                rdq0_byte_n = ss_wdata[6]; rdq1_byte_n = ss_wdata[7];
            end
            SSA_E_GHOST_DISCARD:       ghost_rd_discard_n = ss_wdata[0];
            SSA_E_EA_RESIDUE:          ea_residue_n = ss_wdata;
            SSA_E_EA_PAIR_RHS:         ea_pair_rhs_n = ss_wdata;
            SSA_E_EA_PAIR_VALID:       ea_pair_valid_n = ss_wdata[0];
            SSA_E_RDQ0:                rdq0_n = ss_wdata;
            SSA_E_RDQ1:                rdq1_n = ss_wdata;
            SSA_E_RDQ_N:               rdq_n_n = ss_wdata[1:0];
            SSA_E_RD_PENDING:          rd_pending_n = ss_wdata[1:0];
            SSA_E_RD_DONE_CNT:         rd_done_cnt_n = ss_wdata[1:0];
            SSA_E_RD_AGE0:             rd_age0_n = ss_wdata[0];
            SSA_E_WR_OUT:              wr_out_n = ss_wdata[1:0];
            SSA_E_OPC_VALID:           opc_valid_n = ss_wdata[0];
            SSA_E_OPC_BYTE:            opc_byte_n = ss_wdata[7:0];
            SSA_E_POP_IS_FIRST:        pop_is_first_n = ss_wdata[0];
            SSA_E_LD_B:                ld_b_n = ss_wdata[7:0];
            SSA_E_LD_PLA:              ld_pla_n = ss_wdata[13:0];
            SSA_E_LD_EXT:              ld_ext_n = ss_wdata[0];
            SSA_E_LD_PAGE:             ld_page_n = ss_wdata[2:0];
            SSA_E_LD_HASRM:            ld_hasrm_n = ss_wdata[0];
            SSA_E_LD_RM:               ld_rm_n = ss_wdata[7:0];
            SSA_E_LD_DISP:             ld_disp_n = ss_wdata;
            SSA_E_LD_DLO:              ld_dlo_n = ss_wdata[7:0];
            SSA_E_LD_GRPD:             ld_grpd_n = ss_wdata[0];
            SSA_E_LD_BYTE:             ld_byte_n = ss_wdata[0];
            SSA_E_LD_PRERD:            ld_preread_n = ss_wdata[0];
            SSA_E_LD_RIPE_PREV:        ld_ripe_prev_n = ss_wdata[0];
            SSA_E_ST:                  st_n = ss_wdata[5:0];
            SSA_E_CHG:                 chg_n = ss_wdata[1:0];
            SSA_E_POSTE:               poste_n = ss_wdata[0];
            SSA_E_ROWQ:                rowq_n = ss_wdata[1:0];
            SSA_E_ROW_POSTED:          row_posted_n = ss_wdata[0];
            SSA_E_ROW_PAIRED:          row_paired_n = ss_wdata[0];
            SSA_E_RLOOP_N:             rloop_n_n = ss_wdata;
            SSA_E_SUPPRESS:            suppress_commit_n = ss_wdata[0];
            SSA_E_FIRST_POP:           first_pop_seen_n = ss_wdata[0];
            SSA_E_ROWB0:               rowb0_n = ss_wdata[7:0];
            SSA_E_ROWB1:               rowb1_n = ss_wdata[7:0];
            SSA_E_POLL_PIPE:           poll_pipe_n = ss_wdata[2:0];
            SSA_E_PE_OPC_REG:          pe_opc_reg_n = ss_wdata[7:0];
            SSA_E_PE_PFXCNT:           pe_pfxcnt_n = ss_wdata[7:0];
            SSA_E_PIN_PIPE:            begin
                                         int_p_n = ss_wdata[3:0];
                                         nmi_p_n = ss_wdata[8:4];
                                         ie_p_n  = ss_wdata[12:9];
                                       end
            SSA_E_IRQ_LATCH:           begin
                                         nmi_latch_n   = ss_wdata[0];
                                         irq_shadow_n  = ss_wdata[1];
                                         bnd_armed_n   = ss_wdata[2];
                                         irq_sel_nmi_n = ss_wdata[3];
                                         unhalt_pend_n = ss_wdata[4];
                                         rep_chain_n   = ss_wdata[5];
                                         irq_fast_inta_n = ss_wdata[6];
                                         irq_halt_entry_n = ss_wdata[7];
                                       end
            SSA_E_BRK:                 begin                        // §86
                                         brk_p_n       = BRK_FLOOR'(ss_wdata[3:0]);
                                         brk_arm_n     = ss_wdata[4];
                                         brk_smp_n     = ss_wdata[5];
                                         irq_sel_brk_n = ss_wdata[6];
                                       end
            SSA_E_PE_FLAGS:            begin
                                         pe_opc8080_n = ss_wdata[0];
                                         pe_op8_n     = ss_wdata[1];
                                         iend_owed_n  = ss_wdata[2];
                                       end
            // F49 (U4): F25's four-clock reset march position.
            SSA_E_RST_CTR:             rst_ctr_n = ss_wdata[2:0];
            default: ;
        endcase
