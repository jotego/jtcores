# Toobin' schematics — CPU / PROCESSOR sheets (parse #1)

Source: `doc/Toobin.pdf`, the two "PROCESSOR" sheets (CPU + reset + interrupt + bus buffers).
**Status: first read. Every line tagged `(VERIFY)` must be eye-checked on the PDF before any HDL.**
Standard 74-series TTL throughout; designators like `13M`,`8L`,`20K` are PCB grid locations.

> ⚠️ These two sheets are the CPU core, NOT the memory map. The region selects
> (`/PFRAM`, `/ANMORAM`, `/EEPROM`, `/WDOG`, `/INTLINE`, `RORAM`, `BR//W`) arrive from
> **another sheet** (the address decoder + ROM). The program ROM chips are not on these pages.
> **No PAL is visible on these two sheets** — the decoder PAL/LS138 is on the page we still need.

---

## 1. CPU

- **U68010** (DIP-64), clearly labelled. (We run fx68k/68000 — opcode-compat already proven.)
- **CLK (pin 15) = `1H`** — the CPU is clocked by the video horizontal `1H` net.
  1H = MCKR/2 = 32 MHz/4 = **8 MHz** ⇒ CPU is inherently video-locked. (VERIFY 1H = 8 MHz)
- **HALT (17) and RESET (18)** tied together, pulled up by R62 1K, driven low by `/RESET`
  (Q2 2N3904). So reset & halt are the same line.
- Control: `R//W` (9), `/UDS` (7), `/LDS` (6), `/AS`, `/DTACK` (10), `/VPA` (21),
  `E` (20), `/VMA` (19), `/BERR` (22), `/BR`/`/BG`/`/BGACK` (13/11/12, tied to PR1 pull-up = idle).
  FC0/FC1/FC2 (28/27/26). (VERIFY exact pin numbers — image is low-res.)

### Interrupt inputs (active low, driven directly — matches MAME `interrupt_mixer(false)`)
| pin | net | meaning |
|---|---|---|
| IPL2 (23) | `PR1` (pull-up) | unused → always inactive |
| IPL1 (24) | `/P2TALK` | sound/JSA → main interrupt (VERIFY name "P2TALK") |
| IPL0 (25) | `/IRQ` | scanline interrupt (from sheet-2 comparator) |

⇒ IPL0 alone → level 1; IPL1 alone → level 2. Matches the boot-trace vectors
(vec25/L1 = scanline @0xde8, vec26/L2 = sound @0x489e).

---

## 2. Reset & watchdog

- **Power-on reset**: R60 100K + Q1 2N5306 + C31 .1 + R63 240, `RESET.` node → `14K LS14`
  (Schmitt inverter) → reset chain. CR1 = MV5053 (LED indicator).
- **Watchdog**: `8L LS90` decade counter clocked by **`/VSYNC`**, kicked/reset by **`/WDOG`**
  (write strobe, R106 1K pull-up via `13M LS00`). `WDDIS / JUMP2` = grounding jumper to disable.
  Overflow → `RESET` → Q2 2N3904 → `/RESET` to CPU.
  - MAME: `WATCHDOG_TIMER ... set_vblank_count(8)`. LS90÷N + /VSYNC ⇒ ~8 vsync timeout. (VERIFY count)

---

## 3. Bus buffers

- **Address** `A→BA` (buffered addr): `11M LS244A` (A16..A9) + `10M LS244A` (A8..A1).
  Outputs `BA16..BA1`, always enabled (/1G,/2G grounded). (A1 is lowest — word machine.)
- **Data** `D↔BD` transceivers: `17L LS245A` (D15..D8) + `17K LS245B` (D7..D0).
  - DIR = `BR//W`, `/OE = RORAM`. So the CPU data bus is buffered onto `BD` for ROM/RAM accesses,
    direction = buffered R/W. (VERIFY `RORAM` polarity / what it gates exactly.)
- **Byte write strobes** (`16K LS32`, OR gates):
  - `/WH = /UDS  OR  BR//W`  (high-byte write enable)
  - `/WL = /LDS  OR  BR//W`  (low-byte write enable)
  - i.e. asserted only when the strobe is low AND it's a write.

---

## 4. DTACK / VPA generation (wait-state logic) — ✅ wiring CONFIRMED (user image)

- **`/VPA`**: `/AS` → `14K LS14` → `AS`; `AS` + FC bits → `12K LS20` (4-in NAND) → `/VPA`.
  ⇒ `/VPA` asserts on **interrupt-acknowledge / CPU space (FC=7)** → 68k **autovectoring**.
  (Matches MAME using autovectored IRQs.) (VERIFY which FC/AS terms feed the LS20.)
- **`VACK`** = `15M LS74`: D(12)=`/VPA`, CK(11)=`4H`, `/CLR`(13)=`13M` node, PR(10)=`PR1`, Q(9)=`VACK`.
- **`/DTACK`** = `9M LS163A` sync counter (exact pins from the image):
  - **CK (2) = `1H`**  ·  `/LD (9) = /EEPROM` (preload count for slow EEPROM)
  - `ENT (10) = /VPA`,  `ENP (7) = /DTACK`  (count-enables)
  - `/CLR (1)` = `8M LS02` = **NOR(`/AS`, `13M LS00`)**, with `13M LS00 = NAND(/PFRAM,/ANMORAM)`
    (clears the counter between cycles via `/AS` and the video-RAM selects)
  - `RCO (15)` → `8M LS02` → **`/DTACK`**.
  ⇒ programmable wait-state generator: ROM/work-RAM fast; **video-RAM (`/PFRAM`,`/ANMORAM`) + `/EEPROM`
    get counted waits** (EEPROM via the `/LD` preload). (VERIFY the A–D preload value / terminal count.)
  - FPGA note: our BRAM is zero-latency; jtframe m68k DTACK handling covers this. The exact wait
    counts matter only for cycle-exact audio/raster timing, NOT for boot.
- **`1H`** clocks this counter (CK pin 2) AND the 68010 CLK (pin 15, sheet 1) — same net.

---

## 5. Scanline interrupt generator (sheet 2, bottom) — the `/IRQ` (IPL0) source

This is the hardware behind MAME `interrupt_scan_w` (0x828340) + `scanline_int_ack_w` (0x8283c0).

```
 CPU writes scanline# (BD0..BD5)         vertical counter bits
        |                                 2V 4V 8V 16V 32V 64V 128V 256V (+1V via 25E LS86)
        v  /INTLINE (write strobe, CK)            |
   [20K LS174A]  hex D-latch  ---- INTL? ----> [21K LS85] low  +  [22L LS85] high
        (captures BD0..BD5)                     cascaded magnitude compare
                                                        |  A=B (match)
                                                        v
                                              [15M LS74]  D-FF  (CK=512H via 13M LS500, PR=PR1)
                                                        |  /Q = /IRQ  --> CPU IPL0
                                              CLR <- /IRQACK   (acknowledge clears it)
```

- ✅ **RESOLVED (user) — 9-bit scanline reg, split across two chips:** low 6 bits (BD5:0) in the
  `20K LS174A`; high 3 bits in a SPARE 4-bit latch inside the **`7B SOS-1`** custom (the playfield
  gfx shifter): `/INTLINE→LDCLK`, `BD6→Q1=INTL6`, `BD7→Q2=INTL7`, `BD8→Q3=INTL8`. So the register =
  `BD8:0` latched on `/INTLINE` = MAME `interrupt_scan & 0x1ff`. HDL `intline_reg<=cpu_dout[8:0]` ✓.
  (SOS-1 main role: playfield `PFRD0-15`→`PFPIX0-3` 4bpp serializer @16MHz w/ H-flip — needed for video.)
- ✅ **RESOLVED (user) — it's a 9-bit EQUALITY comparator.** `21K LS85` (less-sig, `2V–16V`)
  cascades into `22L LS85` (more-sig, `32V–256V`): its `A<B`(7)/`A=B`(6)/`A>B`(5) outputs → the top
  chip's `A<B`(2)/`A=B`(3)/`A>B`(4) cascade inputs. **Only the top `A=B` output is used** → fed to the
  `15M LS74`. (`25E LS86` folds the `1V` LSB into the bottom chip's cascade.) So `/IRQ` asserts when
  the programmed line == the V counter. HDL: `scanline_irq` set when `vdump==intline_reg`, cleared by
  `/IRQACK`; `IPLn[0]=~scanline_irq`.
- `/IRQACK` (clears the FF) = the decode of a write to `0x8283c0` (`scanline_int_ack_w`). (VERIFY)
- `/INTLINE` (latch clock) = the decode of a write to `0x828340` (`interrupt_scan_w`). (VERIFY)

---

## 6. Signals that ARRIVE from other (not-yet-seen) sheets

`/PFRAM` (playfield RAM CS), `/ANMORAM` (alpha+MO RAM CS), `/EEPROM`, `/WDOG`, `/INTLINE`,
`/IRQACK`, `RORAM`, `BR//W`, `/RESET`, `/P2TALK`, `/VSYNC`, and the video counters
`1H 4H 512H` + `1V 2V…256V` / `INTL6-8`. ⇒ **next sheet to request: the address decoder + program ROM.**

---

## 7. Compare to MAME (what's confirmed vs new)

| item | schematic | MAME (`toobin.cpp`) | verdict |
|---|---|---|---|
| CPU | 68010, CLK=1H=8 MHz | M68010 @ 32/4 = 8 MHz | ✅ match |
| IPL0 | `/IRQ` scanline | scanline → IPL0 | ✅ match |
| IPL1 | `/P2TALK` | JSA sound → IPL1 | ✅ match (name VERIFY) |
| autovector | `/VPA` on FC=7 | autovectored IRQs | ✅ match |
| scanline IRQ reg | LS174A latch + LS85 compare | `interrupt_scan_w` 0x828340 | ✅ match (9-bit width VERIFY) |
| IRQ ack | `/IRQACK` clears FF | `scanline_int_ack_w` 0x8283c0 | ✅ match |
| watchdog | LS90 / `/VSYNC` | `set_vblank_count(8)` | ✅ match (count VERIFY) |
| DTACK waits | LS163A counter on video-RAM/EEPROM | not modelled (0-wait) | ⚠️ HW-only; ignore for boot |
| byte writes | `/WH`,`/WL` = strobe·R/W | UDS/LDS | ✅ match |

**New vs MAME:** CPU is video-clocked off `1H` (so the CPU/video share one time base — important
for getting the scanline-IRQ phase right), and the explicit wait-state generator for video-RAM/EEPROM.

---

## 8. Eye-check checklist (please confirm on the PDF before HDL)
1. ✅ DONE (user) — IPL1 = `/P2TALK` (sound/JSA → main interrupt, level 2). Confirmed.
2. ◑ PARTIAL (user) — `1H` is the real net clocking the `9M LS163A` DTACK counter (CK pin 2) AND
   the 68010 CLK (sheet 1). `1H = MCKR/2 = MASTER/4 = 8 MHz` (MCKR=16 MHz dot clock) — matches MAME.
   Still nice-to-confirm: dot clock MCKR=16 MHz and CPU pin15←1H explicitly.
3. Scanline-IRQ value bit width: where are INTL6/7/8 latched? (is there a 2nd latch?)
4. The two LS85 A↔B bit/pin assignments (programmed-bit ↔ nV).
5. `/INTLINE`=write 0x828340, `/IRQACK`=write 0x8283c0 (confirm on the decoder sheet).
6. `RORAM` polarity + exactly which accesses enable the `17L/17K` data transceivers.
7. DTACK wait-state count from the `9M LS163A` (preload value) — for later cycle accuracy.

## 9. PALs
- **None on these two sheets** (all 74-series TTL). The address-decode PAL (if any) is on the sheet
  that generates `/PFRAM /ANMORAM /EEPROM /WDOG /INTLINE /IRQACK RORAM` — request that next so you
  can pull its `.jed` and we open it with `jedutil`.
