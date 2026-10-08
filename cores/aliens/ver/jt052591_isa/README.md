# 052591 instruction cross-validation

Run from the project root after `source setprj.sh`:

```
simunit.sh --run cores/aliens/ver/jt052591_isa
```

The test compares 65,536 individual instructions against Furrtek's independent silicon-derived `k052591` model. It exhaustively combines all 64 ALU operation/source encodings, eight destinations, four shift/division modes and both prior-instruction division state bits. Seeded random immediate/control bits and operands are mixed with zero, all-one, signed-overflow and alternating-bit cases. It compares the unshifted ALU result, carry/overflow, shifted register result, branch target, return latch, all register/accumulator writes, division history, external bus latches/control, RAM MSB latch and OUT0.

The gate model is held at its stable clock phase and given the same architectural inputs as the DUT through testbench hierarchy. Its original ALU/flag/mux equations are unmodified. Expected accumulator shifts and state enables also follow the documented instruction format. This isolates arithmetic and instruction semantics from simulator-specific gate timing; it is not a lockstep comparison of two complete running processors. The separate `jt052591_program` suite executes host-loaded game programs against synchronous external RAM and checks their final results.

The loader checks reset of partial uploads by PC writes, high-nibble masking of the fifth byte, wrap at address 63, locked writes targeting address zero while the entry counter still advances, and rejection of configuration writes while START is high. Host writes remain asserted for several clocks to catch repeated-write capture.

## Reference provenance

`k052591_reference.v` is the 2023 Furrtek (Sean Gonsalves) simulation model from [SiliconRE/Konami/052591/sim/k052591.v](https://github.com/furrtek/SiliconRE/blob/master/Konami/052591/sim/k052591.v), taken from the local SiliconRE checkout on 2026-09-24. It is test-only and never part of the synthesized core. Original file SHA-256:

```
c191de48b6a02f95148046ad95dd0faee9fd84d4270b2ba9160a6dba59f1b2a0
```

The modifications are explicit forward declarations of 16 existing implicit scalar wires for Icarus Verilog compatibility and removal of trailing whitespace. No equations, state logic or timing have been changed. The upstream repository's GPL version 2 license is reproduced verbatim as `LICENSE.reference`.

This snapshot is newer than the older copy under `cores/aliens/doc/052591`: upstream corrected zero-extension polarity, the accumulator's left-shift input and operand-register timing. The test intentionally uses the corrected snapshot. The reference retains upstream's uncertainty about external write pulse timing; the processor integration test independently checks actual writes.
