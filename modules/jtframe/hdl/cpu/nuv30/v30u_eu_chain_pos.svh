//==========================================================================
//  v30u_eu_chain_pos.svh -- THE PER-POSITION BOOKKEEPING OF THE CHAIN.
//
//  Included at the head of EVERY chain position in v30u_eu.sv's flattened
//  pass -- position 0 and each of the nine positions >= 1 -- and nowhere
//  else.  It is the ONE copy of what the old `for (chain ...)` loop did once
//  per iteration, which is why it is a file and not ten transcriptions.
//
//  ⚠ IT IS ENTIRELY SIM-ONLY.  Under `SYNTHESIS` it expands to nothing at
//  all, so a chain position costs exactly its arm and no bookkeeping.
//
//  `chain_used` counts POSITIONS ENTERED, so after this line the position
//  index of the arm about to run is `chain_used - 1`.  That subtraction is
//  what re-keys WAVE 6's census off the running count now that there is no
//  loop variable to read.
//==========================================================================
`ifndef SYNTHESIS
chain_used = chain_used + 4'd1;
`ifdef CHAIN_PROBE
// sec.51.2's (position, state) pair census
if (!cp_seen[{chain_used - 4'd1, st_n}]) begin
    cp_seen[{chain_used - 4'd1, st_n}] = 1'b1;
    cp_fd = $fopen(`CHAIN_PROBE, "a");
    $fwrite(cp_fd, "POS %0d ST %0d\n", chain_used - 4'd1, st_n);
    $fclose(cp_fd);
end
// WAVE 6: the ORDERED tuple, recorded here and CENSUSED in the clocked
// observer (see the declaration block's warning).
cp_seq[chain_used - 4'd1] = st_n;
cp_used = chain_used;
`endif
`endif
