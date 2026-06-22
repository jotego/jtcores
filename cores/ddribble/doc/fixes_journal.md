# Double Dribble — Fixes Journal

Running log of bug-finds and fixes made during V1 bring-up. One entry per
fix, **newest at the bottom** (chronological order, top → bottom). Each
entry should tell future-me three things:

1. **What was wrong** — observable symptom.
2. **How we found it** — the sim trace / schematic read / hunch that surfaced it.
3. **The fix** — exact file + line / signal change, and why it's right.

This file is the long-form companion to the "Major fixes that landed in
this session" list in `HARDWARE.md`. HARDWARE.md is a snapshot; this file
keeps the *story* (what we tried, what we ruled out, what we learned).

---

## 2026-06-02 — Main address decoder was dropping CPU writes to chip scroll registers

### Symptom

After the SOUND ROM POST fix landed in the morning, a 3000-frame attract
sim showed the boot reaching **real attract + gameplay** (per user
observation, one good frame of a basketball court was briefly visible).
But the visible image was wrong: messed-up tiles in FG and BG, scrambled
colors, occasional flashes of correct content.

### How we found it

User asked for a triple-check of the 007552 / 007553 PALs before debugging
visuals. We had two reference files:

- `cores/ddribble/doc/Konami_007552_equations.txt` (jedutil decode of main
  PAL JEDEC fuse dump)
- `cores/ddribble/doc/Konami_007553_equations.txt` (sub PAL)

…plus the pin-map document `Konami_007553_pinout.md`.

Method: cross-checked every CPU access in the instrumented 3000-frame log
against the address ranges asserted by each PAL output. Specifically grep'd
the log for CPU reads/writes in every PAL window:

```bash
grep '^\[.*MAIN RD A=0[0-7]' sim_3000.log | awk -F'A=' '{print substr($2,1,4)}' | sort -u
grep '^\[.*MAIN WR A=0[0-7]' sim_3000.log | …
grep '^\[.*MAIN .. A=0[8-f]' sim_3000.log | …
grep '^\[.*MAIN .. A=1[0-7]' sim_3000.log | …   # /DMP window
grep '^\[.*MAIN .. A=1[8-f]' sim_3000.log | …   # /CORAM window
```

This surfaced that the main CPU **was writing 64 byte addresses inside the
PAL chip-1 window (0x0020-0x005F) and another 64 inside the chip-2 window
(0x0820-0x085F)** — but our HDL chip-select was narrowed to `addr <= 0x0004`
and `addr in [0x0800-0x0804]`, so **none of those writes reached the
005885 chips**.

Confirmed independently: the chip-write tags in the same log showed
`k5885_1.*ZURE = 0` and `k5885_2.*ZURE = 0` — *zero* scroll-register writes
recorded inside the chip wrapper, despite all the activity on the CPU bus.

### Root cause

The original `main.v` decoder was built from MAME's address map
(`ddribble.cpp:383-396`), which lists only the 5 "obvious" MMR registers
at 0x0000-0x0004 / 0x0800-0x0804. MAME models the full 005885 as one
black-box device, so it doesn't care about the difference between MMR
bytes and scroll bytes — but our HDL has them split (`cfg_cs` vs `zure_cs`
inside `jtddribble_5885_7121_gfx.v`), and they need **separate chip-select
hits at different CPU addresses**.

The Konami 007552 PAL fires `/GATE1` for the WHOLE 0x0000-0x07FF window
(and `/GATE2` for 0x0800-0x0FFF), then the 005885 chip's *internal*
decoder picks register vs scroll vs VRAM from the low address bits. Our
HDL was emulating only the MMR slice of that window. The 005885 wrapper
was correct; the top-level decoder feeding it was the problem.

### Fix

`cores/ddribble/hdl/jtddribble_main.v` — decoder rewritten strictly from
`Konami_007552.jed`:

```verilog
if      (addr >= 16'h8000)                          rom_cs     = 1;  // /RBN
else if (addr >= 16'h6000 && addr <= 16'h7FFF)      k5885_2_cs = 1;  // /GATE2 VRAM
else if (addr >= 16'h4000 && addr <= 16'h5FFF)      shared_cs  = 1;  // /CWORK
else if (addr >= 16'h2000 && addr <= 16'h3FFF)      k5885_1_cs = 1;  // /GATE1 VRAM
else if (addr >= 16'h1800 && addr <= 16'h187F)      pal_cs     = 1;  // /CORAM (narrowed — 128 B physical)
else if (addr >= 16'h0800 && addr <= 16'h0FFF)      k5885_2_cs = 1;  // /GATE2 regs+zure  ← WAS 0x0800-0x0804
else if (                    addr <= 16'h07FF)      k5885_1_cs = 1;  // /GATE1 regs+zure  ← WAS addr <= 0x0004
```

Plus `/SEL` (bank latch) widened from exact `0x8000` to `0x8000-0x9FFF` —
PAL eq has no NEQ gate so the strobe is wider than we'd modeled.

`cores/ddribble/hdl/jtddribble_sub.v` — reviewed against
`Konami_007553.jed` in the same pass. Functionally correct as-is (boot
code only ever touches the exact byte addresses we model — verified in
the log), but widened DIP2/DIP3 from single-byte to full 1 KB PAL windows
for schematic faithfulness.

`cores/ddribble/doc/Konami_007552_equations.txt` +
`cores/ddribble/doc/Konami_007553_equations.txt` — header comments fixed
(007552 had been labeled "sub CPU", 007553 had been labeled "main CPU" —
both swapped) and enriched with the full input/output pin map.

`cores/ddribble/doc/HARDWARE.md` — item 11 added in the "Major fixes"
section.

### Why we believe this is right

- PAL equations are the authoritative source for what the silicon does.
  `jedutil` was run by MAME 0.276 on the dump from `Konami_007552.jed`;
  no model interpretation.
- The widened decoder + chip's internal sub-decoder gives the same
  net effect as the real /GATE1 + 005885 chain.
- No address range that the boot code actually accesses moves
  category — the only change is that ranges we previously *missed*
  (0x0020-0x005F, 0x0820-0x085F) now correctly route to the chip's
  zure_cs decode.
- pal_cs intentionally kept narrow at 0x1800-0x187F: PAL fires for the
  whole 0x1800-0x1FFF window but only 128 bytes of palette RAM exist
  physically; the rest is mirror and the log confirms the CPU never
  touches it.

### Expected outcome

This is very likely the single biggest visual-bug cause. With the
scroll/strip registers never reaching the chips, every tile position,
layer offset, and strip-map entry stayed at chip-reset zero — which
matches "wrong tiles, occasional glimpse of correct screen" perfectly.

Next sim after this fix should show much improved tile positioning. If
colors are still wrong, the 007327 palette format / 3-3-2 vs other
encoding is the next thing to look at (see task #27).

### Cross-references

- HARDWARE.md → "Major fixes that landed in this session" → item 11
- Task #21 (PAL-derived decoder rewrite) — completed
- Task #29 (instrumentation + 3000-frame sim) — completed; the log is
  what made this find possible

---

## 2026-06-02 — 007327 palette format: xBGR_555, byte-pair, low-byte-first

### Symptom

Boot, POST, and service-mode menus rendered with wildly wrong colors.
Going from R-G-B to B-G-R bit-extraction in the 007327 model flipped
red↔blue but never produced *white* anywhere on screen — every "white"
text label came out as a strong single channel (red, then blue) instead.
That was the sign that a single 8-bit byte per palette entry can't carry
12-bit RGB and we were fundamentally underspecifying the format.

### How we found it

Three converging lines:

1. **Palette write pattern in our sim log** — 802 unique CPU writes
   across 128 distinct addresses ($00-$7F), 97% of consecutive unique
   writes had delta=+1. That's a linear sweep, consistent with CPU
   writing pairs of bytes per color, not one byte per color.

2. **Byte-count arithmetic** — 128 B of palette RAM with the 007327
   outputting 12-bit RGB on the JAMMA edge requires more than 8 bits
   of storage per color. 128 B / 64 colors × 16 bits each fits cleanly;
   128 B / 128 colors × 8 bits each doesn't.

3. **Sibling jtcores implementation** — `cores/castle/hdl/jtcastle_colmix.v`
   line 19 has the comment `// Equivalent to KONAMI 007327`. Same Konami
   custom chip, in-tree, in production. It uses a `pal_half` byte-select
   toggle that reads two consecutive bytes per pixel via the same 8-bit
   BRAM port and assembles a 15-bit RGB color word in a shift register.

4. **MAME ground-truth** (`konami/ddribble.cpp:560`):
   ```cpp
   PALETTE(config, "palette", FUNC(ddribble_state::palette))
       .set_format(palette_device::xBGR_555, 64 + 256, 64);
   ```
   The format is `xBGR_555` — bit 15 unused, bits 14:10 = B[4:0],
   bits 9:5 = G[4:0], bits 4:0 = R[4:0].

5. **Empirical verification from a live MAME byte dump** — user paused
   MAME on the service-mode COLOR TEST page and read the bytes at the
   palette RAM ($1800-$180F). Decoding those bytes as xBGR_555 produced
   the visible color sequence exactly (white / yellow / cyan / green /
   magenta / red / blue at entries 1..7). One iteration was needed to
   discover the byte order:

   | Entry | Bytes (lo, hi) | Word | R/G/B | Color |
   |---|---|---|---|---|
   | 1 | EF, FF | 0xFFEF | 15/23/31 | near-white ✓ (text) |
   | 2 | 03, FF | 0xFF03 | 3/24/31 | yellow ✓ |
   | 3 | EE, 00 | 0x00EE | 14/7/0 | cyan ✓ |
   | 4 | 03, E0 | 0xE003 | 3/16/24 | green ✓ |
   | 5 | EC, 1F | 0x1FEC | 12/31/3 | magenta ✓ |
   | 6 | 00, 1F | 0x1F00 | 0/24/3 | red ✓ |
   | 7 | EC, 00 | 0x00EC | 12/7/0 | blue ✓ |

   Note: **byte at LOWER CPU address is the LOW byte of the word**.
   This is the opposite of what 6809 `STD` (store double) does
   natively — the boot apparently uses two single-byte STAs in
   low-then-high order rather than STD.

### Root cause

`jtddribble_007327.v` modeled each palette entry as a single 8-bit byte
unpacked 3-3-2 → 4-4-4 RGB. The real 007327 stores 64 colors × 16 bits
each, packed xBGR_555, accessed two bytes per pixel through its 8-bit
external data bus. Single-byte unpacking can never produce true white
(R+G+B all max) or accurate mid-tone colors.

### Fix

`cores/ddribble/hdl/jtddribble_007327.v` — completely rewrote the
palette read path:

- New `pal_half` reg toggles each clock; `pal_addr` becomes
  `{ pri, col_mux[4:0], pal_half }` = 7 bits → 128-byte BRAM.
- 16-bit shift accumulator (`pxl_aux`) catches both bytes of a color
  across two clock edges; the assembled word is latched into `col_in`
  on `pxl_cen`. Pattern lifted from `jtcastle_colmix.v`.
- After `pxl_cen` we force `pal_half <= 0` so the next clock reads the
  LOW byte first (matching the empirically-determined low-byte-first
  storage). The big-endian assumption was wrong — initial sim with
  `pal_half <= 1` produced channel-rotated wrong colors.
- RGB decode: `R = col_in[4:0]`, `G = col_in[9:5]`, `B = col_in[14:10]`.
  Truncate each 5-bit field to 4-bit by dropping the LSB to match the
  framework's 4-bit RGB interface.
- BLK gate kept (schematic-traced LS32 OR-tree, post-mux on `col_mux[3:0]`).
- PRI signal kept (schematic-traced gate-network `(|G1[3:0]) & G2[4]`).

### Why we believe this is right

- The format `xBGR_555` is verified two independent ways: (a) the
  in-tree `jtcastle_colmix.v` for the same Konami 007327 chip uses
  it; (b) MAME's `set_format(xBGR_555, ...)` declaration.
- The byte order (LOW byte at LOWER address) is verified empirically
  by decoding the live MAME byte dump against the visible COLOR TEST
  page — every entry maps to the correct color.
- After this fix the **VRAM COLOR row in our sim matches MAME's COLOR
  TEST page byte-for-byte** (cream / yellow / cyan / green / magenta /
  red / blue, contiguous strip, no gaps). All text labels render in
  white.

### Expected outcome

VRAM tile colors and all menu / POST / text rendering are now correct.
Remaining color anomaly (OBJ row blob) was a separate issue — the
sprite-PROM-not-loaded fix below addresses that.

### Cross-references

- `cores/castle/hdl/jtcastle_colmix.v` — sibling reference HDL for
  the same chip.
- `jtddribble_007327.v` header comment — full bit-layout documentation
  and the empirical byte-dump verification table.

---

## 2026-06-02 — sprite-lookup PROM not reaching the chip 2 wrapper (MRA placement)

### Symptom

With the palette format fixed, the COLOR TEST page rendered the **VRAM
COLOR** row correctly (7 distinct colors) but the **OBJ COLOR** row was
invisible — just the label, no squares. The OBJ row uses sprite #2's
output (chip 2 in our HDL) which per MAME passes through a 256-byte
sprite lookup PROM (`690a11.i15`).

### How we found it

1. **MAME source check** (`ddribble.cpp:109-122` palette init):

   ```cpp
   for (int i = 0x0; i < 0x100; i++) {
       uint8_t const ctabentry = color_prom[i] & 0x0f;
       palette.set_pen_indirect(i + 0x40, ctabentry);  // sprite #2 pens
   }
   ```

   Confirms sprite #2 pens flow through the PROM's low nibble. Without
   the PROM, sprite pixels would all collapse to whatever default the
   wrapper produces.

2. **Wrapper config** — `jtddribble_5885_7121_gfx.v` has a
   `BYPASS_OPROM` parameter (default 1). When 1, `oprom_data` is just
   `oprom_addr[3:0]` (passthrough). When 0, a 256-byte BRAM is
   instantiated and loaded by `prom_we & ~prog_addr[8]`. We were
   using `BYPASS_OPROM=1` for both chips with a comment falsely claiming
   "005885 has no internal sprite-color PROM."

3. **First fix attempt** — exposed `BYPASS_OPROM` as a per-instance
   parameter in `jtddribble_5885.v`, set chip 2 to `BYPASS_OPROM=0`.
   Sprites still invisible. Instrumentation showed:
   - `OPROM load count = 0` — `prom_we` never fired during ROM download.
   - `oprom_addr = 00 data=0` always during display — wrapper BRAM was
     never written, so reads returned zeros.

4. **SDRAM bank scan** — the actual 256 bytes of PROM data ended up at
   **bank 3 offset 0x80000** (right after gfx2), not at the bank 1
   offset our `mem.yaml` claimed. JTFRAME had silently relocated the
   region during placement because of an overlap.

5. **Cross-reference with castle** (the working 007327 sibling core):
   - `cores/castle/cfg/mame2mra.toml`: `{ name="proms", start="JTFRAME_PROM_START" }`
   - `cores/castle/cfg/macros.def`: `JTFRAME_PROM_START=0x2b0000`
   - `cores/castle/cfg/mem.yaml`: **NO prom region declared in SDRAM banks**.

   Castle handles PROMs entirely via the `prom_we`/`prog_addr` download
   stream into wrapper BRAMs; it does not allocate SDRAM space for them.

### Root cause

Our `mem.yaml` had the PROM declared as an SDRAM slot in bank 1. JTFRAME
tries to place it physically in SDRAM, detects an overlap (PROM is the
last region in the MRA at 0x100000, but the bank 1 slot didn't have an
explicit `start=` address that matched), and silently moves it to bank 3
where it fits — but the routing for `prom_we` to the wrapper BRAM is
broken in the process, because the bridge thinks the PROM is in bank 1.

The PROM data doesn't actually belong in SDRAM at all — it lives in the
wrapper's internal BRAM, loaded once at boot from the MRA byte stream.

### Fix

Three coordinated changes mirroring castle's pattern:

1. **`cfg/macros.def`** — add `JTFRAME_PROM_START=0x100000`.
   This is the MRA-offset where the PROM bytes start, right after gfx2
   (0x80000 + 0x80000 = 0x100000). It's the END of the ROM image, not
   a real SDRAM bank.

2. **`cfg/mame2mra.toml`** — change the proms region from
   `{ name="proms" }` to
   `{ name="proms", start="JTFRAME_PROM_START" }`.
   The explicit `start=` tells JTFRAME to place this region at the
   macro's value rather than auto-fitting it into a bank.

3. **`cfg/mem.yaml`** — REMOVE the `prom` SDRAM slot from bank 1, and
   remove the `PROM_OFFSET` param that the original mis-design relied
   on. Replace with a NOTE comment explaining that the PROM is loaded
   via `prom_we` to the wrapper BRAM, not SDRAM.

### Why we believe this is right

- After applying all three changes + clean rebuild, the diagnostic
  inside the wrapper showed `prom_we` firing during ROM download
  with `wr_addr=00 data=0` through `wr_addr=ff data=f` — all 256
  bytes loaded into the wrapper BRAM with real data.
- During display, the OPROM read-back samples showed the sprite
  engine producing varied `oprom_addr` (e.g. 50, 52, 54, 57) with
  non-zero `oprom_data` (e.g. 4, 1, 7). The chain CPU sprite-RAM →
  sprite engine → oprom_addr → PROM lookup → palette index is now
  fully live.
- The OBJ COLOR row went from completely invisible to visibly rendered
  in the COLOR TEST page (frame_01053 in the post-fix sim).
- The fix pattern is identical to castle's, which is in production
  for the same 007327 chip.

### Expected outcome

OBJ-layer sprites now have real palette indices and render visibly.
Specific sprite color accuracy on a given test page may still be wrong
because of other suspects (sprite-RAM contents, sprite-tile decode), but
the path through the PROM is no longer the bottleneck.

### Cross-references

- `cores/castle/cfg/mame2mra.toml` + `cores/castle/cfg/macros.def` +
  `cores/castle/cfg/mem.yaml` — canonical pattern for the same 007327.
- `jtddribble_5885.v` — `BYPASS_OPROM` is now a per-instance parameter;
  chip 2 sets it to 0, chip 1 keeps the default of 1.
- AGENTS.md → "Running sims with DIP and cabinet-input overrides" — the
  diagnostic recipe that exposed the missing `prom_we` activity.

---

## 2026-06-03 — CPU and YM/VLM clock rates were approximate, now exact

### Symptom

`cfg/mem.yaml` used the simple `mul:N div:M` form to derive cen signals
from `clk24`. The two rates we needed don't divide 24 MHz cleanly, so
the produced clocks were off:

- **CPU cen**: target 18.432 MHz / 12 = **1.536 MHz**; produced
  `24 MHz / 16 = 1.500 MHz` → **2.3% slow**.
- **YM2203 + VLM5030 cen**: target **3.579545 MHz**; produced
  `24 MHz × 3/20 = 3.600 MHz` → **0.6% fast**.

Not catastrophic (within arcade tolerance for game logic) but YM/VLM
pitch is audibly off and CPU timing is off enough that audio tests and
some sync-sensitive loops could behave differently than on real PCB.

### How we found it

Re-reading the `mem.yaml` clock-derivation comments while looking at
the pending sprite/OBJ issues — the approximation was documented
explicitly in the comments (`actual = 24 MHz / 16 = 1.500 MHz (2.3%
slow)`) but never tightened. Cross-checking with peer Konami cores:

- `cores/ajax/cfg/mem.yaml` uses `freq: 3579545` for its FM cen, which
  produces an EXACT 3.579545 MHz via JTFRAME's fractional-cen
  accumulator.
- `cores/contra/cfg/mem.yaml` uses the same `freq: 3579545` pattern.

The `freq:` directive is the right tool for clocks that don't divide
the master cleanly — JTFRAME emits a fractional-N accumulator that
averages to the requested Hz exactly.

### Root cause

We picked the simpler `mul/div` form when first writing `mem.yaml`,
documented the discrepancy as "within arcade tolerance," and moved on.
Never came back to tighten it.

### Fix

`cores/ddribble/cfg/mem.yaml` — swap both clock entries to the
fractional form:

```yaml
- freq: 1536000        # CPU cen — EXACT 1.536 MHz (was 1.500 MHz)
  gate: [ main, sub, snd ]
  outputs: [ cpu ]

- freq: 3579545        # YM2203 + VLM5030 — EXACT 3.579545 MHz (was 3.600 MHz)
  outputs: [ ym, vlm ]
```

No HDL-side changes needed: the `outputs:` lists are unchanged, so
JTFRAME generates the same `cpu_cen` / `ym_cen` / `vlm_cen` wire names.

### Why we believe this is right

- `freq:` is the JTFRAME idiom for exact fractional clocks; ajax + contra
  both rely on it in production for the same 3.579545 MHz audio rate.
- The HDL interface is unchanged — only the per-tick spacing of the cen
  pulses changes — so no downstream module needs to know about it.
- The `gate: [main, sub, snd]` SDRAM-stall logic is preserved on the
  CPU cen, so the recently-fixed stale-read pattern doesn't regress.

### Expected outcome

- YM2203 FM/PSG output now plays at the correct pitch.
- VLM5030 speech samples play at the correct rate (avoids the
  "slightly chipmunk" effect of running 0.6% fast).
- CPU runs 2.3% faster than before — game logic loops and watchdog
  timing now match the real PCB.

### Cross-references

- `cores/ajax/cfg/mem.yaml` and `cores/contra/cfg/mem.yaml` — peer
  Konami cores using the same `freq: 3579545` idiom.
- HARDWARE.md → CPU architecture section (xtal rates documented from
  schematic).

---

## 2026-06-02 — PRI signal re-enabled + LS157 mux orientation corrected

### Symptom

After enabling the schematic-traced PRI `wire pri = (|g1col[3:0]) & g2col[4]`
(replacing the earlier educated-guess `(g1col[3:0] == 0) & g2col[4]`),
**every dumped frame was pure black** — 22 frames in a 300-frame sim, all
solid 385-byte JPGs. The CPUs were alive (691 MB of bus-trace activity),
but the display path rendered nothing.

### How we found it

Reasoning through the LS157 layer-priority mux semantics. With our
existing wiring `col_mux = pri ? g2col : g1col`:

- New PRI: `(|FG[3:0]) & BG[4]` → `pri=1` iff FG opaque AND BG bit-4 set
  → with this mux, that means "show BG when FG has color bits"
- Result: areas where FG is transparent (the vast majority of attract-mode
  pixels) get `pri=0`, mux selects FG=transparent → all-black render.

The schematic-traced AND-gate logic was correct, but our **LS157 mux
input orientation was opposite** of what was needed for that PRI to make
sense.

### Root cause

The schematic-traced PRI gate signal is the right boolean, but I had
assumed LS157 input wiring (G1 on input A, G2 on input B) that made
PRI=1→BG and PRI=0→FG. The user confirmed from the schematic that the
actual LS157 wiring is the OPPOSITE: **input A = G2 (BG), input B = G1
(FG)**. LS157 truth: SEL=0 → output = A; SEL=1 → output = B. So:
- PRI=0 → output = G2 (BG)
- PRI=1 → output = G1 (FG)

That makes the AND-gate-derived PRI correct: "PRI=1 when FG has color
bits AND BG bit-4 is set → show FG (it's opaque and priority allows it);
PRI=0 → show BG."

### Fix

`cores/ddribble/hdl/jtddribble_007327.v`:

```verilog
// Before (wrong mux orientation, made every pixel black):
wire [4:0] col_mux = pri ? g2col : g1col;

// After (per user schematic read 2026-06-02):
//   LS157 input A = G2 (BG)   SEL=0 → output = A → BG
//   LS157 input B = G1 (FG)   SEL=1 → output = B → FG
wire [4:0] col_mux = pri ? g1col : g2col;
```

The PRI signal itself is the schematic-traced gate output:
```verilog
wire pri = (|g1col[3:0]) & g2col[4];   // LS32 H12 + LS08 G11 trace
```

BLK was also rewritten to its explicit per-PRI-branch form for clarity
(functionally identical to `|col_mux[3:0]`):
```verilog
wire blk = pri ? (|g1col[3:0]) : (|g2col[3:0]);
```

### Why we believe this is right

- The schematic LS157 H13/H14 input wiring is what the user read directly
  off the page: A=G2, B=G1. SEL drives output to A or B per the standard
  74157 truth table.
- After the orientation fix, POST screen renders correctly (every test
  reading OK) — the same screen that was all-black with the previous
  mux orientation.
- BLK rewrite is a clarity-only change; functionally `|col_mux[3:0]`
  and the per-branch form produce the same bit.

### Expected outcome

Display path is no longer black. Tile/text rendering produces correct
shapes (POST screen looks like POST screen). Colors are still wrong at
this point (separate xBGR_555 byte-format fix logged in next entry).

### Cross-references

- Task #27 (PRI revisit) — first half done; the RDU/RDL byte swap
  unexplained part is still pending.

---

## 2026-06-03 — Chip-2 gfx ROM address bits (RA16/RA17) were being discarded

### Symptom

After the palette format + sprite-PROM fixes landed, the OBJ COLOR
row in the service-mode COLOR TEST page showed a vague colored blob
instead of 7 distinct squares. Sprites in actual gameplay (basketball
court) showed the static background fine (backboard, rim, audience
"snow" texture) but the **player sprite was completely invisible**.

### How we found it

User noted that the real PCB has 4 populated MASK1Ms (out of 6 slots —
I7 and I10 empty) on the chip-2 side, providing the full 512 KB of
`gfx2` data. Cross-referencing against our framework's `gfx2_addr`
port width revealed:

- `mem_ports.inc` declares `output [17:1] gfx2_addr` = 17 explicit bits
  + 1 implicit bit 0 (16-bit data) = 256K words byte-address ⇒ **256 KB
  reach** if we route 17 bits to it.
- We were routing `{ main_bank[0], k5885_2_R }` = 1+16 = 17 bits ⇒
  reaching only **128K words = 256 KB**, the LOWER half of the 512 KB
  `gfx2` region. Per MAME's `ROM_LOAD16_BYTE` layout, that lower half
  contains **characters/tiles**, and the upper half (0x40000-0x7FFFF)
  contains **objects/sprites**. So chip 2's sprite engine was reading
  character bytes thinking they were sprite tile patterns — explaining
  both the blob in OBJ COLOR row and the missing player.

User then sent a schematic snippet showing **four LS74 flip-flops
(B15/A10/A11 on page 0)** that latch `CHAF2` (clocked by chip's CHAF2/
CHARA strobes) and the data lines D2/D3 from chip 2's internal SRAM
into **R16, R17, R17N** — i.e. the missing upper address bits aren't
generated inside the 005885 chip, they're produced EXTERNALLY by an
LS74 chain that picks up per-sprite attribute bits from the sprite
list as it's being read.

### Root cause

The contra-derived gfx wrapper (`jtddribble_5885_7121_gfx.v`) internally
computes a full 18-bit `rom_addr` (= `rom_scr_addr` or `rom_obj_addr`
depending on the cycle), but our `jtddribble_5885.v` wrapper was
**truncating to 16 bits** at its output:

```verilog
assign R = base_rom_addr[15:0];   // discarded top 2 bits
```

with a misleading comment that said "banking external on real PCB" —
implying the missing bits should come from CPU bank latch. They don't.
They come from the LS74 chain latching per-sprite attribute bits from
chip 2's sprite-list traversal — which is exactly what the wrapper
already computes internally as `base_rom_addr[17:16]`.

### Fix

Three coordinated changes:

`cores/ddribble/hdl/jtddribble_5885.v` — expose the upper 2 bits:

```verilog
output             RA17,    // = base_rom_addr[17]  (LS74 A10 Q equivalent)
output             RA16,    // = base_rom_addr[16]  (LS74 A11 Q equivalent)
output     [15:0]  R,       // chip's own RA0..RA15
...
assign R    = base_rom_addr[15:0];
assign RA16 = base_rom_addr[16];
assign RA17 = base_rom_addr[17];
```

`cores/ddribble/hdl/jtddribble_game.v` — wire them into the SDRAM
gfx-region addresses:

```verilog
// chip 1: gfx1 is 256 KB → need 17 bits of word address
assign gfx1_addr = { k5885_1_RA16, k5885_1_R };

// chip 2: gfx2 is 512 KB → need 18 bits of word address
//   replaces prior `{ main_bank[0], k5885_2_R }` guess
assign gfx2_addr = { k5885_2_RA17, k5885_2_RA16, k5885_2_R };
```

### Why we believe this is right

- The schematic explicitly shows R16/R17 are generated outside the
  005885 chip by an LS74 chain latching the sprite-RAM data bus
  (D2/D3 from chip's internal 6264SL) clocked by CHAF2/CHARA. That's
  identical in role to what `base_rom_addr[17:16]` represents inside
  our wrapper — both are "high address bits derived from per-tile/per-
  sprite attribute bits."
- Pre-fix: chip 2 could only address the lower 256 KB of gfx2 ROM,
  which per MAME's `ROM_LOAD16_BYTE` declarations is the CHARACTER
  region. Sprites live at 0x40000-0x7FFFF and were unreachable.
- After the fix: chip 2 reaches the full 512 KB; sprite tile patterns
  are fetched from the right ROM region.

### Expected outcome

Sprites become fetchable; chip 2 OBJ engine should produce real sprite
pixels (whether the rest of the sprite-rendering pipeline is correct is
a separate question — e.g. tile-flip handling logged in next entry).

### Cross-references

- User-provided schematic crop showing LS74 chain B15/A10/A11.
- User-provided photo of chip 2 MASK1M sockets (4 populated of 6).
- Task #25 (NEXR trace) and Task #27 (RDU/RDL swap) are still open
  for the remaining unexplained sprite-path quirks.

---

## 2026-06-03 — Per-tile flip disabled for MODE_5885

### Symptom

In the basketball gameplay attract, the right half of the court was
visibly mirrored relative to the left half — same tile artwork drawn
in the same orientation rather than as a mirror image. (Konami stored
half the court artwork once and used per-tile X-flip to render the
mirrored half — saving ROM space.)

### How we found it

User suspected per-tile flipping wasn't being honored and asked
whether the 005885 supports tile-level flip. Inspection of our
contra-derived gfx wrapper showed two relevant signals:

```verilog
// jtddribble_5885_7121_gfx.v MODE_5885 path (lines 220-221, pre-fix):
assign hflip_en   = 1'b0;
assign vflip_en   = 1'b0;
```

And in the tilemap state machine (`jtddribble_5885_7121_tilemap.v`):

```verilog
hflip <= ~txt_row & hflip_en & attr_scan[4];   // X-flip from attr bit 4
vflip <= ~txt_row & vflip_en & attr_scan[5];   // Y-flip from attr bit 5
```

With both enables forced to 0, the AND collapses → no tile ever flips,
regardless of its per-tile attribute byte.

### Root cause

The 007121 (parent chip the gfx module was originally written for) has
a master mmr[6] flip-enable register. The 005885 (which we set
`MODE_5885=1` to select) doesn't have that register. The MODE_5885 path
in the wrapper interpreted "no master register" as "feature absent"
and disabled the flip path entirely. That interpretation was wrong:
the 005885 has the flip logic, it just runs unconditionally (no master
gate) — the per-tile attribute bits drive it directly.

### Fix

`cores/ddribble/hdl/jtddribble_5885_7121_gfx.v` — hard-wire the
enables ON in the MODE_5885 branch:

```verilog
// (best-guess assumption: 005885 always honors per-tile flip bits;
//  the 007121's master enable mmr[6] does not exist on this chip,
//  so we hard-wire ON instead of OFF. Whether attr_scan[4]/[5] are
//  the right bit positions in the 005885's attribute byte is NOT
//  verified — kept the 007121 slots as the first best guess.)
assign hflip_en = 1'b1;
assign vflip_en = 1'b1;
```

### Why we believe this is right (and the caveats)

- Half-mirrored court tiles is exactly the visual you'd see if the
  chip's per-tile X-flip bit is being ignored: same artwork on both
  halves, no mirror.
- We did NOT independently verify that `attr_scan[4]/[5]` are the
  correct bit positions on the 005885 — they're the 007121 slots and
  we kept them as the first attempt. If a future sim shows tiles
  flipping in the wrong direction (or some tiles flipping that
  shouldn't), the next thing to try is remapping which attr_scan bits
  the tilemap state machine reads.
- We're not citing MAME as proof of the 005885 supporting flip — that
  was an earlier framing we walked back at the user's request.

### Expected outcome

Basketball-court mirroring should be correct after this fix. Also any
other tile/sprite that relies on flip-bits to save ROM space (player
animation, repeated UI elements, etc.) should render correctly.

### Cross-references

- User-provided gameplay screenshot showing the half-mirrored court.

---

## 2026-06-03 — Scene-dump instrumentation (rolled back; future = JTFRAME-native)

### Why this entry exists

We added custom HDL plumbing to dump chip-internal RAMs to .hex files
at specific frames (2220, 3000) so we could replay a scene visually
without re-running the boot. The implementation worked but cost us a
lot of cross-module plumbing, and Verilator couldn't see the BRAMs'
`mem` arrays across the `jtframe_dual_ram` module boundary, forcing
us to also add shadow-array tracking. The whole thing was unwound at
user request; the canonical path is JTFRAME's built-in IOCTL-RAM save.

### What was tried (then removed)

- `jtddribble_game.v` — `scene_dump_id [15:0]` register pulsed to 2220
  / 3000 at the corresponding frames; wired into both chip instances.
- `jtddribble_5885.v` — added `SCENE_TAG` string parameter (chip1/chip2)
  + `scene_dump_id` input port, both plumbed through to `u_chip`.
- `jtddribble_5885_7121_gfx.v` — added `SCENE_TAG` parameter,
  `scene_dump_id` input, shadow-copy arrays watching every write into
  `u_attr_ram`/`u_code_ram`/`u_obj_ram` (Verilator couldn't reach the
  `mem` array inside `jtframe_dual_ram` without modifying that file or
  using `--public-flat-rw`, which didn't work because the rejection
  happens at elaboration), and `$writememh` dumps of the shadows + the
  `mmr` and `zure` reg arrays.

### Why it was rolled back

User preference: use the **JTFRAME-native path** instead of custom
$writememh plumbing through wrapper ports. JTFRAME exposes
`JTFRAME_IOCTL_RD` for declaring NVRAM-save regions and
`JTFRAME_SIM_IODUMP=<frame>` for triggering a sim-time dump of those
regions to `dump.bin`. That's the official "scene capture" recipe;
the symmetric load path mirrors what MiSTer hardware does on NVRAM
restore. Reaching for that mechanism keeps us in production code
paths rather than sim-only kludges.

### What remains (preserved from this session)

- Flip-bit fix (next-prev entry): kept.
- RA16/RA17 chip ROM-address extension (above): kept.
- `BYPASS_OPROM` parameter on `jtddribble_5885`: kept.

### TODO (for the JTFRAME-native scene-dump effort)

- Add `JTFRAME_IOCTL_RD=<size>` to `macros.def` with the right region
  byte-count.
- Declare which BRAMs are "save-RAM" via the IOCTL interface (likely
  needs the chip-internal SRAMs to be exposed as mem.yaml dual-port
  BRAMs rather than wrapper-internal — a small refactor).
- Set `-d JTFRAME_SIM_IODUMP=<frame>` on jtsim CLI to trigger.
- Look at a core that already uses `JTFRAME_IOCTL_RD` for the wiring
  pattern (likely cps15 or similar with NVRAM save-game support).

### Cross-references

- `modules/jtframe/doc/macros.md` — `JTFRAME_IOCTL_RD` /
  `JTFRAME_SIM_IODUMP` definitions.
- `modules/jtframe/hdl/inc/ioctl_dump.v` — implementation reference.

---

## Scene-replay LOAD path wired (2026-06-15) — NOT a fix, a diagnostic tool

Wired the standard jtsim `-s <scene>` scene-replay for ddribble (the LOAD
side; the earlier rolled-back work was the DUMP side). This is the
JTFRAME-native path the previous section pointed to — no custom plumbing:

- `cfg/mem.yaml`: `simfile: {}` on the `pal` BRAM → loads `pal.bin`.
- `jtddribble_5885.v`: new `SIMATTR/SIMCODE/SIMOBJ` params forwarded to the
  gfx wrapper's existing `jtframe_dual_ram .SIMFILE(...)` tile/sprite BRAMs.
- `jtddribble_game.v`: per-chip SIMFILE names (chip1 `gfx1_*`, chip2
  `gfx2_*`) + an `ifndef NOMAIN` gate that stubs the main CPU (held in read)
  so it never overwrites the scene BRAMs.
- `ver/game/rest2bin.sh`: splits the scene `rest.bin` into the per-chip
  SIMFILE targets, **de-interleaving** the flat 4 KB tile image into the
  2 KB attr + 2 KB code BRAMs exactly as the HDL writes them
  (`ram_addr={addr[11],addr[9:0]}`, attr=`~A10`, code=`A10`).
- `ver/ddribble/mame_scripts/build_scene_dump.sh`: assembles a scene
  `dump.bin` (fgram+bgram+spr0+spr1+pal) from the `dump_sprites.lua`
  captures.

Run: `FRAMES=3 ./sim-core.sh ddribble ddribble -s ../ddribble/scenes/mame_01800`
(jtsim auto-adds NOMAIN/NOSOUND/SIMSCENE; cached SDRAM banks → boots at
frame 1, ~7 s/run). Outputs graded in `ver/ddribble/sim_results/`.

### What the first two replays reveal (frames 1500 text screen, 1800 dunk)

- **BG layer (chip 2, crowd) renders recognizably** — biggest signal yet
  that the chip-2 tile path + gfx2 ROM routing is broadly correct.
- **FG layer (chip 1) bug is attribute-selective, NOT global addressing:**
  - Bright title row "MOST MEMORABLE TEAM RECORDS" is **pixel-perfect**.
  - The dim header row ("NAME BirthDate…") is **fully garbled AND wrong
    colour** (renders blue, should be dim green) → both pattern address and
    palette wrong for that row's attribute.
  - In the data rows most glyphs are perfect, but the **"/" slash renders
    blank** and the **"4" glyph is malformed** (every "4"), while
    0,1,2,3,5,6,7,8,9 and letters are fine.
  - KONAMI logo (graphic tiles) = blue blob.
- Conclusion: the defect tracks the tile **attribute** (palette/bank/flip
  decode in `jtddribble_5885_7121_tilemap.v`) and/or the per-row text-vs-
  graphic classification (`txt_en`/`scores`/`layout`), NOT the base tile
  address (which the perfect title row proves correct). Sprite/obj path is
  unrelated to this (no on-screen sprites in either scene — both have OBJ
  RAM parked at Y=240).

This is the fast iteration loop for task #30; no tile-path HDL changed yet.

---

## FG vertical alignment −16 (2026-06-15) — verified on the 1500 text screen

The 005885-rendered content sat a constant **16 lines (2 tile rows) too high**
in the captured frame vs MAME's `screen.png`. Root cause: the output capture
window (`jtddribble_video` vtimer, visible 16..239) is offset from MAME's
ddribble visarea Y-origin (0..223). Confirmed by the tile-RAM math: the FG
title tile is at tile-RAM row 3 = scanline 24, which MAME shows at frame row
24 but the FPGA showed at frame row 8.

The output vtimer and the 005885's internal render vtimer share the same period
(both VCNT_END=263, both phase-locked), so this is a window-origin gap, not a
render-vs-output drift. Trying to move the output window to 0..223 hits a
jtframe_vtimer edge case (active region straddling the counter wrap at VB_END=
VCNT_END=263 is degenerate — verified: it compiled but did nothing). So instead
the fix shifts the **rendered content** down 16 lines, gated to MODE_5885, in
`jtddribble_5885_7121_gfx.v`:

    wire [8:0] vrender_disp = MODE_5885 ? (vrender - 9'd16) : vrender;

fed to BOTH `u_tilemap` and `u_obj` (so sprites track tiles). 007121/contra
default unchanged.

Verified with `tools/scenesim/`: scene **mame_01500** (a clean FG-only stats
screen, no BG, no scroll) now has its title at frame row 24 in both MAME and
FPGA, and every text row + the KONAMI logo line up vertically. Remaining red in
that diff is the content garble (broken header row, thin glyphs, "/" + "4"),
not vertical — that's task #30.

### Scene replay does NOT load the 005885 MMR — BG scenes can't be V-graded yet

Scenes mame_01800 / mame_02100 are BG-crowd frames. Their compare stacks are
mostly red because the scene replay loads tile/sprite/palette RAM but **not the
005885 MMR** (scroll position `vpos`, `strip_map` text/scroll row select,
`flip`, `layout`). So the BG (chip 2, which scrolls) renders at default vpos=0,
not MAME's scroll — its vertical position is unreliable regardless of the −16.
The −16 is validated only on the no-scroll FG screen (1500). Loading the MMR
into the scene (regs are `reg mmr[0:7]` / `zure[0:31]` / `strip_map` inside the
gfx wrapper, not BRAMs with SIMFILE) is the next step for BG scene fidelity.

---

## Reference-grounded vtimer: VTOTAL 262 + VCTR centering (2026-06-15)

The schematic (sync buffer + page-0 fetch logic, supplied 2026-06-15) proved the
**005885 (E16) is the sync master**: NCSY (pin 4) / NVSY (pin 59) are chip
*outputs*, just buffered (LS244→LS367→R27/R28) to the connector as SYNC/VSYNC and
fanned out as NSYNC/NVSYNC. So the visible-window/blanking is **internal to the
005885** — no discrete LVBL generator exists to trace (the VERIFICATIONS §M
"LS74 SET at V==239" guess is wrong). The authority is `k005885_REFERENCE.sv`.

Per that reference (lines 191, 262-268, 304-309):
- **VTOTAL = 262 lines** (we had kicker's 264) → `VCNT_END` 263→**261** in BOTH
  the 005885 chip vtimer (`jtddribble_5885_7121_gfx.v`) and the output vtimer
  (`jtddribble_video.v`); the latter's `VS_START` moved 260→256 to keep VSync
  inside the new 240..261 bottom blank. Refresh = 6.144MHz/(384·262) = 61.07 Hz.
- Active video = v_cnt 271..494 = 224 lines (matches our 224).
- A **VCTR vertical-centering input** (`vcnt_start <= 249 - VCTR`) repositions the
  picture. ddribble's picture sits 16 lines low, so the earlier `vrender-16` is
  now framed as that centering: `localparam VCTR_5885 = 9'd16`, applied to the
  render counter fed to tilemap + obj. Not a hack — it models the chip's VCTR.

Verified with `tools/scenesim/`: scene **mame_01500** (clean FG text) stays
pixel-aligned (title row 24 in MAME and FPGA) after the VTOTAL change; lint clean.

### Horizontal centering HCTR (2026-06-15) — both axes now nailed

Measured the residual horizontal offset on 1500: FPGA content was a constant
**6 px left** of MAME (title col 17→11, data col 9→3). The reference's HCTR does
this horizontally (k005885_REFERENCE.sv:92,357 — `NHSY` shifted by
`hsync_start - HCTR[2:0]`). Modeled it the same way as VCTR, but on the
**line-buffer read** position (the shared horizontal analog of `vrender`):
`localparam HCTR_5885 = 9'd6; wire hdump_disp = MODE_5885 ? hdump-HCTR_5885 : hdump;`
fed to BOTH the tilemap read (`line_dump`) and the obj read (`u_obj.hdump`), so
tilemap + sprites center together. Blank/border decisions keep the real `hdump`.

Result (1500): **V Δ=0, H Δ=0** on both title and data rows.

### CORRECTION from scene 300 (2026-06-15): VCTR is 0, not 16

Rendering scene **300 (the POST boot screen)** exposed that the vertical "16" was
NOT centering. 300 is drawn before any game state, so its FG vertical scroll
`vpos=0` — matching the scene-replay default MMR. With `VCTR_5885=16` it rendered
**+16 too low** (V Δ=+16), while its horizontal was Δ=0. So:
- **HCTR_5885 = 6 is genuine horizontal centering** — 300 (vpos/hpos=0 baseline)
  AND 1500 both align horizontally at 6.
- **VCTR_5885 must be 0** — 300 aligns vertically with NO centering. The +16 seen
  on 1500 was that scene's FG **vertical scroll (vpos in the 005885 MMR)**, which
  the replay doesn't load. 1500 happened to need +16; 300 needs 0; a true centering
  constant can't differ between scenes — so it's scroll, not centering.

Set `VCTR_5885 = 0`. Now **scene 300 renders pixel-perfect** (V Δ=0, H Δ=0, the
whole POST screen byte-for-byte matches MAME — first fully-correct ddribble frame).
Scene 1500 is back to V Δ=−16 = its real FG scroll, which will resolve once the
MMR (`vpos`/`strip_map`) is loaded into the scene. The reference's VCTR/HCTR are
"extra" model centering inputs (not 005885 pins), so the magnitudes are matched to
the hardware target (MAME); HCTR=6 is the only real centering, VCTR=0.

Bonus finding: 300's text renders cleanly with **no** thin-pixel/glyph defects —
so the task #30 FG bugs (garbled dim header, "4"/"/" glyphs, KONAMI logo) are
**attribute/glyph-specific**, not a general FG-decode failure. The FG pipeline is
sound; the bugs hit only particular tile attributes the POST screen doesn't use.

### Still open (parts of the same work, not done here)
- **Drive framework sync from the chip vtimer** (single source) instead of the
  separate `jtddribble_video` vtimer — the schematic says the 005885 is master.
  Currently still dual-vtimer, kept phase-locked via matching `VCNT_END`. This is
  the architectural cleanup that would let the centering live in the sync, not a
  content offset.
- **VCTR/HCTR value source** — used a fixed `localparam`; the real VCTR (and the
  horizontal HCTR) value comes from a PCB tie or chip register, not yet traced.
- **H active 240 vs 256** — reference says active H = 240 (280 in wide mode); we
  use 256 and MAME's screen is 256. Needs reconciling.
- BG scenes (1800/2100) still need the MMR scroll loaded to be V-gradable.

---

## "Thin font" pinpointed: gfx1 DATA is correct, the RENDER thins it (2026-06-15)

The FG font renders thinner than MAME (POST line: 248 lit px vs MAME's 399). It
is a render/phase issue, NOT the palette/priority. Settled by instrumenting the
tilemap fetch on scene 300:

- The fetched gfx1 word for the "M" tile (code 0x9e), decoded across all 8
  sub-rows, is byte-identical to MAME's bold M (`.##...##.` = 2px verticals). So
  the gfx1 ROM data, address (incl. RA16), RDU/RDL swap, and fetch handshake are
  all correct — same address always returns the same data (no fetch lag).
- Yet the rendered M is thin (`.#....#.`). So the thinning is downstream of the
  fetch, in the render pipeline (tilemap dump -> line buffer -> pxl_out combine),
  NOT data/palette/pri/pal_half. Tested negative: forcing FG-wins priority and
  flipping pal_half both left the lit count at 248; missing pixels are already 0
  in g1col (= chip pxl_out, upstream of the 007327).

Ruled OUT vs 484b13b (good-font commit): tilemap decode (byte-identical), gfx1
mem.yaml/banks/mame2mra (identical), gfx1 download remap (identical), RDU/RDL
swap (identical; un-swap worse), gfx1_addr RA16 (revert -> same thin). The 007327
was rewritten after 484b13b (1-byte -> 2-byte pal_half read) but it only colours
pixels, can't blank them.

NEXT: pinpoint the render stage. A line-buffer probe showed FG pixels landing at
unexpected hdump (H-blank) positions -> a write(hrender)-vs-read(hdump) column
phase mismatch is the prime suspect. The fetched data is proven good, so the fix
is purely in the dump/line-buffer/pxl_out timing.

---

## 2026-06-16 — Sprites rendered "completely wrong, unrelated tiles" — gfx addr_width truncated RA16

### Symptom

After bringing the 005885 sprite engine up (colour path, multi-tile, off-screen
clip, double-buffer line buffer), tilemaps/text rendered perfectly but **every
sprite was wrong** — not flipped, not mis-coloured, not reordered: the player
sprites came out as solid bars / garbled blocks of *unrelated* tiles. User was
adamant from the start: "the formula is correct but the chip is bad… those are
completely different tiles." They were right.

### How we found it

Stopped guessing at the decode and verified the **fetch against the ROM bytes**.
Confirmed the SDRAM bank = byte-swapped interleave of the raw 690a05/06 ROMs
(0% mismatch for BOTH the chars region and the objects region — data is loaded
correctly). Then probed the live sprite fetch (`[FETCH] num/waddr/RDU/RDL`) and
diffed each fetch against `bank[waddr]`: **mismatch** — the engine reported
`waddr=0x1022A` but the bytes it got were not `bank[0x1022A]`. So the address
path was lying. The smoking gun was the **`%Warning-WIDTHTRUNC` lint on
`jtddribble_game.v:273`** (the `gfx1_addr` assign) that had been dismissed as
harmless for weeks: `gfx1_addr` was `[16:1]` (16 bits) but the chip drives
`{RA16, R[15:0]}` = 17 bits, so **RA16 was silently truncated off the top**. RA16
selects the OBJECTS half of gfx1 (byte 0x20000+); dropped, every sprite read the
CHARS half. Chars rendered fine the whole time because they live in the lower
half (RA16=0) — which is exactly why it looked sprite-specific and hid for so
long. (This also explains the earlier thin-font entry's "revert RA16 -> same
thin": the font is chars, unaffected by RA16.)

### The fix

`mem.yaml` `addr_width` is the **BYTE-range exponent**, and both gfx regions were
one bit short:

- `gfx1` (256 KB = 2^18) addr_width **17 -> 18** → `gfx1_addr` becomes `[17:1]`,
  so `{RA16, R}` lands without truncation. Sprites now fetch the objects half;
  fetch == `bank[addr]` byte-for-byte (8/8); scenes 2700/3300 render correct
  players matching MAME (~97% lit). Text scenes still exact.
- `gfx2` (512 KB = 2^19) addr_width **18 -> 19** → `gfx2_addr` `[18:1]` carries
  `{RA17, RA16, R}` with no truncation either.

game.v's `{RA16,R}` / `{RA17,RA16,R}` assigns were already correct — they only
needed a wide enough generated port. RA17 for gfx1 is genuinely unconnected on
the PCB (2x MASK1M = 256 KB); it is now an explicit sim-asserted "must stay 0"
contract (`jtddribble_game.v`, 0 violations) so it can never silently truncate
the way RA16 did.

**Lesson: never dismiss a `WIDTHTRUNC` warning on a gfx-address bus — it means an
RAxx bit is being dropped, and the chip will read the wrong gfx region.**

---

## 2026-06-16 — Tile HFLIP applied one tile late (off-by-one on sparse tiles)

### Symptom

User observed in the running attract: some tiles that should be h-flipped weren't,
and "tile at pos X gets the flip value of the tile at x-1 (8px before)." Only
*sparse* tiles showed it (dense/symmetric tiles hide a wrong flip), so it looked
intermittent.

### How we found it

Instrumented the serializer. The fetched gfx word is buffered in `row_word`
(latched once per 4-pixel group at `h_cnt[1:0]==3`), but the nibble-flip mux
(`psel`) read the **live** `tile_hflip`. A probe captured the flip in force when
each word was fetched (`rw_hflip`) and counted displayed non-zero pixels where
`tile_hflip != rw_hflip`: it fired on every hflip transition —
`[HFLIP0] gfx=9 psel_flip=0 gfx_flip=1 -> MISALIGNED`. By the time a buffered word
is serialised, `tile_hflip` has already advanced toward the next tile, so the flip
was applied to the neighbouring tile.

### The fix

`jtddribble_k005885.v`: latch `tile_hflip` alongside `row_word` (`rw_hflip`) and
drive the serializer from it — `pixel_hflip = flipscreen ^ rw_hflip` instead of the
live `tile_hflip`. Now the nibble-flip and the word it flips are always the same
tile. Verified: text scenes stay pixel-exact (no flip → no change), and the
4500-frame attract MP4 shows correct flips on the moving court/crowd (user-confirmed).
The half-select in `tile_rom_addr` keeps the fetch-time `tile_hflip` (correct — it
picks which word to fetch); only the display-side mux needed the captured copy.

**General rule for this pipeline: any per-tile attribute consumed at the DISPLAY
stage must be the copy captured WITH the buffered gfx word, not the live latch.**

---

## 2026-06-17 — Redid the 005885 video as a 007121-style line-buffer (smooth scroll + sprite flip/Y)

This is the big one: we replaced the tilemap renderer and fixed two pre-existing
sprite bugs, all grounded in the **Furrtek 007121** and the **005885 reference**,
not MAME. The result is smooth sub-tile horizontal scroll plus correctly flipped,
correctly-positioned sprites (user-confirmed in the running attract demo).

### Why we redid it

The original tilemap was a **direct serializer**: it fetched a tile's gfx word and
muxed it straight to the colour output, in lock-step with the display. That can only
scroll in whole-tile (8px) steps — the fine sub-tile scroll bits (`scroll_x[2:0]`)
had nowhere to go, so the court scrolled in visible 8px jumps. We tried several
shift-register schemes to bolt fine scroll onto the serializer; every one hit a wall
(left-edge priming garbage, and a tilemap-vs-sprite latency mismatch) **because the
serializer renders inline with the display** — there is no slack to delay a pixel by
a sub-tile amount without disturbing everything downstream.

Two sprite bugs were also present the whole time but invisible until the demo
actually scrolled: **h-flip was never applied**, and **sprites sat ~16px too low**.

### The approach: adopt the proven 007121 line-buffer mechanism (sibling chip)

jtcores already ships a JTFRAME-native, Furrtek-grounded **007121**
(`cores/contra/hdl/jtcontra_gfx*.v`) used by 6 cores, driving the **same 007327
palette** ddribble uses. The 005885 and 007121 are sibling Konami tile+sprite chips.
We adopt the 007121 *mechanism* into our ground-up 005885 (NOT the chip itself —
directly adapting 007121->005885 was already tried and failed, see the
`007121_005885` attempt in the tree).

### Tilemap: direct serializer -> double-buffered line-buffer renderer

`jtddribble_k005885.v`: an FSM now renders the **whole scanline into a
double-buffered line buffer** (`u_tm_line`), writing each pixel at the
**fine-scroll-offset column**:
- `tm_hn = {scroll_ctrl[0], scroll_x}` — sets the starting tile + 4px half (the
  coarse + bit-2 fine).
- `tm_hrender = TM_HSTART - scroll_x[1:0]` — the sub-4px fine offset on the write
  address.
- The display reads the buffer back at the screen column (`obj_dcol`), one line
  behind (`tm_vpos = v_cnt+1`); the buffer's 1-line latency cancels the lead.

**Why this is the correct fix and the serializer never could be:** decoupling render
from display makes fine scroll *the write address*. That gives the full 0..7px
sub-tile scroll for free, removes edge-priming (the line is fully built before it is
shown), and auto-aligns with the sprites (which were already a line buffer,
`jtframe_obj_buffer`). The render FSM mirrors the sprite engine and time-shares the
VRAM scan + gfx ROM ports with it (tilemap in the non-obj window `h_cnt<272`,
sprites in `obj_win>=272`).

Gotcha that cost a sim: the tile **CODE byte is at scan `sel=1`, the ATTR byte at
`sel=0`** (confirmed against the scene VRAM dump — our first cut read them swapped,
producing a full screen of "0" glyphs). Verified: FG text pixel-exact (scenes
300/600), gameplay correct (2700), and a sim-only `-d SIM_SCROLLX=N` hook proved
`scroll=4 -> +4px` in logical space, linear/smooth. (The "2x" we saw at first was a
red herring — the sim PNG is 512px = 2x logical, so a raw-PNG measurement doubled
it; see the `reference_sim_png_2x` memory.)

### Sprite h-flip: latched but never applied

`s_fx` (flipx, byte4 bit5) was latched and then ignored. The 007121
(`jtcontra_gfx_obj.v:175` `pxl_data <= hflip ? pxl_data>>4 : pxl_data<<4`, `:185`
the code/h4 column decrement) and the 005885 reference (`lx = sprite_width ^
{5{hflip}}`) both **mirror the gfx column** on hflip. We get the identical result by
mirroring the **line-buffer write position** instead — one line:
`hp_scr = s_fx ? (obj_w-1-spr_hp) : spr_hp`. Flipping the screen write address
reverses both the sub-tile order and the intra-tile pixel order at once.

### Sprite Y: ~16px too low (basket off its pole, cheerleaders inside the court)

The 007121 maps the sprite Y byte **straight onto the render row** —
`jtcontra_gfx_obj.v:122` `vsub = (vrender - Y) ^ vflip`, **no offset**. Our
`OBJ_DY=15` added a spurious offset; combined with the tilemap's `v_cnt+1`
render-ahead and the sprite buffer's 1-line latency, sprites ended up `15+1=16px`
too low. Fixed to the same render-ahead basis the tilemap uses: `OBJ_DY=1`
(`vrr = v_cnt + OBJ_DY = v_cnt+1`). User-confirmed correct height in the demo.

### Grounding principle (reinforced this session)

**Ground sprite/video behaviour in the Furrtek 007121 + the 005885 reference
Verilog, not MAME.** MAME is the tie-break only — and its driver facts are already
mirrored locally in `doc/005885_sprite_format.md` / `doc/005885_implementation.md`,
so there is never a reason to fetch the .cpp from the web.

### Left-edge wrap — SOLVED (first-pixel read-pipeline wrap, not a tilemap torus)

Symptom: as the court scrolls, the leftmost column shows right-edge content (the
playfield centre line + a sliver of the KONAMI logo); on the static POST screen the
same defect is a constant bright-green vertical line one pixel in. MAME shows neither.

The torus theory was **wrong** — it is not the 64-tile (512px) tilemap wrap. The
defect is exactly **one display column wide**, and it is the line-buffer **read
pipeline**, found by instrumenting the mixer:

- `tilemap_px` was `9` (→ `COL=0x19` → green) at **display col 0 only**; col 1+ clean.
- The read column was `tm_rdcol = obj_dcol + TM_HSTART + 2`, with
  `obj_dcol = h_cnt - HB_OPEN`. At `h_cnt` 12..13 — the two clocks **before** the
  display window — `obj_dcol` underflows and **wraps to 0xFE/0xFF**, so `tm_rdcol`
  becomes 0x106/0x107 (the line buffer's **right** edge, ~col 262/263). The read
  pipeline (1-cycle latency) then carries that right-edge value into the **first**
  displayed pixel. On the POST screen the right-guard tile is a uniform green; in the
  scrolling court it is whatever sits at the right edge → the "left wrap."

Fix (jtddribble_k005885.v): derive the read column straight from `h_cnt`:

```
wire [8:0] tm_rdcol = h_cnt - TM_HSTART;
```

This is **algebraically identical** inside the display window — `HB_OPEN−TM_HSTART−2 =
14−6−2 = 6 = TM_HSTART`, so `h_cnt−TM_HSTART = (h_cnt−HB_OPEN)+TM_HSTART+2 = obj_dcol+
TM_HSTART+2` for `h_cnt ≥ HB_OPEN` — but the pre-display columns now count **down**
cleanly to the real left edge instead of wrapping high, so the first pixel reads valid
left-edge data. Verified by re-probing the mixer: `tile_px=0`, `COL=0x10` (backdrop) at
col 0 on every line; the green column is gone.

Note: the **sprite** line buffer reads at `obj_dcol` too, so a sprite sitting at the
extreme right edge could still bleed one pixel onto col 0 by the same mechanism — not
observed on the POST screen (no edge sprites); revisit if a demo capture shows it.

Final sim verification: the POST screen is now **byte-exact with MAME** — lit-pixel
count 4426 vs MAME's 4426 (was 4566 with the stray green column). All 7 working
scene diffs regenerated clean.

### Milestone — ready for hardware play-test (2026-06-17)

The four video items the smooth-scroll demo surfaced are done and validated in sim:

1. Smooth sub-tile horizontal scroll — 007121-style line-buffer tilemap (fine scroll
   = line-buffer write address).
2. Sprite h-flip — mirror the line-buffer write column.
3. Sprite Y position — OBJ_DY=1 (render-ahead basis, no spurious offset).
4. Left-edge wrap — first-pixel line-buffer read derived from `h_cnt` (no obj_dcol
   underflow into the right edge).

Moving to MiSTer hardware play-test next. Known sim-only caveats carried forward:
sprite right-edge → col-0 bleed (above), and the sprite-engine bring-up items still
tracked in STATUS.md.

### Sprite flicker / dropped rows — pipeline the OBJ-RAM reads (2026-06-18)

**What was wrong.** On busy lines the sprite engine dropped sprites and whole
16-px sprite rows — visible flicker both on MiSTer hardware and in the 4500-frame
sim. Bandwidth-independent (the Verilator SDRAM model has ~no latency, yet the
flicker still showed), so it was the on-chip scan loop, not SDRAM contention.

**How we found it.** Counted the sprite FSM's cycle cost against the fixed scan
window `obj_win = h_cnt >= 272` (~896 clk). The FSM read the five OBJ-RAM
attribute bytes (offsets 4,2,0,1,3) **sequentially**, each paying the full BRAM
read latency via `obj_wait 0→1→2` (~3 clk/read ≈ 15 clk just on reads, ~41 clk for
a full 16-px sprite). That fits only ~21 sprites; the BG list is 64 (FG 25), so
busy lines overran the window and the tail of the list was never drawn.

**The fix (jtddribble_k005885.v sprite FSM).** Pipeline the five reads: issue the
byte addresses back-to-back and capture each datum as it leaves the BRAM, driven by
an `obj_rp` phase counter instead of the per-field `obj_wait`. ~15 clk of reads →
~6 clk; off-scanline sprites skip in ~5 clk. The address-issue schedule is
unchanged — only the read latency is hidden — so far more sprites fit the window.

**The trap that cost a wrong attempt — VRAM latency is 1, not 2.** The first version
assumed a **2-cycle** read latency and captured at phases 2,3,4,5,6. That scrambled
*every* sprite (it read the next address's byte into each field). The VRAM is
`jtframe_dual_ram` — a **single**-register read (`qq1 <= mem[addr1]`), so latency is
**1**: `q1@N = mem[addr@N-1]`. The *original* sequential FSM masked this because it
held each address stable for 3 clk (over-waiting), which returns the right byte at
any latency 1–2; the pipeline does **not** hold the address, so the exact latency
matters. Corrected to capture at phases 1,2,3,4,5 (size / Y / code-lo / colour / X)
with the `y_hit` early-out at phase 3 — byte-identical to the sequential reads, just
overlapped.

**Verification.** 4500-frame full sim → MP4; sprites render clean through the
attract/demo (user-confirmed). Throughput fix only — the Verilator model can't show
the hardware speedup, but byte-correctness is proven and the dropped-row symptom is
gone in sim.

### Joystick directions diagonally swapped — wrong JTFRAME_JOY macro (2026-06-18)

**What was wrong.** On MiSTer the pad directions were rotated: UP read as RIGHT,
DOWN as LEFT (and vice-versa) — a diagonal swap, not a clean inversion.

**How we found it.** Full schematic trace of the input mux (page 1, `tile_p1_r1c0`),
confirmed by reading the MD0..MD7 net labels directly:

```
P1 read (0x2801, LS253 G3/F2/G4/G5 select=1 = the 1P column):
  MD0=1P-LEFT (D02→G3 1C1)   MD4=1P-SHOOT1 (D42→G4 1C1)
  MD1=1P-RIGHT (D12→G3 2C1)  MD5=1P-SHOOT2 (D52→G4 2C1)
  MD2=1P-UP   (D22→F2 1C1)   MD6=1P-SHOOT3 (D62→G5 1C1)
  MD3=1P-DOWN (D32→F2 2C1)   MD7=+5V (unused at P1; =D71/DIPSW1.8 at 0x2800)
```
Net suffix = LS253 C-index = read address: `_1`=C0=DSW1 (0x2800), `_2`=C1=P1 (0x2801),
`_3`=C2=P2 (0x2802), `_4`=C3=system (0x2803). All active-low (005273 pull-ups).

So the schematic byte is bit0=LEFT, 1=RIGHT, 2=UP, 3=DOWN — and the HDL `p1_bytes`
layout in `jtddribble_game.v` **already matched it**. The bug was upstream: the
`JTFRAME_JOY_*` macro that reorders the raw MiSTer stick into `joystick1`.

**The fix (cfg/common.def): `JTFRAME_JOY_DURL` → `JTFRAME_JOY_LRUD`.** Traced through
the JTFRAME reorder equations (NOT the macro names — those are misleading):
- Raw MiSTer stick (jtframe `doc/inputs.md`): `joy_in` = [0]=right, [1]=left,
  [2]=down, [3]=up.
- HDL builds `p1_bytes` bit{0,1,2,3} = `joystick1{[3],[2],[1],[0]}`, so it needs
  `joystick1` = {[0]=DOWN,[1]=UP,[2]=RIGHT,[3]=LEFT} (exactly what game.v's comment
  always claimed it wanted).
- `JOY_DURL` = `{joy[2],joy[3],joy[0],joy[1]}` → joystick1 {[0]=LEFT,[1]=RIGHT,[2]=UP,
  [3]=DOWN} → pad ends up UP↔RIGHT, DOWN↔LEFT (the observed diagonal swap).
- `JOY_LRUD` = `{joy[1:0],joy[3:2]}` = `{joy[1],joy[0],joy[3],joy[2]}` → joystick1
  {[0]=DOWN,[1]=UP,[2]=RIGHT,[3]=LEFT} ✓. The comment described the *goal*; the wrong
  macro was reaching for it.

**Not the board / not analog.** The schematic side was already correct, so no HDL bit
layout changed. Double Dribble is digital-only (switches→005273→LS253→sub CPU, no
ADC); the core never reads analog, so analog-stick jitter is a MiSTer mapping concern
(map the d-pad / raise the OSD dead-zone), not something gateable in the core.

**Noted, left as-is:** buttons map B1→SHOOT1, **B3→SHOOT2, B2→SHOOT3** (bit5/bit6
swapped vs a straight mapping) — looks like a deliberate pad-feel choice, every action
still gets a button. Revisit if it plays wrong.

Lint clean. Pending hardware (or scripted-input sim) confirmation.

### Sprite right-edge cut, left col-0, and 1px-right offset (2026-06-18)

Committed in `672ef654b`. Two sprite-engine edge bugs, both found and graded
with the `tools/scenesim/` harness (scenes `mame_02700` / `mame_02400`).

**1. Right ~12px of every sprite cut off + a dirty col-0 on the left.**
The sprite line-buffer (`jtframe_obj_buffer`) erases each column `BLANK_DLY`
cycles after it is read, on the *read* bank. The read enable was wired
`rd = pxl_cen` — asserted EVERY pixel, blanking included. `obj_dcol = h_cnt-14`
is an 8-bit subtraction that **wraps mod-256**, so during early blanking
(h_cnt 2..13) it revisits buffer cols 244..255 and erased them **before** they
were displayed at h_cnt 258..269 → the right ~12px showed blank (clean cut).
The same wrap touched col 0. Fix: gate the erase to the visible window,
`rd = pxl_cen & ~hblank`, so each column is read+erased exactly once, as it is
shown. (Contra uses always-on `rd` and is fine only because its read address
never pre-visits; ddribble's wrap does. Verified before/after: the render diff
landed on *exactly* logical cols 245..255 + col 0, nothing else.)

**2. Sprites sat 1px right of MAME.** Cross-correlated the `mame_02700` player
sprites (edge-map SAD over a shift search) = **dx +1**, consistent across two
regions, dy 0. The tilemap is positionally correct — the static scenes
`mame_00300` (MAE 0.0, perfect), `mame_00600`, `mame_01500` all measure **dx 0**
on the full frame — so the offset is **sprite-only**. Fix: shift the sprite
screen column 1px left, `full_col = (s_xpos + hp_scr) - 1` (the tilemap is the
reference and is already right). Re-simmed + re-measured → sprites **dx 0**.

Both are read-side only (no SDRAM bank rebuild). The "halo" seen alongside these
was NOT the core — it was `tools/scenesim/build_diffs.py` downscaling the 2x FPGA
frame with LANCZOS; the raw FPGA frame is a clean integer-pixel 2x (0% non-uniform
2x2 blocks). Tooling fixed separately to compare at FPGA-native res with NEAREST.

### Gameplay 4× too slow — CPU cen fed the E rate, not 4×E (2026-06-19)

**Symptom (hardware):** gameplay and boot run ~4× too slow.

**Cause:** the three MC6809E run on `jtframe_sys6809 #(.RAM_AW(0))` — i.e. the
**default `CENDIV=1`, which divides the input cen by 4** (the 6809wait makes the
bus/E enable = cen/4, with RECOVERY for the SDRAM-gated wait). But `mem.yaml`
generated the cpu cen at **1.536 MHz (the E rate)**, so the actual bus ran at
1.536/4 = **0.384 MHz — 4× too slow.** Confirmed against contra, which uses
`CENDIV(0)` and feeds the rate directly.

**Fix:** feed 4×E. `mem.yaml` cpu cen `freq: 1536000 → 6144000` (24.576 MHz clk24
/ 4 = 6.144 MHz); `CENDIV=1` then divides to the real 1.536 MHz E. (Tried
`CENDIV=0` + 1.536 first — it BROKE the CPUs: `CENDIV=0` implies `RECOVERY=0`,
which fights ddribble's SDRAM-gated cen; the sound CPU stalled. So keep
`CENDIV=1` and feed 4×E.) The video gets the same cen and over-samples the CPU
bus by 4× exactly as before — unchanged/harmless.

**Verified in sim:** at frame 200 the game is now deep in attract (69k YM2203
writes, sound banks 0–4 cycling, 179 main-CPU PCs) where the old 0.384 MHz timing
only reached attract ~frame 337.

### Still open

- **Sprites lag the BG by 1px during scroll** (hardware, e.g. cheerleaders) —
  catch up 1px at a time. Looks like a 1-frame OBJ-RAM/scroll latency in the
  sprite path vs the line-buffer tilemap. Next: compare sprite-vs-tilemap render
  timing during scroll against MAME; check whether the OBJ engine reads OBJ-RAM a
  frame later than the tilemap samples the scroll register.
- Sprite-engine right-edge → col-0 bleed (above), if a capture surfaces it.
- **Ground the 1px sprite offset against the die, not MAME.** The `full_col − 1`
  in `672ef654b` is correct *output* (sprites now match MAME, and the sprite-vs-tile
  offset is a real internal 005885 property — not on the board schematic), but it
  was set empirically by matching MAME, and the −1 is a coordinate nudge that
  compensates a latency mismatch between *our* two line buffers (sprite =
  `jtframe_obj_buffer` with its `BLANK_DLY` read pipeline + obj_dcol=h_cnt−14;
  tilemap = plain `dual_ram` + tm_rdcol=h_cnt−6). TODO: read the sprite-X vs
  tile-X paths in `doc/k005885_REFERENCE.sv` + `doc/furrtek_007121_schematics.pdf`,
  confirm whether the die's intrinsic sprite/tile offset equals our −1, and move
  the compensation to where the die puts it (or confirm −1 is faithful) instead of
  a bare `full_col − 1`.

### Audio investigation (2026-06-18..19) — VLM voice-ROM read CS misrouted (FIXED); read-handshake starvation still open; FM mute is correct

Deep diagnostic pass (instrumented YM2203 status + VLM5030 internals, both
`SIMULATION`-only in `jtddribble_sound.v`; compared against MAME). **Ruled out a
chain of wrong theories** and localized the voice bug precisely.

**NOT the cause (all measured):**
- YM2203 timer/tempo — works perfectly (status TB flag toggles 5221×, /IRQ 2463×,
  CPU polls correctly). The driver's tempo clock is healthy.
- The scanline IRQ — forcing `.nIRQ(1'b1)` changed nothing.
- "FM never keys on" — **correct**: MAME's audiocpu also never keys on FM in
  attract (`keyON=0`); attract is genuinely FM-quiet. The mute people hear is the
  voice, not the music.
- Voice ROM missing — **loaded** (96% non-zero at 0x10000 of bank1).

**THE finding — the VLM5030 never reads the voice ROM.** Per-speech instrumentation
(`[VLMDIAG]`): every trigger is `bsy_cyc≈46  ME-low_cyc=0  rom_byte_max=00
audio=0..0` — the chip raises BSY for ~46 clk cycles, **never asserts `o_me_l`**
(never fetches a voice byte), synthesizes nothing, drops BSY. `jt12.raw` ≈ 4
non-zero samples / 1.69M; `test.wav` peak 0 (hard silence in sim). This ONE bug
explains both symptoms: no voice (nothing synthesized) AND the sound-CPU churn
(our BSY clears in ~2 µs instead of ~0.5 s, so the driver thinks each voice
finished instantly and retriggers — 16 triggers/4 s vs MAME's idle audiocpu).

**Independent of every obvious input** — `o_me_l` stays high with: phrase forced
to a real value (0x03), `i_tst1` 0 vs 1, `i_vcu` 0 vs driven, `i_clk` clk24 vs
clk48. So the bug is the VLM **start/control SEQUENCE** (RST → phrase-load → VCU →
ST handshake) not matching the gate-level model's expectation — NOT a single pin
or the clock domain.

**Kept fix:** `i_tst1` 1→0 (model-grounded: `ntst1vref=(i_tst1 nand i_vref)`, and
the working sbaskt/yiear VLM cores tie it 0). Not the voice blocker, but correct.

**UPDATE (2026-06-19) — root cause found + the real fix.** The "VLM never enters
ROM-read" was a *downstream* symptom. Forcing a clean START in sim (`-d
VLM_FORCE_START`) showed the VLM *does* try to read the ROM — and exposed the
actual bug:

1. **PRIMARY (FIXED): the SDRAM voice-ROM read CS was misrouted.** `game.v`
   `assign vlm_cs = sound_vlm_cs`, but `sound_vlm_cs` was the sound CPU's **0x3000
   write** decode (the data-latch strobe), NOT the VLM's `/ME` read request. So the
   SDRAM voice ROM was only fetched on CPU writes to 0x3000, never when the VLM
   actually asked for a byte → the chip asserted `/ME`, set its address, and stalled
   forever waiting for a byte the SDRAM was never told to fetch (`vlm_ok_cyc=0`).
   Fix: in `jtddribble_sound.v` the `vlm_cs` OUTPUT is now `~vlm_me_n` (the VLM read
   request); the 0x3000 data-latch strobe moved to internal `vlm_dlatch`. After the
   fix `vlm_ok` fires and the VLM enters ROM-read.
2. **Voice ROM confirmed correctly loaded.** Raw `690a04.bin` = `00 b8 01 c7…`; the
   SDRAM blob is word-byte-swapped (`b8 00 c7 01…`) and the framework's lane select
   serves `vlm_addr=0 → 0x00` = raw byte 0. Data path is good.
3. **Driver doesn't pulse `/ST` in attract** (only RST + data-OE toggle) — that is
   CORRECT (matches MAME's idle audiocpu); voice only fires in gameplay/service.

**STILL OPEN — the VLM never enters playback (NOT starvation).** After the CS fix the
forced-start VLM reaches its read state but `o_a` is frozen at 0, reading `0x00`
forever. Experiments that RULED OUT the obvious causes (all measured, 2026-06-19):
- **Not the clock domain** — `i_clk=clk` (48 MHz, SDRAM domain) vs clk24: identical
  (`o_a=0`).
- **Not the read-handshake starvation** — `vlm_ok` from the romrq is a 1-cycle pulse,
  so I latched it sticky (`vlm_ok_l` held from the pulse until /ME drops). That gave
  the VLM more clk ticks (29→43) and louder output (peak 12→4910) but `o_a` STILL
  stuck at 0 — so being clock-starved was not why it doesn't advance. (The 4910 is
  garbage synthesized from the stuck `0x00`, not voice. Reverted; keep as a candidate
  refinement, the pulsing `vlm_ok` is real but secondary.)
- **Not the START shape** — held ST vs a clean 0→1→0 pulse: identical.
- **Not `i_tst1`/`i_vcu`/phrase value** — all swept, no change.

So the chip is NOT entering its phrase-lookup/playback state: it sits reading address
0 and never advances. The forced harness (`RST → ST` with the phrase on `i_d` via the
`/ME` mux) is evidently NOT a faithful VLM5030 start — the phrase isn't getting into
the command register. The model is shared+proven in sbaskt, so the fix is to either
(a) replicate the EXACT VLM5030 phrase-load/start handshake (study the model's command
latch `latchh`/`eavcu` and the ST/VCU/data timing, or capture a working start in an
sbaskt sim), or (b) just **build for hardware** and let the REAL driver run the proper
start in gameplay/service-mode — the primary blocker (read-CS) is fixed, so voice may
well work there; the forced-test `o_a` stall is most likely a scaffold artifact.

The diag harness (YM2203-status, `[VLMDIAG]`, `[VLMRD]`, and the `VLM_FORCE_START`
forced-start) is committed but `SIMULATION`-only. Mixer resistor/gain values remain
a separate (real) task.

---

## 2026-06-19 — VLM5030 SPEECH SOLVED: RST/ST/VCU are active-high (closes the "never enters playback" item above)

The VLM "never enters playback / `o_a` frozen at 0 / reads `0x00` forever" was NOT a
clock-domain or read-handshake problem. It was **three inverted control pins.**

### How we found it

User traced the VLM5030 control pins on the detailed schematics (NOT the old doc/
images):

- **ST (pin 31) ← YM2203 IOA5, ACTIVE-HIGH, direct** — no `/`, no inverter, no gate.
- **RST (pin 40) ← IOA6, active-high**; **VCU (pin 32) ← IOA4, active-high**.
- **ME (pin 33) → MASK1M /CE direct** (no logic); **OSC1 = SCLK direct**.
- Data path: **LS374 (D7)** latches the sound-CPU bus on the **VDATA(0x3000)** strobe,
  `/OE = IOA7`; the VLM `D0-7`/`A0-15` wire straight to the MASK1M; **IOA3 = A16**.

Our HDL had inverted all three control pins (`vlm_i_start = ~vlm_st_n`, etc.) on the
wrong assumption that they were active-low (`/ST`,`/RST`,`/VCU`). The working
sbaskt/yiear cores feed the same gate-level model's `i_rst`/`i_start` **raw** — which
already confirmed active-high, had we matched them.

### Root cause

With the inversions, `i_start` was held **HIGH** the whole time (IOA5=0 → `~0=1`), so
the model never saw a clean ST **rising edge** to latch the phrase and begin; and
`i_rst` **re-asserted right after the phrase load** (`~IOA6` went high at the `0x00`
control write), resetting the chip and discarding the just-loaded phrase. The model
raised BSY but `o_a` never advanced.

### The fix — `jtddribble_sound.v`

Drop all three inversions: `vlm_i_rst = vlm_rst` (IOA6), `vlm_i_start = vlm_st`
(IOA5), `vlm_i_vcu = vlm_vcu` (IOA4) — all raw / active-high. Renamed the wires off
the misleading `_n` suffix.

### Verification — at the schematic-correct 24 MHz (the 48 MHz fallback was NOT needed)

3000-frame attract sim: **7 of 25 VLM speeches now read the full voice ROM and
synthesize** — `romB_max=ff`, `addr=00115..0a301` (sweeps ~40 KB), `audio=0..1023`
(full 10-bit range), bsy in the tens-of-millions of cycles. The remaining speeches
are the **phrase-0 init/null** calls (correctly silent — the reset handshake loads
phrase 0). The earlier "`data=0` / `addr=0`" reads I chased were ONLY those null
phrase-0 calls; **there was never a byte-lane bug** (the prior entry's point 2 about
the lane serving `0x00` was a red herring — that byte IS phrase-0's table entry).

A long debug detour this session wrongly suspected the FM key-on and the scanline IRQ
(both red herrings — MAME's attract has no FM and never touches the 0x6000 IRQ-ack),
then the clk24↔clk48 read path (also fine). Lesson: a 200-frame sim only ever catches
the phrase-0 null calls; the real voices need a long run (≥~500 frames) to appear.

### Also landed 2026-06-19 (sound-CPU clocking)

- **CPU ran 4× too slow (9209c90f5).** All three MC6809E use `jtframe_sys6809` with
  default `CENDIV=1` (divides the input cen by 4 to make the E/bus enable), but
  `mem.yaml` fed the cen at 1.536 MHz (the E rate) → the bus ran at 0.384 MHz. Fix:
  feed **4×E = 6.144 MHz** so the `/4` lands on the real 1.536 MHz E. (`CENDIV=0` was
  tried and REVERTED — it forces `RECOVERY=0`, which fights the SDRAM-gated cen.)
- **Sound CPU decoupled onto its own gated cen (795f562a6).** The three CPUs shared
  one `cpu_cen` gated by `[main,sub,snd]` together, so the sound CPU lost a cycle on
  every main/sub SDRAM fetch. Split: main+sub+video keep `cpu_cen` (`[main,sub]`); the
  sound CPU gets its own `sndcpu_cen` (`[snd]`). On the real PCB the sound CPU is an
  independent clock domain — it never stalls for main/sub bus traffic.

Commits: `9209c90f5` (speed), `795f562a6` (VLM voice + gate decoupling).

---

## 2026-06-19 — Controls broken: all inputs were inverted (game read every direction pressed)

### Symptom
On hardware the player wouldn't walk — pushing the stick made it pivot/spin in
"random directions unrelated to the stick", and coin/start felt flaky. Visible only
once the 4×-speed fix made the game playable enough to actually try the controls.

### How we found it
First *ruled out* the input MAPPING by checking it against MAME (WebFetch of the
pinned `ddribble.cpp`): addresses `0x2800=DSW1 / 0x2801=P1 / 0x2802=P2 / 0x2803=SYS`,
P1 bits `L/R/U/D @ 0..3` (KONAMI8_B132), read by the **sub** CPU, `JTFRAME_JOY_LRUD`
reorder — **all correct**. So it wasn't a wiring/bit-order bug. Then a gameplay input
sim: a `.cab` driving coin→start→hold-UP plus a `[SUBIN]` probe on the sub's P1 read.
The probe showed the sub reading **P1 = 0x80 on every poll** — all four directions
AND all buttons = 0 = *pressed* (active-low) — and it never changed even with UP held.

### Root cause
`game.v` wrapped all three input bytes in `~`: `p1_bytes = ~{...joystick1...}`.
But **JTFRAME delivers `joystick1`/`joystick2`/`coin`/`start`/`service` ACTIVE-LOW**
(1 = not pressed) and the game reads them active-low, so they must pass **straight
through** — the shipped kicker/contra cores do `{2'b11, joystick1[5:0]}`, no `~`
(note `game_joystick1[9:7]=3'b111` ties unused buttons to 1 = not-pressed = active-low).
Our `~` flipped idle (all-1s) into all-pressed (0x80): the game saw every direction
held at once, couldn't resolve a walk vector → erratic pivoting; coin/start hit by the
same inversion on the SYSTEM byte.

### The fix — `jtddribble_game.v`
Drop the `~` on `p1_bytes`/`p2_bytes`/`sys_byte`; tie the unused bits to 1. Idle now
reads `0xFF`, a single direction reads e.g. `0xFB` (UP).

Lesson: a correct address map + bit order can still be 100% broken by input
**polarity**. JTFRAME inputs are active-low — pass them through, don't invert.

Commit: `cf0117697`.

---

## 2026-06-19 — Audio quality: un-muffle + set the real schematic mixer balance

### Symptom
After the VLM-voice and speed fixes, audio plays but "pitched really low, wrong
instrument / wrong everything" — music muffled, voice mushy.

### Root cause 1 — placeholder RC filters muffled everything
`mem.yaml` had two stacked low-pass filters with absurd cutoffs: a per-channel FM/PSG
RC `r:2k c:100n` = **796 Hz**, AND a final-mix RC `r:1k c:100n` = **1.6 kHz** applied
to the *whole* mix (voice included). That stripped every FM harmonic → muffled, "low",
wrong instruments. Fix (`866490e54`): removed the per-channel FM/PSG LPF (the shipped
cninja YM2203 core filters neither), raised the final LPF to ~16 kHz (`c:100n→10n`).

### Root cause 2 — placeholder mixer gains were all equal
`rsum: 220` for every channel = equal weighting, which is wrong. Traced the real mixer
from the user's page-1 schematics:
- Final op-amp = **LA6358**, feedback **R3 = 10K**.
- **FM** (YM-3014 DAC → UPC324 #1) → **R6 = 3.3K**.
- **SSG** (YM2203 CHA/B/C → UPC324 #2 pin14) → **R9 + C17 + R10 → R7**: R9/R10 (1K each)
  are in series on the SSG output with C17 (0.033µF) as the shunt, so the summing
  resistance is **R9+R10+R7 = 7.6K** (SSG ~2.3× quieter than FM) and the LPF is
  R9·C17 ≈ **4.8 kHz**. (First cut wrongly split R9→FM / R10→SSG; user corrected it.)
- **VLM** → **R8 = 3.3K** *plus a 5.1× pre-amp* (UPC324 R17/R22 = 24K/4.7K) because the
  VLM5030 DAC output is tiny.

Fix (`34d988431` + `bad89027a`): set `rsum` to the schematic input resistors
(`fm 3.3k`, `psg 7.6k`), feedback `rsum 3.3k`, and boost the voice (`vlm 1.5k`) to
stand in for the pre-amp the static mixer can't model. Added the SSG `r:1k c:33n`
(R9·C17) LPF.

### Caveats / open
- The FM:SSG **ratio** (3.3K:7.6K) is schematic-exact; the **absolute level** and the
  **voice boost** are by-ear tuning knobs (JTFRAME normalizes chip levels differently
  than the real DACs). Nudge `vlm rsum`/`psg rsum`/`fm rsum` (lower = louder) per a
  hardware listen.
- The **4066 (D5)** runtime-switched SSG filter (~480 Hz, gated by YM2203 IOA[2:0]) is
  dynamic and can't be modelled in the static JTFRAME mixer — left out; some SSG
  effects may sound a touch brighter than the real board.
- The two UPC324 FM/SSG **pre-amp gains** are not separately accounted for (assumed
  absorbed by JTFRAME's normalization) — revisit if the by-ear balance stays off.

Commits: `866490e54` (un-muffle), `34d988431` (schematic balance), `bad89027a` (SSG R fix).

---

## 2026-06-21 — VLM5030 voice played at half speed (slow / low pitch): shared cen halved it

### Symptom
The VLM5030 speech (the sung anthem) played **too slow and ~an octave low**, while the
YM2203 music sounded fast against it. Confirmed only after running the sim the **full
~120 s** — the anthem needs the long run; a 40 s sim cut it off and looked "stuck",
which sent me chasing phantom sub→sound command-path bugs (it wasn't one).

### How we found it
Instrumented the sub→sound command mailbox (`[SNDSTROBE]` in `jtddribble_game.v`). The
command stream actually **matches MAME** (`78 8c` … `60 6e`), so the command path was
fine — the fault was a clock. Traced the generated cens in
`ver/game/jtddribble_game_sdram.v`.

### Root cause
`mem.yaml` had `- freq: 3579545 / outputs: [ym, vlm]`, which the codegen turns into
**one** `jtframe_gated_cen #(.W(2))`. That module **divides each successive cen output
by 2**, so `ym_cen` = cen[0] = 3.58 MHz (correct) but `vlm_cen` = cen[1] =
**1.79 MHz (HALF)** → the VLM5030 ran at half its OSC1 rate → slow / low-pitched voice.

### The fix
Split into **two separate `freq: 3579545` blocks** (`outputs: [ym]`, `outputs: [vlm]`),
each a `W=1` full-rate cen. Verified in the regenerated `_sdram.v`: two
`jtframe_gated_cen #(.W(1),.NUM(455),.DEN(3124))` instances, both 3.58 MHz. The
schematic confirms both chips get the full 3.58 MHz SCLK directly.

### Caveats / open
- The YM2203 clock was already correct (3.58 MHz); the "YM too fast" impression was the
  music running at correct speed against the half-speed voice.
- Voice is "mostly OK" now (user) — some output **filtering on the exit** still being
  tuned by ear.
- Gotcha: same-frequency chips need SEPARATE `mem.yaml` `freq` blocks, or the 2nd+
  outputs come out divided by 2.

---

## 2026-06-21 — YM2203 FM played too fast: jt03 clocked in the WRONG clock domain

### Symptom
The FM music (the anthem melody) played **too fast** — at the schematic 3.58 MHz it was
**~4×** MAME's tempo; a stop-gap half-clock (`ym_cen` = 1.79 MHz) brought it to **~2×**
("better but still too fast", per the user). The VLM5030 **voice was always correct** —
only the FM was fast.

### How we found it
Confirmed MAME's tempo from a YM register trace of the full anthem (`.inp` replay):
NB (reg 0x26) = **0xFA always**, TB reloaded **8.52×/frame** → TB period **1.93 ms**.
The driver writes **no** prescaler reg (0x2D/2E/2F) and **no** test reg (0x21), so
`div_setting` = ÷6 and `fast_timers` = 0, both at reset — jt12 at cen = 3.58 MHz
*should* give exactly 1.93 ms. So the bug had to be the **cen actually reaching jt03**.
A `[CENRATE]` probe (count clk-edges per `ym_cen` pulse + FM `snd_sample` ticks) proved
it: **2.000 clk-edges per cen pulse**, FM sample rate **99.4 kHz** (real chip = 49.7 kHz).

### Root cause
The `mem.yaml` `clocks:` block is keyed **`clk24:`**, so every cen — including `ym_cen` —
is generated by `jtframe_gated_cen` on **clk24** as a **1-clk24-wide pulse** (confirmed in
`ver/game/jtddribble_game_sdram.v`: `u_cen2_clk24 … .clk(clk24)`). But jt03 was clocked on
**clk48** (`.clk(clk)`). `jt12_div` counts `if(cen)` on **every** posedge clk, so a
1-clk24-wide pulse spans **2 clk48 edges** and was **counted twice** → jt12's internal cen
ran at 2× → at 3.58 MHz the doubling interacted with the operator scan to make the FM
**4×** fast. The **VLM never had this** because it is (correctly) clocked on `clk24`,
matching `vlm_cen`'s domain — which is exactly why the voice was right and only the FM fast.
(This supersedes the previous entry's note that "the YM clock was already correct" — it was
not; the YM was independently fast, masked at the time by the half-speed voice.)

### The fix
Clock jt03 on **clk24** (`jtddribble_sound.v`: `.clk(clk24)`), matching `ym_cen`'s domain
exactly like the VLM, and **restore the real 3.58 MHz** in `mem.yaml` (drop the 1.79 MHz
stop-gap — it was only masking the domain bug). With jt03 counting each cen pulse **once**:
- `ym_cen` = **3.58 MHz** (real schematic SCLK)
- FM sample rate = **49.7 kHz** (= real YM2203, measured)
- TB period = 3456/3.58e6 = **1.93 ms = MAME** (measured)

### Caveats / open
- jt03's CPU-bus inputs (`cpu_dout`/`A`/`ym_cs`/`cpu_rnw`) are clk48-domain, now sampled on
  clk24 — safe because clk24 = clk48/2 synchronous (same PLL) and the 6809E bus is stable
  for the whole ~651 ns cycle (the VLM already does the same clk48-write → clk24-read for
  `vlm_data_latch`).
- Sim validates the **rate/correctness** (cens are modelled accurately); it is NOT a
  bandwidth claim — final by-ear confirmation is the rendered anthem / hardware.
- The earlier "comsc half-clock / jt03 model quirk" framing was a **wrong diagnosis** — the
  real cause was the clk-domain mismatch, not a jt12 YM2203 model error.

### CONFIRMED (2026-06-21, by ear)
`test_ymfix.wav` (jt03 on clk24 + real 3.58 MHz) matches `mame_anthem_120.wav` — user
verdict: **"perfect"**. The clk-domain fix is the whole fix; nothing else was needed.

**Bottom line — what it actually was:** the YM2203 (jt03) was clocked on **clk48** while
its `ym_cen` enable is generated on **clk24** (the mem.yaml `clocks:` block is keyed
`clk24:`). `jt12_div` counts `if(cen)` on *every* posedge clk, so it saw each 1-clk24-wide
cen pulse on **two** clk48 edges and **double-counted** it → the FM engine ran fast. At the
real 3.58 MHz that ×2 compounded with the operator scan to ~**4×**; the earlier 1.79 MHz
"half-clock" cancelled one factor, leaving the **2×** the user heard as "better but still
too fast." The VLM5030 was always (correctly) on clk24 — which is exactly why the **voice
was right and only the FM was fast**.

**The whole fix (2 lines):**
- `jtddribble_sound.v`: jt03 `.clk(clk)` → `.clk(clk24)`
- `mem.yaml`: `ym` cen `1789772` → `3579545` (drop the half-clock; it only masked the bug)

Measured after fix: `ym_cen` = 3.58 MHz, FM sample rate = 49.7 kHz (= real YM2203),
TB period = 1.93 ms (= MAME). The "jt03 model quirk / comsc half-clock" framing in the
prior entries was a **wrong diagnosis** — the cause was the clk-domain mismatch.

**Cross-check (the slow-CPU experiment):** with the YM correct, dropping the SOUND 6809E to
the old wrong 0.384 MHz E (cen `1536000` → CENDIV ÷4) dragged the anthem out ~9× (onset
0.11/s vs 0.98/s). That proves the music tempo is paced by the **sound CPU + TB together**,
and confirms the FM clk-domain fix — not any CPU-clock change — was the correct lever.
(The sound CPU stays at `6144000` = 1.536 MHz E = MAME; the slow value was a test only.)
