//============================================================================
//  v30u_eu_preload.svh -- THE NEXT-STATE BLOCK'S HEAD, IN ONE PLACE BECAUSE
//  IT IS NOW NEEDED IN TWO.
//
//  This is VERBATIM the text that stood at the head of `v30u_eu.sv`'s
//  next-state `always @*` before the ce/ce_half PHASE SPLIT (WAVE 2,
//  2026-09-08): every `_n` preloaded from its own flop, then the 24 scratch
//  temporaries zeroed.  NOTHING IN IT CHANGED -- IT MOVED.
//
//  WHY IT IS INCLUDED TWICE.  The split runs STAGE 1 (blocks (a)-(f))
//  UNCONDITIONALLY, so that the phase-split shadow is re-derived on the SS
//  resume-drain edge from the FULLY RESTORED register file.  Stage 1 writes
//  `_n`, and under `ss_we` those writes must not survive: an `ss_we` clock
//  commits `_n` for EVERY register, so a `_n` the stream has not addressed yet
//  must still read as its own flop or the restore corrupts it.  Re-running
//  this head at the top of the `ss_we` arm UNDOES stage 1 exactly, and that
//  arm is then byte-identical to what it always was.
//
//  FALSIFIER: `sw/phase_split_lint.py` -- exactly two `include` sites, and the
//  `ss_we` arm's include must stand immediately before the ss_write include.
//============================================================================
    //-- preload: `_n` starts at the flop, so an arm that assigns nothing holds
    for (i = 0; i < 8; i = i + 1) gpr_n[i] = gpr[i];
    for (i = 0; i < 4; i = i + 1) sreg_n[i] = sreg[i];
    pc_n = pc;
    psw_n = psw;
    tmpa_n = tmpa;
    tmpa_byte_n = tmpa_byte;
    tmpb_byte_n = tmpb_byte;
    tmpc_byte_n = tmpc_byte;
    opr_byte_n = opr_byte;
    tmpb_n = tmpb;
    tmpc_n = tmpc;
    ea_residue_n = ea_residue;
    ea_pair_rhs_n = ea_pair_rhs;
    ea_pair_valid_n = ea_pair_valid;
    opr_n = opr;
    ind_n = ind;
    count_n = count;
    pfxcnt_n = pfxcnt;
    stat_n = stat;
    sign_neg_n = sign_neg;
    bit_n_n = bit_n;
    al_op_n = al_op;
    al_tmp_n = al_tmp;
    al_eaconst_n = al_eaconst;
    al_eaval_n = al_eaval;
    al_adjust_n = al_adjust;
    al_adjtmp_n = al_adjtmp;
    al_bitarm_n = al_bitarm;
    al_bitn_n = al_bitn;
    al_spent_n = al_spent;
    upc_page_n = upc_page;
    upc_opc_n = upc_opc;
    upc_loc_n = upc_loc;
    seg_override_n = seg_override;
    seg_ovr_n = seg_ovr;
    rep_kind_n = rep_kind;
    lock_pfx_n = lock_pfx;
    opc_reg_n = opc_reg;
    op8_n = op8;
    imm8_n = imm8;
    opc_base_n = opc_base;
    opc_from_modrm_n = opc_from_modrm;
    modrm_reg_n = modrm_reg;
    xop_n = xop;
    rep_test_n = rep_test;
    rep_pol_n = rep_pol;
    bus_word_n = bus_word;
    opc8080_n = opc8080;
    mode8080_n = mode8080;
    intr_pending_n = intr_pending;
    eu_halted_n = eu_halted;
    int_p_n = int_p;
    nmi_p_n = nmi_p;
    nmi_latch_n = nmi_latch;
    ie_p_n = ie_p;
    rep_chain_n = rep_chain;
    irq_shadow_n = irq_shadow;
    bnd_armed_n = bnd_armed;
    irq_sel_nmi_n = irq_sel_nmi;
    irq_sel_brk_n = irq_sel_brk;
    brk_p_n = brk_p;
    brk_arm_n = brk_arm;
    brk_smp_n = brk_smp;
    unhalt_pend_n = unhalt_pend;
    irq_fast_inta_n = irq_fast_inta;
    irq_halt_entry_n = irq_halt_entry;
    m_kind_n = m_kind;
    r_kind_n = r_kind;
    wb_kind_n = wb_kind;
    m_idx_n = m_idx;
    r_idx_n = r_idx;
    wb_idx_n = wb_idx;
    m_ea_n = m_ea;
    r_ea_n = r_ea;
    wb_ea_n = wb_ea;
    m_seg_n = m_seg;
    r_seg_n = r_seg;
    wb_seg_n = wb_seg;
    m_byte_n = m_byte;
    r_byte_n = r_byte;
    wb_byte_n = wb_byte;
    pend_active_n = pend_active;
    pend_off_n = pend_off;
    pend_seg_n = pend_seg;
    pend_byte_n = pend_byte;
    pend_io_n = pend_io;
    opr_fresh_n = opr_fresh;
    opr_loaded_n = opr_loaded;
    rdp0_byte_n = rdp0_byte;
    rdp1_byte_n = rdp1_byte;
    rdq0_byte_n = rdq0_byte;
    rdq1_byte_n = rdq1_byte;
    rdq0_n = rdq0;
    rdq1_n = rdq1;
    rdq_n_n = rdq_n;
    rd_pending_n = rd_pending;
    ghost_rd_discard_n = ghost_rd_discard;
    rd_done_cnt_n = rd_done_cnt;
    rd_age0_n = rd_age0;
    iend_owed_n = iend_owed;
    rst_ctr_n = rst_ctr;
    tsel_n = tsel;
    pe_opc_reg_n = pe_opc_reg;
    pe_opc8080_n = pe_opc8080;
    pe_op8_n = pe_op8;
    pe_pfxcnt_n = pe_pfxcnt;
    wr_out_n = wr_out;
    opc_valid_n = opc_valid;
    opc_byte_n = opc_byte;
    pop_is_first_n = pop_is_first;
    ld_b_n = ld_b;
    ld_pla_n = ld_pla;
    ld_ext_n = ld_ext;
    ld_page_n = ld_page;
    ld_hasrm_n = ld_hasrm;
    ld_rm_n = ld_rm;
    ld_disp_n = ld_disp;
    ld_dlo_n = ld_dlo;
    ld_grpd_n = ld_grpd;
    ld_byte_n = ld_byte;
    ld_preread_n = ld_preread;
    ld_ripe_prev_n = ld_ripe_prev;
    st_n = st;
    chg_n = chg;
    ending_n = ending;
    rowq_n = rowq;
    row_posted_n = row_posted;
    row_paired_n = row_paired;
    rloop_n_n = rloop_n;
    suppress_commit_n = suppress_commit;
    first_pop_seen_n = first_pop_seen;
    rowb0_n = rowb0;
    rowb1_n = rowb1;
    poste_n = poste;
    poll_pipe_n = poll_pipe;

    //-- ...and the SCRATCH TEMPORARIES start at zero, for the same reason the
    //   `_n` mirrors start at the flop: an arm that assigns nothing must not
    //   LATCH.  These 24 are pure per-evaluation locals -- every one of them is
    //   written before it is read on every reachable path (the writes dominate
    //   the reads inside one arm: `stop` at the head of the chain, `ie_now` /
    //   `brk_now` at the head of block (a), `nloc`/`carry`/`taken`/`bubble` at
    //   the head of the row body, `pv`/`rm*`/`ea`/`rseg`/`bsw` at the head of
    //   their decode arm, `v1`/`v2` immediately above the `wd1` include, and
    //   `tk`/`ti`/`ts`/`te`/`tb` on the swap line that reads them) -- so a
    //   defined starting value is UNOBSERVABLE and only removes 24 Quartus
    //   10240 latch inferences.  NONE of them is referenced by
    //   `v30u_eu_ss_write.svh`, so the `ss_we` arm holding them was never read
    //   either; the only reads outside this block are the `ifndef SYNTHESIS`
    //   observer (guarded `!ss_we`, where every one of them IS assigned) and
    //   the `_unused_eu` sink.
    //
    //   ⚠ THIS IS NOT A PLACE TO PARK A DEFAULT THAT MATTERS.  It is placed
    //   OUTSIDE the `chain` unroll on purpose: a value written at chain
    //   position k must still be visible at k+1, and it is.  If a future edit
    //   ever wants one of these to CARRY between evaluations it must become a
    //   `_n`/register pair, not lose a line from here.
    stop = 1'b0;
    chain = 4'd0;
    v1 = 16'd0;
    v2 = 16'd0;
    bsw = 1'b0;
    wb1 = 1'b0;
    wb2 = 1'b0;
    rdh_byte = 1'b0;
    pv = 14'd0;
    nloc = 4'd0;
    carry = 1'b0;
    taken = 1'b0;
    bubble = 1'b0;
    retire_now = 1'b0;
    rep_chained = 1'b0;
    ie_now = 1'b0;
    brk_now = 1'b0;
    ea = 16'd0;
    rseg = 3'd0;
    rmmod = 2'd0;
    rmreg = 3'd0;
    rmrm = 3'd0;
    tk = 2'd0;
    ti = 3'd0;
    ts = 3'd0;
    te = 16'd0;
    tb = 1'b0;
