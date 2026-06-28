# Arbalest — changes made to shared modules (cal50 / jtkiwi / jtx1010)

This document lists, precisely, every shared file
this branch changes, what the change is, why it was needed, and the source that
verifies it.

> **Scope.** This branch touches exactly **six** files outside `cores/arbalest/`:
>
> | File | Change |
> |---|---|
> | `cores/cal50/hdl/jtcal50_video.v`  | new parameters (sprite width, vtimer, scroll/sprite offsets, bg blend) + forwarding |
> | `cores/cal50/hdl/jtcal50_colmix.v` | `SCR_EN` — optionally blend the X1-001 background layer |
> | `cores/cal50/hdl/jtx1012.v`        | `HOFFS`/`VOFFS` — parametrize the tilemap scroll origin |
> | `cores/kiwi/hdl/jtkiwi_gfx.v`      | `SPRMODE` — 16 KB sprite RAM + metafox bank (width derived) |
> | `cores/kiwi/hdl/jtkiwi_obj.v`      | `SPRMODE` — wider sprite LUT address + bank |
> | `modules/jtx1010/hdl/jtx1010_pcm.sv` | 9-bit sample-end page (the PCM-silence fix) |
>
> Per-core HDL lives in `cores/arbalest/hdl/jtarbalest_*.v`. **No `modules/jtframe`
> behaviour is changed by this branch.**

Every shared change is gated by a **parameter whose default reproduces the original
behaviour**, so the existing users — **calibr50** (`cal50`) and the **kiwi/TNZS**
family — are byte-for-byte unaffected and lint unchanged. arbalest opts in via the
instantiation in `jtarbalest_game.v`:

```verilog
jtcal50_video #(.SPRMODE(1),              // SETAC: 16KB sprite RAM + 0x1000 bank
    .VB_END(9'd7), .VB_START(9'd231),     // 224-line visarea
    .THOFFS(16'h06), .TVOFFS(-9'd8),      // tilemap scroll origin
    .SPR_HADJ(9'd5-9'd8),                 // sprite x offset (SPR_VADJ left at 8)
    .SCR_EN(1)                            // X1-001 background layer
) u_video( ... );
```


---

## 0. (Context) X1-012 tilemap bank bit — changed in arbalest's own cfg

Not a shared-file change, but recorded here because it is the same chip the shared
`jtx1012.v` drives. The X1-012 keeps two tile pages (VRAM 0 and 0x1000); `vctrl[2]`
selects which is shown. The bank is **bit 3** (`0x08`), and bit 4 (`0x10`) is a
separate colour/gfx-mode bit. arbalest's `cfg/mmr.yaml` decodes `at: "4[3]"`.

**Source.** MAME `seta/x1_012.cpp`: tilemap RAM bank = `vctrl[2] & 0x08`. Confirmed
by a register dump on the metafox/arbalest title screen (`vctrl[2] = 0x0009`, bit 3
set → page 1, where the title lives).

---

## 1. `cores/cal50/hdl/jtcal50_video.v` — video top made parametrizable

Five independent generalisations, each with a calibr50-preserving default. The
parameters are forwarded to `jtx1012`, `jtkiwi_gfx` and `jtcal50_colmix`.

### 1a. Sprite mode — `SPRMODE` (address width derived)
```verilog
parameter  SPRMODE=0, // 0 = TNZS  (8KB, 0x800 page — calibr50)
                      // 1 = SETAC (16KB, 0x1000 bank — metafox; MAME seta001 setac_eof)
localparam OBJAW = SPRMODE ? 13 : 12; // sprite addr width
```
A single `SPRMODE` knob selects the sprite scheme; the address width (`OBJAW`,
12=8KB / 13=16KB) is **derived** from it, since the two always co-vary (`SETAC`
needs the 13-bit address). The sprite-RAM ports widen with `OBJAW`
(`dma_addr[OBJAW:1]`, `code_addr[OBJAW-1:0]`) and `SPRMODE` passes into `jtkiwi_gfx`.
`SPRMODE=0` (default) = the old calibr50 wiring.

### 1b. Vertical visible area — vtimer parameters
The `jtframe_vtimer` vertical constants become parameters:
```verilog
parameter [8:0] V_START=0, VB_START=240, VB_END=0,
                VS_START=253, VS_END=261, VCNT_END=271; // defaults = calibr50 (240 lines)
```
arbalest overrides `VB_END=7, VB_START=231` for its **224-line** window. Horizontal
timing and refresh are unchanged; only the vertical window moves.

**Source.** MAME `downtown.cpp` `set_visarea`: metafox/arbalest show rows 16..239
(224 lines) vs calibr50's taller window.

### 1c. Tilemap scroll origin — `THOFFS` / `TVOFFS`
```verilog
parameter [15:0] THOFFS = 16'h20; // default = calibr50
parameter [ 8:0] TVOFFS =  9'd0;
```
Forwarded to `jtx1012` as `#(.HOFFS(THOFFS),.VOFFS(TVOFFS))`. arbalest uses
`THOFFS=0x06, TVOFFS=-8` to line the X1-012 layer up with MAME. Default `0x20/0`
reproduces calibr50 exactly (see change 2).

### 1d. Sprite vdump/hdump offset — `SPR_VADJ` / `SPR_HADJ`
```verilog
localparam [8:0] VADJ = SPR_VADJ, HADJ = SPR_HADJ; // defaults 8 / 5 = calibr50
```
These were the hard-coded `VADJ=9'd8, HADJ=9'd5` literals; now parameters. arbalest
keeps `SPR_VADJ=8` but uses `SPR_HADJ=5-8=-3` to align sprites horizontally.

## Side effects

calibr50 instantiates `jtcal50_video` with all defaults, so every
widened bus collapses to 12 bits, the vtimer keeps its 240-line numbers, the offsets
keep `0x20/0/8/5`, and the colmix bg path is bypassed. calibr50 lints unchanged.

---

## 2. `cores/cal50/hdl/jtx1012.v` — parametrized tilemap scroll origin

### What changed
The hard-coded scroll origin became two parameters:
```verilog
parameter [15:0] HOFFS = 16'h20; // was the literal +16'h20 on hpos
parameter [ 8:0] VOFFS =  9'd0;  // new vertical scroll bias
...
hpos <= pre_hpos + HOFFS;            // was pre_hpos + 16'h20
wire [8:0] vscr = vpos[8:0] + VOFFS; // new; feeds jtframe_scroll .scry
```

### Plain English
The X1-012 tile layer needs a constant scroll offset to position the picture. The
horizontal offset was baked at `0x20` (calibr50's value); it is now `HOFFS`, and a
matching vertical bias `VOFFS` was added (`vpos` fed `jtframe_scroll` directly
before). metafox/arbalest pass `HOFFS=0x06, VOFFS=-8`.

### Side effects
Defaults are the original literals (`HOFFS=0x20`, `VOFFS=0` ⇒ `vscr==vpos`), so
calibr50's tilemap is byte-identical.

---

## 3. `cores/kiwi/hdl/jtkiwi_gfx.v` + `jtkiwi_obj.v` — 16 KB sprite RAM + metafox bank

The X1-001 object engine (shared with the kiwi/TNZS family) gained a single
`SPRMODE` knob; the address width `OBJAW` is derived from it (`SPRMODE ? 13 : 12`).

### `jtkiwi_obj.v`
```verilog
parameter  SPRMODE = 0;             // 0=TNZS (8KB), 1=SETAC (16KB)
localparam OBJAW   = SPRMODE ? 13 : 12;
output [OBJAW:1] lut_addr;
generate
    if( SPRMODE ) assign lut_addr = { page, 2'b00, ~st[1], objcnt }; // 13-bit
    else          assign lut_addr = { page, 1'b0,  ~st[1], objcnt }; // 12-bit (TNZS/cal50)
endgenerate
```

### `jtkiwi_gfx.v`
- `lut_addr`/`code_addr`/`dma_addr` widen with the derived `OBJAW`.
- The metafox display-buffer bank:
  ```verilog
  wire setac_bank = ((cfg[1] ^ (~cfg[1]<<1)) & 8'h40)!=0; // cfg[1] = m_spritectrl[1]
  ```
- Routing chooses the bank source per `SPRMODE`:
  ```verilog
  .page( SPRMODE ? setac_bank : obj_page )   // jtkiwi_obj (foreground)
  code_addr = { {(OBJAW-12){SPRMODE ? setac_bank : 1'b0}}, tm_addr }; // bg buffer MSB
  .page( SPRMODE ? 1'b0 : tm_page )          // jtkiwi_tilemap: no 0x800 split under SETAC
  dma_addr = dma_bsy ? {{(OBJAW-12){1'b0}},dma_txa} : cpu_addr[OBJAW-1:0]; // full CPU window
  ```

### source
MAME `seta/seta001.cpp` `draw_foreground()`: the foreground bank adds `bank_size`
(0x1000 words) when `((m_spritectrl[1] ^ (~m_spritectrl[1] << 1)) & 0x40)` — exactly
`setac_bank`. `m_spritectrl[1]` is `cfg[1]`. The mode name follows MAME's
`seta001_device::setac_eof()` (the seta.cpp 0x1000-bank scheme) vs `tnzs_eof()`.

### Side effects
kiwi (TNZS) and calibr50 instantiate with the default `SPRMODE=0` (→ `OBJAW=12`), so
`setac_bank` is never selected, the generate picks the original 12-bit `lut_addr`, and
the page routing reverts to `obj_page`/`tm_page`. No change for them; both lint clean.

---

## 4. `cores/cal50/hdl/jtcal50_colmix.v` — optional X1-001 background layer (`SCR_EN`)

### What changed
```verilog
module jtcal50_colmix #(parameter SCR_EN = 0) ( ... );
// X1-001 pen-bit order, applied to the background just like the sprites
assign scr_srt = {scr_pxl[8:4],scr_pxl[1],scr_pxl[3],scr_pxl[0],scr_pxl[2]};
assign scr_sel = SCR_EN & gfx_en[1] & (scr_srt[3:0]!=4'h0);
assign bg      = scr_sel ? scr_srt : tiles_pxl;     // bg replaces tiles_pxl in the mux
...
    2'b01: col_addr = bg;                 // was tiles_pxl
    2'b11: col_addr = obj_sel ? obj_srt : bg; // was : tiles_pxl
```
`scr_pxl` (the X1-001 `draw_background` column-scrolled output, previously marked
"unused ?") is now consumed.

### Side effects
For `SCR_EN=0` (calibr50) `scr_sel` is always 0 ⇒ `bg == tiles_pxl`, so the `case`
is byte-identical to the original. calibr50 lints clean.

### Source
MAME `seta/seta001.cpp` `draw_background()` (the column-scrolled sprite background);
the pen-bit reorder matches the foreground `obj_srt` permutation already in this file.

---

## 5. `modules/jtx1010/hdl/jtx1010_pcm.sv` - widen 1 bit

### What changed
The sample **end** comparison widened from 8 to 9 bits, and the sample address is
formed as a 21-bit sum so the top-of-range carry survives:
```verilog
// before
reg  [7:0] finish;  finish <= -cfg_data;
rom_addr <= {start,12'd0}+{4'd0,cur[19:4]};
if(rom_addr[19:12] >= finish) keyoff;
// after
reg  [8:0] finish;  finish <= 9'h100 - {1'b0,cfg_data};
wire [20:0] full_addr = {1'b0,start,12'd0}+{5'd0,cur[19:4]};
rom_addr <= full_addr[19:0];
if(full_addr[20:12] >= finish) keyoff;
```

### source
- MAME `sound/x1_010.cpp`, `sound_stream_update()`:
  `end_addr = (0x100 - reg->end) << 12` — a 9-bit end page; `end=0` → `0x100000`.
- Verified live: a probe shows `finish=0x100`, `start=0x60`, `delta=0x04` (matching
  MAME's channel-15 config); PCM bytes read at `0x60000` are byte-identical to the
  metafox `x1snd` ROM. The sim `test.wav` went −91 dB (silence) → −22 dBFS (metafox)
  / −25.8 dBFS (arbalest).

### Side effects
Only **arbalest** and **cal50** use `jtx1010`. For `end ≠ 0` the behaviour is
bit-identical, so calibr50 is unaffected (lints clean); the fix strictly corrects the
previously-broken `end = 0` case.

---

## Verification sources at a glance

| Change | Primary source |
|---|---|
| X1-012 bank bit (`vctrl[2]&0x08`, in arbalest cfg) | MAME `seta/x1_012.cpp` + title register dump (`vctrl[2]=0x0009`) |
| Sprite RAM 8 KB↔16 KB + bank (`SPRMODE`) | MAME `seta/seta001.cpp` `draw_foreground()` (`((ctrl2^(~ctrl2<<1))&0x40)`) |
| X1-001 background blend (`SCR_EN`) | MAME `seta/seta001.cpp` `draw_background()` |
| Vertical visarea 224 vs 240 | MAME `downtown.cpp` `set_visarea` (metafox rows 16..239) |
| Tilemap / sprite offsets (`THOFFS/TVOFFS/SPR_*`) | per-pixel grading vs MAME (scene harness) |
| X1-010 end page / silence fix | MAME `sound/x1_010.cpp` `sound_stream_update` (`end_addr=(0x100-end)<<12`) + live bus/PCM probe |

All MAME references are mirrored locally under `cores/cal50/doc/` and
`modules/jtx1010/doc/` for offline lookup.
