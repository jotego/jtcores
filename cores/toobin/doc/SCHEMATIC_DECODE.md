# Toobin' schematics — address decode + ROM/RAM/EEPROM sheets (parse #2)

Source: `doc/Toobin.pdf`, the two "ROM / decode" sheets. First read; `(VERIFY)` = eye-check before HDL.
All 74-series TTL + the ROM/RAM/EEPROM chips + **one SLAPSTIC**. Bus naming: `BAn` = buffered address
(from the CPU sheet LS244s), `RDn` = ROM/RAM data bus, `Dn` = CPU data bus.

> ✅ **RESOLVED: the SLAPSTIC (`SLAPSTK4`, 6/7K) is NOT STUFFED on Toobin'** (footprint circled
> "no stuffed", user eye-check). The board uses the shared System-1/2 layout that has the socket,
> but Toobin' leaves it empty ⇒ **no ROM banking, flat linear program ROM = exactly MAME.**
> **We do NOT implement a slapstic.** See §5.

---

## 1. Program ROM — 8× 27512 (512 KB, 0x000000–0x07ffff)

- **F column** `1F 2F 4F 5F` → data `RD0–RD7` (**low byte**).
- **J column** `1J 2J 4J 5J` → data `RD8–RD15` (**high byte**).
  ⇒ matches MAME `ROM_LOAD16_BYTE`: `*f`=odd/low, `*j`=even/high. ✅ (and my assembled image)
- Address `BA1–BA16` to all (A0–A15 of each 27512).
- **`/ROM0–/ROM3` select** = `12M LS139` from **`A17,A18`**, enable `Ḡ` = **`BA23`**:
  `/ROM0`=00, `/ROM1`=01, `/ROM2`=10, `/ROM3`=11 → four 128 KB blocks.
  - /ROM0 → 1F/1J @0x00000, /ROM1 → 2F/2J @0x20000, /ROM2 → 4F/4J @0x40000, /ROM3 → 5F/5J @0x60000.
  - ✅ **CONFIRMED (user, eye-check):** LS139 enable pin = `BA23` ⇒ ROM decodes only when BA23=0.
    Enable is **BA23 alone** (A22 and A19–A21 NOT in the term) ⇒ those are **don't-cares**, so the
    program ROM **mirrors** every 0x80000 across the A19–A22 range (partial decode, PCB-faithful) —
    unlike MAME's flat `0x000000–0x07ffff`. HDL decode: `rom_cs = ~BA23` then A17/A18 pick the bank;
    do NOT add an `addr <= 0x7ffff` upper bound.

## 2. Work RAM — 2× 6264 (`626WD15`) (16 KB, 0x82c000–0x82ffff)

- `7F` → `RD0–RD7` (low), `7J` → `RD8–RD15` (high). Address `BA1–BA13` (8K words).
- `CS = /RAM`, `CS2 = PR7` (pull-up), writes `/WL`/`/WH`, read `/OE`. ✅ matches MAME 16 KB work RAM.

## 3. EEPROM — `2804A-30` (`/EEPROM`)

- **Byte-wide, low byte only** (`RD0–RD7`), write `/WL`, CE `/EEPROM`, read `/OE`.
- ✅ **CONFIRMED (user, eye-check):** chip marked **"8K" = 8 Kbit = 1 KB**, addressed by **`BA1–BA10`**
  (10 lines, NOT 11 — my earlier 2 KB read was wrong). Matches MAME window `0x82a000–0x82a3ff` = 0x400
  = 1 KB of CPU address space (≈512 device bytes since it's a byte device on the 16-bit bus, low byte).
- `mem.yaml` `nvram` = `addr_width 10` (1 KB), `addr main_addr[10:1]`, `data_width 8` — already correct.

## 4. Data path — ✅ CONFIRMED (user, eye-check)

- `RD ↔ D` transceivers `9L LS245C` (hi byte) / `9K LS245C` (lo byte): DIR (pin 1) = `BR//W`,
  `/OE` (pin 19) = **`RDRAM`**.
- **`RDRAM` = `F32_out · /EEPROM · /RAM`** (active-low enable), built as:
  - `25K F32` (OR): `F32_out = /AS | BA23` → low only on an active cycle with **BA23=0** (the ROM,
    `0x0xxxxx`; note EEPROM/RAM/I-O all live at BA23=1).
  - `26F LS10` (3-in NAND): `NAND(F32_out, /EEPROM, /RAM)` (pins 1,2,13 → 12).
  - `14K LS14` (inverter) → `RDRAM`.
  - ⇒ `/OE` asserts for **ROM cycle (BA23=0) OR EEPROM OR RAM**; stays off for video-RAM (0xC0xxxx)
    and the 0x82xxxx I/O registers (verified all cases).
- ⇒ **the `RD` bus carries only ROM + work-RAM + EEPROM data.** Then the CPU sheet's `17L/17K`
  buffer `D ↔ BD` for the video/IO side.
- **HDL meaning:** the CPU read-data mux sources `rom_data`/`ram_data`/`eeprom_data` for those three
  regions; video/IO read data comes via the separate `BD` path. No extra logic — just the read mux
  priority. (`BR//W` = buffered R/W sets direction, automatic in the mux.)

## 5. ✅ SLAPSTIC — `SLAPSTK4` (loc 6/7K) — NOT STUFFED, out of scope

- The footprint exists (shared System-1/2 layout) and is wired: inputs `BA1–BA14`, `CK=/AS`, outputs
  `BS0/BS1` → `6M LS157` mux (vs `A13/A14`) → program-ROM high bits in the `/ROM3` (5F/5J) region;
  `26K F139` sub-decodes `BA15/BA16`.
- **But the chip is not installed on Toobin'** (footprint circled "no stuffed"). With it absent the
  `6M LS157` passes the direct `A13/A14` ⇒ **flat linear ROM, no banking** = MAME's model.
- ✅ **We do NOT implement a slapstic** and need no unlock sequence. `atarisys1_ref/SLAPSTIC.vhd` is
  kept only as dead reference. (Tiny follow-up: confirm the LS157 SEL default passes A13/A14 — but
  the game running in MAME with a flat ROM already proves the net mapping is linear.)

---

## 6. The full register / region decode (this is the memory map)

**Video RAM region** — `12K LS20` enables `12M LS139` when `BA23 · A22 · AS` (= 0xC0xxxx):
| select | addr | region | MAME |
|---|---|---|---|
| `/PFRAM` | 0xc00000 | playfield RAM | ✅ |
| `/ANMORAM` | 0xc08000 | alpha + motion-object RAM | ✅ |
| `/CRAM` | 0xc10000 | color/palette RAM | ✅ |
| (Y3) | 0xc18000 | unused | — |
(decoded from `A16, BA15`.)

**Write strobes** — `7M LS138`, enable `/WL`, select `BA8/BA9/BA10`; plus `10K LS139` (select `BA6/BA7`):
| select | addr | MAME write | 
|---|---|---|
| `/WDOG` | 0x828000 | watchdog reset | ✅ |
| `/AUDIOWR` | 0x828101 | `main_command_w` (JSA) | ✅ |
| `/ZLATCH` | 0x828300 | `intensity_w` ("Z"=intensity/brightness) | ✅ (VERIFY name) |
| `/INTLINE` | 0x828340 | `interrupt_scan_w` (scanline-IRQ latch — the CPU-sheet LS174A clock) | ✅ |
| `/SLINKPTR` | 0x828380 | `slip_w` (sprite link pointer) | ✅ |
| `/IRQACK` | 0x8283c0 | `scanline_int_ack_w` | ✅ |
| `/SRESET` | 0x828400 | `sound_reset_w` | ✅ |
| `/UNLOCK` | 0x828500 | eeprom `unlock_write` | ✅ |
| `/HSCROLL` | 0x828600 | `xscroll_w` | ✅ |
| `/VSCROLL` | 0x828700 | `yscroll_w` | ✅ |

**Reads / region selects** — `7L LS138` (enable `BA23·/AS·~A17`, select `BA13/BA14/BA15`) + `10K LS139`
(select `BA11/BA12`):
| select | addr | MAME read |
|---|---|---|
| `/CONTROLS` | 0x828800 | `portr("FF8800")` paddles | ✅ |
| `/INPUTS` | 0x829000 | `portr("FF9000")` service/vbl/snd | ✅ |
| `/AUDIORD` | 0x829801 | `main_response_r` (JSA) | ✅ |
| `/EEPROM` | 0x82a000 | eeprom r/w | ✅ |
| `/LETA` | **0x826000?** | MAME: `0x826000 .nopr()` "who knows? read at controls time" | ⚠️ see below |

### Two MAME mysteries this sheet SOLVES
- **`/LETA`** → almost certainly the `0x826000` that MAME stubs as `nopr()` "who knows?". It's a
  **LETA analog/quadrature controller** read — the paddle path. (VERIFY `/LETA`=0x826000, and whether
  toobin populates a LETA chip or just reads quadrature phases at `/CONTROLS` 0x828800.)
- **`/ZLATCH`** → the `0x828300` intensity/brightness register ("Z" latch).

---

## 7. Cross-check summary vs MAME
The entire `0x828xxx` register map and the `0xC0xxxx` video-RAM map **match MAME exactly** — strong
confidence the decode is right. Net-new vs MAME: (a) the **SLAPSTIC**, (b) **`/LETA`@0x826000** is a
real select (MAME nop), (c) names for intensity=`/ZLATCH`, slip=`/SLINKPTR`.

---

## 8. LONG verification list (for later — eye-check on the PDF / BOM / boot-trace)

### Slapstic
1. ✅ DONE — `SLAPSTK4` is **NOT STUFFED** ("no stuffed", user eye-check) → no slapstic, no banking,
   flat ROM = MAME. Out of scope. Items 2–4 (mux bits / unlock seq / add-if-diverges) all moot.

### Program ROM / decode
5. ✅ DONE — `/ROM0–3` from `A17,A18`, LS139 enable `Ḡ`=`BA23` (active-low, ROM at BA23=0). A22 &
   A19–A21 are don't-cares → ROM mirrors (partial decode). HDL: `rom_cs=~BA23`, no upper-bound compare.
6. ✅ DONE (user, confirmed) — F = low byte (`RD0-7`), J = high byte (`RD8-15`); matches MAME
   `*f`=odd/low / `*j`=even/high and the assembled image. **maincpu blob byte order `width=16
   reverse=true` ({J=high,F=low}) confirmed correct** — no longer a boot-time unknown.
7. `26K F139` role in the slapstic region (`SP1` sub-decode of BA15/BA16).

### Work RAM / EEPROM
8. `626WD15` = 6264 8Kx8 ×2 = 16 KB; `CS=/RAM`, addr `BA1–BA13`. Confirm `CS2=PR7` pull-up.
9. ✅ DONE — EEPROM `2804A-30`, "8K"=8Kbit=**1 KB**, addr `BA1–BA10`, strictly low-byte (`/WL`,`RD0-7`).
   `mem.yaml nvram` aw10 already matches.
10. ✅ DONE (user) — `RDRAM` (/OE of 9L/9K LS245C) = `F32_out · /EEPROM · /RAM`, where
    `F32_out=/AS|BA23` (25K F32 → 26F LS10 3-in NAND → 14K LS14). DIR=`BR//W`. RD bus = ROM+RAM+EEPROM.

### Register decode (confirm each select's exact address bits)
11. `7M LS138`: enable `/WL`, select `BA8/9/10` → /WDOG /AUDIOWR /ZLATCH /INTLINE /SLINKPTR /IRQACK
    /SRESET /UNLOCK /HSCROLL /VSCROLL. Confirm each output pin→address.
12. `10K LS139` (×2): which selects /AUDIORD /INPUTS /CONTROLS (BA11/BA12) and
    /IRQACK /SLINKPTR /INTLINE /ZLATCH (BA6/BA7).
13. `7L LS138`: enable terms (`BA23`,`/AS`,`~A17` via 14K LS14) + select `BA13/14/15` →
    /EEPROM /LETA + sub-decode enables.
14. `/ZLATCH` = 0x828300 intensity? `/SLINKPTR` = 0x828380 slip? confirm.

### LETA / inputs
15. `/LETA` = 0x826000 (= MAME's nopr)? Does a LETA chip exist on the board, and how are the
    paddle quadrature phases wired to `/CONTROLS` (FF8800)? (ref: `atarisys1_ref/leta_rep.vhd`,`quad.vhd`)

### Video-RAM region
16. `12K LS20` enable = `BA23·A22·AS` → 0xC00000; `12M LS139` split on `A16,BA15` →
    /PFRAM 0xc00000, /ANMORAM 0xc08000, /CRAM 0xc10000. Confirm A17/A18/A19-A21 don't-cares.
17. `/ANMORAM` is shared alpha+MO — confirm the alpha vs MO split is a lower-bit decode (A15? the
    `0xc08000` alpha / `0xc09800` mob boundary) done elsewhere (video sheet).

### DTACK / wait-states (from CPU sheet, cross-ref)
18. `/PFRAM`,`/ANMORAM`,`/EEPROM` drive the `9M LS163A` DTACK wait-state counter — get the preload
    (wait count) for cycle-exact timing later.

### PALs
19. **No PAL visible on these decode sheets** — the map is done in LS139/LS138/LS20 TTL. (Good: no
    `.jed` needed for the memory map.) The slapstic is the only "custom". Re-scan the BOM for any
    `PAL`/`GAL`/`137xxx` on the video & audio sheets when we get there.
