# Arbalest — Fixes Journal

One entry per fix, newest at the bottom. Each entry tells future-me: 1) what was
wrong, 2) how we found it, 3) the fix and why it's right.

---

## 2026-06-22 — Quartus synthesis fails: sub `u_bank.dout` connected to `{bank,4'bx}`

### Symptom
The MiSTer hardware build (Quartus Analysis & Synthesis) aborted:

```
Error (10663): Verilog HDL Port Connection error at jtarbalest_sub.v(137):
  output or inout port "dout" must be connected to a structural net expression
Error (12152): Can't elaborate user hierarchy "...:u_sub"
```

Verilator lint (`./lint-core.sh arbalest`) passed clean — this only showed up in
Quartus.

### How we found it
The error names the exact line. `jtframe_8bit_reg u_bank` had
`.dout( {bank, 4'bx} )` — the `4'bx` "don't-care" literal padding the unused low
nibble. Verilator accepts an `x`-literal inside an output-port concat; Quartus
requires every output port to drive a real **structural net**, and `{bank,4'bx}`
is an expression, not a net. Grepped the rest of `cores/arbalest/hdl/*.v` for
other `'bx`/x-literal port connections — none.

### Root cause
`u_bank` latched the 0x1000 "ROM-bank + coin-lockout" write into `bank[3:0]`,
but **`bank` was never read**: the 8 KB sub ROM is mirrored across 0x6000-0xffff
(`rom_addr = {5'd0, A[12:0]}`), so there is no actual banking, and coin-lockout
is a no-op here. The whole register was dead logic whose only artifact was the
synthesis-illegal `4'bx` connection. The 0x1000 write's one live effect — acking
the sub IRQ — is `in_cs & cpu_wr` feeding `u_irq.clr`, independent of `u_bank`.

### Fix
Removed the dead `jtframe_8bit_reg u_bank` instance and the `wire [3:0] bank;`
declaration in `cores/arbalest/hdl/jtarbalest_sub.v`, leaving a comment that
banking/lockout are intentionally not implemented. No functional change (the IRQ
ack path is untouched); lint stays clean and the synthesis error is gone.

### Caveats / open
If real ROM banking is ever needed for an arbalest-family member, re-add the
latch and drive `rom_addr` from it — and connect `.dout` to a declared net, never
an `x`-padded concat. LESSON: Verilator lint does NOT catch Quartus structural-net
port errors; an `x`-literal in an output-port connection passes sim and fails the
hardware build.

Commit: fix(arbalest): drop dead sub bank latch — {bank,4'bx} fails Quartus synthesis

---

## 2026-06-23 — Inputs/coins dead — missing metafox main→sub control channel (sub_ctrl_w)

### Symptom
Neither metafox nor arbalest responded to any input in sim or on hardware. The
metafox title sat on "INSERT COIN" forever — inserting coins never registered a
credit, so START never worked and the game could never be played. (Audio was also
silent, consistent with the game never leaving the idle attract state.)

### How we found it
Long forensic chase; recording what was RULED OUT so the next session doesn't
re-walk it:
- Verified the sub READS the coin correctly: COINS port (0x1000) returns 0xff idle
  and 0x7f when COIN1 is injected (bit7 active-low). So the cabinet wiring, port
  decode (COINS@0x1000 / P1@0x1002 / P2@0x1006), and input polarity were all fine.
- Verified the sub ROM (single 8KB EPROM ROM_RELOAD'd across 0x6000-0xffff — banking
  is a no-op), the sub interrupts (NMI@240, IRQ@112), and the X1-017 protection
  formula (offset*0x1f + 3 specials) all match MAME exactly. None was the bug.
- Steady-state shared RAM (sub↔main) matched MAME at idle, so the shram address
  mapping (sub byte k ↔ main 0xb00000+2k low/odd byte, umask16 0x00ff) was correct.
- A clean same-frame MAME A/B (idle vs coin-held, deterministic) showed MAME credits
  a coin (shram 0x034/0x038/0x044 change) while the FPGA never set those markers —
  the break was main-side, in coin→credit, not in reading the coin.
- The smoking gun: the sub polls soundlatch 0x0800/0x0801 ~1396×/run but my sub
  returned the 8'hff default (lat_cs was decoded but never muxed into cpu_din).
  A MAME write-tap on 0xa00000-0xa00007 then showed the main ACTIVELY drives the
  channel: 0xa00000=0x14/0x15/0x1c (bit0 0→1), 0xa00004=0xff, 0xa00006=0xf1.

### Root cause
The entire metafox/arbalest **main→sub control channel** (`sub_ctrl_w`, 0xa00000-
0xa00007, umask16 0x00ff) was unimplemented:
- 0xa00000 bit0 rising = **pulse-reset the W65C02 sub** (the main resyncs the I/O
  handshake by restarting the sub). The FPGA never reset the sub, so the sub's
  handshake state diverged from what the main expected and the main never credited.
- 0xa00004 → soundlatch0, 0xa00006 → soundlatch1, read back by the sub at
  0x0800/0x0801. The FPGA fed the sub a phantom 0xff for every latch poll.

### Fix
Implemented the channel in `jtarbalest_game.v` and `jtarbalest_sub.v`:
- game.v: on a sub_ctrl low-byte write (`subctrl_cs & ~cpu_rnw & ~cpu_dsn[0]`),
  decode `cpu_addr[2:1]`: off0 captures bit0 and, on its rising edge, loads a
  reset stretcher (`subrst_cnt`, counted down at cen8) → `sub_rst = rst | cnt!=0`;
  off2→slatch0, off3→slatch1. `sub_rst` now drives `u_sub.rst`; slatch0/1 are new
  sub inputs.
- sub.v: `cpu_din` now returns `A[0] ? slatch1 : slatch0` for `lat_cs`
  (0x0800/0x0801) instead of 8'hff.

### Why we believe this is right
With the channel in place metafox runs the full input chain in sim: coins credit
(title flips "INSERT COIN" → "PUSH 1P 2P START BUTTON", frame 561), START begins
the game, and gameplay renders (frame 951: "1P 3000", the player ship over the
desert stage moving under cab control). Lint clean.

### Caveats / open
- arbalest (game_id=1) shares the identical channel and machine config so the fix
  applies, but its attract timing differs from the metafox-tuned cab — confirm with
  an arbalest-specific coin cab.
- Returning the empty latch as 0 alone did NOT fix it; the sub RESET is the load-
  bearing part. Soundlatch0/1 are now wired through but their exact role in the
  protocol is not fully characterised.
- Audio (X1-010, main bus) should be re-checked now that the game actually reaches
  play state — it was likely mute only because the game never left idle attract.

Commit: fix(arbalest): implement metafox main->sub control channel (sub reset + soundlatch) — fixes dead inputs

---

## 2026-06-23 — Parametrize vtimer visarea — metafox/arbalest are 224 lines, not calibr50's 240

### Symptom
metafox content looked vertically offset vs MAME, and in scene replay the whole
screen looked badly misplaced. The FPGA frame measured 384x240 while MAME's metafox
visible area is 384x224.

### How we found it
- Scene replay (`tools/scenesim`) can't grade this: the arbalest scene capture dumps
  VRAM/pal/yram/dma but NOT the X1-012 scroll/control registers (`vctrl_w` @0x800000),
  so the scrolled BG never lands where MAME has it — the compare stack was all red.
  RULED OUT scene replay for offset grading here.
- Graded via FULL sim instead (now that metafox boots — the CPU drives the scroll
  regs). Cross-correlated the full-sim title vs MAME `screen.png`: FPGA was 240 wide
  (portrait) vs MAME 224, best align at dx=+7 (and the leftmost FPGA columns were
  blank border) — i.e. the FPGA rendered ~16 extra vertical lines.

### Root cause
`jtcal50_video` was cloned for calibr50 and baked calibr50's vtimer visarea
(`VB_START=240, VB_END=0` -> visible lines 0..239 = 240, MAME set_visarea 8..247).
metafox/arbalest set_visarea is rows **16..239 = 224 lines** (same H visarea; only
the vertical window differs — arbalest's machine config calls `metafox(config)` and
overrides only sprite/tilemap X, not the screen). The size macro
`JTFRAME_HEIGHT=240` matched calibr50, so the testbench also errored
("video size mismatch ... core outputs 384x224") once the timer was corrected.

### Fix
- `jtcal50_video.v`: added vertical-visarea module parameters
  (`V_START/VB_START/VB_END/VS_START/VS_END/VCNT_END`) defaulting to calibr50's
  exact current values (calibr50 unchanged, lint confirms), and wired them into the
  `jtframe_vtimer` instance.
- `jtarbalest_game.v`: instantiate `jtcal50_video #(... .VB_END(9'd7), .VB_START(9'd231))`
  = 224 visible lines, refresh (VCNT_END) unchanged.
- `cfg/macros.def`: `JTFRAME_HEIGHT` 240 -> 224.

### Why we believe this is right
Full-sim title re-graded vs MAME `screen.png`: frame is now **224x384, byte-for-byte
matching MAME's dimensions**, and the cross-correlation X offset collapsed from +7 to
**0** (SAD 5.65). The META FOX logo overlays cleanly in that axis.

### Caveats / open
- A residual **+8 px native-horizontal** offset remains (in the portrait it shows as
  the "INSERT COIN"/copyright lines doubled top-to-bottom). This is NOT the visarea —
  it's the content-X position (tilemap `set_xoffsets` differs metafox(-19,16) /
  arbalest(-1,-2) / calibr50(-2,-3), plus sprite `fg_x`). The FPGA tilemap bakes
  calibr50's `+0x20` hpos and `HADJ=5`. Parametrize those next to finish alignment.
- Scene replay still can't reproduce the BG until the X1-012 MMR/scroll regs are
  captured+restored (separate task).

Commit: feat(arbalest): parametrize jtcal50 vtimer visarea — metafox/arbalest are 224 lines

---

## 2026-06-23 — X1-012 tilemap bank select used the wrong bit (4 instead of 3)

### Symptom
arbalest attract showed the wrong tilemap content — the demo/title background was
wrong ("something under the copyright that shouldn't be there") and the layered
title scene didn't match MAME. (Investigated while chasing the missing ARBALESTER
logo; this is a real, separate tilemap bug.)

### How we found it
Read MAME's X1-012 device (src/mame/video/x1_012.cpp). It is ONE tile layer with
TWO banks ("2 tilemaps, only one displayed"), bank = `vctrl[2] & 0x0008` (bit 3);
bit 4 (0x10) is the color/gfx mode. The generated `jtx1012_mmr.v` had
`assign bank = mmr[4][4]` — bit 4, the color-mode bit, not the bank. Source
`cal50/cfg/mmr.yaml` had `bank: at "4[4]"` with a `# other bits unknown` comment —
a guess. A MAME write-tap on the vctrl regs (0x800000-5) confirmed arbalest's title
runs with `vctrl[2]=0x0009` (bank bit 3 SET, color 0) and an X-scroll ramp
0x00->0xc6, Y=0x60.

### Root cause
The FPGA watched bit 4 for the bank, so when the game selected bank 1 (vram 0x1000)
it never switched, rendering bank 0's tiles instead.

### Fix
`cores/{arbalest,cal50}/cfg/mmr.yaml`: bank `at: "4[4]"` -> `"4[3]"`. The
`jtx1012_mmr.v` is gitignored and regenerated by `jtframe mmr` on every sim/build.
After the fix, tiles-only sim correctly shows the bank-1 title scene.

### Caveats / open
- The **ARBALESTER logo is still missing** — but layer-isolation (`-gfx 1` tiles /
  `-gfx 8` sprites) proves it is NOT on the tilemap: the title tilemap pans
  horizontally (X-scroll ramp) while the logo stays fixed, so the logo is SPRITES,
  and those specific sprites are dropped. Next: the X1-001 setac / 2-buffer
  (OBJAW=13/SETAC=1) handling.
- The FPGA does not apply MAME's `y = vctrl[1] - (256-vis_dimy)/2` (16px for a
  224-line game) — a small separate vertical-scroll refinement.
- bit 4 (color/gfx mode, `vctrl[2]&0x10`) is still unhandled in the FPGA; metafox/
  arbalest title runs color mode 0 so it doesn't bite here.

Commit: fix(arbalest): X1-012 tilemap bank is vctrl[2] bit3 not bit4

---

## 2026-06-26 — X1-010 PCM silent — `end`-register 8-bit wrap key-off (no audio)

### Symptom
metafox/arbalest produced no sound at all. A 5000-frame `test.wav` measured −91 dB
(digital silence). The game had clearly reached play state (coins, attract), so the
sound command path was alive — but the X1-010 never emitted a sample.

### How we found it
Traced MAME's X1-010 bus accesses first (audio bring-up rule). Findings, in order:
- The chip is byte-accessed: each X1-010 register = one 68000 *word*, so the FPGA
  register index = `cpu_addr[13:1]` (already correct). Data sits on D[7:0]; metafox's
  frequency write lands on the even/high lane but the 68000 model broadcasts the byte
  to both lanes, so `cpu_dout[7:0]` still carries it (probe confirmed `delta=04`).
  → **byte lane was NOT the bug** (the long-standing STATUS suspicion was wrong).
- Probed the FPGA sound path: writes reach the chip, **keyon fires (ch15 val=01)** and
  `cen_pcm` runs — yet output stayed 0. So the kill was *inside* the PCM playback FSM.
- Probed `jtx1010_pcm`: metafox writes only channel regs 0,1,2,4 (status/volume/
  frequency/start) and **never writes reg 5 (`end`)**, relying on the hardware
  `end=0 → full 0x100-page range`. MAME does the same: `end_addr=(0x100-end)<<12`.

### Root cause
`jtx1010_pcm.sv` kept `finish` as 8 bits: `finish <= -cfg_data` and
`if(rom_addr[19:12]>=finish) keyoff`. With `end=0`, `-0 = 0x00`, so the very first
page compare (`start=0x60 >= 0`) was true → **instant key-off every sample** → silence.
The 8-bit negate cannot represent MAME's 9-bit end page `0x100`.

### Fix
Widen the end page to 9 bits and form the sample address as a 21-bit sum so the
top-of-range carry survives:
- `reg [8:0] finish;  finish <= 9'h100 - {1'b0,cfg_data};`  (end=0 → 0x100)
- `wire [20:0] full_addr = {1'b0,start,12'd0}+{5'd0,cur[19:4]};`
- `rom_addr <= full_addr[19:0];  if(full_addr[20:12]>=finish) keyoff;`
For `end!=0` the 9-bit compare is bit-identical to the old 8-bit one, so no other
game (cal50/calibr50 shares this module) changes behaviour.

### Why we believe this is right
After the fix the probe shows `finish=100`, `delta=04`, `start=60` (all matching
MAME's ch15 config) and PCM reads `00 fe fe fe fe fd fd fd fd fd` at 0x60000 —
**byte-identical** to the metafox x1snd ROM (`up001015`@0x60000). `test.wav` jumped
from −91 dB to −22 dBFS peak / −41.8 dBFS RMS, stereo, with real sample content.

### Caveats / open
- This is the shared `modules/jtx1010/hdl/jtx1010_pcm.sv`; the fix is in the shared
  module (only arbalest + cal50 use it; cal50 lints clean and is unaffected for end!=0).
- Levels/voicing not yet A/B-graded against the MAME reference WAV
  (`cores/arbalest/doc/` capture); the silence is fixed and the samples are
  byte-accurate, but mix balance vs MAME is a later polish step.

Commit: fix(x1010): PCM silent — end-register 8-bit wrap caused instant key-off
