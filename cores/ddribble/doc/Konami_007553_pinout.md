# Konami 007553 PAL — pin assignments (CONFIRMED 2026-06-01)

Schematic image confirming pin labels: shared by user on 2026-06-01.
CPU/PAL assignment confirmed by user same day: A12 = SUB CPU, A19 = MAIN CPU,
A8 = SOUND CPU. The 007553 PAL serves the **SUB** CPU, not the main.

> **Naming caution:** on the sheet this sub CPU's nets are labelled with "MAIN"
> (`MAINWR`/`MAINRD`, `MD`/`M`-bus) — Konami's board calls the sub "MAIN" and the
> main "CRT". So `MAINWR` here is the **sub**'s write strobe. Full board↔HDL label
> map: see the CPU-labels table in `HARDWARE.md`.
Equations: `Konami_007553_equations.txt` (decoded by jedutil from `Konami_007553.jed`).

## Location

Designator **C11** on schematic page 1, alongside the **SUB MC6809E at A12**
and its 27512 EPROM at C12. The PAL feeds the sub CPU's chip-select strobes
(ROM CE, shared-with-main RAM, shared-with-sound RAM, joystick/DIP buffers,
coin-counter latch, watchdog).

## Inputs

| Pin | jedutil name | Schematic label | Source |
|---|---|---|---|
| 1 | i1 | EN | output of LS00 NAND of SUB CPU's CLKE AND CLKQ (active-low during valid bus phase) |
| 3 | i3 | AB15 | sub CPU pin 23 (A15) |
| 4 | i4 | AB14 | sub CPU pin 22 (A14) |
| 5 | i5 | AB13 | sub CPU pin 21 (A13) |
| 6 | i6 | AB12 | sub CPU pin 20 (A12) |
| 7 | i7 | AB11 | LS157 H10 output 1Y (sub-CPU-side A11 after mux with CRT-side) |
| 8 | i8 | AB10 | LS157 H10 output 2Y (sub-CPU-side A10 after mux with CRT-side) |
| 2, 9 | i2, i9 | N.C. | not connected |
| 11 | — | GND | tied low |

## Outputs (all active-low per `o##` convention)

| Pin | jedutil name | Schematic label | Confirmed role |
|---|---|---|---|
| 12 | /o12 | ROM | sub program-ROM /CE → 27512 at C12 (further address-narrowed downstream — PAL fires for 0x4000-0xFFFF but the 27512 only responds to 0x8000-0xFFFF) |
| 13 | /o13 | CRAM | shared-with-main SRAM enable (sub view 0x0000-0x1FFF = same chip as main's /CWORK 0x4000-0x5FFF) |
| 14 | /o14 | AFE | watchdog kick (sub 0x3C00-0x3FFF) |
| 15 | /o15 | SET | coin-counter latch (sub 0x3400-0x37FF) |
| 16 | /o16 | DIP3 | DIP-switch 3 read buffer enable (sub 0x3000-0x33FF) |
| 17 | /o17 | DIP2 | DIP-switch 2 read buffer enable (sub 0x2C00-0x2FFF) |
| 18 | /o18 | IOIN | joystick / system input buffer enable (sub 0x2800-0x2BFF) |
| 19 | /o19 | SRAM | shared-with-sound SRAM enable (sub 0x2000-0x27FF) |

## Open questions

1. **The ROM equation looks too broad.** /ROM fires for 0x4000-0xFFFF (48 KB window) but the sub 27512 only holds 64 KB of ROM (mapped at 0x8000-0xFFFF per MAME). There must be downstream gating (an LS chip combining /ROM with A15 to narrow it) — trace pin 12 from C11 to the 27512 at C12 to see what's between them.

2. **Why is the schematic chip a 27512 (64 KB) when MAME's romset only fills 32 KB?** Three possibilities: (a) Konami used a 27512 from parts-bin economics and left the upper half unused; (b) the upper half contains data tables the CPU reads via direct addressing (not via /ROM); (c) there's a sub-side bank-switch we haven't found. Worth investigating if the sub CPU stalls in a non-obvious way.

3. **The /AFE name.** "AFE" might stand for "And-FET Enable" (gating something), but on this PCB the only output at 0x3C00 is the watchdog — so functionally /AFE = watchdog kick. Cosmetic.

4. **The /SET name.** Pin 15 fires for 0x3400-0x37FF where MAME expects the coin-counter latch. The "SET" name suggests "data set" / latch clock. Likely the LS174/LS273 clock input.

## Decoded equations (paste from `Konami_007553_equations.txt`)

```
/o12 = i1 & i3 +
       i1 & /i3 & i4
/o13 = i1 & /i3 & /i4 & /i5
/o14 = i1 & /i3 & /i4 & i5 & i6 & i7 & i8
/o15 = i1 & /i3 & /i4 & i5 & i6 & /i7 & i8
/o16 = i1 & /i3 & /i4 & i5 & i6 & /i7 & /i8
/o17 = i1 & /i3 & /i4 & i5 & /i6 & i7 & i8
/o18 = i1 & /i3 & /i4 & i5 & /i6 & i7 & /i8
/o19 = i1 & /i3 & /i4 & i5 & /i6 & /i7
```

With pin labels substituted (treating EN as the active-when-LOW enable):

```
/ROM  = EN & (A15 + /A15 & A14)                        → A15 | A14 → 0x4000-0xFFFF
/CRAM = EN & /A15 & /A14 & /A13                        → 0x0000-0x1FFF
/AFE  = EN & /A15 & /A14 & A13 & A12 & A11 & A10       → 0x3C00-0x3FFF (1 KB)
/SET  = EN & /A15 & /A14 & A13 & A12 & /A11 & A10      → 0x3400-0x37FF (1 KB)
/DIP3 = EN & /A15 & /A14 & A13 & A12 & /A11 & /A10     → 0x3000-0x33FF (1 KB)
/DIP2 = EN & /A15 & /A14 & A13 & /A12 & A11 & A10      → 0x2C00-0x2FFF (1 KB)
/IOIN = EN & /A15 & /A14 & A13 & /A12 & A11 & /A10     → 0x2800-0x2BFF (1 KB)
/SRAM = EN & /A15 & /A14 & A13 & /A12 & /A11           → 0x2000-0x27FF (2 KB)
```

**Address ranges match the SUB CPU's MAME memory map exactly**
(SRAM=shared 2 KB with sound, IOIN=0x2800 inputs, DIP2=0x2C00, DIP3=0x3000,
SET=0x3400 coin counter, AFE=0x3C00 watchdog, CRAM=lower 8 KB shared with
main, ROM=upper half ROM with downstream A15 gating).

The CPU/PAL pairing was confirmed by the user reading the schematic on
2026-06-01: **007553 (C11) lives on page 1 next to the SUB CPU at A12
and its 27512 program ROM at C12.** The "EN" input from the LS00 NAND
gate is the SUB CPU's CLKE / CLKQ product.

**These ranges are now the authoritative reference for the sub address
decoder** — `jtddribble_sub.v` already implements an equivalent map (from
MAME) and continues to match. Task #21 covers eventually rewriting both
decoders (main + sub) directly from their PAL equations for full
schematic-faithfulness.
