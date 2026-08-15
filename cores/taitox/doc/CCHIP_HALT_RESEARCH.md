# Superman boot continuation — research notes from the cabal-branch session

> Investigation done while user worked on cabal branch.  Looked at
> Rainbow Islands, Operation Wolf, Volfied wirings + Fulvio's two
> Rainbow C-chip wrappers + Superman's own ROM around the $1852 halt.
> The goal: figure out how the boot is supposed to escape the
> "NO ERROR" wait at $1852 with SR.I=7.

## 1. Cross-game C-chip wiring (all 5 Taito C-chip games)

| Game             | 68k IRQ | cchip mapping          | Notes |
|------------------|---------|------------------------|-------|
| Superman         | **IRQ-6** (HOLD_LINE) | $900000-$900FFF | Highest pri before NMI |
| Rainbow Islands  | IRQ-4   | $800000-$800FFF        | |
| Operation Wolf   | IRQ-5   | $0F0000-$0F0FFF (mirror $1000) | optional cchip (older sets use shared-RAM HLE) |
| Volfied          | IRQ-4   | $F00000-$F00FFF        | |
| (Op Wolf, twinhawk-style boards skip the cchip in software) | | | |

All five drive `m_cchip->ext_interrupt(ASSERT_LINE)` on vblank, exactly
like our wiring after commit `af625270b`.

Superman is the ONLY one with IRQ-6.  This matters: the boot at
`$2E6A` does `ORI #$0700, SR` which sets SR.I=7 → IRQ-6 masked.  On
the other games, IRQ-4/-5 would also be masked under SR.I=7 — but
they likely don't end up with SR.I=7 at the halt, because their
self-test display routines are reached differently.

## 2. Fulvio's two Rainbow Islands wrappers (telling)

In `Fulviuus/jtcores risle-hdl/cores/risle/hdl/`:

- `jtrisle_cchip.v`  (677 lines) — **HLE FSM wrapper**, no real MCU,
  uses a hand-extracted `jtrisle_cchip_sim_rom.mem` (data captured from
  MAME debug runs) and a Verilog state machine to walk it.  This is
  what was in his bring-up for Rainbow.

- `jtrisle_cchip_mcu.v`  (440 lines) — **real-MCU wrapper**.  This is
  what we copy-adapted into `jtsuperman_cchip.v`.

The interesting bit: **`jtrisle_cchip.v` (FSM) explicitly documents
the same 68k-side bank-register bug we fixed in our wrapper** in
commit `b8207fac0`:

> `//   0xC00-0xDFF  bank register, NEW MAME taitocchip mapping (sel_bank)
>  //                ← rbisland B39 ROM uses this address for bank writes;
>  //                  without including it here, bank_68k stays at 0 and
>  //                  every CRAM[1][0x100] (round-data request flag)
>  //                  write goes to the wrong bank; the FSM then never
>  //                  sees the request and the CPU hangs in the BGE-loop
>  //                  at PC 0x6150 waiting for the byte to flip to 0xFF.`

So **Rainbow Islands has the same "stuck waiting on a byte that
should flip" symptom as Superman did pre-fix**, on PC 0x6150 instead
of 0x2C26.  Fulvio fixed it for the HLE FSM but apparently not for the
MCU wrapper.  Our Superman fix is more correct than his Rainbow MCU
wrapper.

The MCU wrapper still has:
  - MCU ASIC region clamped to 0x1400-0x1403 (should be 0x1400-0x17FF)
  - 68k-side bank-set still in $X600-$X7FF only (NEW mapping at
    $XC00-$XDFF missing)
  - Bank-set writes also clobber asic_ram

These are exactly the three bugs we just fixed for Superman in
`b8207fac0`.  **When we eventually re-promote `jtsuperman_cchip.v`
into a shared `jt78c11`-style module, the Rainbow MCU wrapper will
inherit our fixes for free.**

## 3. Superman's $F01CCA gate flag — deeper trace

The screen-render trap at $3EEA is gated by

    $3ED0: CMPI.W #2, ($1CCA, A5)
    $3ED6: BNE.B   $3EDA    ; flag != 2 → render the result screen
    $3ED8: RTS              ; flag == 2 → skip, boot continues

Static analysis of the 68k ROM finds **five write sites** to
($1CCA, A5):

| Site   | Value written | Phase |
|--------|---------------|-------|
| $4296  | 0             | reset/init |
| $42D4  | 1             | phase 1 done |
| $44EA  | 3             | phase 3 done |
| $41C0  | 4             | phase 4 (final) |
| $453C  | 4             | phase 4 alt |

**No write of value 2 anywhere in the maincpu ROM.**

The boot flag transitions 0 → 1 → 3 → 4 in static writes.  Value 2 is
specifically *checked for* but never *set* by the code.  Three
interpretations of this:

**(a) Sentinel — "currently transitioning"**: value 2 means
the boot is mid-transition.  The IRQ-6 ISR briefly leaves the flag
at 2 during a back-to-back write sequence we haven't traced.  If
we'd added a probe that watched ($F01CCA) at every clock, we'd see
the value 2 flicker for a few cycles, then settle to 3 or 4.  The
gate `CMPI #2` is read by some OTHER code path that should only run
during that brief window.

  Verifiable by: SDRAM-side write trace of $F01CCA in the sim.

**(b) Mirrored from cchip**: the IRQ-6 ISR at $06C4 chains to
$3A92, which we partially decoded.  $3A92 reads cchip shared RAM
($900001, $900003, …) into ($1C4E, A5) etc., and tests
($1CCA, A5) against 0 and 3 (`$3AB0`, `$3ACA`).  Maybe a code path
we didn't follow writes the cchip's ASIC reg 1 state directly into
($1CCA, A5).

  Static check: the boot DOES use ASIC reg 1 ($900803) as a
  command/status register.  At PC $2AE2:

      $2AE2: while (asic_ram[1] != 5) {       ; poll ASIC reg 1
                if (asic_ram[1] != 1) loop;    ; expect 1
                ...do work...
                asic_ram[1] = 2;               ; ACK with value 2
                ...
                return;
             }

  So **the 68k writes value 2 to cchip ASIC reg 1 explicitly** as part
  of a request-response protocol.  The MCU's mask ROM almost
  certainly mirrors that into a status byte the 68k can then poll.
  If $F01CCA is the work-RAM copy of that byte, the cchip is the
  ONLY thing that can ever set it to 2 — which would explain why
  static ROM analysis finds no 68k write of 2.

  **This is the strongest hypothesis.**  Our wrapper's ASIC-reg
  emulation is faithful (post-fix), but the MCU mask ROM's response
  to the 68k's "write 2 to ASIC[1]" might be missing because some
  shared-RAM byte the MCU expects to read isn't where it thinks.

**(c) Service-mode terminal**: value 2 means "service mode active"
and the boot is supposed to halt at the "NO ERROR" screen until
the operator power-cycles.  Mostly ruled out because our DIPs don't
have service mode set and there's no manual coin-insert in the sim.

## 4. The handshake at $2AE2 is the key

We knew about the J/F/4 → G/W/K handshake on shared RAM bytes 0/1/2.
What we DIDN'T trace is this SECOND handshake on ASIC reg 1:

  - 68k: `while (asic[1] != 5) { if (asic[1] == 1) { …; asic[1] = 2 } }`
  - MCU (mask ROM): probably the inverse — wait for 2, respond with 5

This is reached by the boot AFTER the J/F/4 handshake but BEFORE the
$1852 halt.  If the MCU never advances asic[1] past 1, the boot loops
at $2AE2 (we'd see PC=$2AE2 in the trace) — but in our sim the 68k
reaches $1852, so this handshake DOES complete.  Question is: what
side-effect of completing it should set $F01CCA = 2?

## 5. IRQ-6 handler chain — what to inspect next

The IRQ-6 vector is $06C4.  $06C4 → $3A92 (main work).  $3A92 reads
PA/PB from cchip shared RAM into ($1C4E, A5) and ($1C4F, A5) each
frame.  We saw it checks ($1CCA, A5) at $3AB0 (for 0) and $3ACA
(for 3).  It almost certainly has more conditional paths we didn't
chase that would set the flag.

**Concrete next step for Superman:**

1. Add a SDRAM-write probe in `_main.v` that fires on any write to
   `$F01CCA` and prints the value + the source 68k PC.  Run FRAMES=80
   and see the actual state-flag trajectory.

2. If the trajectory never includes 2, look for a code path in $3A92
   (or its callees) that should set it but doesn't — likely because
   it depends on a byte from the cchip that isn't being read
   correctly.

3. If the trajectory DOES include 2 transiently, the gate at $3ED0
   is intentional and meant to catch a different path.  In that case
   the issue is "the screen-render is supposed to be the BOOT path,
   and something else (timer / Tilt / counter overflow) is supposed
   to break the BRA -2".

## 6. One more curiosity: the IRQ-4 vector

Superman's IRQ-4 vector ($070) is set to **$082C** — a real handler
that does a delay loop and ends with `BRA.W $2E6A` (the screen
renderer too).  MAME doesn't wire IRQ-4.

If real Superman hardware **does** drive IRQ-4 from something
(a counter? port-F output of the cchip MCU?), and that fires when
the cchip wants to display a test screen, that would explain the
existence of $082C.  Worth checking the real-board schematic.

## 7. Open ROM-side question

After the screen renderer at $1820 halts at $1852, the only way to
escape on real hardware would be:

  - NMI (IRQ-7) — but our vector at $7C is $FFFFFFFF, ruled out
  - IRQ-6 from cchip MCU's port-F or asic_ram[1] state change
    — Superman's cchip wrapper output `int_n` is supposed to drive
    something; we currently stub it at 1
  - Bus error from a memory access that fails — no candidate
  - Reset — boot would restart, not progress

So the next concrete avenue: **wire `cchip.int_n` in our wrapper to
something the MCU sets, then drive `IPLn` on the 68k accordingly.**

The MAME `taito_cchip_device` class doesn't expose an `int_n` output,
but real-board pinout DOES show pin 34 driving "DTACK out to 68k
(/CDTA)" — which is just DTACK, not IRQ.  Pin 53 is `/NMI` and the
diagram says it's "used on rainbow islands" — so RAINBOW DOES USE
NMI from the cchip!  Worth checking if Superman uses it too.

That's the next thread to pull.

## 8. Summary of what to do at the next Superman session

(Roughly in order of cheapness)

1. Add a $F01CCA write probe in `_main.v` and re-sim FRAMES=80 →
   see actual state trajectory.
2. If 2 never appears: investigate the cchip MCU's mask-ROM response
   to the asic[1] write-2 protocol.  Likely needs an MCU-side memory
   probe.
3. Look at the real-board cchip pin 53 (/NMI) wiring in Superman
   docs / schematics.  If it drives 68k NMI, wire `cchip.int_n` (or
   a new MCU pf-out probe) to drive `IPLn = {0,0,0}` (level 7) in
   `_main.v`.
4. Once boot continues, the X1-001A video subsystem (kiwi-shape, not
   in build) is the next gating issue.
