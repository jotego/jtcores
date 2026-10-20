//==========================================================================
//  v30u_eu_arm_decode2.svh -- ONE CHAINABLE ARM OF THE MODEL'S STEP,
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
//    loader_impl.h:283-373 -- the post-loop `one_byte_logic` / width / ModR-M fan-out
//==========================================================================
    pv = ld_ext_n ? pla3_ext(ld_b_n) : pla3_native(ld_b_n);
    ld_pla_n = pv;
    if (!ld_ext_n && pla3_one_byte_logic(pv)) begin
        // fz2 P2 / `L-B` -- **`HLT` DOES NOT PARK WHEN IT RETIRES INTO THE
        // TRAP.**  `brk_seen` is the term, and it is the SAME signal the
        // sibling arm of this `if` reads on this same clock for the same
        // reason (W3.5's law below: at this decode the arm flop still carries
        // the previous boundary's value and `brk_seen` is the live one,
        // measured 23/23).  A parked part has no next boundary, so an arm
        // sampled at the `HLT`'s own retire has nowhere to be spent and the
        // trap is lost outright.
        //
        // MEASURED, banked FLASH #14 captures, chip against fabric core
        // (`docs/notes/fz2_p2_prereg_2026-08-10.md` §2.2).  Exemplar
        // `fz2e/535042`: an `IRET` restores `TF`, the redirect lands on a
        // byte `F4`, and the chip reads vector 1 with **no HALT cycle ever
        // driven** -- and the frame it pushes carries IP `0e84`, ONE PAST the
        // `F4`.  Silicon RETIRED the `HLT` and took the trap at its boundary;
        // it did not halt and then wake.  The core's own trace has the sample
        // right (`BRKS seen=1` at the correct boundary) and then parks.
        //
        // With the term false this falls into the `ONE_BYTE_LOGIC` arm `HALT`
        // is already a member of; `v30u_eu_1bl.svh` is `default: ;` for this
        // xop and ends with the identical `psw_n = (psw_n & PSW_WRITABLE) |
        // PSW_FORCED` this arm writes, so the fall-through makes the same
        // architectural write and then takes the ordinary boundary -- which is
        // where the trap is due.  No flop, no wire, no save-state address, and
        // no opcode named that this line did not already name.
        // *Falsifier*: a capture in which the chip drives a HALT cycle at a
        // `HLT` whose own retire boundary has the BRK/TF arm standing.
        if (pla3_xop(pv) == PLA3_BL1_HALT && !brk_seen) begin
            // S9a: `halt_decode()` is called HERE, after `pop_opcode`'s own
            // `charge(1)`, so `eu_halt` rides the DECODE clock -- the state
            // this arm hands over to.  One rule, both paths.
            eu_halted_n = 1'b1;
            // clear_consumed(): the wake's pop is a fresh instruction's `F`,
            // and the HALT path never reaches `S_INSTR_END` to say so.
            pop_is_first_n = 1'b1;
            psw_n = (psw_n & PSW_WRITABLE) | PSW_FORCED;
            st_n = S_HALTED;
        end else begin
            // §35.3 -- THE 1BL EXECUTE STROBE IS THIS EDGE, NOT THE NEXT ONE.
            // The model is `charge(1); wait_retire_lead(); <write>; charge(1);`
            // -- the write commits at clk_ = pop+1, i.e. it is VISIBLE DURING
            // the clock this arm hands over to, so it has to be made on the
            // edge that hands over.  The wait's condition is available here:
            // `q_ripe_lead_n` is the next-state view and says "the head is
            // poppable by pop+2", which is `wait_retire_lead`'s test AT
            // clk_ = pop+1, exactly.
            //
            // `S_1BL_LEAD` keeps the case where it is NOT yet satisfied and
            // becomes a PURE WAIT; `S_1BL_CHG` is the trailing `charge(1)`
            // both paths owe.  MEASURED, `FA idx 4`: the golden's status
            // nibble is already 2 (IE=0) on clock 1 and `S_1BL_LEAD` was
            // standing there, so the write landed on the edge ENDING clock 1.
`ifndef SYNTHESIS
            // wrfuzz W3.5's decode probe (see `trc_1bld_*` in v30u_eu.sv).
            trc_1bld_hit = 1'b1; trc_1bld_ripe = q_ripe_lead_n;
            trc_1bld_seen = brk_seen; trc_1bld_arm = brk_arm;
            trc_1bld_smp = brk_smp_n; trc_1bld_shd = irq_shadow_n;
`endif
            // wrfuzz W3.5 -- ...AND THE LEAD LEADS THE SUCCESSOR'S POP, SO A
            // FORM THAT RETIRES INTO THE TRAP HAS NO POP TO LEAD.
            //
            // `wrfuzz_provenance.md` §7's law, the `ucore`'s rendering of it:
            // `wait_retire_lead()` returns AT ONCE when the BRK/TF arm is set,
            // because when the arm is set this instruction retires INTO the
            // trap and its successor is never popped.  The WAIT ITSELF IS
            // KEPT -- §7.5 falsified deleting it (the odd-`ip` half of
            // `loader_impl.h`'s 250/250 golden says the FLAG WRITE does wait
            // for its byte to arrive; deleting the queue test moved `FA`,
            // `FB` and `INT.FB`, 181 row-diffs).  Two laws, one call.
            //
            // ⚠ THE GATE IS `brk_seen`, NOT `brk_arm`, AND THAT IS MEASURED,
            // NOT CHOSEN.  This arm rides the OPCODE POP'S OWN CLOCK (the
            // chain `S_OPC_POP -> S_DECODE -> S_DECODE2`, and equally
            // `S_EPOP -> S_TAIL -> S_INSTR_END -> S_TAKE_OPC -> ...`), so
            // `brk_smp` -- the sample instant §85.2a fixed at pop + 1 -- has
            // NOT HAPPENED YET and the arm flop still carries the value the
            // previous boundary spent.  MEASURED (`sw/w35_take.py arm`, the 23
            // P1 seeds, ZERO exceptions): `brk_arm` = 0 on 23/23 at this
            // decode, `brk_seen` = 1 on 23/23, `brk_smp_n` = 1 on 23/23, and
            // the sample lands exactly ONE clock later.  W3.4's mirror gate
            // read `brk_arm` here, could not fire, fell through to
            // `S_1BL_LEAD` and fired at decode + 2 -- which is `wr1/201055`'s
            // 2731 against the model's 2729, §7.8's reported miss, explained.
            //
            // AND THE BOUNDARY NEEDS NOTHING: `S_1BL_CHG` plus the zero-cost
            // `S_INSTR_END` put the successor's `S_OPC_POP` -- `bnd_opc` -- at
            // decode + 2, and decode + 2 IS the chip's take on 23/23 (§7.4's
            // "its own opcode pop + 2, WAIT-INDEPENDENT").  §7.8's proposed
            // second boundary arm for this path is NOT needed and is not taken.
            //
            // `irq_shadow` is NOT a term, for the model's own reason and now
            // by measurement: every pop state clears it and every opcode is
            // popped by one, so it is 0 at this decode on 23/23.  §7.8's named
            // trap is ANSWERED and INERT -- the difference that mattered was
            // never the shadow, it was the ARM'S AVAILABILITY.
            //
            // `S_1BL_LEAD` is deliberately NOT gated: the model tests
            // `brk_pending_` ONCE, at entry, and then loops.
            //
            // *Falsifier*: any capture in which a `ONE_BYTE_LOGIC` form
            // retiring into a BRK/TF take has its boundary later than its own
            // opcode pop + 2 with a dry queue; or any `FA` / `FB` golden that
            // moves when this gate is armed (they fire no trap, so `brk_seen`
            // is 0 in their goldens and they are untouched by construction).
            if (q_ripe_lead_n || brk_seen) begin
                `include "v30u_eu_1bl.svh"
                st_n = S_1BL_CHG;
            end else begin
                st_n = S_1BL_LEAD;
            end
        end
        stop = 1'b1;
    end else begin
        ld_byte_n = pla3_byte_only(pv) ? 1'b1
                : pla3_w_from_bit0(pv) ? (ld_b_n[0] == 1'b0)
                : 1'b0;
        op8_n  = ld_byte_n;
        imm8_n = ld_byte_n || (ld_b_n == 8'h83) || (ld_b_n == 8'h6B);
        xop_n  = pla3_xop(pv);
        // ...and the sreg-MOV class arms the recognition shadow (`8C` / `8E`,
        // load AND store -- both measured).  One boundary, spent by it.
        //
        // W3.1 -- AND THE `POP` sreg ENTRY IS IN THE SAME CLASS.  The shadow
        // is a property of the MICROCODE ENTRY, not of a PLA column: `8C`/`8E`
        // are `00?.100011?0.00` and `07`/`0F`/`17`/`1F` are `00?.000??111.00`,
        // and the ROM has no third entry between them.  There is no PLA bit
        // for the second one -- `pla3_sreg_mov` is exactly `8C`/`8E`, checked
        // against the generated table -- so it is three opcodes named in ONE
        // place.  `0F` is the extension escape on this part and is excluded by
        // `!ld_ext_n`, which is also what stops `0F 1F` reading as `POP DS`.
        //
        // MEASURED chip-side, `sw/w31_shadow.py`: `07` and `17` are grace 1 on
        // 6 of 6 pairs and grace 0 on none, while `PUSH` sreg (`06`/`16`, the
        // ADJACENT entry `00?.000??110.00`) is grace 0 on 5 of 5 and `LES` /
        // `LDS` grace 0 on 11 of 11.
        if (!ld_ext_n && (pla3_sreg_mov(pv) ||
                          ld_b_n == 8'h07 || ld_b_n == 8'h17 ||
                          ld_b_n == 8'h1F))
            irq_shadow_n = 1'b1;
        ld_page_n = ld_ext_n ? 3'd4 : ((rep_kind_n != REP_NONE) ? 3'd1 : 3'd0);
        opc_reg_n = ld_b_n;
        ld_hasrm_n = pla3_has_modrm(pv);
        st_n = pla3_has_modrm(pv) ? S_MODRM : S_NORM_CHG;
        stop = 1'b1;
    end
