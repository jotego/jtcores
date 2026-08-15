# X1-001A schematic notes — Superman (Taito X System)

Source: `Superman [schematics].pdf` (10 sheets, drawing **W5100307A**, "MAIN PC BOARD Ass'y SCHEMATIC DIAGRAM", Taito Corporation, dated **63.11.24** = 1988-11-24). NAPS2 scan of hand-drawn originals at 1199×783pt per sheet.

Important to call out up front: **what the schematic calls the sprite chip is `X1-001` (not `X1-001A`), and it is one of FOUR Taito-custom gate arrays on this board.** They appear together on sheets 3 and 4:

| Chip | Sheet | Numbering on sheet | Function (apparent from connections) |
|---|---|---|---|
| **X1-001** | 3/10 | block **40** | Sprite controller. Owns video timing, OBJ-RAM address bus, drives VBLNK / HBLNK / VSYNC / HSYNC. |
| **X1-002** | 3/10 | block **39** | Sprite renderer. Receives CA / CGA / CGD buses, drives `OB[15:0]` back into X1-001 area. Shares the 16 MHz crystal with X1-001. |
| **X1-003** | 4/10 | block **58** | RGB DAC. Drives three external RO-012 ladder DACs (one per color channel) and SYNC composite. |
| **X1-006** | 4/10 | block **55** | CPU↔palette interface gate array. Bridges the 68K bus to the palette RAM and re-emits VST/HST sync to the X1-003. |

MAME's `x1_001_device` collapses all four of these into one model. When this document says "X1-001" it means the **physical X1-001 die** on sheet 3 unless otherwise noted.

---

## 1. X1-001A pinout and CPU interface

**What the schematic shows**

- **CPU**: HD68000P-8 (chip block **7**, sheet 1/10). Full 16-bit data bus `D15:D0` (pins 54–58/59–62), full address bus `A23:A1` (pin 22 = A23 down to pin 29 = A1). `LDS`, `UDS`, `AS`, `R/W`, `DTACK`, `BR/BG/BGACK`, `VPA`, `BERR`, `IPL2:0` all routed.
- The X1-001 die itself is **NOT** directly on the 68K data bus. Look at sheet 3, chip block 40:
  - 68K data bus `D15:0` enters through a pair of **HC245** transceivers (chip blocks **21, 22**), which connect to the **OBJ-RAM** (the 2× 4364 SRAMs at blocks 23, 24), NOT to the X1-001 pins.
  - 68K address bus `A12:1` enters through **HC367** buffers (chip blocks **25, 26**), again routed to the OBJ-RAM address pins, not the X1-001.
  - X1-001 sees the OBJ-RAM bus on its own `OA[12:0]` / `OB[15:0]` pins on the OPPOSITE side of the 4364s. So X1-001 is a bus master on the OBJ-RAM, not on the 68K bus.
- The CPU's actual handle on the X1-001 video subsystem is via the `VDCM CS` strobe (sheet 2, F138 chip 17, output Y5) — this is **NOT shown wired into the X1-001 (block 40)**; instead it goes to the X1-002 (block 39, pin 2 = `VDCMCS`). So **the spritectrl/spriteylow registers actually live behind the X1-002, not X1-001**. (See §3.)
- CPU access to the palette is via the X1-006 (sheet 4, block 55). X1-006 receives **`A9..A1`** (pins 35–43) and `D15:0` (pins 49–62 / 50–61) directly from the 68K buses, plus `EDS`/`LDS`/`R/W`/`RD`/`CLRAM CS` on its control side (pins 34, 33, 41, 44, 45). So palette CPU-side is 16-bit-wide, 10 bits of word address (i.e. 1 KW = 2 KB visible, consistent with MAME's 0x800 palette region).

**Address-line wiring of the sprite-chip group**

Two F138 3-to-8 decoders on sheet 2 (chip blocks **17** and **18**) do the upper-address decode. Both take `A22, A21, A20` to their C/B/A select pins. Block 17 outputs (verbatim labels from the schematic):

| Output | Label |
|---|---|
| Y7 | `WRAM CS` |
| Y6 | `ORAM CS` |
| Y5 | `VDCM CS` |
| Y4 | `VDCS CS` |
| Y3 | `CLRAM CS` |
| Y2 | `TC0030CMD CS` |
| Y1 | `SOUND CS` |
| Y0 | `ROMCS` |

Enable inputs to F138 #17 are `FC`, `AS`, `A23` (the schematic labels them next to pins 4, 5, 6 of the package). The polarity stamps which 8 MB half this decoder serves; the labels above are consistent with the MAME map ($E00000 = ORAM, $D00000 = VDCM, $F00000 = WRAM) only if A23=H gates the 138 in.

**Data-bus width**: the X1-001 / X1-002 / X1-003 / X1-006 chips together expose a **16-bit** CPU-side bus. The HC245 OBJ-RAM transceivers (sheet 3, blocks 21+22) are wired as one byte each on D15:8 and D7:0; the X1-006 (sheet 4, block 55) explicitly takes D15..D0.

**MAME source pointers**: search `x1_001_device::spritectrl_w`, `spriteylow_w`, `spriteram` in `mame/src/mame/video/seta.cpp` and the address map in `mame/src/mame/drivers/taito_x.cpp`.

---

## 2. OBJ-RAM organization

**What the schematic shows (sheet 3/10)**

- OBJ-RAM is **2× 4364 (150 ns) SRAMs**, chip blocks **23** and **24**. A 4364 is 8K×8, so the pair gives **8K × 16 = 16 KB** addressable as 8K words. That matches MAME's `$E00000-$E03FFF` (0x4000 byte addresses = 0x2000 word addresses = 8192 words).
- The 68K side reaches OBJ-RAM through HC367 address buffers (blocks 25, 26) carrying `A12..A1` and HC245 data transceivers (blocks 21, 22). The `OE`/`DIR` of the HC245 is driven by `OBJ`, an internal strobe assembled from `ORAM CS`, `CKW`, `LWR` (HC4075 chip blocks 27, 28 on sheet 3). So the CPU side gets bus access only when the X1-001 is NOT itself using OBJ-RAM (the `OBJ` arbitration signal).
- The X1-001 side: pins `OA[12:0]` and `OB[15:0]` of block 40 connect directly to the other side of the SRAMs. That's a flat 13-bit address — i.e. the X1-001 can address the **entire 16 KB** of OBJ-RAM linearly. There is **no bank-select pin externally wired to OBJ-RAM address line A13**, because there is no A13 — 8K is fully covered by A12:0.
- There is **no extra flip-flop, no 74LS74 page-flip, no shadow buffer SRAM** in the OBJ-RAM region. The schematic only shows the two 4364s plus the buffers/transceivers above. So whatever "bank" MAME models is purely an internal X1-001 state element selecting which half of the 8 KW the renderer fetches from, not a hardware mux on the SRAM address lines.

**Implication for MAME's `bank = 0x1000` swap**

MAME maps $E00000 and $E02000 as two views of the same 0x1000 words because the **CPU sees both halves flat** (one linear 8 KW region behind A12). The "bank" is a **rendering-time** selection inside X1-001: when its internal logic asserts `OA12=0` it reads the low half as sprites; when it asserts `OA12=1` it reads the upper half. The schematic supports this — the X1-001 owns `OA12` outright — but it does **not** show the logic gate inside the chip that picks the value. That gate is in the X1-001 die.

**MAME source pointers**: `x1_001_device::draw_sprites_map`, `bank_size`, the `spritectrl[1] & 0x40` test.

---

## 3. Sprite-Y / scroll RAM organization

**What the schematic shows**

This is where the X1-002 (sheet 3, block 39) lives — and it is the chip that the CPU reaches via `VDCM CS`. Look at sheet 3 block 39:

- The `VDCM CS` net (sheet 2 F138 #17 Y5) lands on **block 39 pin 2** (labeled `VDCMCS` on the schematic).
- The X1-002 also receives `RST`, `DE`, `RD`, `VBLNK`, `HBLNK`, `VSYNC`, `HSYNC`, `CKW` from the X1-001 on pins 29–38 (so the X1-002 is a "consumer" of X1-001 video timing, not a master).
- The X1-002 fans `CA[8:1]` and `CGA/CGD` buses out — these go to the tile/character ROM stage on sheet 5/10 (the four 234000 mask ROMs at blocks 43, 45, 37, 38).
- **There is no external SRAM in the `VDCM CS` region.** The schematic shows the chip select going into the X1-002 package and that's it. So the `spriteylow` 0x600 bytes ($D00000-$D005FF in MAME) and the four `spritectrl` words ($D00600-$D00607) **are registers/RAM inside the X1-002 die**, not external memory. There is no separate SRAM chip mapped there.

**Bottom line**:
- `spritectrl[0..3]` are **internal D-latches inside the X1-002** addressed by the low CPU address bits when `VDCM CS` is asserted.
- `spriteylow` (Y coordinates / per-column scroll bytes) is also **internal storage** inside the X1-002. The schematic gives no hint whether it's a small RAM array or a register file; either way it does not appear as an external SRAM.

**MAME source pointers**: `x1_001_device::spriteylow_w`, `spritectrl_w`, the device's `spriteram_buffer`/`spritectrl` internal arrays.

---

## 4. spritectrl[1] decoding (BG column count + bank-select)

**Cannot be answered from the schematic.**

The bank-select XOR logic MAME implements (`((ctrl2 ^ (~ctrl2 << 1)) & 0x40)` ⇒ "swap when bits 5 and 6 are equal") is **internal to the X1-002**. The schematic only shows the chip-select / address / data lines going into the X1-002 package; it does not break the X1-002 die open. There is no discrete logic gate on the PCB driving an external "bank" signal off bits 5 and 6 of any register — those bits never leave the X1-002.

Same for the "bits[3:0] = numcol" interpretation: there is no external column-count signal you can probe; the value affects only the X1-002's internal fetch sequencing.

To verify either of these, you need either:
- The Seta X1-002 die-shot / patent (Seta JP patent JPH02-XXXX, MAME comments point to it), or
- Direct hardware testing — write known `spritectrl[1]` values on real hardware and capture the resulting OBJ-RAM access pattern (logic analyser on the `OA[12:0]` pins).

**MAME source pointers**: search `numcol`, `bank_size`, `0x40`, `ctrl2` in `x1_001_device::draw_sprites`.

---

## 5. Vertical timing

**What the schematic shows**

- **Master oscillator**: a 16 MHz TTL oscillator can on sheet 3/10, block **39's neighbour** (labeled `16M TTL`, R2 = 22 Ω damping resistor, footprint block 33). Its output drives the X1-001 (block 40) `X1`/`X2` (XTAL) pins and the X1-002 (block 39) shares the same crystal feed.
- **CPU clock**: sheet 1/10, lower middle. The CPU clock `CPUCLK` is taken via R7 = 47 Ω from a JP-Box / F244 buffer (block 10) clocking-chain that picks between `CK`, `CK`, `CK3` — three taps. JP-Box on sheet 1 shows pins 1/16, 2/15, 3/14, 4/13 with one `CK` / `CK` / `CK3` per row, i.e. the user can strap which divided clock drives the 68K.
- The actual divider that produces pixel clock, HSYNC, VSYNC is **inside the X1-001 die**. The schematic shows the timing OUTPUTS (`HSYNC`, `VSYNC`, `HBLNK`, `VBLNK`, `CKW`) leaving block 40 toward the X1-002/X1-006/JAMMA edge, but it does **not** show the divider chain or any external counter that would expose the H/V totals.
- Composite-sync stitching: sheet 4, the X1-003 (block 58) receives `VSYNC` → `VST` (pin 20) and `HSYNC` → `HST` (pin 19) from the X1-006 (block 55), and emits `SYNC`/`SYNC` on pins 22/23 through R16 = 47 Ω to the JAMMA `SYNC` line. Vertical and horizontal counters are not on the PCB.
- LS161 (block 48, sheet 4) is a 4-bit counter clocked off `HSYNC` via an HC32 (block 49) — this generates the `H3` divided signal used to drive part of the sprite pipeline. It is not the master V counter; it's a small post-divider for the X1-006 pipeline.

**Conclusion on 60 Hz vs 57.46 Hz**

The schematic gives you **16 MHz master** as the only hard number. Total H/V counts and the exact frame rate are NOT visible — they're set by the divider inside the X1-001 die. The 16 MHz / 6 MHz pxl_cen ratio is consistent (16/6 ≈ 2.67, or 8 MHz with 2-pixel cells, etc.), but you cannot pin down 57.46 Hz vs 60.00 Hz from the schematic alone. You need either:
- A scope on the `VSYNC` output of X1-001 (block 40, pin labelled `VSYNC`) on real hardware, or
- MAME's `x1_001_device` timing constants cross-checked against the X1-001 die behaviour.

**MAME source pointers**: search `XTAL(16'000'000)`, `screen_raw_params`, `MCFG_SCREEN_RAW_PARAMS` in the taito_x driver, and `x1_001_device::screen_update`.

---

## 6. VBLANK / interrupt path

**What the schematic shows (sheet 1/10)**

The 68K's IPL pins (block 7, pins 23 = `IPL2`, 24 = `IPL1`, 25 = `IPL0`) are tied through R7 = 330 Ω (pull-up) and driven by two **LS107 J-K flip-flops** in the upper-left of sheet 1:

- **Top LS107** (drawn first): `VBLNK` input feeds its J/K. Output drives the **`IPL1`** line. The CLEAR side is `IPL1 CLR CS` (sheet 2, F138 chip 18 output Y6) — i.e. the CPU acknowledges by writing to the address that asserts that strobe.
- **Bottom LS107**: `TC0030CMD INT` input feeds its J/K. Output drives the **`IPL2`** line. CLEAR is `IPL2 CLR CS` (F138 chip 18 output Y3).

So the topology is:
- **VBLNK is latched into IPL1.** Cleared when CPU writes the `IPL1 CLR CS` magic address. This is a held interrupt request, **NOT a level-pulse from the X1-001** — the LS107 latches the VBLNK edge and presents a static low to the 68K until acknowledge.
- **TC0030CMD-INT is latched into IPL2.** Same latch-and-clear pattern.

**Gigandes / Ballbros / Kyustrkr IRQ2**

Those boards do NOT have a TC0030CMD chip on them. On the Superman board the only thing wired to `IPL2` is `TC0030CMD INT`; on a Gigandes board the same `IPL1` VBLNK path likely produces what MAME calls "IRQ2" (since asserting `IPL1` only, with `IPL2=H` and `IPL0=H`, produces 68K IRQ level 2). The schematic available is **the Superman board**, so this is inference — you'd want to compare against the Gigandes schematic if one exists.

**Superman IRQ6**

If MAME says Superman's IRQ6 comes from the C-chip timer, that maps to **both `IPL2` AND `IPL1` being asserted simultaneously** (IPL2=L, IPL1=L, IPL0=H → 68K reads level 6). The schematic shows two independent latches; nothing wires the TC0030CMD interrupt into BOTH IPL1 and IPL2 simultaneously. So either:
- MAME is wrong about IRQ6 (the level is actually 4 if only IPL2 fires, or 6 only if VBLNK happens to coincide), **or**
- There is additional wiring I cannot resolve from the scan resolution — worth zooming in on the LS107 outputs near pins 23/24 of the 68K. Specifically look at whether the bottom LS107 Q output is wired to **both** IPL2 AND IPL1 via a diode-OR or jumper.

**The schematic does NOT show a separate hardware VBL→C-chip path.** The C-chip's "internal timer" claim in MAME would be entirely inside the TC0030CMD die.

**MAME source pointers**: `irq2_line_hold`, `irq6_line_hold`, `superman_state::interrupt`, `tc0030cmd_device`.

---

## 7. OBJ-RAM read timing

**What the schematic shows**

The X1-001 owns the OBJ-RAM bus through its `OA[12:0]` / `OB[15:0]` pins (sheet 3, block 40). CPU access to OBJ-RAM is arbitrated by the `OBJ` strobe:

```
OBJ ← LS11 #15 NOR( VDCM CS, VDCS CS, ORAM CS )      (sheet 3)
     and
OBJ-strobe ← HC4075 #28 from ( ORAM CS, CKW, LWR )    (sheet 3)
```

The HC245 OBJ-RAM transceivers (blocks 21, 22) are enabled by these strobes. So **the CPU only drives OBJ-RAM during its own bus cycles**, and the X1-001 drives OBJ-RAM the rest of the time, gated by `CKW` (the pixel-clock-related signal from X1-001 pin 30).

**What you CANNOT tell from the schematic**: whether the X1-001 fetches sprites **once per scanline** (per-line buffering, classic Seibu/Capcom style) or **once per frame** (DMA into internal latches). Both are implementable behind the same external pin set — the difference is internal sequencing of the `OA[12:0]` walk. The schematic shows `OA[12:0]` as outputs of the X1-001 going to the SRAM, with no external counter or DMA controller, so the walk is fully internal.

Best test on hardware: scope the `OA12` and `OA0` pins relative to `HSYNC` and `VBLNK` and see whether OBJ-RAM is being walked every line or only during VBLNK.

**Implication for mid-frame writes**: because the arbitration is per-bus-cycle (`OBJ` strobe gates the HC245 only when the CPU has the `ORAM CS` window), **the CPU can write OBJ-RAM mid-frame and is NOT locked out except for arbitration of the same SRAM cycle**. Whether that produces visible tearing depends on whether X1-001 reads each sprite slot once-per-line or once-per-frame, which the schematic does not tell you.

**MAME source pointers**: search `spriteram_buffer`, `spritebuffer`, the `buffer_sprites` callbacks in `seta.cpp`.

---

## 8. Sprite Y coordinate offset

**Cannot be answered from the schematic.**

The Y-offset MAME applies (`-0x12` for Superman, `-0x0a` for Gigandes) is a **per-game cosmetic adjustment to match raster alignment**. The schematic has no external Y-offset register, no jumper labeled Y-OFFSET, and no inverter on a Y-coordinate net. There is also no per-game strap pin documented on the X1-001 (block 40) — every pin I can identify is either a power/ground, a clock, a bus, or a chip-select.

Most likely explanation: the offset is **a wiring convention** — the X1-001's internal V counter and its sprite-Y comparator use a specific zero point relative to where VBLNK starts, and each game's developer wrote sprite Y data assuming a particular monitor frame alignment. MAME just bakes the constant in to recover the original look.

If there IS a strap I missed, it would be one of the otherwise-unannotated pins on the X1-001 package (block 40). Pins 1, 33 are XTAL (consumed by the 16 MHz can). Pins around 21–28 are mostly OB/OA buses. Worth a manual re-check of the Superman vs Gigandes PCBs side-by-side.

**MAME source pointers**: search `yoffs`, `set_gfx_yoffsets`, `m_yoffset` in `x1_001_device`.

---

## 9. Color palette format

**What the schematic shows (sheet 4/10)**

The DAC stage is the X1-003 (block 58) driving three **RO-012** ladder DACs (blocks labeled `B`, `G`, `R` — annotated as `RO-012 ×3` at top of sheet 4). Counting the lines per channel into each RO-012:

- **B (blue)**: pins 24, 25, 26, 27, 28, 29 of X1-003 — **6 lines** to RO-012 channel B → output `B` to JAMMA pin 13.
- **G (green)**: pins 30, 31, 32, 33, 34, 35 — **6 lines** to RO-012 channel G → output `G` to JAMMA pin N (label cut off in scan, but standard JAMMA green pin).
- **R (red)**: pins 36, 37, 38, 39, 40, 41 — **6 lines** to RO-012 channel R → output `R` to JAMMA pin 12.

The 6-lines-per-channel observation is **at odds with MAME's xRGB-555 (5 bits/channel) model** — at face value the hardware supports 18-bit color (262144 colors). But:
- Often one of the six lines is a `BLNK`/intensity strobe rather than a true color bit, leaving 5 active color bits.
- Or one of the six is grounded / unconnected on this PCB even though the X1-003 die supports it.

The scan is not sharp enough to read whether all six lines per channel are actually data, or one of them is fixed/strobe. The composite `SYNC` is produced separately on pins 22/23 of the X1-003 (through R16 = 47 Ω) — so sync is NOT eating one of the per-channel lines, the strobe interpretation must be intra-channel.

**Bit ordering at the DAC**: cannot determine which of the 5 (or 6) lines is MSB from the schematic alone; you'd need the RO-012 pinout. MAME's "R in high bits, B in low" is a CPU-side palette-entry interpretation, not a DAC-pin interpretation, so it doesn't directly conflict with the schematic.

**MAME source pointers**: search `xxxxRRRRGGGGBBBB` / `xRRRRRGGGGGBBBBB` palette callbacks in `seta.cpp`, `paletteram_xxxx...`.

---

## 10. Per-game wiring differences (Superman vs Gigandes)

**The schematic on hand is the Superman board only.** A Gigandes board may be different. Things visible on the Superman sheets that COULD plausibly differ on the Gigandes PCB:

- **TC0030CMD (C-chip) is Superman-specific.** Sheet 6/10 is essentially the C-chip subsystem (block 56). Gigandes / Ballbros / Kyustrkr boards do not have this chip; their `IPL2` line and `TC0030CMD CS` net would be missing or grounded. This is the single biggest per-game difference and is consistent with MAME's "Superman IRQ6 is from C-chip timer; others use IRQ2 from VBL".
- **Jumpers on the Superman board** (each could be strapped differently on a sister board):
  - **JP1** (sheet 1): SRAM size for the work RAM pair — `64K` vs `256K` (`4364` vs `43256`). Cosmetic / cost choice, no behavioural effect on X1-001.
  - **JP2, JP3, JP4** (sheet 2, 6): clock-selection / input-routing straps.
  - **JP5, JP6** (sheet 1): A17 vs A18 routing into the F139 ROM-bank decoder — i.e. ROM-size selection (1 Mbit vs 2 Mbit mask ROM).
  - **JP7** (sheet 2): clock taps for the H1/H2 path into the LS74 (block 8).
  - **JP8** (sheet 7): `W.D.T OFF` — watchdog disable jumper.
  - **JP9, JP10** (sheet 8): `ZROM A16` selection for the Z80 sound program ROM (1 Mbit vs 2 Mbit).
  - **JP11** (sheet 4): `CK3` tap selection on the X1-006 H3 input.
- **No JUMPER labeled Y-OFFSET, COL-COUNT, BANK, or anything that affects the X1-001/X1-002 directly.** The X1-001 (block 40) and X1-002 (block 39) pinout looks identical between what's drawn here and what you'd expect on Gigandes — none of the pins are strap-loaded with resistors, only the standard bus / clock / sync connections.

**Conclusion**: there is **no visible per-game pin strap on the X1-001 or X1-002**. The Superman ↔ Gigandes Y-offset difference (`-0x12` vs `-0x0a`), the `numcol` differences, and the bank-select formula are all **software / register-state differences**, not board-level wiring differences.

The one real board-level difference visible from this schematic alone is the **presence of the C-chip on Superman**, which only affects the IRQ path (§6), not the sprite chip's behaviour.

**MAME source pointers**: per-game `set_offsets`, `m_yoffs` in machine setup; `superman_state`, `gigandes_state` separation.

---

## Appendix: useful greps for cross-referencing this PCB in MAME source

```
mame/src/mame/drivers/taito_x.cpp
mame/src/mame/video/seta.cpp                  # X1-001 / X1-002 device
mame/src/mame/machine/taitocchip.cpp          # TC0030CMD (Superman)
mame/src/mame/audio/taito_en.cpp              # TC0140SYT + YM2610
```

Symbol names worth searching:
- `x1_001_device` — the sprite chip class
- `spritectrl_w`, `spriteylow_w`, `spriteram` — register/RAM access
- `numcol`, `bank_size`, `ctrl2`, `0x40` — the bank/column logic
- `m_yoffs`, `set_offsets`, `set_gfx_yoffsets` — Y offset registration
- `irq2_line_hold`, `irq6_line_hold` — interrupt entries
- `tc0030cmd_device` — Superman C-chip
- `XTAL(16'000'000)`, `screen_raw_params` — timing constants

Net names from this schematic worth searching (Taito service-manual context):
- `WRAM CS`, `ORAM CS`, `VDCM CS`, `VDCS CS`, `CLRAM CS` — F138 #17 outputs
- `IPL1 CLR CS`, `IPL2 CLR CS` — IRQ-ack strobes
- `VBLNK`, `VBLNKH`, `HBLNK`, `CKW` — X1-001 timing outputs
- `CA8..CA1`, `CGA17..CGA0`, `CGD15..CGD0` — the sprite ROM buses (X1-002 ↔ tile ROMs ↔ X1-001)
