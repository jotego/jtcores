//==========================================================================
//  v30u_eu_arm_ea_calc.svh -- ONE CHAINABLE ARM OF THE MODEL'S STEP,
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
//    loader_impl.h:394 -- `ea_compute(m, rm, disp)`, one pure function call
//==========================================================================
    // ZERO-COST: the address adder; the clocks it needs were spent above.
    rmmod = ld_rm_n[7:6];
    rmrm  = ld_rm_n[2:0];
    case (rmrm)
        3'd0: ea = gpr_n[R_BW] + gpr_n[R_IX];
        3'd1: ea = gpr_n[R_BW] + gpr_n[R_IY];
        3'd2: ea = gpr_n[R_BP] + gpr_n[R_IX];
        3'd3: ea = gpr_n[R_BP] + gpr_n[R_IY];
        3'd4: ea = gpr_n[R_IX];
        3'd5: ea = gpr_n[R_IY];
        3'd6: ea = (rmmod == 2'd0) ? 16'd0 : gpr_n[R_BP];
        default: ea = gpr_n[R_BW];
    endcase
    // Retain the EA adder's pre-displacement half without overwriting the
    // microcode tmpa register.  The distinction is normally invisible, but
    // register-form LEA exposes it through the still-armed ADD datapath.
    ea_residue_n = ea;
    // THE ADDER'S B RAIL IS LOADED ON EVERY EA CALCULATION, AND WHAT IT TAKES
    // IS THE SECOND ADDEND -- the index register where the form has one and
    // nothing is added after it, the displacement otherwise, and ZERO where
    // there is nothing to add (`ld_disp_n` is 0 on a form with no
    // displacement, so the one mux covers both).  Measured on silicon over
    // thirteen directed socket probes, `<predecessor> 8D F7`:
    // docs/notes/suite_divergence_results_2026-09-20.md sec.6.2.
    //   [BW+IX]  -> IX      [BP+IY] -> IY      [IX] / [IY] / [BW] -> 0
    //   [disp16] -> disp    and mod=01/10 -> disp (PREDICTED, NOT MEASURED:
    //   no silicon probe of a base+index+displacement form exists).
    // `_valid` no longer means "there was a pair"; it means "the rail was
    // loaded by an EA calculation and nothing has written tmpb since", which
    // is what the clear beside every tmpb write below already implemented.
    ea_pair_valid_n = 1'b1;
    ea_pair_rhs_n = ((rmmod == 2'd0) && (rmrm <= 3'd3))
                  ? (rmrm[0] ? gpr_n[R_IY] : gpr_n[R_IX])
                  : ld_disp_n;
    ea = ea + ld_disp_n;
    rseg = seg_override_n ? {1'b0, seg_ovr_n}
         : ((rmrm == 3'd2) || (rmrm == 3'd3) ||
            ((rmrm == 3'd6) && (rmmod != 2'd0))) ? 3'd2 : 3'd3;
    ind_n = ea;
    al_eaconst_n = 1'b1;
    al_eaval_n   = ea;
    m_ea_n = ea;  m_seg_n = rseg;
    st_n = S_BIND;
