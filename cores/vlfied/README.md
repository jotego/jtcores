# Volfied (JTVOLFIED) — scaffold

Taito, 1989. Qix-style area-capture game. MAME driver: `taito/volfied.cpp`.

**Status: SCAFFOLD / step 1 only.** Forked off `cores/rastan`. Untracked WIP —
not built, not simulated. Boots nothing yet; the C-chip and framebuffer are
stubs.

## Hardware

| Block | Part | Donor |
|-------|------|-------|
| Main CPU | 68000 @ 8 MHz | `jtframe_m68k` (rastan) |
| Audio CPU | Z80 @ 4 MHz | `jtframe_sysz80` (rastan) |
| Sound | YM2203 @ 4 MHz | `jt03` (ddribble) |
| Audio I/F | PC060HA | `jtvolfied_pc060` ← rastan, verbatim |
| Sprites | PC090OJ | `jtvolfied_obj` ← rastan, verbatim |
| Protection | TC0030CMD (uPD78C11 + 8 KB EPROM + 8 KB DRAM) | `jtsuperman_upd78c11` + `jtsuperman_cchip` |
| Colour | TC0070RGB / PC050CM, xBGR-555 | colmix |
| Background | **player-drawn bitmap framebuffer** | **none — `jtvolfied_fb.v`, NEW** |

Resolution 320×240 visible, ~60 Hz. Master XTAL 32 MHz (also 26.686 and 20 MHz).

## What's reused vs. new

~80% of the core is parts-bin: Rastan donates the entire sound + sprite +
PC060HA subsystem; Superman donates the C-chip CPU core. The only block with
no donor is the Qix-style bitmap framebuffer.

## Open work (in priority order)

1. **`jtvolfied_cchip.v`** — currently a STUB (RAM + placeholder input
   injection + immediate DTACK). Drop in `jtsuperman_cchip` (REAL_MCU=1),
   load Volfied's EPROM via the `ceprom` bus, and verify the MCU port→input
   mapping against MAME. Trace MAME first (per MEMORY).
2. **`jtvolfied_fb.v`** — the real new block. Decide BRAM vs. SDRAM+linebuffer
   for the 512 KB bitmap; implement per-bit write masking (RMW); confirm the
   scanout map and `video_ctrl` page-flip / `0x60` status read.
3. Pin video timing totals to MAME (vtimer params are placeholders).
4. Widen PC090OJ sprite RAM to 16 KB (rastan obj uses 1 KB).
5. `sprite_ctrl_w` (700000) → obj palette bank.
6. Confirm 68k IRQ level and PC060HA byte lane (e00001/e00003).
7. SDRAM offsets in `cfg/macros.def` are placeholders — pin to ROM_START.

See `doc/STATUS.md`.
