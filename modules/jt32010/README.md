# jt32010 — Texas Instruments TMS320C10 (TMS32010)

A synthesisable 16-bit DSP core, written for the Toaplan TP-009 / Twin Cobra
boards (Wardner, Twin Cobra, Flying Shark, Sky Shark, Demon's World), where the
part is a gameplay coprocessor rather than protection.

**Status: verified in simulation against a reference model. Not yet synthesised,
not yet run against a real game ROM.**

## What it is

- 12-bit program address space, 16-bit instruction words
- 8-bit data address space; the C10's 144 words of on-chip RAM are inside this
  module (0x00-0x7f page 0, 0x80-0x8f page 1)
- 32-bit accumulator, 16x16 multiplier into a 32-bit P register, barrel shifter
  on the ALU input, two auxiliary registers, four-level hardware stack
- One interrupt line and one polled BIO input
- All 60 instruction forms

One machine cycle is four `cen` pulses, so driving `cen` at the part's CLKIN
rate makes the instruction stream advance at hardware speed. Measured against
MAME's cycle table the ratio is 4.0000 CLKIN per machine cycle.

## Interface

| Port | Dir | Notes |
|---|---|---|
| `rst`, `clk`, `cen` | in | `cen` at CLKIN rate, nominally 14 MHz on Toaplan hardware |
| `hold` | in | freezes the core, modelling the HALT input |
| `irq` | in | a high level latches a pending interrupt; the pin cannot clear it |
| `bio` | in | polled by BIOZ. **High means branch taken** — this follows MAME's `bio()` callback, not the physical active-low pin |
| `rom_addr` / `rom_data` | out/in | program memory, one clock of latency |
| `pa`, `pdout`, `pdin`, `pwr`, `prd` | | the IN and OUT instructions |
| `dbg_*` | out | trace taps for the conformance bench; no effect on behaviour |

## Verification

`ver/cpu/` holds a conformance harness built around `ref32010.c`, a
transcription of MAME 0.289's `tms320c1x.cpp` into C. Random programs are run
through both the C model and the RTL, and the two instruction traces are
compared word for word.

`ver/cpu` is a jtframe unit test, so GitHub Actions picks it up through its
`.simunit` file and runs it on every pull request. `init.go` builds the C model
and generates one program and one reference trace per case; `test.v` replays
each program through the RTL and compares machine state instruction by
instruction. Six cases cover the same shape as the full suite below: three
interrupt rates, and two of them repeated with the core held for part of every
clock, which must not change the trace at all.

```
source modules/jtframe/bin/setprj.sh
simunit.sh --run modules/jt32010/ver/cpu   # the six cases CI runs
```

The shell harness is the deeper local fuzz, too long to run on every push:

```
cd ver/cpu && ./regress.sh          # full suite
./run.sh <seeds> <steps> <irq>      # one configuration
```

Latest result: **81 programs x 20,000 instructions, 1.62 M instructions, exact
match**, across interrupt rates of none / every 97 / 23 / 7 instructions and
HALT duty cycles of 0 / 35 / 80 %.

`coverage.py` confirms the fuzz reaches everything: all 60 instruction forms
executed, 276k direct and 324k indirect memory references, and the overflow
flag raised 428 times in a 600k-instruction sample.

Bugs this harness caught while the core was being written, all of which would
have been very hard to find from a running game:

1. A store belonging to a two-cycle instruction (`IN`) committed *after* the
   auxiliary register post-modification, so it wrote to the modified address.
   The hardware uses the pre-modification address.
2. Two status-register updates in one instruction clobbered each other, so
   `LDP` set DP but silently failed to repoint ARP — and every arithmetic
   instruction that both overflowed and updated ARP lost one of the two.
3. `BV` never cleared the overflow flag it consumes.
4. `BANZ` and `BV` had their branch condition re-evaluated in the second
   machine cycle, by which point the instruction had already modified the very
   state the condition tests.

## Known limitations

- **Verified against MAME, not against silicon.** MAME's model is itself an
  approximation in places; its own source notes that the ADD/SUB overflow
  behaviour implemented there is not what the TI manual describes.
- **`TBLW` cannot write program memory.** On Toaplan hardware the program
  space is mask ROM, so the write is dropped, which is what MAME does too. A
  system with external program RAM would need this wired up.
- **Interrupt latency differs from MAME.** MAME charges three machine cycles
  for the vector; this core spends one extra CLKIN. Behaviour is identical,
  timing differs by about 11 CLKIN per interrupt.
- **Not yet run against a real dump.** The Toaplan DSP ROM is the next input
  needed; the same harness will diff against MAME running the actual game.
- **Not yet synthesised.** No Quartus in the development environment, so there
  are no resource or timing numbers yet.

## Licence

GPL-3.0-or-later. Written from the TMS320C1x behaviour documented in MAME
0.289 (`src/devices/cpu/tms320c1x/`, BSD-3-Clause, copyright Tony La Porta)
used as a specification. No third-party RTL was copied.
