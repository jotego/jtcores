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

## Resource use

The Biocom Pocket build (Cyclone V 5CEBA4F23C8, `--nodbg`) maps the `jt8051`
instance to 2,631 combinational ALUTs and 340 registers, with no M10K block
RAM. The microcode ROM is synthesized as logic.

Program ROM and internal data RAM belong to the surrounding `jtframe_8751mcu`
wrapper rather than `jt8051`: the 4 KiB program ROM uses four M10Ks and the
128-byte data RAM uses one M10K, for five M10Ks (33,792 implemented bits) for
the complete MCU wrapper.

So overall: 2631 ALUT, 340 registers, 5 M10Ks
