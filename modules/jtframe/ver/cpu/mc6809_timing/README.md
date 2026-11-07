# MC6809 instruction timing

This unit test checks directed instruction intervals on the current `mc6809i`
RTL. It samples `OP && cen_E` on rising clock edges. The opening opcode fetch
is excluded and the next opcode fetch is included. Page 2/3 prefixes keep their
internal second-byte fetch inside the measured instruction.

The test checks the zero-mask PSHS/PSHU fast path, the SWI/SWI2/SWI3 entry
latencies and distinct vectors, and IRQ wake-up from SYNC and CWAI. SWI/SWI2/SWI3
must land at `$0150`/`$0160`/`$0170` through `$FFFA`/`$FFF4`/`$FFF2`.

For wait instructions, the test counts E edges starting with the target opcode
fetch edge and stops when the CPU enters its stable wait state. SYNC reaches
`CPUSTATE_SYNC` on edge 4, with BA high and AVMA low. This measures wait-state
entry; its total fetch-to-fetch interval depends on when an interrupt arrives.
CWAI reaches `CPUSTATE_CWAI_POST` on edge 20, with AVMA low. The test then
asserts IRQ and requires the handler opcode fetch at `$0150`. It uses the
internal state for the CWAI boundary because its four padding states share the
same external wait-bus shape.

Run from the repository root:

```sh
source setprj.sh
simunit.sh --run modules/jtframe/ver/cpu/mc6809_timing
```
