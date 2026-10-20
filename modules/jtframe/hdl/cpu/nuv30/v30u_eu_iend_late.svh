//============================================================================
//  v30u_eu_iend_late.svh -- the part of `loader_decode`'s per-instruction
//  latch reset that THE POST-`E` ROW STILL READS.
//
//  F22.  In the model the order is fixed and obvious: the post-`E` row runs
//  inside `run_micro`, and only then does `step()` return and the successor's
//  `loader_decode` reset these latches.  In the EU the two land on DIFFERENT
//  edges -- the successor's decode is chained zero-cost into the `E` row's own
//  edge (it must be: `st` has to be S_MODRM/S_NORM_CHG during the decoder's
//  clock or the ModR/M byte is demanded one clock late), while the post-`E`
//  row is F8's one-bit debt, discharged at the top of the NEXT edge.  So the
//  reset arrived FIRST and the post-`E` row read a machine that had already
//  been cleared for its successor:
//
//    `40`  `SIGMA -> M`   wrote nothing   (m_kind cleared)  ax unchanged
//    `9C`  `SIGMA -> SP`  wrote tmpb      (ALU latch reset)  sp unchanged
//    `AA`  `SIGMA -> DI`  same                               di unchanged
//    0225  `PFXCNT -> tmpa`                                  pfxcnt cleared
//
//  DEFERRAL IS ONLY LEGAL FOR A FIELD THE EDGE-`c` CHAIN NEVER WRITES.  That
//  is the whole condition, and it is what the set below is selected by: the
//  post-`E` row reads these AND S_TAKE_OPC / S_DECODE / S_DECODE2 / S_PFX_CHG /
//  S_EXT_CHG1 write only `ld_b`/`op8`/`xop`/`opc_reg`/`ld_hasrm`/`pfxcnt`, so
//  for everything here the REGISTER still holds the predecessor's value at the
//  discharge and deferring the reset restores the model's order without moving
//  the decoder's byte-demand schedule by a clock.  The operand BINDING that
//  follows (S_NORM_CHG / the EA states) already runs on the later edge, after
//  the discharge, so it still lands on top of this.
//
//  For a field the chain DOES write, deferral is not merely insufficient, it is
//  actively wrong (it lands on top of the successor's own write) and the value
//  must TRAVEL with F8's debt instead -- `opc_reg` (F23), `op8` (D1) and, as of
//  pass 4, `pfxcnt`, which was F22's REGISTERED RESIDUE.  See the `pfxcnt_eff`
//  block in `v30u_eu.sv`.  `pfxcnt`'s reset is therefore back in S_INSTR_END's
//  IMMEDIATE block, where `loader_decode`'s prologue puts it.
//============================================================================
m_kind_n = OK_NONE; r_kind_n = OK_NONE; wb_kind_n = OK_NONE;
// F47 -- `begin_sequence()`'s OTHER line.  `CpuT::step()` (sim/exec_impl.h:777)
// opens EVERY instruction with `begin_sequence()` (:710), which is
// `pend_ = Pending{}; rdq_.clear(); opr_fresh_ = false; rep_elems_ = 0;`.
// S_IRQ_D transcribes that whole block verbatim (v30u_eu_step.svh, "`begin_
// sequence()`: the pairing latch and the completed-read store") and so does
// reset -- but S_INSTR_END, the ORDINARY instruction boundary, transcribed only
// its `rep_elems_` line (`rep_chain = 1'b0`).  So a `-> OPR` write in
// instruction N left the PAIRING LATCH ARMED into N+1, and `eu_pair` fired on
// N+1's POSTING row and handed the BIU N's operand: the write cycle is
// addressed and timed exactly right and carries the WRONG DATA WORD, which is
// F47's whole shape.  Diffuse by opcode (50-57, 6A, 8F, A2/A3, EE, AA, 86, ...)
// because the leak is a property of the BOUNDARY, not of either instruction --
// which is why the 169,000-case golden suite never reaches it: a
// single-instruction case cannot build it.
//
// DEFERRED HERE rather than in S_INSTR_END's immediate block, by this file's
// own stated condition: the post-`E` row STILL READS `opr_fresh` (the `poste &&
// pend_active && (opr_fresh || poste_wr_opr)` arm of `eu_pair`, and `opr_now`),
// and the edge-`c` chain (S_TAKE_OPC / S_DECODE / S_DECODE2 / S_PFX_CHG /
// S_EXT_CHG1) never writes it -- so the register still holds the predecessor's
// value at the discharge and `iend_owed` pays it in the model's order.
opr_fresh_n = 1'b0;
// §87.A -- ...and the OPR-VALID interlock, for the SAME reason and at the SAME
// instant.  `begin_sequence()` clears it, and this file IS the ordinary
// instruction boundary's transcription of `begin_sequence()` (S_IRQ_D and reset
// have their own copies).  Leaving it set would carry the predecessor's operand
// validity into the successor, and the successor is exactly where the
// illegal-form stall has to be able to fire.
opr_loaded_n = 1'b0;
// ...and the `ALU OPC` permutation base, for the same reason (`40`/`48`, whose
// INC/DEC comes from `opc_base = A_INC`, came out as ADD).
opc_base_n = 5'd0; opc_from_modrm_n = 1'b0; modrm_reg_n = 3'd0;
// the address adder stands on the SIGMA path with its default operation
al_op_n = A_ADD; al_tmp_n = 2'd0;
al_eaconst_n = 1'b0; al_adjust_n = 2'd0; al_bitarm_n = 1'b0; al_spent_n = 1'b0;
