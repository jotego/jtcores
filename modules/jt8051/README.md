# JT8051

JT8051 is a cycle-scheduled Intel 8051/8751-compatible MCU for JTCORES.

`cen` is an oscillator-period enable. A complete machine cycle is twelve
`cen` pulses; the CPU asserts in simulation if consecutive `cen` pulses do
not have an intervening idle system-clock edge. Instruction timing originates
in `ucode/8051.yaml`, which is expanded with
`jtframe ucode --output jt8051 jt8051 8051`.

The public memory interface keeps program ROM, 128-byte internal RAM, and
external MOVX memory separate. The JTFRAME wrapper owns the memories so
whole-MCU simulations include their real synchronous access delay.

`ver/vectors/tests.yaml` follows the JT65C02 vector format: every test entry
contains its 8051 `asm` source and the matching architectural `check` on the
same line.  `ver/vectors` invokes `testgen` to assemble a named group with the
installed `as31` assembler and evaluates those checks at
`jt8051_ctrl.next_instruction`.  Entries may also provide `cycles`, expressed
in 8051 machine cycles; the bench measures the corresponding twelve `cen`
pulses between instruction boundaries.  The direct assembler form is:
`as31 -Fbin -Otest.bin test.asm`.
