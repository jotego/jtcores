# Toaplan DSP subsystem — verification

Phase 2 of the Wardner bring-up: `cores/wardner/hdl/jttoaplan1_dsp.v`, the glue
the arcade board puts around the TMS320C10, and the IKA32010 core
(`modules/ika32010`) it is connected to.

## What is verified

**Transaction conformance** (`./run.sh [activations]`). A model of the host CPU
raises the run bit, waits to be released, then drops it. Every host-visible
event — window re-points, reads, writes, port 3 control words, the release — is
logged and diffed against the same subsystem modelled in C (`ref32010.c`,
`toaplan` mode), which is transcribed from MAME's `tms32010.cpp`,
`toaplan/toaplan_dsp.cpp` and the `wardner_state::dsp_host_*_cb` overrides.

Two DSP programs drive it, written in `asm32010.py`, a small assembler:

- `prog_protocol.py` — the normal shape of a transaction: open with `0xffff` to
  port 3, read four operands from work RAM through an advancing window, sum and
  multiply them, write the result into sprite RAM and a marker into palette RAM,
  touch the top and bottom of the window's address range, then arm the release
  and close with `0x0000` to port 3. Also checks BIOZ falls through when BIO is
  clear and branches when it is set.
- `prog_edge.py` — the near misses. The host may only restart when a *zero* is
  written into word 0 or 1 of *work* RAM. This tries the right value at the
  wrong address, the wrong value at the right address, the right value in the
  wrong RAM, and a window pointing at no RAM at all, closing each attempt with a
  port 3 zero. Anything too generous releases the host early and the log
  diverges on the spot.

Each program runs at three different host idle times, because the handshake is a
strict sequence and how long the host waits must not change the log at all.
Every run makes six activations, so the interrupt that starts each one is
checked after the DSP has been halted, not only after reset.

**Properties**, checked continuously rather than inferred from the log:

1. The host's HALT line may only fall as the result of a zero written to port 3
   while the release flag is already armed.
2. The DSP's program counter must not move while the run bit is low.
3. Nothing may reach host memory, and no port activity may occur, while the run
   bit is low.

`+abortwr=1` drops the run bit on the exact clock a port strobe is live — the
core holds WE_n low between two clock enables, so that window is the only
moment a strobe can be stranded. The host cannot really do this, since it is
halted for the whole transaction, but the wrapper must not leak anything if it
does.

## Proving the suite can fail

`./mutate.sh` breaks the wrapper ten ways and requires the suite to notice each
one. Current result: **10 caught, 0 missed.**

```
release arm ignores the word address        release arm ignores the value written
port 3 zero releases without the arm        sprite RAM decoded as work RAM
invalid window treated as work RAM          window offset one bit too narrow
port strobes not gated by the run bit       interrupt held as a level not a pulse
BIO presented with the wrong polarity       BIO not set on the closing port 3 write
```

Two of these earned their place by finding gaps rather than confirming health.
"Port strobes not gated by the run bit" was initially missed, and closing it
needed both a new property and an abort timed to the one clock where a strobe is
live. "Window offset one bit too narrow" was also missed, because neither test
program used an offset with bit 10 set — the program was extended rather than
the harness.

"Interrupt held as a level" matters more with IKA32010 than it looks. MAME holds
INT asserted for the whole run, but IKA32010 latches a falling edge of INT_n
through a sampler that stops with the DSP's clock, so a level would be seen on
the first activation and missed on every one after it. The wrapper pulses
INT_n instead, and the mutation is caught by the second activation hanging.

## Against the real ROM

`./run_real.sh <dir with the wardnerb PROMs>` rebuilds the DSP's mask ROM from
the bootleg set's eight nibble PROMs and runs the real Wardner DSP program
through both models, comparing at two levels: every instruction (PC and all
registers) and every host-visible transaction. The host RAM contents are varied
by seed, because the real code dispatches on a command block the Z80 would
normally have left there.

Latest result, with IKA32010 and its `CALL` fix: **480,000 instructions and 580
transaction events compared across 16 host RAM seeds, PASS.** 80 instruction
lines differ, exactly five per seed, and all of them in the two status bits
described below. 99.5% of those instructions were inside
the real program; two seeds ran off the end of the code into unmapped space
after ~144 instructions, which is what a DSP given command data no Z80 would
ever write is entitled to do. 749 distinct addresses of the 1,536-word ROM were
reached, the rest being data tables and functions these command values do not
select.

### Where IKA32010 and MAME differ

IKA32010 has no trace outputs, so `tb_dsp.v` reads its registers by
hierarchical reference. MAME keeps the top of the stack in `STACK[3]` and
IKA32010 in `stack[0]`, so the stack is printed in reverse.

Two differences remain, and `itrace_cmp.awk` tolerates exactly these, each only
where it can show; any other difference fails the run:

- **OVM at reset.** MAME's reset sets OVM; IKA32010 leaves it clear. The Wardner
  program runs `ROVM` as its third instruction, so the status word differs on
  the first three trace lines only.
- **INTM when an interrupt is taken.** MAME sets INTM as it vectors; IKA32010
  only changes INTM on `DINT` and `EINT`. The Wardner vector at `002` is
  `B 30b`, and `30b` is `DINT`, so INTM differs on those two lines of each
  activation and nowhere else.

A third IKA32010 issue, the data page pointer being held at 0, cannot show here
at all: the Wardner ROM contains no `LDPK 1`, `LDP` or `LST`. See
`modules/ika32010/README.md`.

A fourth was a real fault on this ROM, and is fixed in the copy under
`modules/ika32010`: upstream's `CALL` pushed the address of its own operand, so
every `RET` came back one word early and ran that operand as an `ADD`. Seed 7
found it, at instruction 145: a `CALA` into the dispatch table at `0x539`, whose
`CALL 0510` pushed `0x53a` where MAME pushes `0x53b`. Of the 23 `CALL`s in the
program's code, 15 reload ACC straight after returning, which hides the fault;
the other 8 do not. None of the other seeds reach a `CALL` at all, which is why
the rest of the suite could not see it.

The comparison is by instruction, not by clock, so it does not see how long an
instruction takes. The main CPU boot bench does: its port log is the same with
either core, but a DSP activation during boot that lasts 391 bench ms finishes
179 µs later on IKA32010 than on the earlier core, which followed MAME's cycle
table. Presumably IKA32010 counts some instructions' machine cycles
differently; which ones has not been measured.

### A note on the ROM

No ROM data is in this repository, and the project's own `.gitignore` rule
`/cores/*/ver/**` means none can be committed from here by accident. The
bootleg set is used because it dumps the DSP's mask ROM as PROMs; the parent
set has no Wardner dump at all and substitutes the Flying Shark MCU
(`d70012u_gxc-02_mcu_71001`, in the `fshark` set, where it is the only copy
MAME does not flag), which is why MAME marks it BAD_DUMP in all four
Wardner-family sets.

Its first two words are `f900 0304` and `f900 030b`: a branch at the reset
vector and a branch at the interrupt vector, which is what a TMS320C10 program
must start with, and is the cheapest confirmation that the nibble assembly is
right.

### How far the two images actually differ

An earlier version of this file said the two were "different programs" on the
strength of their CRC32s, `273bf449` against `eee0ff59`. That was wrong.
Compared word for word they agree on **1534 of 1536 words**, and the two that
differ do so in one bit each - bit 7, the TMS320C10's direct/indirect
addressing flag:

```
       parent        bootleg
$034   0780 ADD *,7  0700 ADD 0,7    adds RAM[AR[ARP]] or RAM[dp:0]
$36d   6880 MAR *    6800 MAR 0      clears ARP, or does nothing at all
```

`MAR` looks like a no-op in both forms but is not: `ref32010.c`'s
`UPDATE_ARP` runs whenever bit 3 of the low byte is clear, so the indirect
form assigns ARP - here to 0 - while the direct form of `MAR` does nothing.
Both differences are therefore real.

It is not a dump defect in the PROMs. Both differing nibbles come from
`82s137.3d` bit 3, which is set at 310 of its 1024 addresses, so that bit is
not stuck, and the two are the only nibble mismatches across the whole
`0x400`-word range that PROM covers.

**Neither address is executed by anything tested here.** The 16 seeds reach
2541 distinct program counters and neither `$034` nor `$36d` is among them, so
running the parent image through the same comparison gives identical
instruction traces on all 16 - which proves nothing about the difference. Which
image is right for Wardner is therefore still an argument rather than a
measurement: the bootleg PROMs are a direct dump of the DSP on a Wardner
board, and the parent's is a Flying Shark part MAME substitutes because no
genuine Wardner dump exists, which is a good argument but not evidence. It
matters for the MRA, which can only assemble the parent's.

## Known limitations

- **Only the Wardner address decode is exercised.** The `TWINCOBR` parameter
  selects the 68000-side decode (a 13-bit offset over a 16 KB window); the
  formula is taken from `twincobr_state::dsp_host_addr_cb` but nothing tests it.
- **The host is a model, not a Z80.** What is verified is that the wrapper
  halts and releases correctly, not that the real main CPU responds to its HALT
  line as expected. That arrives with phase 3.
- **The DSP programs are hand-written, not the real one.** They exercise the
  protocol deliberately, including cases the real code may never hit; conversely
  the real code may do something these do not cover. The genuine dump remains
  the input that would settle it.
- **Only 34 of the 60 instruction forms are exercised.** That is what the real
  program uses; the synthetic fuzz suite that covered all 60 belonged to the
  earlier jt32010 core and went with it. Instruction coverage of IKA32010 itself
  is upstream's.
