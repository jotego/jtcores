# CPS2 external DTACK timing

Run `source setprj.sh` at the repository root, then
`simunit-all.sh --only jtcps2_dtack`.

The directed test covers every high address nibble, opposite clock edges,
aborted cycles, acknowledgement retention, and DMA bus ownership.

Four real fx68k instances check a short read/modify/write loop with the
production `jtframe_68kdtack_cen` generator. The baseline takes 38 CPU clocks;
the DL-1827 delay adds one wait per external transfer, giving 47 clocks.
Occasional late memory responses exercise recovery without changing those
47 clocks. A TAS loop checks the AS-held data-strobe gap: it takes 63 clocks
(52 instruction clocks plus 11 waits), since TAS's second transfer retains
the board acknowledgement. Tests check both timing and written data.

`init.go` creates a disposable Icarus-compatible fx68k source and copies its
microcode ROMs. It changes only an enum-valued ternary into an equivalent
if/else; the production CPU source is untouched.

## Schematic basis and limits

Source: Loic "WydD" Petit's CPS2 reverse-engineering schematics (CC-BY),
[DL-1827 PDF](https://petitl.fr/cps2/DL-1827.pdf), sheets `control-states`,
`addr-decoder`, `objram-control-in`, and `interrupt-out`.

With the CPU owning the bus and the board enabled, U36R143/U28R133 produce
the active-AS reset release. U26R31 (FDO) samples 1 on CLK16M rising, then
U28R38 (FDO) samples it on CLK16M falling. U28R38's rising Q clocks the
active-low BUS-RANGE into U22R89 (FDN). FDO has active-low reset; FDN has
active-low set. AS release resets the first two and presets the third.
U25R130/U25R131 combine that result with the Z80 acknowledgement.

The address gates decode an external timed cycle for `$000000-$4fffff`
and `$800000-$ffffff`. AS falls on the CPU phase entering S2; the next
rising edge captures it, and the following falling edge changes DTACK.
That falling edge is already the CPU's first acknowledgement sample, so
the result is one wait state, not zero.

The core models this external timed path at master-clock resolution. It
retains the existing DL-1525 local-access treatment for `$500000-$7fffff`
and existing QSound bus-grant/memory-ready handshake; it does not claim to
recover the unknown DL-1525 internal acknowledgement logic. The board's
CPSA-E input is tied low. DMA scheduling and duration are unchanged.

The delay is counted on delivered CPU phases. While it is pending,
`bus_legit` forbids both memory-stall debt creation and repayment. Artificial
SDRAM delays after board acknowledgement eligibility remain recoverable.
Hardware testing is still needed to measure the effect on SSF2X gameplay.
