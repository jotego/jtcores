# Schematic Verification Checklist — Double Dribble (GX690)

Living document. **Every MAME reference in our code that COULD be replaced with a schematic-grounded fact**, plus what to look for to do the swap. Goal: minimise MAME-only claims; promote each to "SCHEMATIC: traced" when verified.

## How to use this doc

1. Pick an unchecked item (☐).
2. Find the listed schematic location, trace the listed signal/chip.
3. Note what you found in the **Notes** column.
4. If verified, swap the MAME ref in the source file for `SCHEMATIC: <page/designator>: <fact>`, mark the item ☑ here.
5. If unverifiable (custom-chip internal, missing trace), mark it ⛔ with reason — that documents "MAME is the only practical source".

Status legend:
- ☐ unchecked
- ☑ verified — schematic ref in code
- ⛔ unverifiable from schematic — MAME ref stays as-is
- ⚠ DISCREPANCY — schematic and MAME disagree

---

## A. ROM sizes — `cores/ddribble/cfg/mem.yaml`

| ☑ | Item | Location | What to verify | Source files & lines |
|---|---|---|---|---|
| ☑ | Main ROM = 64 KB (27512) | SCHEMATIC page 1 top-left | EPROM under main CPU labelled 27512 | mem.yaml:57-58 |
| ☐ | Sub ROM = 32 KB (27256) | SCHEMATIC page 0 near A19 | Find the EPROM near A19, read top marking. Confirm 27256 → 32 KB | mem.yaml:65-66 |
| ☑ | Sound ROM = 32 KB (27256) | SCHEMATIC page 1 top-right | 27256 next to sound CPU — already traced | mem.yaml:73-74 |
| ☑ | VLM voice ROM = 128 KB (MASK1M) | SCHEMATIC page 1 E7 | MASK1M with 17 address pins → 128 KB | mem.yaml:81-82 |
| ☐ | gfx1 = 256 KB (2 × 128 KB) | SCHEMATIC page 0 around 005885 E16 | Count MASK1M chips; verify each is 128 KB (28-pin DIP with 17 addr pins) | mem.yaml:91-92 |
| ☑ | gfx2 = 512 KB (4 × 128 KB) | SCHEMATIC page 0 around 005885 H16 + PCB photo verified 2026-06-01 | Schematic shows 6 sockets at I7/I8/I10/I11/I12/I13; PCB photo confirms 2 are empty (vestigial — Konami shared-PCB pattern). 4 populated matches MAME's gfx2. | mem.yaml:99-100 |
| ☐ | Sprite lookup PROM = 256 B | SCHEMATIC page 0 r1c2 designator I15 | 16-pin PROM with 8 address pins → 256 B | mem.yaml:107 |

**Notes**: ROM sizes are derivable from chip type alone (chip number → datasheet → size).

---

## B. Clock sources — `cores/ddribble/cfg/mem.yaml`

| ☑ | Item | Location | What to verify | Source |
|---|---|---|---|---|
| ☑ | 18.432 MHz master xtal | SCHEMATIC page 0 r0c1 | Active osc-can "18.432MHZ-0", pin 3 OUT → LS244 G14 → CK18 | mem.yaml:23-29 |
| ☑ | 3.58 MHz audio xtal | SCHEMATIC page 1 | Active osc-can "3.58MHZ-0", pin 3 OUT → LS244 G14 → SCLK | mem.yaml:37-42 |
| ☐ | /12 divider chain → CPU E/Q | SCHEMATIC page 0 sync-gen area | Trace CK18 → LS393 I9 → LS161 D14 → CLKE/CLKQ pins on A19. Identify which specific outputs hit which pin | mem.yaml:23-29 (TODO note) |
| ☐ | /3 divider → pixel clock 6.144 MHz | Same area | Trace CK18 → LS161 D14 (configured as /3) → pixel clock distribution | (not yet referenced) |

---

## C. BRAM sizes — `cores/ddribble/cfg/mem.yaml` (most likely to have discrepancies)

| ☑ | Item | Currently says | What to verify on schematic | Notes |
|---|---|---|---|---|
| ☑ | `shared_ms` 8 KB (main↔sub) | mem.yaml `addr_width: 13` | **CONFIRMED on schematic.** = **6264SL at C13** (`A0..A12` = 8 KB). Main side: 007552 `/CWORK`→`CWORKGE`→LS245 H11 (`CD` bus, `CRTWR`). Sub side: 007553 `/CRAM`→`CRAMGE`→LS245 E11 (`MD` bus, `MAINWR`). Address muxed `C`↔`M` by LS157 A13/B13/B14/A14; write = `CRAMWE`. | mem.yaml `shared_ms` |
| ☑ | `shared_sa` 2 KB (sub↔sound) | mem.yaml `addr_width: 11` | **CONFIRMED on page-1 schematic.** = the **2128SL C9** (A0..A10 = 2 KB). Dual-ported: M-side (D10 `MAINWR`/`MD`) traced back to the sub CPU 6809E @ A12 (the `MAINWR` name is the sub's, despite "MAIN"); S-side (D8 `SWORKGE`/`SOUNDWR`/`SD`) = sound CPU @ A8; LS157 B9/B10/B11 address-mux `M`↔`S`. Matches the 007553 `/SRAM` decode (0x2000-0x27FF) + MAME. See HARDWARE.md naming-gotcha note. | mem.yaml `shared_sa` |
| ☐ | `fgvram` 4 KB | mem.yaml:154 `addr_width: 12` | Find which physical chip backs CPU 0x2000-0x2FFF. Likely half of 6264SL H19 (8 KB total, split by chip-select) — confirm by tracing /CS pin to 007552 PAL `/GATE1` (pin 13) output | mem.yaml:150-160 |
| ☐ | `bgvram` 4 KB | mem.yaml:165 `addr_width: 12` | Same — likely other half of H19. Verify /CS source | mem.yaml:162-167 |
| ⛔ | `spr1` 4 KB | mem.yaml:172 `addr_width: 12` | **Probably INSIDE the 005885 E16 chip** — no separate SRAM visible. MAME tells us size; cannot verify externally | mem.yaml:168-181 |
| ⛔ | `spr2` 4 KB | mem.yaml:182 `addr_width: 12` | Same — probably inside 005885 H16 | mem.yaml:183-194 |
| ⛔ | `pal` 128 B | mem.yaml:194 `addr_width: 7` | Inside 007327 palette chip — cannot verify externally | mem.yaml:195-199 |

**Methodology to verify each SRAM chip**:
1. Locate the chip on the schematic
2. Read the chip's part number (top marking, e.g., `2128SL` / `HM6264SL`)
3. Look up the datasheet's address-pin count (2K = 11 pins, 8K = 13 pins, 32K = 15 pins)
4. Trace the chip's `/CS` pin back through any LS gates to find which CPU address triggers it
5. Trace the data pins to confirm which CPU bus(es) it serves

---

## D. BRAM address ranges — `cores/ddribble/hdl/jtddribble_main.v`

| ☑ | Item | Currently MAME-ref | What to verify on schematic |
|---|---|---|---|
| ☑ | Main 0x1800-0x1FFF = palette (CRAM) | 007552 `/CORAM` (pin 17) — confirmed by jedutil equation `/NEQ & /A15 & /A14 & /A13 & A12 & A11`. The PAL fires for the full 2 KB window; the 128 B narrowing to 0x1800-0x187F is done downstream by LS gates (or by the palette chip's own /CE = `/CORAM AND A11..A7 == 11111`). |
| ☑ | Main 0x2000-0x3FFF = chip 1 VRAM | 007552 `/GATE1` (pin 13) — confirmed by jedutil equation `/NEQ & /A15 & /A14 & A13`. Wraps both FG/BG VRAM AND sprite RAM into one CS, decoded internally by the 005885's A11..A12 bits. |
| ☐ | Main 0x3000-0x3FFF = sprite RAM 1 | _main.v:19 | Same pattern, different A bits |
| ☐ | Main 0x4000-0x5FFF = shared with sub | _main.v:19 | Trace SHARED CS to the dual-port chip |
| ☐ | Main 0x6000-0x6FFF = BG VRAM | _main.v:19 | Same |
| ☐ | Main 0x7000-0x7FFF = sprite RAM 2 | _main.v:19 | Same |
| ☐ | Main 0x8000 = bank-switch latch (W) | _main.v:77 | 007552 `/SEL` (pin 19) fires for 0x8000-0x9FFF and is NOT NEQ-gated — strong candidate for the bank-latch enable. Trace `/SEL` from C15 to a 74LS174/LS273 flip-flop whose data inputs are CPU `D0..D2` and outputs are `R16`/`R17`/`R17N`. |
| ☑ | Main 0x8000-0xFFFF = program ROM | 007552 `/RBN` (pin 12) → /CE of 27512 at C19 (confirmed by user reading schematic). Single 64 KB ROM; the bank-switch only steers VRAM-ROM (gfx) banks, not main-CPU code. |
| ☑ | Main 0xA000-0xFFFF = fixed ROM | Same `/RBN` (pin 12) — the 27512 covers the entire 0x8000-0xFFFF window in one chip, so 0xA000-0xFFFF is fixed by definition. |

**Note**: as of 2026-06-01 the PAL truth tables are NOT a blocker any more — both 007552 (main) and 007553 (likely sub) have been dumped and decoded with MAME `jedutil`. Equations are in `Konami_00755{2,3}_equations.txt` next to this file. Most main-side ranges in this section are now ☑. Sub-side ranges remain ☐ until pin labels for 007553 are read off the schematic and substituted into the equations.

---

## E. BRAM address ranges — `cores/ddribble/hdl/jtddribble_sub.v`

| ☑ | Item | Currently MAME-ref | What to verify on schematic |
|---|---|---|---|
| ☐ | Sub 0x0000-0x1FFF = shared with main | _sub.v:21 | Trace 007552 PAL SEL output (likely) to the shared SRAM chip |
| ☐ | Sub 0x2000-0x27FF = shared with sound | _sub.v:21 | Trace 007552 output to sound shared chip |
| ☐ | Sub 0x2800-0x2803 = DSW1/P1/P2/SYSTEM | _sub.v:21 | Trace 007552 output to LS244 buffer enable |
| ☐ | Sub 0x2C00 = DSW2 | _sub.v:21 | Same |
| ☐ | Sub 0x3000 = DSW3 | _sub.v:21 | Same |
| ☐ | Sub 0x3400 = coin counter (W) | _sub.v:21 | Trace 007552 output to LS174/LS273 latch driving JAMMA coin pins |
| ☐ | Sub 0x3C00 = watchdog (W) | _sub.v:21 | Trace 007552 output to LS123 monostable or 555 timer driving system reset |
| ☐ | Sub 0x8000-0xFFFF = ROM | _sub.v:21 | Trace 007552 output to 27256 sub-CPU /CE |

---

## F. BRAM address ranges — `cores/ddribble/hdl/jtddribble_sound.v` (mostly done)

| ☑ | Item | Status | Notes |
|---|---|---|---|
| ☑ | Sound 0x0000-0x07FF = shared with sub | LS138 A9 Y0 traced | _sound.v:80 |
| ☑ | Sound 0x1000-0x1001 = YM2203 (OPN) | LS138 A9 Y1 traced | _sound.v:81 |
| ☑ | Sound 0x3000 = VLM5030 (VDATA) | LS138 A9 Y3 traced | _sound.v:86 |
| ☐ | Sound 0x2000 = IRQEN puzzle (LS138 A9 Y2 — not in MAME) | _sound.v:82-85 | TRACE: where does LS138 A9 Y2 (IRQEN) go on the schematic? Probably to a flip-flop that latches YM2203's IRQ pin into the sound CPU's IRQ pin. If found, MAME has a documentation bug. |

---

## G. CPU interrupt wiring — `cores/ddribble/hdl/jtddribble_*.v`

| ☑ | Item | Currently MAME-ref | What to verify on schematic |
|---|---|---|---|
| ☐ | Main FIRQ source | _main.v:184 (MAME ddribble.cpp:324) | Trace main CPU FIRQ pin (pin 3 on the 6809E in page 1 top-left) backwards. Source should originate in the page-0 sync-gen LS74 flops (B15/A10/A11). |
| ☐ | Sub FIRQ source | _sub.v (not yet documented in code) | Same as main — trace A12's FIRQ pin (page 1, pin 3) back to the LS74 sync flip-flops on page 0 that produce NVSY (cross-page net). |
| ☐ | Sub IRQN source | 007552 has output named IRQN | Likely a separate enable for the FIRQ — verify what it gates |
| ☐ | Sound CPU IRQ pin disposition | _sound.v:24 (claims "no IRQ wired") | Verify sound CPU's IRQ (pin 4), FIRQ (pin 3), NMI (pin 2) are all tied to VCC. If any goes to a signal, we have a sound IRQ source MAME missed. |

---

## H. Bank-switch latch hardware — `cores/ddribble/hdl/jtddribble_main.v`

| ☑ | Item | Currently MAME-ref | What to verify on schematic |
|---|---|---|---|
| ☐ | Main bank latch chip identity | _main.v:24, 167 (MAME ddribble.cpp:331-334) | Find the LS174/LS273/LS374 flip-flop near 007552 PAL (C15) whose clock input is driven by `/SEL` (pin 19) — the only ungated PAL output that fires for 0x8000-0x9FFF. Data inputs CPU D0-D2; outputs `R16`/`R17`/`R17N` going to page 0. |
| ☐ | VLM voice ROM bank latch | _sound.v (in vlm5030_ctrl_w discussion) | Find the flip-flop driven by YM2203 IOA[3] whose output goes to MASK1M E7's A16 pin |

---

## I. VLM5030 control wiring — `cores/ddribble/hdl/jtddribble_sound.v`

| ☑ | Item | Currently MAME-ref | What to verify on schematic |
|---|---|---|---|
| ☐ | YM2203 IOA[6] → VLM /RST | _sound.v:153 | Trace IOA[6] pin of YM2203 directly to VLM5030 RST pin |
| ☐ | YM2203 IOA[5] → VLM /ST | _sound.v:154 | Trace IOA[5] to VLM5030 ST pin |
| ☐ | YM2203 IOA[4] → VLM /VCU | _sound.v:155 | Trace IOA[4] to VLM5030 VCU pin |
| ☐ | YM2203 IOA[3] → VLM bank | _sound.v:156 | Trace IOA[3] through a flip-flop to MASK1M E7 A16 |
| ☐ | YM2203 IOA[2:0] → 4066 D5 filter switches | _sound.v:158-160 | Trace each of IOA[2], IOA[1], IOA[0] to a control pin on the 3× 4066 at D5 |
| ☐ | YM2203 IOA[7] → some bus-OE | _sound.v:153 (claims "data-bus OE") | Trace IOA[7] to whatever LS245 /OE pin it gates |
| ☐ | YM2203 IOB[7] ← VLM /BSY | _sound.v:128 | Trace VLM5030 BSY pin to YM2203 IOB[7] |

---

## J. Audio R/C values — `cores/ddribble/cfg/mem.yaml` (all PLACEHOLDER)

| ☑ | Item | Currently | What to measure on schematic |
|---|---|---|---|
| ☐ | `audio.rsum` master | mem.yaml:224 = 220 (placeholder) | Find the summing resistor at the LA6358 op-amp input (page 1 r1c1 area) |
| ☐ | `audio.rc` master LPF | mem.yaml:225 (placeholder) | Find the R/C network between UPC324 final stage and LA6358 |
| ☐ | `fm` channel rsum + rc | mem.yaml:235 | Find FM mix R + filter R/C in UPC324 input around YM2203 MO pin |
| ☐ | `psg` channel rsum + rc | mem.yaml:236 | Find SSG mix R + filter R/C (4066 D5 gates each SSG channel through its own filter) |
| ☐ | `vlm` channel rsum + rc | mem.yaml:239 | Find VLM5030 output mix R + filter R/C |

**Visible R/C values on schematic page 1** (from earlier reads):
- Resistors: 47K, 24K, 22K, 10K, 5.6K, 4.7K, 3.3K, 2.2K, 2K, 1.5K, 1K
- Capacitors: 10U/16E, 4.7U/25T, 2200P, 0.15U/35T, 0.1U, 0.047U, 0.033U

Mapping each value to its position in the audio network requires methodical tracing.

---

## K. Input matrix — `cores/ddribble/hdl/jtddribble_game.v` (MAME-ref dependency removed by your trace methodology in `PART A` discussion)

| ☑ | Item | What to verify on schematic |
|---|---|---|
| ☐ | LS253 SEL pin source | Trace pin 14 of LS253 F2/G3/G4 to identify how the player-select works |
| ☐ | LS253 data inputs ↔ JAMMA pin names | Trace each of D0..D3 backwards through 005273 to JAMMA edge labels |
| ☐ | CD-bus → CPU data bit mapping | Trace which LS244/LS245 puts CD on which CPU data bit |
| ☐ | DSW1 bits 0..7 ↔ DIPSW8P switches | Trace each switch to LS244 H6 pins |
| ☐ | DSW2 bits 0..7 ↔ second DIPSW8P | Same |
| ☐ | DSW3 bits 0..3 ↔ DIPSW4P | Trace through LS367 buffer |
| ☐ | SYSTEM byte (coin/start/service) | Trace each JAMMA pin to a buffer to a CPU data bit |

**Once all of K is done**, the comment `// All active LOW (1 = not pressed)` in `_game.v:75` becomes "// SCHEMATIC-traced bit mapping (see VERIFICATIONS.md K)" and the implicit MAME dependency on `konamipt.h` macros disappears.

---

## L-pre. 007452 chip — RESOLVED ☑ (2026-06-01)

**Outcome: 007452 at C17 is populated but hardware-disabled on Double Dribble's PCB.** No HDL needed.

### How we verified

User traced pin connections on schematic page 0 against Furrtek's silicon-decap pinout (https://github.com/furrtek/SiliconRE/tree/master/Konami/007452):

| Pin | Function (per Furrtek) | Wiring on ddribble PCB | Effect |
|---|---|---|---|
| 12 | CS12 (chip select) | Tied +5V | Never selected — no CPU bus access |
| 16 | CLK | Tied +5V | No clock transitions — state machine frozen |
| 39 | AB12 (CPU addr bit 12) | Tied +5V | Address decoding inputs overridden |
| 41 | AB15 (CPU addr bit 15) | Tied +5V | Same |
| 20 | K8 | Tied +5V | (unknown function, likely an input-tie default) |

Any one of these (especially CS12 or CLK) would disable the chip; together they confirm Konami deliberately bypassed it for this game variant.

### Why Konami populated it anyway

Shared-PCB economics. The GX board layout is used across multiple Konami titles; some (Contra, Combat School, Flak Attack, WEC Le Mans) actively use 007452 for math acceleration. Double Dribble doesn't need fast math, so they reused the board with this chip disabled.

### Document corrections this triggered

- HARDWARE.md: C17 entry rewritten — was "CRT/RAM helper" (wrong), now "Math+bankswitcher, DISABLED on this PCB"
- Open question #6 closed
- jtcontra_007452.v (the GPL3 Jotego implementation based on Furrtek's decap) **not needed** for ddribble

---

## L. Custom-chip behaviour — cannot derive from schematic (MAME stays)

| ⛔ | Item | Why unverifiable |
|---|---|---|
| ⛔ | 005885 internal register map | Konami custom, no datasheet, no schematic of internals |
| ⛔ | 007327 palette encoding | Same |
| ⛔ | 007452 CRT-helper behaviour | Same |
| ☑ | 007552 PAL truth table | JEDEC dumped — `Konami_007552.jed` / decoded as `Konami_007552_equations.txt`. Confirmed MAIN-CPU decoder (pin 12 /RBN → 27512 ROM CE at C19). |
| ☑ | 007553 PAL truth table | JEDEC dumped — `Konami_007553.jed` / decoded as `Konami_007553_equations.txt`. Function inferred (sub or sound decoder); pin labels still need schematic confirmation. |
| ⛔ | 005273 input-pack passive details | Resistor network, just smoothing — no per-pin behaviour to verify |
| ⛔ | Sprite RAMs (spr1, spr2) location | Probably inside 005885 chips |
| ⛔ | Palette RAM (pal) location | Probably inside 007327 chip |

For these, MAME source (or the existing MiSTer `k005885.sv` for the 005885) is the only practical reference.

---

## M. Video timing parameters — `cores/ddribble/hdl/jtddribble_game.v` (vtimer params)

Currently uses kicker's values (Konami GX standard, MAME-verified-on-PCB). Each parameter has a corresponding schematic structure that, traced, would replace the MAME dependency.

The math chain:

```
PixelClock       = MasterClock / PixelDivider   = 18.432 / 3 = 6.144 MHz
FrameRate        = PixelClock  / (TotalH × TotalV)
ActiveResolution = activeH × activeV
```

| ☑ | Parameter | Current value | What to trace on schematic |
|---|---|---|---|
| ☑ | MasterClock = 18.432 MHz | ✓ | osc-can on page 0 r0c1 (already verified) |
| ☐ | PixelDivider = 3 | `pxl_cen` from JTFRAME PLL `jtframe_pll6144` | Trace **LS161 D14** on page 0 sync-gen area. Confirm `LD` (pin 9) tied to `RC` (pin 15), and `D0..D3` (pins 3-6) tied to `0b1101` (= 13). That makes the counter sequence 13→14→15→13→14→15 = /3 divider. Pixel clock output = one of the Q pins or RC. |
| ☐ | TotalH = 384 pixels per line | `HCNT_END = 9'd383`, `HB_END = 9'd383` in u_vtimer | Trace H-counter cascade (LS393 I9 lower half + maybe LS161). Find the wrap-detector gate (NAND or LS85 comparator). The bit pattern it matches = wrap value. `0b101111111` = 383 → TotalH = 384 |
| ☐ | activeH = 256 active pixels | `HB_START = 9'd255` in u_vtimer | Trace LHBL generator: LS74 flip-flop SET on H == 255, RESET on H wrap. SET trigger = HB_START. Confirms 256 active pixels |
| ☐ | HS pulse position (303..335) | `HS_START = 9'h12F`, `HS_END = 9'h14F` | Similar LS74 for HS generation. SET trigger = HS_START = 303, RESET trigger = HS_END = 335. ~32-pixel pulse |
| ☐ | TotalV = 264 lines per frame | `VCNT_END = 9'd263` in u_vtimer | Trace V-counter cascade (clocked once per H-wrap). Wrap-detector matches `0b100000111` = 263 → TotalV = 264 |
| ☐ | activeV = 224 active lines | `VB_START = 9'd239`, `VB_END = 9'd015` in u_vtimer | Trace LVBL generator: LS74 SET at V == 239, RESET at V == 15 → active region is V == 16..239 = 224 lines |
| ☐ | VS pulse position (line 260+) | `VS_START = 9'd260` | LS74 for VS. SET trigger at V == 260 |
| | **→ Derived: FrameRate = 60.606 Hz** | `18.432e6 / 3 / 384 / 264` | Falls out from the above |
| | **→ Derived: 256×224 @ 60.6 Hz** | | Matches MAME, matches PCB, matches our macros.def WIDTH=256 HEIGHT=224 |

**Methodology shortcut**: rather than tracing every gate, you can verify TotalH/TotalV at sim runtime by viewing the H and V counter signals in `gtkwave` and counting cycles from reset to reset. That bypasses the schematic trace but only confirms what the SIM does, not what the REAL PCB does — for true schematic-first verification, the gate trace is necessary.

**Priority**: low. These values match what kicker uses and kicker is MAME-verified-on-PCB. The trace is a "doc-completeness" item rather than a bug-hunt item — but if you ever suspect sim refresh rate differs from real PCB, this is the only way to know which is wrong.

---

## Progress tracker

- **Verified (☑)**: 5 items (main ROM, sound ROM, VLM ROM, 18.432 MHz xtal, 3.58 MHz xtal, sound CPU LS138 decoder)
- **To verify (☐)**: ~52 items across sections A-K, M
- **Unverifiable (⛔)**: 8 items in section L — these are documented as MAME-only by design

Estimated time to clear sections A, B, C: ~2 hours of careful schematic + chip-marking reading.
Estimated time to clear D, E (PAL output traces): ~4 hours.
Estimated time for J (audio R/C): ~2 hours of trace+measure.
Estimated time for M (video timing): ~2 hours but very low priority (matches kicker which is PCB-verified).

---

## When all `☐` become `☑` or `⛔`

`cores/ddribble/hdl/*.v` and `cfg/mem.yaml` should have a SCHEMATIC reference for every fact except the 8 items in section L. The doc rule becomes: **MAME ref appears only where L explicitly justifies it; everywhere else it's a code-smell indicating someone gave up too early on schematic verification.**
