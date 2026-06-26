# Double Dribble — Hardware notes from schematics

PCB: Konami GX690 (Double Dribble), 1986.
Source: Konami factory schematics, sheets dated **1986-11-12**, scale 1:1, tolerance A1.

This document records what is **directly visible** on the two schematic sheets supplied (`schematic_p0.png`, `schematic_p1.png`). Anything I had to infer is flagged. Anything I could not see is in **Open questions** at the bottom.

> **Sheet layout — corrected 2026-06-01 (second pass).** The schematic packet is COMPLETE — all three CPUs are present. Page roles were previously labelled BACKWARDS in this doc; the correct mapping (per direct schematic read + jedutil decode of both PALs) is:
> - **Page "p0"**: **MAIN CPU** (MC6809E at designator **A19**), its **Konami 007552** address-decoder PAL at C15, the 27512 main program ROM at C19 (driven by 007552 pin 12 `/RBN`), **BOTH 005885 graphics chips** (E16 + H16) with their MASK1M tile ROMs, palette / VRAM / sprite framebuffer, JAMMA edge.
> - **Page "p1"**: **SUB CPU** (MC6809E at designator **A12**, top-left area) with its **Konami 007553** address-decoder PAL at C11, a 27512 sub program ROM at C12 (driven by 007553 pin 12 `/ROM`); the input matrix (005273 packs + LS253 mux) and the dip-switch buffers connect to the sub via 007553's `/IOIN`, `/DIP2`, `/DIP3` strobes; also on this page is the **SOUND CPU** (MC6809E at designator **A8**, near the YM2203) with its 27256 program ROM and the YM2203 + YM3014 + VLM5030 chain, decoded by discrete LS-series logic (**no PAL** on the sound side).
>
> **Both PALs are now fully decoded.** Equations in `Konami_007552_equations.txt` (main side) and `Konami_007553_equations.txt` (sub side). 007552 outputs match MAME's main memory map; 007553 outputs match MAME's sub memory map.
>
> **Earlier mistakes in this doc** — for the record so anyone reading old commits understands the correction:
> 1. The first pass had "page 0 = sub" and "page 1 = main". Both pages were labelled with the wrong CPU.
> 2. The earlier guess "007553 is the main decoder at C11" was the consequence of mistake #1. With pages and PAL identities both corrected, the decoder roles flip cleanly: 007552 = main, 007553 = sub.
> 3. An even earlier version claimed a sub-CPU sheet was missing. The sub CPU was always there — at A12 on page 1, not A19 on page 0.

### CPU architecture (3 × MC6809E, all clocked at 18.432 MHz ÷ 12 ≈ 1.536 MHz)

```
┌──────────┐  shared 8K SRAM @  ┌──────────┐  shared 2K SRAM @  ┌────────────┐
│   MAIN   │ ◄═main 0x4000-5FFF►│   SUB    │ ◄═sub  0x2000-27FF►│   SOUND    │
│ MC6809E  │   sub  0x0000-1FFF │ MC6809E  │  sound 0x0000-07FF │  MC6809E   │
│ 27512    │                    │ ??K PROG │                    │ 27256 PROG │
│ → 2x005885│                   │ → DSW1/2/3│                   │ → YM2203   │
│ → palette│                    │ → P1/P2/Sys│                  │ → VLM5030  │
│ → VRAMs  │                    │ → coin ctr │                  │            │
│ → spr RAM│                    │ → watchdog │                  │            │
│ bank @8K │                    │ no banking │                  │ no banking │
└──────────┘                    └────────────┘                  └────────────┘

Sound chain: MAIN -> SUB -> SOUND (main never talks to sound directly).
Input chain: PCB inputs -> 005273 packs -> LS253 mux -> only SUB CPU reads them.
```

> ### ⚠ CPU labels — read this before tracing nets or the POST
>
> In this doc and the HDL, "main"/"sub"/"sound" follow our **HDL / MAME** convention.
> The **board's own net names and POST labels are INVERTED** for the two main-board
> CPUs — Konami names them by *role* (the graphics CPU = "CRT", the game-logic CPU =
> "MAIN"). The HDL is **not** being renamed; this table is the dictionary:
>
> | our HDL / MAME | chip | decoder | board net names | POST label |
> |---|---|---|---|---|
> | **main** | 6809E @ A19 | 007552 (C15) | **"CRT"** — `CRTWR`/`CRTRD`, `CD`/`C`-bus, `/CWORK`→`CWORKGE` | `CRT …` |
> | **sub**  | 6809E @ A12 | 007553 (C11) | **"MAIN"** — `MAINWR`/`MAINRD`, `MD`/`M`-bus, `/CRAM`→`CRAMGE`, `/SRAM` | `MAIN …` |
> | **sound**| 6809E @ A8  | LS discrete | **"SOUND"** — `SOUNDWR`, `SD`/`S`-bus, `SWORKGE` | `SOUND …` |
>
> So a `MAINWR` on the sheet is our **sub**'s write strobe; `CRTWR` / `CRT WORK RAM` /
> `CRT ROM` is our **main**. ("Main" is called "CRT" because our main CPU drives the two
> 005885 video chips.) **One exception:** the phrase "CPU side vs **CRT side**" in a VRAM
> address mux means the raster/display read port, *not* this CPU.
>
> Shared RAMs (both schematic-confirmed): **C13** (6264SL, 8 KB) = main↔sub
> (`shared_ms`); **C9** (2128SL, 2 KB) = sub↔sound (`shared_sa`).

Main CPU memory map (decoded by the **Konami 007552 PAL at C15** — JEDEC dump + decoded equations live in this folder as `Konami_007552.jed` / `Konami_007552_equations.txt`. The PAL's 8 active-low outputs are `/RBN` (pin 12, ROM CE at C19), `/GATE1` (pin 13, 005885 chip 1), `/GATE2` (pin 14, 005885 chip 2), `/CWORK` (pin 15, shared RAM), `/DMP` (pin 16, → disabled 007452), `/CORAM` (pin 17, palette), `/G2AB11` (pin 18, → 005885 chip 2 A11 with register-window mask), `/SEL` (pin 19, bank-latch enable).):
```
0x0000-0x0004   Video registers (k005885 #1)  W
0x0800-0x0804   Video registers (k005885 #2)  W
0x1800-0x187F   Palette RAM
0x2000-0x2FFF   FG VideoRAM
0x3000-0x3FFF   Sprite RAM 1
0x4000-0x5FFF   Shared RAM (with SUB)
0x6000-0x6FFF   BG VideoRAM
0x7000-0x7FFF   Sprite RAM 2
0x8000          Bank-switch latch  W
0x8000-0x9FFF   Banked ROM
0xA000-0xFFFF   Fixed ROM
```

Sub CPU memory map (decoded by the **Konami 007553 PAL at C11** on page 1 — JEDEC `Konami_007553.jed` / decoded equations `Konami_007553_equations.txt`. Outputs: `/CRAM` (pin 13, shared with main, 0x0000-0x1FFF), `/SRAM` (pin 19, shared with sound, 0x2000-0x27FF), `/IOIN` (pin 18, joystick/system at 0x2800-0x2BFF), `/DIP2` (pin 17, 0x2C00-0x2FFF), `/DIP3` (pin 16, 0x3000-0x33FF), `/SET` (pin 15, coin counter at 0x3400-0x37FF), `/AFE` (pin 14, watchdog at 0x3C00-0x3FFF), `/ROM` (pin 12, sub program ROM 0x8000-0xFFFF, downstream-gated narrower than the PAL's raw 0x4000-0xFFFF). Pin labels confirmed by direct schematic read 2026-06-01. See `Konami_007553_pinout.md` for the full pin-to-net mapping.):
```
0x0000-0x1FFF   Shared RAM (with MAIN)
0x2000-0x27FF   Shared RAM (with SOUND)
0x2800          DSW1                R
0x2801          P1 input            R
0x2802          P2 input            R
0x2803          System / coin / start R
0x2C00          DSW2                R
0x3000          DSW3                R
0x3400          Coin counter        W
0x3C00          Watchdog            W
0x8000-0xFFFF   ROM
```

Sound CPU memory map (fully schematic-traced via LS138 A9 decoder on page 1 — see VERIFICATIONS.md section F):
```
0x0000-0x07FF   Shared RAM (with SUB)
0x1000-0x1001   YM2203              R/W
0x3000          VLM5030 data        W
0x8000-0xFFFF   ROM
```


---

## Page 0 — Main CPU + Video board

This page holds the **MAIN MC6809E** (designator **A19**, top-left area) together with the entire video subsystem: two independent Konami 005885 tile/sprite generators (E16 + H16), the 007327 palette, and the MASK1M pattern ROMs. The 007552 PAL at C15 is the main CPU's address decoder.

### Chip inventory — page 0

| Designator | Part | Function |
|---|---|---|
| **A19** | **MC6809E** (drawn as `6809E` on sheet) | **Main CPU** — 8-bit, 64 KB addressable. Visible pins: `HALT` (40), `NMI` (2), `IRQ` (4), `FIRQ` (3), `RESET`, `BUSY`, `AVMA`, `LIC`, `TSC`, `BS`, `BA`, `R/W` (32), `E`, `Q`. Address A0..A15, data D0..D7. **NB:** the signal named `MAINWR` on the sheet is **not** this CPU's strobe — despite the name it is the *sub* CPU's write strobe (see the sub-CPU note below). |
| **C19** | **27512** | Main program EPROM (64 K×8) — `/CE` driven by 007552 pin 12 (`/RBN`). Fits the entire 6809 address space; the bank latch downstream of 007552 `/SEL` is for VRAM/gfx-ROM-bank features, NOT for main-CPU code paging. |
| **C15** | Konami **007552** | Main address-decoder PAL (PAL10L8). Inputs: `NEQ` (pin 1), A11..A15 (pins 7,6,5,4,3). Outputs: `/RBN` (12, ROM CE), `/GATE1` (13, 005885 chip 1), `/GATE2` (14, 005885 chip 2), `/CWORK` (15, shared RAM with sub), `/DMP` (16, → 007452 disabled), `/CORAM` (17, palette RAM), `/G2AB11` (18, chip 2 A11 with PAL register-window mask), `/SEL` (19, downstream bank-latch enable). Decoded equations: `Konami_007552_equations.txt`. |
| E16 | Konami **005885** | Graphic generator #1 (layer "G1") — outputs `G1COL[4:0]` |
| H16 | Konami **005885** | Graphic generator #2 (layer "G2") — outputs `G2COL[4:0]` |
| C17 | Konami **007452** | **Math + bankswitching chip** (7×8 multiplier + 16/16 divider) per Furrtek's silicon decap. **DISABLED on this PCB** — CS12 (pin 12), CLK (pin 16), AB15 (pin 41), and AB12 (pin 39) are all tied to +5V. Any one of these would kill the chip; together they make it unambiguously vestigial. Konami populated it because the GX board is shared across multiple games — other titles in the family use it. For Double Dribble, no HDL needed. |
| I1  | Konami **007327** | Colour palette → RGB DAC, output goes to JAMMA pins for RED/GREEN/BLUE/VGND |
| **C13** | **6264SL** | 8K×8 SRAM — **main↔sub shared RAM** (`shared_ms`, `A0..A12`). Dual-ported: main/"CRT" side via `CWORKGE` (007552 `/CWORK`) → LS245 H11 (`CD` bus, `CRTWR` dir); sub/"MAIN" side via `CRAMGE` (007553 `/CRAM`) → LS245 E11 (`MD` bus, `MAINWR` dir). Address muxed `C`-bus↔`M`-bus by LS157 A13/B13/B14/A14. Write `CRAMWE`, `CS2`=+5. |
| H19 | **HM6264SL** | 8K×8 SRAM — video scratch (likely one 005885's tile RAM) |
| I7, I8, I10, I11, I12, I13 | **MASK1M** (×6 visible) | 128K×8 mask ROMs — character / sprite pattern ROMs split between the two 005885s |
| (×4) | **4464** DRAM (64K×4) | Sprite frame-buffer — two pairs (= 64K×8 ×2, one per 005885's sprite plane) |
| H13, H14 | **LS157** | 2:1 colour mux: selects `G1COL[4:0]` vs `G2COL[4:0]` under `PRI` |
| C10 | LS00 | NAND glue around R16/R17/R17N (bank-aware sprite-ROM addressing) |
| H9 | LS04, LS32 (multi) | Inverters + ORs around CRTRD/CRTWR/CGRAM |
| B15, A10, A11 | LS74 (×4) | Sync flip-flops driving NCSY/NVSY chain |
| S15-area | LS393 | Counter (sync chain divider) |
| G14 etc. | LS244 | Bus buffers (mostly for video-bus → JAMMA) |
| — | LS138 | One decoder in the CRT-area select logic |

### Buses observed — page 0

- **CPU side (into 007452 / 007327 / 005885s):** `AB12..AB0`, `D80..D87` (8-bit data), `CRTRD`, `CRTWR`, `CGRAM`, `RESET`, `CLK2`, `CLKQ`.
- **005885 internal video buses:** `AX12..AX0` (12-bit video addr to its own 6264 SRAM), `V07..V00` (8-bit video data), `VCB7..VCB0` + `VCD7..VCD0` (chip-internal sub-buses), `RDU7..RDU0` + `RDL7..RDL0` (16-bit sprite-pattern fetch, U=upper byte / L=lower byte from MASK1M pair).
- **Colour:** `G1COL[4:0]`, `G2COL[4:0]` → LS157 muxed by `PRI` → `COL[4:0]` → 007327 palette input.
- **Sync / timing:** `NCSY`, `NVSY` (composite + vertical sync), `CK18` (18 MHz reference visible on E16 pin 1), `NCK1`, `NCK2`, `CKIS`.
- **Bank / flip:** `R16`, `R17`, `R17N` feed the LS00 at C10 to gate MASK1M chip-enables — i.e. main-CPU writes to a bank latch select which half of the character ROMs each 005885 sees. `NFLIP2`, `VFLIP2` reach the 005885s as orientation controls.
- **IRQ/INT chain pins on 005885:** `NIRQ`, `NMI`, `NFIR`, `NEXR`, `NRES`, `MRNW` — direction (input vs output of the chip) is visible on schematic by following each net to its destination. (No silicon decap of 005885 exists; MiSTer's `k005885_REFERENCE.sv` in our doc/ folder is the next-best reference for pin direction.)

### Colour / palette path

```
G1COL[4:0] ─┐
            ├─► LS157 (H13/H14, sel = PRI) ──► COL[4:0] ──► 007327 (I1) palette ──► RED/GREEN/BLUE/VGND → JAMMA P1
G2COL[4:0] ─┘
```

`007327` is a Konami palette LUT (RGB outputs are 4 bits per channel — pin labels `CRED`/`GREEN`/`CBLUE`/`CVGND` go to JAMMA P1 pins 12 / 13 / 14 / 14-GND respectively, confirm vs MRA).

### Connectors — page 0

- **P1**: KEL56P-1 — standard 56-pin JAMMA edge (NOTE block confirms it: *"JAMMA EDGE 56PIN, PIN NO. NUMBER = PARTS-SIDE, ALPHABET = SOLDER-SIDE, /A/ = small letter"*).
- **P2**: SVCN4P — 4-pin SVCN connector (the 4-player extension for the second pair of joysticks). Visible on page 1's input section.

---

## Page 1 — Sub CPU + Sound CPU + I-O + audio out

### Chip inventory — page 1

#### Sub-CPU side (top-left area of page)

| Designator | Part | Function |
|---|---|---|
| **A12** | **MC6809E** (drawn as `6809E` on sheet) | **Sub CPU** — 8-bit, 64 KB addressable. Visible control pins: `HALT` (40), `NMI` (2), `IRQ` (4), `FIRQ` (3), `RESET`, `BUSY`, `AVMA`, `LIC`, `TSC`, `BS`, `BA`, `R/W` (32), `E`, `Q`. Address A0..A15, data D0..D7. Pages adjacent to main CPU via the shared 8 KB SRAM. |
| **C12** | **27512** | Sub program EPROM (64 K×8 — but per MAME's romset only 32 KB of data are loaded; see `mem.yaml` `sub` region note). `/CE` driven by 007553 pin 12 (`/ROM`). |
| **C11** | Konami **007553** | Sub address-decoder PAL (PAL10L8). Inputs: `EN` (pin 1, from LS00 NAND of CLKE & CLKQ), A15..A10 (pins 3,4,5,6,7,8 — A11/A10 muxed via LS157 H10 between CPU side and CRT side). Outputs: `/ROM` (12, sub ROM CE), `/CRAM` (13, shared with main 0x0000-0x1FFF), `/AFE` (14, watchdog 0x3C00), `/SET` (15, coin counter 0x3400), `/DIP3` (16), `/DIP2` (17), `/IOIN` (18, joystick/system inputs at 0x2800), `/SRAM` (19, shared with sound 0x2000-0x27FF). Decoded equations: `Konami_007553_equations.txt`. |
| (near sub CPU) | **2128SL** (one of two) | 2K×8 SRAM — sub work RAM (mux'd between CPU and CRT via LS157s) |
| H8 | LS04 | Inverter producing **`MAINWR`** from the sub-CPU `R/W` (yes — the *sub*'s write strobe is named `MAINWR` on the sheet; there is no `SUBWR`). |
| H10 | LS157 | Sub-CPU high-address mux (CPU side vs CRT side) feeding the 007553 PAL inputs. |
| B9, B10, B11 | LS157 (×3) | Address mux for the **C9** shared SRAM (`M`-bus vs `S`-bus), `SEL`=`CLKE*`. |
| D8 | LS245 | **Sound**-side transceiver on the shared **C9** SRAM (`SWORKGE` enable, `SOUNDWR` dir) — connects the sound CPU data bus to C9; the sub side of C9 uses D10 (`SRAMGE`/`MAINWR`). |
| (osc near H9) | **3.58 MHz xtal** | Visible can — YM2203 master clock (3.579545 MHz NTSC sub-carrier) |

> **Naming gotcha (resolved from the page-1 schematic):** the `MAINWR` strobe and
> the `M0..M15`/`MD0..MD7` bus belong to the **sub** CPU (A12, 007553-decoded),
> **not** our main CPU (A19, 007552). `C9` (2128SL, 2 KB) is the **sub↔sound shared
> RAM** (`shared_sa` in the HDL), dual-ported: D10 (`SRAMGE`/`MAINWR`) = sub side,
> D8 (`SWORKGE`/`SOUNDWR`) = sound side, address muxed by LS157 B9/B10/B11. The sub
> reaches it via the 007553 `/SRAM` strobe (`0x2000-0x27FF`); the sound CPU sees it
> at `0x0000-0x07FF`. So the "sub work RAM" / "B9/B10 mux" framing above is really
> **C9's sub side** — there may be just this one shared 2128SL here, not two;
> re-verify against a tile showing any sub-local RAM.

#### Sound-CPU side (top-right area of page)

The sound CPU has **no dedicated PAL** — its address decode is done with discrete LS-series logic (LS27/LS02/LS08/LS138 around F9-F11) for ROM/SRAM/YM2203/VLM5030/shared-SRAM selects.

| Designator | Part | Function |
|---|---|---|
| **A8** | **MC6809E** | **Sound CPU** — 8-bit, 64 KB addressable; same control-pin set as the main CPU. Sits near the YM2203. |
| (next to A8) | **27256** | Sound program EPROM (32 K×8). |
| (top-right SRAM) | **2128SL** (the other one) | 2K×8 SRAM — sound CPU work RAM |
| F10 / F9 / G7 / G11 | LS27 / LS02 / LS08 | Write-strobe decode → `SOUNDWR`, `CRTWR`, `SRAMWE`, `CRAMWE`. (`MAINWR` arrives here as an **input** = the sub CPU's write strobe, used to gate the sub's side of the C9 shared SRAM — see the naming-gotcha note above.) |
| (many) | LS245 | Bus transceivers — `MAINWR`, `SOUNDWR`, `CRTWR` gated |
| A10 | LS393 | Sound-clock divider |
| (top right glue) | LS00, LS04, LS502/LS02 | Reset gating, OE/WE glue |
| various | LS157 (×4) on left | 2:1 muxes on CRAM / SRAM address bus — switch the SRAM/CRAM banks between CPU-side and CRT-side |
| various | LS74 | Edge flops on CLKE / SCLK distribution |

#### Sound generation (top-right quadrant)

| Designator | Part | Function |
|---|---|---|
| (centre) | **YM2203** (OPN) | 3-ch FM + 3-ch SSG; `OPN` is its `/CS`. `SH1`/`SCLK`/`OP-O` go to YM3014; `IOA[7:0]`/`IOB[7:1]` are the dipsw / extra-I-O port |
| (right of YM2203) | **YM3014** | 16-bit floating-point serial DAC for YM2203's `MO`; outputs analog `BUFF` to op-amp |
| (lower) | **VLM5030** | Sanyo PCM speech synth; pins `RST`, `OSC1/2`, `MTE`, `VREF`, `VCU`, `BSY`, `SCLK`, `ME`, `A0..A16`, `D0..D7` |
| E7 | **MASK1M** | VLM5030 voice ROM (128 K×8) |
| A9 | LS138 | Sound-CPU I-O decode → `IRQEN`, `VDATA`, `OPN` (YM2203 CS), `SWORK` |
| D5 | 4066 (×3) | Analog mute / channel-mix switches between YM3014, VLM5030 BUFF and op-amp summing node |
| D4 | UPC324 (×2 sections) | NEC quad op-amp — channel sum / low-pass / gain stage |

#### I-O matrix and DIPs (bottom half)

| Designator | Part | Function |
|---|---|---|
| CR1, CR3, CR4, CR5 (and one more) | Konami **005273** (×5) | Resistor-pack input conditioners for joystick / button lines |
| F2, G3, G4 | LS253 (×3) | 4-to-1 muxes — select between P1/P2 inputs (and P3/P4 from the SVCN4P) onto bus `C0..C11` |
| (×2 banks) | DIPSW8P, RA1, RA2 (2.2 K×8 pull-ups) | DIPSW1 + DIPSW2 (8-pos each) — game options |
| (×1) | DIPSW4P + LS367 (LS367 buffers it onto `CD0..CD7`) | Test / cabinet DIPSW |
| H6 | LS244 | Buffers DIPSW into bus `E1`/`E2` |

#### Audio output (bottom right)

| Designator | Part | Function |
|---|---|---|
| (bottom right) | LA6358 | Sanyo dual op-amp — final speaker drive |
| D4 | UPC324 sections | Pre-amp / mixer (cont. from top-right) |
| (terminals) | SPEAKER-BUT1 / BUT2 | Mono speaker output to JAMMA edge |

### Inputs → MUX → CPU

```
1P-START …………………… [005273 CR1] ─┐
2P-START                                 │
1P-UP / 2P-UP                            │
1P-DOWN / 2P-DOWN  ……… [005273 CR5] ─┤
1P-LEFT / 2P-LEFT                        │
1P-RIGHT / 2P-RIGHT … [005273 CR4]      ├─► LS253 ×3 (F2,G3,G4) ─► C0..C11 ─► main-CPU input port
1P-SHOOT1..3 / 2P-SHOOT1..3 [CR3 etc.]  │
3P-/4P- variants (SVCN4P 4-pin)         │
DIPSW1 (8b)  ─[RA1]─[buffers]──────────►│
DIPSW2 (8b)  ─[RA2]─[buffers]──────────►│
DIPSW4P (4b) ─[LS367]──────────► CD0..CD7
```

(LS253 select pin is `dipsel` or `player_sel` — driven by an I-O write; trace through the sub-side PAL to identify the source.)

### Sound chain

```
sound CPU (6809E) ──D[7:0]── 27256 (program)
                  ──D[7:0]── 2128SL (work RAM)
                  ──D[7:0]── YM2203 (CS=OPN)  ─SH1/SCLK/MO─► YM3014 ─BUFF─┐
                  ──D[7:0]── VLM5030 ←────A[16:0]──── MASK1M E7 (voice)   │
                                          ME / SCLK from sound CPU port    │
                                                                            ├─► 4066 sw ─► UPC324 mix/gain ─► LA6358 ─► SPEAKER BUT1/BUT2
                                                                            │
                  ←── IRQEN (from LS138 A9) — IRQ ack/enable                │
```

### Chip-select decode (page-1 bottom)

```
MAINWR ──┐ (from MAIN CPU; sub CPU has its own SUBWR via the sub-side PAL)
         ├─► LS27 (F10) ─► LS02 (F9) ─► SRAMWE  (main work RAM)
SOUNDWR ─┤                                CRAMWE  (palette RAM)
CRTWR ───┘                                CRAMGE  (palette RAM /OE)
         (analogous SRAMGE for /OE)
```

The same block produces enables for the SRAM and CRAM banks (which page-1 LS157s then mux onto the CPU vs CRT address ports).

### Clocking (what's visible)

- **CK18** = **18.432 MHz** (schematic-confirmed, active osc-can on page 0 r0c1 → LS244 G14 buffer → CK18 net) feeds 005885 E16 pin 1 on page 0. Master video-domain clock for the entire video subsystem.
- **CLK2 is NOT a CPU clock — it is the video dot-clock domain.** Traced on the
  schematic: `CLK2` = **`NCK2`** (E16 / 005885 #1 pin 3, the chip's buffered clock
  output) routed through an **LS14** Schmitt inverter (pin 5 in → pin 6 out), so
  `CLK2 = ~NCK2`. It clocks the **007327** (I1) on pin 40, i.e. the palette/DAC
  latches the `COL` colour bus on the falling edge of `NCK2`. The 005885 therefore
  owns the pixel-sample clock for the whole colour path. In the Furrtek 007121
  netlist this exported clock is `PIN_CK2` (see `furrtek_007121_schematics.pdf`
  p2 CLOCK DIV); the internal tile pixel pipeline runs on `CK24_4`. `CLKQ` is the
  6809E Q bus clock (CPU-write timing into 007452/007327), a separate domain.
- **SCLK** on page 1 is the sound clock (YM2203 needs ~3 MHz; 27256+6809E run at ~1.5 MHz E = ~6 MHz oscillator before divide).
- **CLKE / CK16** are intermediate domain ticks distributed via LS74 flops on page 1.
- The actual oscillator can(s) are not visible on these two sheets.

---

## CURRENT STATE — V1 bring-up status (2026-06-02 morning)

Reached after a long day of bring-up. The boot now executes through MAME's
POST screen. Frame 275 of a 500-frame sim renders:

```
MAIN TO RAM  C13  OK      (cyan)
MAIN TO RAM  C 9  OK      (cyan)
SOUND TO RAM C 9  OK      (cyan — fixed via `gate:` clause)
MAIN WORK RAM C13  OK
CRT WORK RAM      OK
OBJECT RAM1/RAM2  OK
VIDEO  RAM1/RAM2  OK
MAIN ROM  C12  OK
CRT  ROM  C13  OK
SOUND ROM A 6  BAD       (red — the only remaining test failure)
```

> **POST labels are the board convention** (see the CPU-labels table near the top):
> `MAIN …` = our **sub** (work RAM C13 = `shared_ms`, program ROM C12), `CRT …` =
> our **main** (`CRT ROM` is the main EPROM at **C19** — the `C13` here is a
> screen-read slip), `SOUND …` = the sound CPU. So `MAIN TO RAM C13`/`C9` is the
> **sub** exercising the two shared RAMs it bridges, and `SOUND TO RAM C9` is the
> sound side of C9.

### POST screen now ALL OK 🎉 (added 2026-06-02 morning)

After the IOB bit-0 fix below, every line of the POST renders cyan "OK":
SOUND ROM A 6 is no longer red. Boot can now proceed past POST.

### Major fixes that landed in this session

1. **SDRAM bank split** (4 banks vs all-on-bank-0). Without it, sub CPU
   reset vector read returned 0xFF and sub executed garbage.
2. **NRD inversion** on both 005885 wrappers — `.NRD(~main_rnw)` not
   `.NRD(main_rnw)`. Single-character fix that unblocked all CPU↔chip
   writes (the chip was interpreting reads as writes and vice versa).
3. **Interrupt swap** — chip 1 NFIR → CPU IRQ, chip NIRQ → CPU FIRQ,
   chip NNMI → CPU NMI. Per direct schematic read; the chip's pin
   labels are misleading.
4. **Sub CPU interrupts** wired from chip 1's shared bus (1 kΩ pull-up
   wired-OR pattern; chip 2's interrupts dangle per the user's read of
   the schematic).
5. **BA-offset fix in macros.def** — BA2_START=0x40000 (not 0x40100),
   BA3_START=0x80000 (not 0x80100). The +0x100 was wrongly reserving
   space for prom, but prom lives outside all banks per the MRA layout.
6. **007327 module** (`jtddrbl_colmix.v`) — bundles the LS157 H13/H14
   layer-mux + PRI gate logic + 128-byte palette BRAM lookup + BLK
   blanking. Models the schematic chip + surrounding glue.
7. **Bank routing for chip 2 gfx ROM** — main CPU's 3-bit bank register
   exposed (`bank_out` port) and routed as MSB of `gfx2_addr`.
8. **Slot offsets in bank 1** (SND_OFFSET=0x4000 words, VLM_OFFSET=0x8000
   words) — without these, all slots in a shared bank default to offset
   0, causing snd to read sub's bytes.
9. **`gate: [main, sub, snd]` on cpu_cen clock** — the breakthrough
   fix for the stale-byte stale-read pattern. Cribbed from contra's
   mem.yaml. JTFRAME holds cpu_cen LOW while any of the named SDRAM
   slots is busy, so CPUs never sample `cpu_din` before SDRAM serves
   the byte. Solved the "0x83E0 returns 0x00 instead of 0x86" pattern
   that was failing the SOUND ROM checksum and producing inconsistent
   tile rendering.

10. **VLM BSY routing to YM2203 IOB[0]** (was IOB[7]) — single-bit
    fix in `jtddrbl_sound.v` line 131. We had `{vlm_bsy, 7'h7f}`
    placing it at bit 7. Sound CPU's POST routine polls
    `LDA $1001; BITA #$01; BNE` waiting for IOB[0] to clear. Our 7'h7f
    filler made bit 0 always 1 → loop stuck forever → sound CPU never
    reached its ROM-checksum code. Fix: `{7'h00, vlm_bsy}`. Result:
    SOUND ROM A 6 POST = OK.

11. **Main decoder reg windows widened to PAL ranges** (2026-06-02). The
    earlier main.v decoder narrowed k5885_1_cs to `addr <= 0x0004` and
    k5885_2_cs reg window to `addr in [0x0800-0x0804]` — only the 5
    "obvious" MMR byte addresses. BUT the 005885 also has scroll/strip
    (zure) registers at chip-internal addr 0x20-0x5F, which the CPU
    writes via main 0x0020-0x005F (chip 1) and 0x0820-0x085F (chip 2).
    The 3000-frame instrumented sim confirmed all 64 zure addresses
    were being WRITTEN by the CPU but our too-narrow chip-select gate
    was dropping them (0 ZURE writes logged inside the chip wrapper
    despite 128 unique zure addresses touched at the CPU bus).
    
    Fix: rewrote the main decoder strictly from `Konami_007552.jed`
    equations (decoded via jedutil):
      - /GATE1 = chip 1 CS at `0x0000-0x07FF + 0x2000-0x3FFF`
      - /GATE2 = chip 2 CS at `0x0800-0x0FFF + 0x6000-0x7FFF`
      - /SEL (bank latch) widened to `0x8000-0x9FFF` (PAL is not NEQ-gated)
      - pal_cs kept narrow at `0x1800-0x187F` (128 B physical; PAL fires
        for the whole `0x1800-0x1FFF` window but the rest is just mirror
        and CPU never touches it — log confirms).
    
    Sub decoder reviewed simultaneously against `Konami_007553.jed`:
    functionally correct (boot code only touches the exact byte addresses
    we model), but widened DIP2/DIP3 ranges from single-byte to full
    1 KB PAL windows for schematic faithfulness. Header comments in
    both .jed-equation docs corrected (007552 = MAIN, 007553 = SUB —
    they had been swapped).
    
    Likely fixes the messed-up tile positioning / scrolling observed in
    the 3000-frame attract-mode sim (zure registers never reached chip).

### Current mem.yaml bank layout

```
Bank 0:  main only (64 KB, 8-bit)
Bank 1:  sub (32K) + snd (32K, SND_OFFSET=0x4000 words) + vlm (128K, VLM_OFFSET=0x8000) + prom
Bank 2:  gfx1 only (256 KB, 16-bit)
Bank 3:  gfx2 only (512 KB, 16-bit)
```

cpu_cen clock has `gate: [main, sub, snd]` to stall CPUs during SDRAM busy.

### Sound CPU wiring (cross-checked vs user's schematic read 2026-06-02)

All 5 wiring points match between HDL and schematic:

| Schematic | HDL |
|---|---|
| Sound CPU → SD bus → 27256 program ROM | snd region SDRAM (bank 1 slot 1) |
| Sound CPU → SD bus → YM2203 | ym_cs decode at 0x1000-0x1001 |
| LS374 latch SD→VD for VLM commands | `vlm_data_latch` register on write to 0x3000 |
| MASK1M voice ROM ← VD bus from VLM (direct, no CPU) | `vlm_addr/vlm_data` SDRAM port |
| MASK1M A16 = YM2203 IOA3 (bank) | `vlm_bank = ym_ioa_out[3]; vlm_addr={vlm_bank, vlm_internal_addr}` |

### Next session start here — open hunts

**P1 — SOUND ROM A 6 BAD (task #28).** Last red line on POST screen. Sound
CPU now reads its program-ROM bytes correctly (verified 0x83E0=0x86,
0x83E4=0x01 — both stable across all reads after the `gate:` fix). But
the checksum compare still fails. Theories ranked:
  - **Most likely**: checksum constant stored at a specific address in
    sound ROM (often the LAST byte of the 32K = 0x7FFF) that sound CPU
    reads to compare. If THAT byte is still mis-fetched, "BAD" fires
    even though the sum is otherwise right.
  - Sound CPU's checksum routine may depend on YM2203 timer/IRQ we
    haven't fully wired.
  - The result reporting back to main CPU via shared_sa might be broken.
  Diagnostic plan: extend the sound `$display` trace to dump the LAST
  100 reads near the time SOUND ROM result is reported (correlate with
  main's writes to the POST-screen tile positions).

**P2 — task #27**. Two known V1 expedients to revisit:
  - PRI is the educated-guess `(g1col[3:0]==0) & g2col[4]` not the
    schematic-traced `(|g1col[3:0]) & g2col[4]` (commented out in
    jtddrbl_colmix.v).
  - RDU/RDL bytes are swapped in game.v on both 005885 wrappers. Without
    swap → garbage chars. With swap → readable POST. WHY the swap is
    needed isn't traced — probably MRA `<interleave>` map="01"/"10" vs
    SDRAM byte ordering mismatch.

**P3 — task #25**. Trace shared NEXR net between 005885 #1 and #2.
Currently both wrappers tie NEXR=1'b1; verify there isn't a CPU-driven
reset on that net.

## Known technical debt — V1 working but not schematic-faithful

These were applied during V1 bring-up because they produce better visual
output than the schematic-faithful version. Both must be revisited:

1. **PRI logic in `jtddrbl_colmix.v` uses educated guess instead of
   the schematic-traced gate network.** The schematic-traced version
   (`PRI = (|G1COL[3:0]) & G2COL[4]`) — which the user read off the
   LS32 H12 + LS08 G11 gate network 2026-06-02 — is implemented but
   commented out. The live version is the V1 baseline (`PRI = (G1COL[3:0] == 0)
   & G2COL[4]`) because it gave visually-better tile rendering during
   V1 bring-up. Once the rest of the pipeline is stable, swap the
   comment back to the schematic-traced expression and verify the
   output matches MAME.

2. **Graphics ROM RDU/RDL bytes are swapped vs the natural mapping
   in `jtddrbl_game.v` u_k5885_1 + u_k5885_2.** With the byte-swap
   applied, the POST screen renders readable text (matches MAME up to
   color decode). Without the swap, the POST text appears as garbage
   characters. The swap is empirically correct but we haven't proven
   why — the MRA `<interleave>` map="01"/map="10" attributes look like
   they should produce the unswapped ordering. To revisit when there's
   time: trace whether the SDRAM controller, the MRA loader, or the
   chip's RDU/RDL pin definition is the source of the mismatch.

## Open questions (resolve later)

1. ✅ **CPU type resolved.** All three CPUs are MC6809E (drawn as `6809E` on schematic, 40-pin footprint, standard 6809 pinout). We instantiate `jtframe_sys6809` in HDL.
2. ✅ **007552 PAL truth table — RESOLVED.** JEDEC dump obtained and decoded with MAME's `jedutil`. Outputs: `/RBN` (ROM CE), `/GATE1`/`/GATE2` (005885 chip selects), `/CWORK` (shared with sub), `/DMP` (→ disabled 007452), `/CORAM` (palette), `/G2AB11` (chip-2 A11 mask), `/SEL` (bank-latch enable). See `Konami_007552_equations.txt`.
3. ✅ **007553 PAL — RESOLVED.** JEDEC dumped, pin labels confirmed from schematic (page 1, C11, paired with sub CPU at A12 + 27512 sub ROM at C12). Outputs: `/ROM` (sub ROM CE), `/CRAM` (shared with main), `/SRAM` (shared with sound), `/IOIN`, `/DIP2`, `/DIP3`, `/SET` (coin counter), `/AFE` (watchdog). See `Konami_007553_equations.txt` and `Konami_007553_pinout.md`.
4. ✅ **Oscillator values resolved.** **18.432 MHz** master (active osc-can on page 0 r0c1, drives CK18 net) and **3.579545 MHz** sound (active osc-can on page 1, drives SCLK net — both feeding YM2203 CLK and VLM5030 OSC1).
5. **Layer priority source.** `PRI` enters the page-0 LS157 H13/H14 muxes from page 1. Trace it backwards on page 1 — likely a flip-flop output driven by the 007552 `/SEL` strobe (pin 19) latching one bit of `D0..D7`.
6. ✅ **007452 — RESOLVED.** Physically populated at C17 but hardware-disabled on Double Dribble's PCB (CS, CLK, and key address bits all tied to +5V). Vestigial chip from shared-PCB economics. No HDL needed. (Previously documented as a "CRT helper" — that was wrong: Furrtek's silicon decap shows it's a math + bankswitcher chip used in Contra, Combat School, etc.)
7. **005885 dual-instance behaviour.** Both E16 and H16 are wired as full layer generators with identical pin connections. The two color buses `G1COL[4:0]` and `G2COL[4:0]` feed the LS157 priority mux at H13/H14 — implying each chip drives one of two independent layers (FG and BG, or layer1 and layer2). One could be repurposed as "sprite engine only" if the game code never enables its tile output, but the wiring is symmetric.
8. **R16 / R17 / R17N driver.** Used on page 0 (LS00 at C10) to gate the MASK1M chip-enable. Almost certainly outputs of the `SET`-strobe latch on page 1 (= the main-CPU bank register).
9. **VLM5030 trigger path.** `ME` (memory-enable / start) and `SCLK` are wired but the source register on the sound-CPU side is not labelled — `VDATA` from LS138 A9 is probably the data-latch CS.
10. **4P connector pinout (SVCN4P).** Only the 4-pin SVCN edge is shown. Trace each of the 4 pins to its 005273 input pack to identify which player (P3 / P4) the connector serves, then to the appropriate JAMMA-extension pin number per the JAMMA standard.

---

## Where to look next

- **Doc rule for this project**: every fact in this file should be schematic-grounded where the schematic shows it. The schematic packet is complete (page 0 + page 1) — most questions can be answered by tracing nets. Fallback options for things the schematic genuinely can't show (PAL truth tables, custom-chip internals): (1) MiSTer reference `doc/k005885_REFERENCE.sv` for the 005885, (2) Furrtek's silicon decap (https://github.com/furrtek/SiliconRE/tree/master/Konami) for chips like 007452 and the family-cousin 007121, (3) MAME `src/mame/konami/ddribble.cpp` as the last resort.
- Neighbouring JTCORES cores that use the same 005885 family worth referencing for HDL precedent: [cores/kicker](../../kicker/) (Iron Horse), and possibly [cores/labrun](../../labrun/).

---

## File index in this folder

- [schematic_p0.png](schematic_p0.png) — page 0 (video), 4763 × 3681
- [schematic_p1.png](schematic_p1.png) — page 1 (sound CPU / I-O / decode), 4763 × 3681
- `schematic_p{0,1}.jp2` — original JPEG-2000 files from Konami packet
- `tile_p{0,1}_r{0,1}c{0,1,2}.png` — 3×2 grid tiles used to read the schematic (can be regenerated with `sips`; safe to delete)
- `tile_p1_cpus.png` — tighter crop of the page-1 CPU/sound area (safe to delete)
