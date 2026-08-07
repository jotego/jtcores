# Volfied — STATUS

## SIM BRING-UP LOG (session 9 — TAITO logo fixed: sprite gfx mirror) ✅
Root cause of the missing TAITO logo: PC090OJ sprite-gfx ROM mirroring.
- MAME's pc090oj region is 768 KB (0xC0000, 6144 tiles). The logo uses sprite
  codes 0x1607 / 0x160E-0x1618. Verified via MAME region dump that
  0xA0000-0xBFFFF is an exact MIRROR of 0x80000-0x9FFFF: the c04-10/c04-09
  ROMs (64 KB each = tiles 0x1000-0x13ff) are mirrored into 0x1400-0x17ff
  (half-size ROM / unconnected high address line on the PCB).
- Our MRA only loads 640 KB and FF-pads 0xA0000+, so codes 0x14xx-0x17xx read
  0xFFFF -> solid 0xF tiles -> the TAITO logo showed as a solid navy block
  (while the in-range VOLFIED-title sprites rendered fine).
- Fix in jtvolfied_obj.v: fold sprite codes 0x1400-0x17ff back to 0x1000-0x13ff
  (clear bit 10 when code[12]&~code[11]) so they read the real mirrored gfx:
      code_m = (code[12]&~code[11]) ? {code[12:11],1'b0,code[9:0]} : code[12:0];
  Confirmed: TAITO logo now renders correctly.
- Investigation also re-confirmed (via the :video_ram share, 512 KB) that the
  background bitmap is genuinely EMPTY during attract in MAME too -> all title
  art/HUD/logos are PC090OJ sprites, not BG.

## SIM BRING-UP LOG (session 8 — "missing TAITO logo" is a SPRITE issue)
Investigated the missing TAITO logo. Key finding: it is NOT a background bug.
- Instrumented jtvolfied_fb: during attract the displayed bitmap reads ALL ZERO
  (scan_q=0000) and the CPU makes ZERO nonzero writes to either VRAM page.
- Verified against MAME: read videoram 0x400000-0x47ffff via Lua at frames
  60/120/180/240/300 -> all zero. So the background bitmap is genuinely EMPTY
  during the whole title/attract in MAME too; it is only drawn during gameplay.
- => the TAITO logo, VOLFIED logo, HUD, copyright are ALL PC090OJ sprites.
  Our core renders the VOLFIED-title sprites correctly but the TAITO-logo
  screen collapses to a solid navy rectangle (shape/colour lost).
- Prime suspect (already a known TODO): jtvolfied_obj is rastan's PC090OJ port
  and only scans a 2 KB sprite-RAM window (video passes main_addr[10:1]); Volfied
  PC090OJ RAM is 16 KB (0x200000-0x203fff). Sprites/attributes outside the low
  window won't draw. Next: widen the obj sprite-RAM addressing to 13 bits and/or
  check PC090OJ features rastan's port omits, vs MAME pc090oj.cpp.

## SIM BRING-UP LOG (session 7 — FG/sprite vertical align) ✅
The PC090OJ sprite layer (HUD/text) sat one display-line too high vs the
background, clipping the top "1UP HIGH SCORE 2UP" row off-screen. Fixed by the
sprite buffer X offset in jtvolfied_obj.v:
    buf_pos = xpos + 9'd4   (was rastan's +14; -10 total = one line + 2px down)
On this ROT270 display the sprite raster-H (buf_pos) IS the display-vertical
axis (and increasing buf_pos moves the FG UP, so we subtract). The full HUD now
shows and lines up with MAME. (ydiff/vrender Y zone stays at rastan's -8.)

## SIM BRING-UP LOG (session 6 — BG image + COIN ERROR) ✅
The background bitmap now renders correctly — the VOLFIED title logo (and the
TAITO logo screen) draw properly instead of a solid blue block. Two fixes:
- **Data ROM placement.** `no_offset=true` on the maincpu region packed it
  contiguously (0xC0000), dropping the 0x40000-0x7ffff gap, so the 512 KB level
  /logo image data sat at SDRAM 0x40000 while the 68k reads it at 0x80000 ->
  wrong image, right position. Fix: REMOVE no_offset (honour MAME offsets) so
  data lands at 0x80000 with an FF gap; that makes maincpu 1 MB, so the bank
  starts had to move: JTFRAME_BA1_START 0xC0000->0x100000, BA2 0xE0000->0x120000
  (otherwise the audio CPU landed inside maincpu's data and corrupted the Z80,
  which showed up as the sound-handshake spin again). main_addr stays A[19:1].
- **C-chip COIN ERROR.** With the real MCU the boot stopped at "COIN ERROR".
  MAME's C-chip reads PB (F00009) = 0xFC at idle: the coin bits are ACTIVE-HIGH
  at the port (idle=0), opposite JTFRAME's active-low coin. Inverting the coin
  bits in jtvolfied_cchip (port_pb = {6'h3f, ~coin[1], ~coin[0]}) clears it.
  Verified idle port bytes vs MAME: PA=FF PB=FC PC=FF PD=FF (all others match).
- Result: boot runs through the title sequence (20 frames to ~268), VOLFIED
  logo + copyright + HUD render correctly.

## SIM BRING-UP LOG (session 5 — REAL C-CHIP) ✅
The stub C-chip is replaced by the **real Taito TC0030CMD** = uPD78C11 MCU +
4 KB internal mask ROM + 8 KB external EPROM, reusing jtsuperman_cchip /
jtsuperman_upd78c11 (now pulled in files.yaml from the superman core).
- C-chip ROMs: the internal mask ROM (`cchip_upd78c11.bin`, 4 KB) is a SHARED
  device ROM across all Taito C-chip games -> reuse superman's `mask_rom.mem`.
  The external EPROM is Volfied's `cchip_c04-23` -> converted to
  `cchip_eprom.mem` (`xxd -p -c1`), placed in cores/volfied/{hdl,ver/game}/.
  Both are baked via $readmemh inside jtsuperman_cchip (no SDRAM bus needed).
- jtvolfied_cchip REAL_MCU=1 instantiates jtsuperman_cchip(BRING_UP=0). 68k map
  matches Volfied ($000-$7FF SRAM @f00000, $800-$FFF ASIC @f00800). Port map
  from volfied.cpp machine_config:
    PA bit5=START2 bit6=START1 bit7=SERVICE1 ; PB bit0/1=COIN1/2 ;
    PC bit0=TILT bit2-5=U/D/L/R bit6=BUTTON1 ; PD/AD=P2 cocktail (idle).
  ext_tick = one-clk VBL pulse (volfied.cpp m_cchip->ext_interrupt on VBL).
- Result: sim boots with the real MCU (cchip init prints mask_rom[0]=54,
  eprom[0]=54), renders the attract screen (12 frames, same HUD+playfield),
  cchip traffic ~8406, fb=393216, pal=9092, obj=3422 — i.e. the real C-chip
  drives the protocol and the game runs. Stub kept behind REAL_MCU=0.

### Caveats / next on the C-chip
- Input port mapping (PA/PB/PC bit positions, joystick U/D/L/R order) is a
  best-effort from volfied.cpp; verify under actual play (insert coin / move).
- jtsuperman_cchip ADC (cr0..3) and timer modelling are acknowledged-incomplete
  in superman; Volfied uses the AD port only for cocktail, tied idle here.
- int_n from the C-chip is left unconnected (Volfied routes no C-chip IRQ to
  the 68k, unlike Superman's IRQ6).

## SIM BRING-UP LOG (session 4 — IT RENDERS) ✅
The core now **boots to a recognisable Volfied screen in sim**: score HUD
(`00 50000 00`) + `CREDIT 0` (PC090OJ sprites) and the blue playfield, correct
portrait orientation. 15 distinct frames over a 200-frame run (animating).
Fixes that got pixels on screen:
- **Bitmap pixel decode** implemented verbatim from volfied.cpp
  refresh_pixel_layer in jtvolfied_fb.v (12-bit index: color[10:8]=px[8:6];
  if px[15] -> color[11]=1, low nibble=px[12:9] (cleared if px[13]); else
  low nibble=px[3:0]). page=video_ctrl[0], addr=y*512+(x+1).
- **Sprite palette bank** wired from sprite_ctrl_w (0x700000). volfied.cpp
  colpri_cb: colbank = 0x100|((sprite_ctrl&0x3c)<<2); PC090OJ pen =
  (colbank+color)*16+pixel => sprite palette index = {1'b1, sprite_ctrl[5:2],
  obj_pxl[7:0]} (0x1000-0x1fff). Was tied to 0 -> read empty entries 0-0xbf
  while the game writes palette at 0x100-0x1fc8 -> all black. Now reads hit the
  real colours (pdout_nz ~18M, max_rdaddr 0x1202).
- Confirmed: palette writes land at word 0x100..0x1fc8; bitmap palette is
  0x000-0xfff (mostly empty at attract = palette[0] black background, correct).

### Remaining polish (next)
- Verify exact pixel/line alignment & vtimer totals vs the 26.686 MHz video
  timing (pxl_cen currently divides by 3; frame rate ~65 Hz). Compare a sim
  frame to a MAME screenshot pixel-for-pixel.
- Bitmap playfield detail / background image during gameplay (need a demo that
  draws into VRAM; attract shows mostly the cleared field).
- Sprite priority / per-sprite color vs bitmap (colpri pri_mask=0 = sprites
  over everything — currently obj-over-bitmap, matches).
- Strip the \`ifdef SIMULATION\` debug counters in jtvolfied_main.v /
  jtvolfied_colmix.v / jtvolfied_fb.v before release.
- Replace the C-chip stub with the real jtsuperman_upd78c11 (REAL_MCU=1).

## SIM BRING-UP LOG (session 3 — sound + render)
- **Sound "handshake" was a false alarm:** it was caused by running the sim
  with `-nosnd` (defines NOSOUND -> stubs jtvolfied_snd -> PC060HA sub side and
  Z80 gone -> main CPU's handshake poll never answered -> spin on 0xe00000).
  **Volfied's main CPU waits on the Z80, so sims MUST run WITH sound:**
      ./sim-core.sh volfied volfied        # NOT -nosnd
- With sound enabled the 68k completes a full frame loop and the per-region
  write counts **match MAME exactly**:
      fb (bitmap) = 262144,  pal = 9092,  obj = 2358   (== MAME frame-150)
  cchip/vctrl advance per frame, intn toggles, no PC derail. The CPU + C-chip
  stub + sound + sprite/palette/bitmap WRITE paths are effectively correct.
- **Still black on screen — next phase is the VIDEO DISPLAY path** (the
  framebuffer "new block"). From volfied.cpp refresh_pixel_layer:
  - page select = `video_ctrl & 1`  (jtvolfied_fb page bit = video_ctrl[0] ✔)
  - VRAM word address = `y*512 + x`  (scan_addr {page,vrender,hdump} ✔)
  - **pixel format is NOT a plain index** (this is the bug to fix in fb/colmix):
        bit15      = select image (which nibble is the index)
        bits 12:9  = image B / palette idx bits 8..A (when bit15 set)
        bits 12:10 = ALWAYS contribute to palette address
        bits  3:0  = image A (palette idx when bit15 clear)
    Current placeholder `fb_pxl = scan_q[7:0]` + `{5'd0,fb_pxl}` is wrong ->
    colours resolve to ~black. Implement the real decode + confirm vtimer
    totals/pxl_cen against the 26.686 MHz video timing.
- Note: `doc/mame.xml` must contain volfied for `jtframe mra`; regenerate with
  `mame -listxml "volfied*" > doc/mame.xml` (restored to ddribble after runs).

## SIM BRING-UP LOG (session 2)
MAME instrumented (`ver/volfied/mame_scripts/trvolfied.mame` + lua) and the core
now **builds, lints clean, builds the ROM from the MRA, and simulates** via
`./sim-core.sh volfied volfied`. Findings + fixes, in order:

- **MAME golden facts captured** (`/tmp/volfied_main.tr`): boot order is
  video_ctrl=0 → video_mask=0xffff → reads video_ctrl expecting **0x60** →
  PC060HA → C-chip RAM init. C-chip device indices: inputs at 3/4/5
  (idle FD/3C/FF), ASIC idx1→0x01. By frame 150 MAME writes the full 262144-word
  bitmap, 9092 palette, 2358 sprite words. Level-**4** VBL autovector → 0x400.
- **doc/mame.xml** is per-core; regenerate for volfied with
  `mame -listxml "volfied*" > doc/mame.xml` before `jtframe mra`.
- Fixes that moved the boot forward (verified against the golden PC trace):
  1. **JTFRAME_VERTICAL** — volfied is rotate=270 (caught by mra validation).
  2. **IRQ level 4** — `IPLn={intn,2'b11}` (was level 6 → wrong vector).
  3. **DTACK bug** — `cchip_dtackn` tied 0 was ANDed into the CPU DTACKn,
     forcing immediate ack and corrupting SDRAM reads. Removed.
  4. **vctrl read path** — `cpu_din` mux was missing `vctrl_dout` (d00000 must
     read 0x60). Routed it through.
  5. **work RAM → BRAM** — SDRAM work RAM had read-after-write corruption (68k
     stack `rts` popped 0x000000). Moved to on-chip `jtframe_dual_ram16`. This
     unblocked the whole boot.
- **Current state:** 68k boots and runs real game code — reset → video init →
  16 KB RAM clear → PC060HA init → **C-chip RAM init (~8210 accesses)** →
  **palette (~7044)** → **sprites (~1028)**. No PC derail; stays in legit ROM.
- **Current blocker:** after drawing setup the main CPU spins polling the
  **PC060HA at 0xe00000** (sound handshake) — waiting for the Z80. Screen still
  black (never completes a frame). `fb`(bitmap) writes = 0 (gated behind the
  sound wait). Next: trace MAME's Z80 + PC060HA handshake (per MEMORY) and bring
  up the sound path so the main CPU proceeds.
- Debug instrumentation lives in `jtvolfied_main.v` under \`ifdef SIMULATION\`
  (progress counters + PC-derail/stall detectors). Strip before release.

---


## Where we are
Step 1 (scaffold off rastan) done. Untracked WIP. Not built / not simulated.
The skeleton compiles structurally (YAML valid, all files present, SDRAM bus
names match mem.yaml), but two blocks are deliberate stubs so it will not run
a game yet.

## File map
| File | State |
|------|-------|
| `cfg/macros.def` | hardware notes + clocks; SDRAM offsets are PLACEHOLDERS |
| `cfg/files.yaml` | pulls volfied + shared `jtsuperman_upd78c11` + jt12 (jt03) |
| `cfg/mem.yaml` | banks: ram / main / snd / orom / ceprom. Framebuffer NOT a bus (BRAM) |
| `cfg/mame2mra.toml` | regions maincpu/audiocpu/pc090oj/cchip_eprom |
| `hdl/jtvolfied_game.v` | top, wiring only |
| `hdl/jtvolfied_main.v` | 68000 + full address decode (real) |
| `hdl/jtvolfied_snd.v` | Z80 + jt03(YM2203) + PC060HA (real) |
| `hdl/jtvolfied_pc060.v` | copied verbatim from rastan |
| `hdl/jtvolfied_obj.v` | PC090OJ, copied verbatim from rastan |
| `hdl/jtvolfied_colmix.v` | palette mix, bitmap behind sprites (real) |
| `hdl/jtvolfied_video.v` | vtimer + fb + obj + colmix (real wiring, placeholder timing) |
| `hdl/jtvolfied_fb.v` | **STUB-ish**: BRAM bitmap, no mask RMW, placeholder scanout |
| `hdl/jtvolfied_cchip.v` | **STUB**: RAM + placeholder input inject + instant DTACK |

## Next steps (priority)
1. Trace MAME first (Z80 + C-chip command flow + first video write) per MEMORY.
2. Bring up 68k: ROM + work RAM, boot until it polls the C-chip / video_ctrl.
3. C-chip: set `REAL_MCU=1`, instantiate `jtsuperman_cchip` with Volfied EPROM
   on the `ceprom` bus; verify MCU port→input mapping against MAME.
4. Framebuffer: choose BRAM vs SDRAM+linebuffer; implement per-bit write mask
   (RMW); confirm scanout map, page-flip and `video_ctrl_r`=0x60 status.
5. Pin video timing totals + pixel clock to MAME (26.686 MHz video osc).
6. Widen PC090OJ sprite RAM to 16 KB; wire `sprite_ctrl_w` (700000) to obj_pal.
7. Confirm 68k IRQ level and PC060HA byte lane.

## Known shortcuts taken in the scaffold
- `flip` tied 0; `obj_pal` tied 0.
- IRQ level / VPA handling copied from rastan pattern, unverified for volfied.
- SDRAM bank offsets are guesses; pin to ROM_START region sizes.
