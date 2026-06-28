# Arbalest — changes made to shared modules (cal50 / jtkiwi / jtframe / jtx1010)

The arbalest core (Seta `downtown.cpp`: **metafox** = game_id 0, **arbalester** =
game_id 1) reuses building blocks from other cores instead of copying them — see
`cores/arbalest/cfg/files.yaml`. Bringing metafox/arbalest up forced a handful of
changes to those **shared** files. This document explains, in plain English, every
such change, why it was needed, and the source that verifies it.

> Scope: only files **outside** `cores/arbalest/` are covered here. Per-core HDL
> (`jtarbalest_*.v`) is documented in `STATUS.md` and `fixes_journal.md`.
>
> Honesty note on `jtframe`: the arbalest branch made **no behavioural change** to
> `modules/jtframe`. The jtframe diffs you may see on this branch
> (`jtframe_pxlcen.v` PXLCLK 55/70, `doc/audio.md` `rc_en`) come from the **cabal /
> taitob / ddribble** work that shares this branch's lineage, not from arbalest.
> They are listed at the bottom only so nobody mistakes them for arbalest work.

The shared building blocks all originate from the **calibr50** (`cal50`) core, which
is the *other*, simpler member of `downtown.cpp`. Every change below was made to let
the **same** module serve both calibr50 (its original target) **and** the
metafox/arbalest variant, with parameter defaults that reproduce calibr50 exactly —
so calibr50 is byte-for-byte unaffected.

---

## 1. `cores/cal50/cfg/mmr.yaml` — X1-012 tilemap **bank bit** was wrong

### What changed
The X1-012 tilemap control word `vctrl[2]` has a 1-bit "bank" field. It was decoded
from **bit 4** (`at: "4[4]"`); it is now decoded from **bit 3** (`at: "4[3]"`).

```yaml
# before
- name: bank
  dw: 1
  at: "4[4]"
# after
# vctrl[2]: bit3 (0x08)=tilemap bank (vram 0 / 0x1000), bit4 (0x10)=color/gfx mode
- name: bank
  dw: 1
  at: "4[3]"
```

### Plain English
The X1-012 tilemap chip keeps two screens of tile data (page 0 at VRAM offset 0 and
page 1 at offset 0x1000). One bit of its control register picks which page is shown.
We were reading the wrong bit, so the title screen (which lives in page 1) was never
selected — the wrong half of VRAM was drawn. Bit 3 (mask `0x08`) is the real bank
select; bit 4 (mask `0x10`) is a separate colour/graphics-mode bit.

### Why it's right / source
- MAME `seta/x1_012.cpp` (`x1_012_device`): the tilemap RAM bank is taken from
  `vctrl[2] & 0x08`, and the colour/mode select is `& 0x10`.
- Confirmed empirically: a MAME register dump on the metafox/arbalest **title**
  screen reads `vctrl[2] = 0x0009`, i.e. bit 3 set → page 1. With the old bit-4
  decode the title page was never reached.

### Blast radius
calibr50 also uses this mmr — but calibr50's tilemap behaviour is unchanged because
the corrected bit is simply the one the hardware actually uses; calibr50 lints clean.

---

## 2. `cores/cal50/hdl/jtcal50_video.v` — made the video top **parametrizable**

Two independent generalisations, both with calibr50-preserving defaults.

### 2a. Sprite address width — `OBJAW` / `SETAC` parameters
New module parameters:
```verilog
parameter OBJAW=12, // sprite code/LUT addr width: 12 = 8 KB (calibr50), 13 = 16 KB (metafox)
parameter SETAC=0,  // 1 = metafox-style sprite bank (2x 8 KB buffers)
```
The sprite-RAM ports widen with `OBJAW` (`dma_addr [OBJAW:1]`,
`code_addr [OBJAW-1:0]`) and the parameters are forwarded to `jtkiwi_gfx`.

**Plain English.** The X1-001 sprite chip has a different amount of sprite RAM per
game. calibr50 has **8 KB** (one buffer). metafox/arbalest have **16 KB** — two 8 KB
sprite buffers, with a hardware "bank" bit choosing which buffer the engine shows
this frame. The video module was hard-wired to 8 KB; it is now sized by `OBJAW`
(12 bits = 8 KB, 13 bits = 16 KB) with `SETAC` turning on the second-buffer bank.
Defaults (`OBJAW=12, SETAC=0`) = the old calibr50 wiring exactly.

**Source.** MAME `seta/seta001.cpp` (X1-001): the sprite-RAM size and the
double-buffer bank are per-game. metafox/arbalest use 16 KB with the "setac" bank;
calibr50 uses 8 KB. (The bank equation itself lives in change 3b.)

### 2b. Vertical visible area — vtimer parameters
The `jtframe_vtimer` vertical constants were turned into parameters:
```verilog
parameter [8:0] V_START=0, VB_START=240, VB_END=0,
                VS_START=253, VS_END=261, VCNT_END=271; // defaults = calibr50
```
arbalest's `jtarbalest_game.v` overrides `VB_END=7, VB_START=231`.

**Plain English.** "Visible area" is which scan-lines actually appear on screen.
calibr50 shows **240** lines; metafox/arbalest show **224** (the picture is shorter,
with bigger top/bottom borders). The vertical timing was baked in for calibr50's 240
lines; it is now adjustable so metafox/arbalest can request their 224-line window
without changing the refresh rate. The horizontal timing is identical for all three,
so only the vertical numbers move.

**Source.** MAME `downtown.cpp` machine config `set_visarea`:
- metafox / arbalest: `(0, 383, 16, 239)` → rows 16..239 = **224** lines.
- calibr50: `(0, 383, 8, 247)` → rows 8..247 = **240** lines.

### Blast radius
calibr50 instantiates `jtcal50_video` with no parameter overrides, so it gets
`OBJAW=12, SETAC=0` and the 240-line defaults — identical to before.

---

## 3. `cores/kiwi/hdl/jtkiwi_obj.v` and `jtkiwi_gfx.v` — X1-001 sprite engine, 8 KB↔16 KB

These two files are the shared SETA X1-001 sprite engine (originally written for
TNZS/kiwi, reused by calibr50). They were parametrized the same way: `OBJAW` widens
the sprite-RAM address, `SETAC` switches in the metafox double-buffer behaviour.
Defaults reproduce the kiwi/calibr50 (8 KB, no bank) behaviour bit-for-bit.

### 3a. `jtkiwi_obj.v` — sprite LUT address + bank layout
```verilog
// non-SETAC (8 KB): {page, 0,  ~st[1], objcnt} = page*0x800  + ...
// SETAC   (16 KB): {page, 00, ~st[1], objcnt} = page*0x1000 + ...   (bank @ word 0x1000)
generate
    if( SETAC ) assign lut_addr = { page, 2'b00, ~st[1], objcnt }; // 13-bit
    else        assign lut_addr = { page, 1'b0,  ~st[1], objcnt }; // 12-bit
endgenerate
```

**Plain English.** When reading a sprite's attributes, the engine builds an address
into sprite RAM. For 8 KB RAM that address is 12 bits and the "page" bit lands at the
0x800 boundary. For 16 KB RAM the address is 13 bits and the page (now a buffer-bank)
bit lands at the 0x1000 boundary — which is where metafox keeps its second sprite
buffer (`0xe02000`). The `generate` picks the right layout from `SETAC`.

### 3b. `jtkiwi_gfx.v` — the metafox **buffer-bank** equation + full 16 KB CPU window
```verilog
// metafox (setac) foreground bank, from MAME seta001 draw_foreground:
//   banked when ((ctrl2 ^ (~ctrl2<<1)) & 0x40) != 0,  ctrl2 = m_spritectrl[1] = cfg[1]
wire setac_bank = ((cfg[1] ^ (~cfg[1]<<1)) & 8'h40)!=0;
...
.page( SETAC ? setac_bank : obj_page )                 // pick the bank source per game
assign dma_addr = dma_bsy ? {{(OBJAW-12){1'b0}},dma_txa}
                          : cpu_addr[OBJAW-1:0];         // SETAC: full 16 KB CPU write window
```

**Plain English.** Two metafox-specific things:
1. **Which buffer is displayed.** metafox flips between its two sprite buffers using
   a quirky bit-twiddle of sprite-control word 1 (`ctrl2`): the buffer is the second
   one when `((ctrl2 ^ (~ctrl2<<1)) & 0x40)` is non-zero. calibr50 uses its existing
   `obj_page` logic instead; `SETAC` chooses which source feeds the engine's `page`.
2. **CPU write window.** The 68000 must be able to write the whole 16 KB sprite RAM,
   so the CPU-side `dma_addr` uses the full `OBJAW`-wide address (zero-extended back
   to 12 bits for the 8 KB case so calibr50 is unchanged).

**Source.** MAME `seta/seta001.cpp`, `draw_foreground()`: the foreground sprite bank
adds `bank_size` (0x1000 words) when `((m_spritectrl[1] ^ (~m_spritectrl[1] << 1)) &
0x40)` — exactly the `setac_bank` expression. `m_spritectrl[1]` is `cfg[1]` here.

### Blast radius
kiwi (TNZS family) and calibr50 instantiate these with the default `OBJAW=12,
SETAC=0`, so `setac_bank` is never selected and all widths collapse to the original
12-bit form. No change for them.

---

## 4. `modules/jtx1010/hdl/jtx1010_pcm.sv` — X1-010 PCM was silent (the audio fix)

### What changed
The PCM voice's sample **end** comparison was widened from 8 to 9 bits, and the
sample address is now formed as a 21-bit sum so the top-of-range carry survives:
```verilog
// before
reg [7:0] finish;  finish <= -cfg_data;
... if(rom_addr[19:12] >= finish) keyoff;
// after
reg [8:0] finish;  finish <= 9'h100 - {1'b0,cfg_data};
wire [20:0] full_addr = {1'b0,start,12'd0}+{5'd0,cur[19:4]};
rom_addr <= full_addr[19:0];
... if(full_addr[20:12] >= finish) keyoff;
```

### Plain English
The X1-010 plays a PCM sample from a **start** page to an **end** page. metafox and
arbalester set up start/volume/frequency but **never write the end register**,
relying on the chip rule "end = 0 means play the whole 1 MB". The engine computed the
stop point as `-end` in **8 bits**, so `end = 0` wrapped to `0`, and the very first
sample's page (≥ start) already satisfied "page ≥ 0" → the voice keyed **off
immediately**, on every channel → total silence. Using a 9-bit end page, `end = 0`
correctly becomes page `0x100` (the top of the 1 MB range), so the voice plays.
For any non-zero end the 9-bit compare is identical to the old 8-bit one, so nothing
else changes.

### Why it's right / source
- MAME `sound/x1_010.cpp`, `sound_stream_update()`:
  `end_addr = (0x100 - reg->end) << 12` — a 9-bit end page; `end = 0` → `0x100000`.
- Verified live: a probe after the fix shows `finish=0x100`, `start=0x60`,
  `delta=0x04` — matching MAME's channel-15 config — and the PCM bytes read at
  `0x60000` are **byte-identical** to the metafox `x1snd` ROM (`up001015`). The sim
  `test.wav` went from −91 dB (silence) to −22 dBFS (metafox) / −25.8 dBFS
  (arbalest). Full write-up: `fixes_journal.md`, entry 2026-06-26.
- Bus-level findings that ruled out the wrong suspect (the "16-bit byte lane"): each
  X1-010 register maps to one 68000 word, so the register index is `cpu_addr[13:1]`,
  and the data is on `D[7:0]`. metafox's frequency write hits the high lane but the
  68000 model broadcasts the byte to both lanes, so it still lands.

### Blast radius
Only **arbalest** and **cal50** use `jtx1010`. For `end ≠ 0` the behaviour is
bit-identical to before, so calibr50 is unaffected (lints clean). The fix is strictly
a correction for the previously-broken `end = 0` case.

---

## 5. `modules/jtframe/…` — NOT arbalest work (listed to avoid confusion)

These shared-folder diffs exist on the branch but were authored for other cores:

| File | Real owner | What it is |
|---|---|---|
| `hdl/clocking/jtframe_pxlcen.v` | **taitob** (commit `285b09d44`) | adds PXLCLK codes 55 (cabal) / 70 (taitob); arbalest uses PXLCLK 8 and is untouched by it |
| `doc/audio.md`, `doc/macros.md` | **ddribble** | documents the `rc_en` switchable RC filter |
| `bin/*`, `devops/xjtcore.sh`, `src/jtframe/*`, `target/mister/*`, `verilator/test.cpp` | general tooling / branch merges | build & sim tooling that diverges from `master-andrea`; not arbalest RTL |

Arbalest itself adds **no** behavioural change to `modules/jtframe`.

---

## Verification sources at a glance

| Change | Primary source |
|---|---|
| X1-012 bank bit (`vctrl[2]&0x08`) | MAME `seta/x1_012.cpp` + title-screen register dump (`vctrl[2]=0x0009`) |
| Sprite RAM 8 KB↔16 KB + bank | MAME `seta/seta001.cpp` `draw_foreground()` (`((ctrl2^(~ctrl2<<1))&0x40)`) |
| Vertical visarea 224 vs 240 | MAME `downtown.cpp` `set_visarea` (metafox `16..239`, calibr50 `8..247`) |
| X1-010 end page / silence fix | MAME `sound/x1_010.cpp` `sound_stream_update` (`end_addr=(0x100-end)<<12`) + live bus/PCM probe |

All MAME references are mirrored locally under `cores/arbalest/doc/` and
`modules/jtx1010/doc/` for offline lookup.
