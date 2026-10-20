//==========================================================================
//  v30u_eu_arm_bind.svh -- ONE CHAINABLE ARM OF THE MODEL'S STEP,
//  carried in its own file so that the flattened chain and the
//  33-arm case can both `include it and there is exactly ONE copy
//  of the body in the tree (WAVE 7, G-11).
//
//  IT IS INCLUDED IN TWO PLACES AND NOWHERE ELSE:
//    * v30u_eu_step.svh's `case (st_n)`, i.e. chain POSITION 0;
//    * v30u_eu.sv's flattened pass, i.e. chain POSITION >= 1.
//  Both sites supply the surrounding `begin` / `end`, so this file
//  is a STATEMENT LIST and nothing else.  It declares nothing and
//  carries no block label: it is elaborated twice in one scope.
//
//  THE SPEC POSITION IT IS A CUT POINT IN (WAVE 6 sec.1, and it is
//  why this arm is zero-cost at all -- there is no `charge()`
//  between it and its predecessor):
//    loader_impl.h:414-484 -- the OPC select and operand binding
//==========================================================================
    // ZERO-COST.
    pv = ld_pla_n;
    rmmod = ld_rm_n[7:6];
    rmreg = ld_rm_n[5:3];
    rmrm  = ld_rm_n[2:0];
    ld_grpd_n = 1'b0;
    // LEA exposes the address adder's full (post-displacement) result rather
    // than consuming it as a memory address.  That full result is therefore
    // what remains on the stale EA rail for a following register-form POP.
    if (!ld_ext_n && (ld_b_n == 8'h8D) && (rmmod != 2'd3))
        ea_residue_n = ind_n;
    if (ld_hasrm_n && (pla3_xop(pv) == 4'hB)) begin
        ld_page_n = ld_b_n[3] ? 3'd3 : 3'd2;
        opc_reg_n = ld_rm_n;
        ld_grpd_n = 1'b1;
    end
    modrm_reg_n = rmreg;
    opc_from_modrm_n = 1'b0;
    opc_base_n = 5'd0;
    if ((ld_page_n == 3'd2) || (ld_page_n == 3'd3)) begin
        opc_base_n = A_INC; opc_from_modrm_n = 1'b1;
    end else if (!ld_ext_n && (ld_b_n[7:2] == 6'b100000)) begin
        opc_base_n = 5'd0;  opc_from_modrm_n = 1'b1;
    end else if (!ld_ext_n && ((ld_b_n == 8'hC0) || (ld_b_n == 8'hC1) ||
                             (ld_b_n[7:2] == 6'b110100))) begin
        opc_base_n = A_ROL; opc_from_modrm_n = 1'b1;
    end else if (pla3_xop(pv) == 4'hC) begin
        opc_base_n = A_INC;
    end
    rep_test_n = TEST_NONE;
    rep_pol_n  = 1'b0;
    if (pla3_xop(pv) == 4'hE) begin
        if (!ld_ext_n && (ld_b_n[7:1] == 7'b1110000)) begin
            // A carry-repeat prefix on E0/E1 selects the CARRY rail, while
            // the LOOP opcode bit -- not the 64/65 prefix bit -- remains the
            // polarity input.  Socketed V30 controls over both prefixes,
            // E0/E1 and the three reachable CMP flag combinations measured:
            //   E0 + {64,65}: take iff CY=0
            //   E1 + {64,65}: take iff CY=1
            // This is one PLA-class mux plus the opcode polarity wire; it is
            // also the shared cause of fuzz mc1/1112 and mc1/2523.
            if ((rep_kind_n == REP_C) || (rep_kind_n == REP_NC))
                rep_test_n = TEST_CY;
            else
                rep_test_n = TEST_Z;
            rep_pol_n = ld_b_n[0];
        end else if ((rep_kind_n == REP_E) || (rep_kind_n == REP_NE)) begin
            rep_test_n = TEST_Z; rep_pol_n = (rep_kind_n == REP_E);
        end else if ((rep_kind_n == REP_C) || (rep_kind_n == REP_NC)) begin
            rep_test_n = TEST_CY; rep_pol_n = (rep_kind_n == REP_C);
        end
    end
    // the 0F BIT-FIELD group selects BYTE registers for both ModR/M operands
    bsw = ld_byte_n || (ld_ext_n && (pla3_xop(pv) == 4'h3));
    m_kind_n = OK_NONE; m_idx_n = 3'd0; m_byte_n = 1'b0;
    r_kind_n = OK_NONE; r_idx_n = 3'd0; r_byte_n = 1'b0; r_ea_n = 16'd0; r_seg_n = 3'd3;
    // 8D / mod=3 performs no EA calculation.  Silicon nevertheless executes
    // it and the row-1 SIGMA -> R transfer observes BOTH retained EA-adder
    // rails: A through `ea_residue`, and B through `ea_pair_rhs` whenever no
    // tmpb write has replaced what the last EA calculation put there.  Every
    // EA calculation loads B -- with the index, the displacement, or zero --
    // so `ea_pair_valid` is about REPLACEMENT, not about the form.
    // mc2/491 is the two-input witness (2594+retained SI 0fa3=3537); the
    // single-addend rows, where B is zero and not stale, are M4/M5/M7 of the
    // 2026-09-20 socket capture (sw/testdata/wave26/b2b/).
    if (!ld_ext_n && (ld_b_n == 8'h8D) && (rmmod == 2'd3)) begin
        tmpa_n = ea_residue_n;
        if (ea_pair_valid_n) tmpb_n = ea_pair_rhs_n;
    end
    if (ld_hasrm_n) begin
        if (pla3_sreg_mov(pv)) begin
            r_kind_n = OK_SREG; r_idx_n = {1'b0, rmreg[1:0]}; r_byte_n = 1'b0;
        end else begin
            r_kind_n = OK_REG;  r_idx_n = rmreg; r_byte_n = bsw;
        end
        // INS/EXT always use the ModR/M fields as the two byte-register
        // selectors.  The mod bits still determine how many displacement
        // bytes the loader consumes, but they do not turn either selector
        // into a memory operand: the bit-field stream itself is addressed by
        // DS:IX in microcode.  On 0F 33 A8 disp16 silicon therefore reads
        // DS:IX, with no speculative read of the decoded ModR/M EA.
        if ((rmmod == 2'd3) ||
            (ld_ext_n && (pla3_xop(pv) == 4'h3))) begin
            m_kind_n = OK_REG; m_idx_n = rmrm; m_byte_n = bsw;
        end else begin
            m_kind_n = OK_MEM; m_byte_n = ld_byte_n;
        end
        if (pla3_dir_from_bit1(pv) && ld_b_n[1]) begin
            tk = m_kind_n; m_kind_n = r_kind_n; r_kind_n = tk;
            ti = m_idx_n;  m_idx_n  = r_idx_n;  r_idx_n  = ti;
            te = m_ea_n;   m_ea_n   = r_ea_n;   r_ea_n   = te;
            ts = m_seg_n;  m_seg_n  = r_seg_n;  r_seg_n  = ts;
            tb = m_byte_n; m_byte_n = r_byte_n; r_byte_n = tb;
        end
    end else if (pla3_acc_w_operand(pv)) begin
        m_kind_n = OK_REG; m_idx_n = R_AW; m_byte_n = ld_byte_n;
    end else if ((ld_b_n < 8'h40) && (ld_b_n[2:0] >= 3'd6)) begin
        r_kind_n = OK_SREG; r_idx_n = {1'b0, ld_b_n[4:3]};
    end else begin
        m_kind_n = OK_REG; m_idx_n = ld_b_n[2:0]; m_byte_n = ld_byte_n;
    end
    wb_kind_n = m_kind_n; wb_idx_n = m_idx_n; wb_ea_n = m_ea_n;
    wb_seg_n = m_seg_n;   wb_byte_n = m_byte_n;

    ld_preread_n = 1'b0;
    if (ld_hasrm_n && (rmmod != 2'd3) && !(!ld_ext_n && pla3_modrm_store(pv)))
        if ((m_kind_n == OK_MEM) || (r_kind_n == OK_MEM)) begin
            ld_preread_n = 1'b1;
            // §87.A: the decoder's operand pre-read is the OTHER thing that
            // fills OPR, and it does not go through `rdq` -- `S_PRERD` writes
            // `opr` itself.  The model sets its flag straight off `ld.preread`
            // at the decode, not at the delivery, and so does this.  THIS IS
            // THE WHOLE `mod == 3` ASYMMETRY: the pre-read runs only for
            // `has_rm && mod != 3 && !MODRM_STORE`.
            opr_loaded_n = 1'b1;
        end

    row_posted_n = 1'b0;
    if (ld_preread_n)     st_n = S_PRERD;
    else if (ld_grpd_n)   st_n = S_GRPD_CHG;
    else                st_n = S_ENTER;
    if (st_n != S_ENTER) stop = 1'b1;
