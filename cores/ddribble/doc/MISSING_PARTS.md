# Missing-sheet parts checklist — Double Dribble (GX690)

The two schematic sheets we have cover roughly **two thirds** of the PCB. This document lists every chip and circuit that is **not** on our sheets but **must** be on the board (verified via MAME `konami/ddribble.cpp` and Konami GX690 architectural conventions).

Use this list to walk the actual PCB and circle each item on the photo. The companion file `board-annotated.png` shows colour-coded regions of what each schematic page covers.

---

## Colour code (matches `board-annotated.png`)

| Colour | Meaning |
|---|---|
| 🟢 **GREEN** | Covered by schematic page 0 (video) |
| 🔵 **BLUE** | Covered by schematic page 1 (main CPU + sound + decode + I-O) |
| 🔴 **RED** | **Missing** — needs to be located on the PCB |

---

## Missing items (RED zones)

### A. Sub CPU and its peripherals (the biggest gap)

| # | Item | Identifying features | Reference |
|---|---|---|---|
| **A1** | Third **MC6809E** (sub CPU) | 40-pin DIP, marking `HD68B09EP` / `MC68B09EP`. Distinct from the two 6809s we've placed (main is next to 27512; sound is next to YM2203). | MAME ddribble.cpp:537 — `MC6809E(config, m_subcpu, XTAL(18'432'000) / 12)` |
| **A2** | Sub CPU program ROM | 28-pin DIP windowed EPROM, **27256** (32 KB). Adjacent to the sub CPU's address-bus pins. Label may start `690c02` or similar. | MAME ddribble.cpp:587-588 — `ROM_REGION( 0x8000, "subcpu", 0 )` / `ROM_LOAD( "690c02.bin", … 0x8000, … )` |
| **A3** | MAIN ↔ SUB shared SRAM | 28-pin DIP, **8 KB SRAM** (typical: HM6264, HY6264, or similar). Data lines fan to **both** CPU data buses — visible as a chip with two LS245 transceivers feeding it, one from each side. | MAME ddribble.cpp:390 (main side) + ddribble.cpp:400 (sub side) — `share("sharedram")` |
| **A4** | Bus-arbitration cluster around A3 | 2-3× **74LS245** transceivers (one per CPU side of the shared SRAM), plus 1-2× **74LS157** muxes for address arbitration. Typically clustered tight around A3. | Konami convention — schematic page 1 already shows the same pattern around the main work-RAM area |
| **A5** | Coin-counter latch | One 74LS174 / 74LS273 flip-flop. Sub CPU writes 0x3400 latch this. | MAME ddribble.cpp:408 — `map(0x3400, 0x3400).w(FUNC(coin_counter_w))` |
| **A6** | Watchdog timer | Usually a 555 timer + monostable + reset gate, OR a 74LS123 + RC. Triggered by sub-CPU writes to 0x3C00. If the watchdog isn't kicked within ~200 ms, it pulses the global RESET line. | MAME ddribble.cpp:409 — `map(0x3c00, 0x3c00).w("watchdog", watchdog_timer_device::reset_w)` |

### B. Clock generation (not on page 0 or page 1)

| # | Item | Identifying features | Reference |
|---|---|---|---|
| **B1** | 18.432 MHz master oscillator can | Metal/ceramic can marked `18.432` or `18.4320`. Drives the page-0 `CK18` net. | MAME ddribble.cpp:534-540 — all three `MC6809E(config, …, XTAL(18'432'000) / 12)` |
| **B2** | Master clock-divider chain | One or two 74LS161 / 74LS393 / 74LS74 counters dividing 18.432 MHz down to: 6.144 MHz (pixel clock), 1.536 MHz (E/Q for all 3 CPUs), and possibly other intermediate rates. | Konami convention; the actual chip mix depends on the specific board revision. |

### C. Possible additional items to look for

| # | Item | Identifying features | Reference |
|---|---|---|---|
| **C1** | Main-CPU bank-switch latch | 74LS174 or LS374, latches main CPU writes to 0x8000 into a bank-select bit. May be on the main-CPU area of our page 1, or on a missing sheet. | MAME ddribble.cpp:393 — `map(0x8000, 0x8000).w(FUNC(bankswitch_w))` |
| **C2** | VLM5030 bank-switch latch | 74LS174 / LS273. VLM5030 sees a 64 KB window over its 128 KB ROM — bank bit is latched by sound CPU. | MAME ddribble.cpp:421-424 — `vlm_map: bankr(m_vlmbank)` |
| **C3** | Power-on reset circuit | RC delay + 74LS123 monostable, plus the watchdog reset combined. | Standard arcade pattern. |

---

## Already located (confirm against your PCB)

These should match the **GREEN** and **BLUE** zones on the annotated image. If anything is in a different location than I've drawn, tell me and I'll redo the zones.

### 🟢 Green zone — schematic page 0 (MAIN CPU + video)

- **MC6809E** main CPU at designator **A19** (top-left area)
- **27512** main program ROM at designator **C19** — `/CE` driven by 007552 pin 12 (`/RBN`)
- **007552** main address-decoder PAL at **C15** — JEDEC + decoded equations in this folder; outputs drive ROM, both 005885s, palette, shared RAM, bank latch.
- 2× **005885** (E16, H16) — the two big PLCC customs in the centre of the board
- **007327** palette → RGB DAC (I1)
- **007452** math/bank chip (C17) — physically present but hardware-disabled on this PCB
- **HM6264SL** VRAM (H19)
- 4× **4464** DRAMs (sprite framebuffer, in pairs)
- 4× **MASK1M** tile/sprite ROMs (I7-I13)
- Priority-mux **74LS157** (H13, H14)
- **PROM** 256 B sprite-lookup (I15) — the small 16-pin PROM
- Sync flip-flops 74LS74 (B15, A10, A11)
- Glue: 74LS00 C10, 74LS04 H9, 74LS32 (multi), 74LS138, 74LS393

### 🔵 Blue zone — schematic page 1 (SUB CPU + SOUND CPU + I-O)

- **MC6809E** sub CPU at designator **A12** (top-left area)
- **27512** sub program ROM at designator **C12** — `/CE` driven by 007553 pin 12 (`/ROM`). Physical chip is 64 KB but MAME's romset only loads 32 KB; see `mem.yaml` `sub` region for details.
- **007553** sub address-decoder PAL at **C11** — JEDEC + decoded equations + pin-label confirmation in this folder; outputs drive sub ROM, shared-with-main RAM, shared-with-sound RAM, inputs, DIPs, coin counter, watchdog.
- **2128SL** sub work RAM
- **MC6809E** sound CPU at designator **A8** (near the YM2203)
- **27256** sound program ROM
- **No PAL** on the sound CPU side — decode is all discrete LS-series logic (LS27/LS02/LS08/LS138 around F9-F11).
- **2128SL** sound work RAM
- **YM2203** + **YM3014**
- **VLM5030** + **MASK1M** voice ROM (E7)
- **74LS138** sound I-O decoder (A9)
- 3× **CD4066** analog mute switches (D5)
- **UPC324** quad op-amp (D4)
- **LA6358** dual op-amp (audio final stage)
- 5× **005273** input resistor packs (CR1, CR3, CR4, CR5, +1)
- 3× **74LS253** input muxes (F2, G3, G4)
- 2× **DIPSW8P** + RA1/RA2 pull-up packs (DIPSW1, DIPSW2)
- **DIPSW4P** + **74LS367** buffer (DIPSW3)
- **3.58 MHz** oscillator can (near LS74 H9)
- LS245/LS157/LS74/LS245 glue
