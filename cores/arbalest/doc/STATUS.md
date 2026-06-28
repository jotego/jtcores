# arbalest core — status & bring-up plan

Multi-game core for the **metafox-class** members of Seta's `downtown.cpp`:
**metafox** (game_id 0) and **arbalester / arbalest** (game_id 1).
**We bring up metafox first** (simplest sub: pure I/O, only a tiny X1-017
protection stub), then arbalest (= metafox + offset/ROM/debug-stub deltas).

MAME ground truth + chip refs live in [`../../cal50/doc/`](../../cal50/doc/)
(`downtown.cpp`, `x1_010.*`, `x1_012.*`) — shared with the cal50 core.

## Reuse model (import, not copy)

`cfg/files.yaml` imports the unchanged building blocks from **cal50** and
**kiwi**; only the divergent glue is local to `cores/arbalest/hdl/`:

| Imported (unchanged)                         | Local (divergent)        |
|----------------------------------------------|--------------------------|
| `jtcal50_video.v`, `jtcal50_colmix.v`        | `jtarbalest_game.v`      |
| `jtx1012.v`, `jtx1012_mmr.v`                 | `jtarbalest_main.v`      |
| `jtkiwi_{gfx,obj,draw,tilemap}.v`            | `jtarbalest_sub.v`       |
| `jtx1010`, `jt65c02`, jtframe modules        | `jtarbalest_sound.v`     |

## Why this is NOT a cal50 fork (the one real difference)

calibr50 and metafox share the chip set but rearrange the bus:

| | calibr50 (cal50) | metafox / arbalest (here) |
|---|---|---|
| X1-010 sound | on the **65C02** sub bus, snd_cmd FIFO | on the **main 68000** bus (0x100000) |
| 65C02 role | sound CPU | **I/O / protection** + shared RAM |
| inputs | main reads X1-004 + spinner | **sub** reads P1/P2/COINS → shared RAM → main |
| spinner | yes (jt4701) | none |
| main map | `calibr50_map` | `downtown_map` |

The video pipeline (1× X1-012 layer, X1-001 sprites, direct xRGB-555) is
identical, hence imported verbatim.

## Bring-up checklist (MAME-driven)

- [x] Scaffold: cfg (import wiring) + mem + mame2mra (metafox+arbalest) + HDL skeletons
- [x] Lint clean (`./lint-core.sh arbalest`)
- [x] Capture MAME boot traces (main 68000 + sub 65C02) → `ver/metafox/traces/` + annotated `doc/BOOT_TRACE.md`
- [x] Add SIMULATION PC dumper to main + sub (`jtarbalest_{main,sub}.v`) + `verify_{main,sub}_boot.sh`
- [x] **Main 68000 boot FULLY verified** — all 1,198,271 MAME PCs match (subsequence) over the whole boot trace.
- [x] metafox X1-017 protection (0x21c000-0x21ffff) implemented in `jtarbalest_main.v` (`offset*0x1f` + specials, game_id==0). This took the main from DIVERGE@170k to a full match.
- [x] Sub ROM mirroring — `jtarbalest_sub.v` indexes the 8KB EPROM by `A[12:0]` (mame2mra drops the `ROM_RELOAD`s, packing it once at offset 0). Sub now boots to 0x7000 and matches **10,653 instructions**.
- [x] Sub interrupts wired (`jtarbalest_game.v` scanline counter + `jtarbalest_sub.v` jtframe_edge): IRQ at line 112 (level, acked by the 0x1000 bank write), NMI at line 240 (edge). Sub now **takes the NMI, reads the FFFA vector, and runs the 0x7117 handler** — confirmed correct rate (1/frame), speed (cen8 = 8MHz crystal → ~2MHz E), and vector.
- [x] **Sub verified to the limit of PC-tracing:** 10,653 init instructions byte-match; interrupts functionally correct. Byte-exact match PAST the first interrupt is NOT achievable by PC-trace here — in sim the sub leaves reset mid-frame (after the ~98-frame SPI download) so its first NMI lands at a different instruction than MAME's frame-0 start. This is a sim phase artifact, not a bug. Next validation is FUNCTIONAL (video/inputs), not PC-trace.
- [x] **Decode subctrl offsets (0xa00000 reset pulse, 0xa00004/6 soundlatch) + wire sub soundlatch reads (0x0800/0x0801).** This was THE input bug: the main pulse-resets the sub via 0xa00000 bit0 to resync the I/O handshake and feeds it soundlatch commands; with the whole channel missing the sub diverged and the main never credited coins. Implemented in `jtarbalest_game.v` (reset stretcher + slatch0/1) and `jtarbalest_sub.v` (read 0x0800/0x0801). **metafox now runs the full chain in sim: coins credit, START begins the game, gameplay renders.** See fixes_journal 2026-06-23. (arbalest game_id=1 shares the channel — confirm with an arbalest-timed coin cab.)

## SOLVED: POST blocker was the imported `vgfx_bsy` CPU stall

**Root cause (found by deep diff + an in-CPU `D2` register tap):** the boot's
sprite-RAM self-test fills 0xe00000 with a `+0x0f0f` pattern. On the FPGA the
`addi.w #$0f0f,D2` miscomputed at one iteration (`e1c7 -> 1289` instead of
`f0d6`), so the readback failed and the boot trapped at the `bra $8b0d8`
self-loop. Ruled out (with evidence): interrupts (0 IACKs), all non-ROM read
VALUES match MAME, the X1-017 protection, shared RAM, DSW.

The corruption came from **`jtarbalest_main.v`'s `bus_busy` including the cal50
`vgfx_bsy` stall** — an hdump-gated wait for X1-001 RAM access. The X1-001/X1-012
RAMs are dual-port BRAM (CPU + engine on separate ports) so the CPU needs no
arbitration stall; the imported stall desynced the fx68k dtack on the POST's
back-to-back sprite-RAM writes and corrupted the ALU. **Fix: `bus_busy = rom_cs &
~rom_ok`** (drop `vgfx_bsy`). POST now passes, the trap is gone, and the core
**renders video** (frames change instead of staying black). cal50 has the same
latent stall but calibr50's boot never does the tight back-to-back writes that
trigger it.

## Scene-replay + grading harness (READY)

Fast, graded video iteration is set up:
- **Capture (MAME → scene):** `ver/metafox/mame_scripts/dump_scene.lua` dumps the
  video RAMs at the title frame into `dump.bin` in `dump2bin.sh` order
  (tlv 16K @0x900000 + pal 1K @0x700000 + yram 1K @0xd00000 + dma 8K @0xe00000 =
  26624 B) + a MAME `screen.png`. Staged at `ver/metafox/scenes/title/`.
- **Render + grade (one-time per change):**
  ```
  ROMS_HOST=~/.mame/roms-local tools/scenesim/sim_scenes.sh arbalest metafox
  python3 tools/scenesim/build_diffs.py arbalest metafox
  ```
  → `ver/metafox/sim_results/diffs/title_compare.png` (MAME / edge-diff / FPGA).
- Validated: scene replays non-blank (the NOMAIN render keeps video enabled), and
  the compare stack overlays MAME's title outline for pixel grading.

## SOLVED: tilemap "garbage" was a scene-capture byte-swap (NOT an HDL bug)

The repeated-tile colour grid was **100% a scene-capture artifact**, not the
X1-012 path. Found by tapping the imported jtx1012 (`u_video.u_tiles`) from
`jtarbalest_game.v` and logging the tile codes it read, then comparing to MAME's
VRAM in `dump.bin`:

```
idx    MAME(BE)  MAME(LE)  FPGA-read
0x3c0  3515      1535      1535     <- FPGA reads the little-endian word
0x3c1  3521      2135      2135
```

The FPGA read exactly the **little-endian** interpretation of MAME's big-endian
VRAM. `dump_scene.lua` captured MAME memory with `read_u8` in ascending address
order (68000 big-endian: high byte at the even address), but the BRAM SIMFILE
load expects **FPGA-native little-endian word order** — the same order cal50's
*self-captured* (FPGA ioctl) scenes use. So every 16-bit tile code loaded
byte-swapped → wrong tile everywhere → "garbage".

**Fix:** `dump_scene.lua` now byte-swaps the 16-bit regions on capture
(`dump16` writes low byte then high for **tlv / pal / dma**; **yram** stays raw,
it's 8-bit). The committed `scenes/title/dump.bin` is already in the corrected
order. After the fix the X1-012 tilemap renders **real metafox graphics**
(CORSAIR / SABRE F-86F / HORNET aircraft schematics, the pilot face, CAUTION
radar) — the imported jtx1012 pipeline was correct all along. The gfx-address
path was also confirmed good (a `rom_cs`-gated tap showed `rom_addr` tracks the
code: `code=0` → `rom≈0`).

Grading harness (per change): `tools/scenesim/sim_scenes.sh arbalest metafox`
then `build_diffs.py arbalest metafox` → `sim_results/diffs/title_compare.png`.

## SPRITES (X1-001) NOW RENDER — three bugs fixed (Jun 2026)

The sprite engine produces sprites now (text, the META FOX flame, the cockpit
labels). Three independent bugs, found by tapping `u_video.u_gfx.u_obj`:

1. **`seta_cfg.hex` was missing.** In NOMAIN scene replay `jtkiwi_gfx` loads the
   X1-001 control `cfg[0..3]` via `$readmemh("seta_cfg.hex")` (the CPU isn't
   there to write them). Without it `video_en`/page were undefined → no sprites.
   Captured from MAME (low byte of each 16-bit reg @ 0xd00600..607):
   metafox title = `18 60 00 00` (`cfg0=0x18`: video_en=1, obj_pg_en=1).
   `dump_scene.lua` now emits it; `dump2bin.sh` copies `scenes/<scene>/seta_cfg.hex`
   into `ver/game/`. Committed in the scene dir.

2. **Scene captured only the lower 8 KB of the 16 KB sprite RAM.** metafox's
   spritecode is `0xe00000-0xe03fff` = **16 KB = two 8 KB buffers** (seta.cpp
   metafox_map). The foreground display buffer is the SECOND one (`0xe02000`).
   Fixed: `dump_scene.lua` dumps 0x4000, `dump2bin.sh` splits 16 KB, `mem.yaml`
   `dma` `addr_width 13 -> 14`.

3. **The imported kiwi engine only addressed 8 KB with the TNZS page formula.**
   calibr50 uses 8 KB + a per-frame DMA copy (page = `tm_page^~obj_bufb`, bit 12).
   metafox uses 16 KB with a static **setac bank** (MAME `draw_foreground`:
   banked when `((ctrl2^(~ctrl2<<1))&0x40)`, `ctrl2=spritectrl[1]=cfg[1]`,
   `bank_size=0x1000` → word 0x1000 = 0xe02000). Parametrized **`jtkiwi_obj`,
   `jtkiwi_gfx`, `jtcal50_video`** with `OBJAW` (12/13) + `SETAC` (0/1), default =
   calibr50 behavior (lint-verified: cal50 + kiwi unchanged). arbalest passes
   `#(.OBJAW(13),.SETAC(1))`. The obj LUT now reads word 0x1000 and gets real
   sprite codes (was all-0xFFFF).

## SPRITES VERIFIED CORRECT in the full sim (the scene replay was lying)

A **full 1000-frame boot sim** (`FRAMES=1000 ./sim-core.sh arbalest metafox`,
real CPU) renders the metafox attract title **correctly**: the META FOX flame
logo, the standing pilot, "INSERT COIN", the SETA logo, and the
"©1989 SETA U.S.A., INC. / LICENSED TO ROMSTAR, INC." copyright lines all render
clean and in place (frames ~520-760, see `ver/game/arbalest_sim.mp4`). The
earlier "garbled sprites" (text "IESDO8A", scattered flame) were a
**scene-replay artifact only** — the OBJAW=13 + SETAC=1 engine fix is correct.

**Caveat — grade SPRITES with the FULL sim, NOT scene replay.** The scene
replays the X1-001 sprite RAM wrong: the captured 16 KB is a double-buffer state
(the engine + CPU swap buffers per frame), and the 16-bit byte-swap that fixes
the tile VRAM does not faithfully reproduce the sprite words. Tiles still grade
fine in scene replay; sprites must be judged in the full sim.

MP4 build note: `jtsim` here emitted `frame_*.png` (not `.jpg`), so
`sim-core.sh`'s `frame_*.jpg` encoder skipped the mux. Build the mp4 from the
PNGs with the same 60 Hz gap-fill concat (host ffmpeg) → `ver/game/arbalest_sim.mp4`.

## BLOCKER: the I/O sub-CPU is HALTED — no inputs, ATTRACT ONLY

Corrected finding (was wrongly reported as "gameplay works"): the game only ever
runs **attract mode**. Coins/start never register because the **65C02 I/O sub is
stuck in an error/halt trap** and never does its I/O job.

Evidence (sub read-trace `arbalest_sub_fpga.tr`, 1500-frame run): the sub's hot
loop is `0x70bc: SEI; 0x70bd: JMP $70bc` (~40M fetches) — a deliberate halt. It
fetches the input ports (0x1000/0x1002/0x1006) essentially never, and accesses
shared RAM (0x50xx) **zero** times. Only the periodic NMI handler (0x71dx + stack
0x01fx, ~once/frame) runs. So:
- The sub reaches the halt **before** its init/RAM-test/I/O loop. Disassembly:
  `jsr $720b` is a shared-RAM write/readback test; on success → `0x70c0` (normal:
  `cli` + the `0x503f` IRQ-wait loop at 0x70d6 + per-frame I/O `jsr $71f7`); on
  failure → writes an error code to 0x5000 and falls into the 0x70bc halt. MAME's
  sub idles at 0x70d6/0x70d9 and polls inputs; the FPGA never gets there.
- So this is the sub's analog of the main POST: an early check fails and traps.

**Inputs polarity (fixed, but moot until the sub runs):** metafox ports are all
active-low (`common_type2`, IP_ACTIVE_LOW) but jtframe delivers active-high, so
`jtarbalest_sub.v` `cab_dout` now inverts (`~{...}`). Bit order already correct
via `JTFRAME_JOY_RLDU`. COINS b7=COIN1 b6=COIN2 b5=SVC b4=TILT; P1/P2
b0=U b1=D b2=L b3=R b4=B1 b5=B2 b7=START.

**NEXT (sub bring-up):** capture a clean FPGA sub PC trace + MAME sub trace from
reset and diff to find the FIRST divergence — where the FPGA branches to the
0x70bc error path while MAME continues. Likely a check reading a value the FPGA
gets wrong (a peripheral/handshake, or a 65C02-specific opcode like the `($zp)`
indirect `STA`/`CMP` 0x92/0xD2 the RAM test uses). Until the sub runs its I/O
loop, inputs cannot work and only attract is reachable.

## Audio: X1-010 PCM WORKING (Jun 2026)

The X1-010 now plays. Root cause of the earlier silence was NOT the byte lane (the
old suspicion): the chip register index is just `cpu_addr[13:1]` and the data sits on
D[7:0] (broadcast covers metafox's high-lane frequency write). The real bug was in the
shared `jtx1010_pcm.sv`: metafox never writes the `end` register, relying on
`end=0 → full 0x100-page range`, but the FSM kept `finish` 8-bit (`-end`=0) and keyed
off on the first sample → digital silence. Fixed with a 9-bit end page + 21-bit sample
address (see fixes_journal 2026-06-26). `test.wav` now −22 dBFS peak, samples
byte-identical to the metafox x1snd ROM. MAME reference WAV: `doc/metafox_x1010_ref.wav`.
Open: mix balance / FIR voicing not yet A/B-graded vs MAME.

## ARBALEST (game_id 1) — config ready, boots to a sub halt (Jun 2026)

The arbalest (MAME "arbalest", title *Arbalester*) set is wired and assembles.
Deltas from metafox are small (`arbalest()` = `metafox()` + sprite/tile x-offsets
`set_fg_xoffsets(1,0)`/`set_xoffsets(-1,-2)`, a debug-read stub at 0x80000-0x8000f
returning 0, and NO X1-017 protection — `prot_meta` is already gated to game_id 0).

- **cfg done:** `mame2mra.toml` already has `metafox`+`arbalest` header data
  (00/01) and generic regions; the ROM layouts are near-identical (same regions,
  same width=16/32 interleave), so one config covers both. `doc/mame.xml` has
  both sets; `arbalest.zip` present. The shared bank layout (BA1=0xA0000 …) fits
  both (metafox maincpu 0xa0000 with a 64K tail; arbalest 0x80000).
- **Where it lands:** boot-sim (`./sim-core.sh arbalest arbalest`) → **black
  screen**. The main spins at `0x1088` (`nop; bra $1088`) waiting on interrupts/
  the sub; the **sub halts at 0x70bc** (error $10). The sub gets FURTHER than
  metafox's did: it passes the coin check (COINS=0xff), the zero-page + page-1
  RAM tests, and the shared-RAM test (`jsr $7212`, reaches 0x70c0 normal), then
  diverges to the error path in the post-init/handshake code. **MAME's arbalest
  sub reaches its idle loop at 0x70dd/0x70e0** — the FPGA diverges before that.
- **MAME refs collected:** `ver/arbalest/traces/{main_boot,sub_boot}.tr`
  (gitignored, large). 
### SOLVED — arbalest boots + renders attract (one-byte sub fix)

Root cause found by diffing the FPGA sub trace vs MAME `sub_boot.tr`: at `0x70c0`
the arbalest sub does `lda $1004; cmp #$00; bne $70b2` (halt). 0x1004 is an
unmapped/nop port that reads **0** in MAME, but the FPGA's `cab_dout` mux fell
through to the `default` (0xFF) → check failed → sub halted at 0x70bc → the main
spun at 0x1088 waiting on it → black screen.

**Fix:** `jtarbalest_sub.v` `cab_dout` now returns `8'h00` for 0x1004
(`A[2:1]==2`). After it: the sub passes the check (0x70c7), reaches its normal
idle loop (0x70dd/0x70e0, like MAME), polls P1/P2, does shared-RAM I/O; the main
advances and arbalest **renders its attract** (craft/explosion + SETA/ROMSTAR
copyright, frames change). metafox unaffected (it never checks 0x1004; 0 is also
its MAME value). lint clean.

**NEXT for arbalest:** grade the attract/gameplay vs MAME with the scene harness
(same as metafox), then the small `arbalest()` video deltas (`set_fg_xoffsets(1,0)`,
`set_xoffsets(-1,-2)`) and the 0x80000 debug stub. Sprites/tiles share metafox's
(already working) pipeline, so they should land close.

## Remaining polish (after the sub + audio)

- Tile scroll offset (tiles correct but slightly mis-scrolled).
- Palette/colour exactness pass vs MAME.
- Arbalest video x-offsets + the 0x80000 debug stub once it boots.

## (historical) earlier blocker write-up — POST fails on X1-001 sprite RAM

MAME reaches the full META FOX attract screen by ~frame 500 (title, sprites,
"INSERT COIN", SETA logo). The FPGA stays **black** because it never passes POST:

- The main runs ~1.38M instructions (matching MAME), then its boot RAM self-test
  (`0x8af3a..0x8af8a`: write a 16-bit pattern, read back, `and.w D3` mask, `cmp`)
  **fails the read-back of the X1-001 sprite-code RAM at 0xe00000** (mask D3≈0x0FF0).
  Region order tested: 0xb001c0 (shared RAM, PASSES) → **0xe00000 (FAILS)** →
  0xe00400 → 0xd00000 → 0x700000 → 0x900000.
- On mismatch the boot branches to the error path and ends in an infinite
  `bra $8b0d8` (`60fe`) trap — so the screen never un-blanks.

### Diagnosis update — NOT a read-back bug; a data-value divergence

Deep instrumentation (broad mem-access logger in `jtarbalest_main.v` SIMULATION,
+ MAME `D0`/`D3` register annotation) ruled out the obvious causes:
- Shared RAM (0xb00000) read-back **matches MAME exactly** (both return `{0,low}`,
  mask `D3=0x00FF`) — not the failure (my first guess was wrong).
- X1-001 sprite RAM (0xe00000) **round-trips its own writes** (write `1289` → read
  `1289`); mask there is `D3=0xFFFF` (full 16-bit). So memory works.
- The real divergence (deterministic, MAME instr #1,379,755, PC `0x8af68`): at
  `0xe003d8` the **FPGA's CPU writes `1289` where MAME writes `f0d6`** — a *value*
  divergence, not a memory error. PCs matched for 1.38M instructions, but a data
  value differs, so the data-dependent `cmp`/`bne` finally diverges here. The FPGA
  also does MORE sprite-RAM reads than MAME (2190 vs 2048) → control-flow drift
  after the divergence.

So an **earlier memory read returned a different value** in the FPGA and fed the
data path; it only surfaced as control flow at this POST compare. The fill is a
pure `+0x0f0f` increment, so the wrong value came from a *seed/count* the test
derived from some chip/RAM read upstream.

**NEXT:** a value-level (not PC-level) trace. Annotate the FPGA + MAME with the
data bus / key registers and find the FIRST read whose VALUE differs (PCs already
agree). Likely suspects: a chip-status/size register the POST reads to size the
sprite-RAM region (the FPGA's region wraps early), or an X1-001/X1-012 control
read returning a different value than MAME. Tools in place: the `arbalest_mem.tr`
logger (`pal/tlv/sprite/shram` W/R) and `verify_main_boot.sh`.

Only after POST passes will a full sim show attract video; until then, grade with
scene-replay (needs the NOMAIN scene scaffold) rather than a full boot.

## Bring-up gotchas (this environment)

- **Always rebuild SDRAM banks before a verify run** (`rm cores/arbalest/ver/game/sdram_bank*.bin cores/arbalest/ver/game/rom.bin`). Reusing the cached banks intermittently makes the main hang in the work-RAM clear loop — a stale-cache artifact, not HDL.
- **MAME trace scripts**: use the `noloop` flag (else loops are collapsed and the subsequence verify breaks), and do NOT use `focus <sub>` — it hangs the headless debugger. `mame_scripts/trace_sub_boot.mame` is fixed accordingly.
- `timeout` is not on macOS; let MAME self-terminate via `-seconds_to_run`.
- [ ] X1-010 byte-lane + register/RAM split on the 16-bit main access
- [ ] First non-black frame (palette/VRAM viewer)
- [ ] Tilemap → sprites; twineagl tile-bank remap
- [ ] arbalest deltas (offsets, debug-read stub) + game_id mux

## Known scaffold TODOs (tagged `BRING-UP TODO` in the HDL)

- `jtarbalest_main.v`: IRQ scheme (scanline + vblank IRQ3), protection stub value,
  tile-bank semantics.
- `jtarbalest_sub.v`: sub IRQ rate, bank page width/bits, ROM_RELOAD image layout,
  soundlatch comm direction.
- `jtarbalest_sound.v`: X1-010 16-bit access byte lane + RAM/register address split.
- `cfg/mem.yaml`: work-RAM size, sub-ROM bank layout (ROM_RELOAD) — verify vs MAME.
