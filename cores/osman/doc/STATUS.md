# Osman / Cannon Dancer — bring-up status

New jtcores core. **Osman (World)** / **Cannon Dancer (Japan)**, Mitchell (Atlus license), 1996.
Hardware: Data East **"Simple 156"** — board MT5601-0 (DEC-22VO), the *simplest* DE156 board.

MAME driver: `dataeast/simpl156.cpp` (machine `mitchell156`, `init_osman`). Sets: `osman` (parent,
ROT0, World), `candance` (clone, Japan). **Identical ROMs** — region lives only in the EEPROM image.
Reference C++ mirrored under `doc/mame/` (simpl156.cpp, deco16ic, decospr, deco156_m, decocrpt).

Reference implementation for the shared hard parts: **rejectedcoins' Night Slashers core**
(`~/develop/Arcade-NightSlashers_MiSTer`, core `nslasher`, deco32 hardware). Same DE156 ARM + deco156
decrypt + deco56 tile decrypt + DECO16IC tilemaps. We **do not copy files** — it is a reference only.
Osman drops everything nslasher adds on top: no Z80, no YM2151, no Ace blender, no 5bpp sprites, one
tilegen instead of two.

## Hardware spec (from simpl156.cpp)

### CPU
- **ARM (DE156)** @ 28 MHz / 4 = **7.000 MHz**. Encrypted; `deco156_decrypt` (doc/mame/deco156_m.cpp).
- Only ROM + 4K internal work RAM are true 32-bit; every video/palette/sprite device sits on the
  **low 16 bits** of the 32-bit bus (upper 16 read back as $FFFF — data-bus pull-ups).
- **IRQ:** vblank → `ARM_IRQ_LINE` (HOLD on vblank asserted, CLEAR when it deasserts). No sound CPU IRQ.

### Video
- Refresh **58 Hz**. Screen 64×8 by 32×8; **visarea (0, 319, 8, 247) = 320×240**. ROT0.
- Palette **xBGR-555**, **1024 entries** (4096/4), 16-bit membits.
- **1× DECO16IC** tilegen, two playfields pf1 & pf2, both **DECO_64x32**.
  - pf1 col_bank 0x00, pf2 col_bank 0x10, both col_mask 0x0f.
  - tile bank callback: `((bank>>4)&0x7)*0x1000`. 8×8 uses gfx bank 0, 16×16 uses gfx bank 1.
- **1× DECO_SPRITE** (chip 52), sprites 16×16 **4bpp**, palette base **0x200**, 32 palettes.
  - Sprites are `set_flip_screen(true)` — flipped relative to the tilemaps.
  - priority callback keys on sprite word `pri & 0xc000` → {0, 0xf0, 0xf0|0xcc, 0xf0|0xcc}.
  - sprite RAM walked as `0x1400/4` entries (8K RAM, top address line grounded → only 8K usable).
- Draw order (screen_update): fill pen 256 → pf2 (pri 2) → pf1 (pri 4) → sprites.

### Memory map (mitchell156_map, on top of base_map)
32-bit ARM space. Video/pal/spr/rowscroll devices are 16-bit (upper half reads $FFFF).
```
000000-07FFFF  ROM (512 KB, 32-bit, deco156-encrypted)
100000         OKI #1  "okisfx"   (SFX, R/W byte)
140000         OKI #2  "okimusic" (music, banked, R/W byte)
180000-187FFF  main RAM (32 KB, 16-bit)
190000-191FFF  sprite RAM (8 KB, 16-bit)
1A0000-1A0FFF  palette RAM (4 KB, 16-bit, xBGR555)
1B0000-1B0003  R: IN1 (players)   W: eeprom_w (see below)
1C0000-1C001F  DECO16IC pf control (dword)
1D0000-1D1FFF  pf1 name table  (mirror 1D2000)   1D4000-1D5FFF pf2 name table
1E0000-1E1FFF  pf1 rowscroll                      1E4000-1E5FFF pf2 rowscroll
1F0000-1F0003  control reg (readonly / nopw — DE156 pin pulse; ignore)
200000-200003  R: IN0 (system)     [base_map]
201000-201FFF  systemram (4 KB internal, 32-bit, mirror 2000) [base_map]
```
`eeprom_w` (write to 0x1B0000): `okimusic` bank = `data[2:0]`; EEPROM clk=`data[5]`, di=`data[4]`,
cs=`data[6]` (93C46, 16-bit).

### Inputs
- **IN0 @0x200000:** b0 coin1, b1 coin2, b2 service1, b3 service (no-toggle, active-low), b7 vblank
  (active **high**), b8 eeprom DO. Upper unused.
- **IN1 @0x1B0000:** P1 b0-3 = U/D/L/R (8-way), b4-6 = buttons 1-3, b7 = start1;
  P2 b8-11 = U/D/L/R, b12-14 = buttons, b15 = start2.
- 2 players, **3 buttons** each (osman is fixed to 3-button per the EEPROM notes).

### ROMs (set `osman`, region byte offsets)
| region   | file        | size  | notes |
|----------|-------------|-------|-------|
| maincpu  | sa00-0.1e   | 512K  | DE156-encrypted ARM |
| tiles    | mcf-00.9a   | 512K  | in a 2 MB region via `ROM_CONTINUE`: blk0→0, blk1→0x100000, blk2→0x080000, blk3→0x180000; **deco56-encrypted**; 4bpp RGN_FRAC(1,2) planes split at 0x100000 |
| sprites  | mcf-01.13a  | 2M    | @0x600000 |
| sprites  | mcf-02.14a  | 2M    | @0x400000 |
| sprites  | mcf-03.14d  | 2M    | @0x200000 |
| sprites  | mcf-04.14h  | 2M    | @0x000000 (8 MB region, 4bpp RGN_FRAC(1,2) split at 0x400000, **not** encrypted) |
| okisfx   | sa01-0.13h  | 256K  | OKI #1 samples |
| okimusic | mcf-05.12f  | 2M    | OKI #2, **address bitswap** deinterleave in init_simpl156, then bank[2:0] |
| eeprom   | eeprom-*.bin| 128B  | region defaults; candance differs only here |

### Decryption / init (init_simpl156 + init_osman)
1. `okimusic` address descramble: `bitswap<24>(x, 23,22,21,0,20,19..1)` — moves the low address bit
   up to bit 20 (the OKI banking chip drives the true low line).
2. `deco56_decrypt_gfx("tiles")` — tile gfx are encrypted (same deco56 as nslasher tiles).
3. `deco156_decrypt` — ARM program decrypt.
4. `init_osman` also installs a PC=0x5974 idle-skip — MAME-only, irrelevant to FPGA.

## Reuse map — TWO sources

### A. Video ← **cninja** (in-tree, jtframe-native, lint-clean) — the SAME Data East chips
Osman's `deco16ic` tilegen and `DECO_SPRITE` (chip 52) are the exact chips cninja already ports as
generic modules. Import them **directly via files.yaml cross-core `get:`** (the arbalest←cal50/kiwi
pattern — no copy, no relocation, cninja is not modified so nothing to re-lint):
- **`cores/cninja/hdl/jtframe_deco16.v`** — faithful `deco16ic.cpp` single-PF renderer (rowscroll/
  colscroll, runtime 8×8/16×16, 64×32/64, screen+per-tile flip, banking). **Instantiate 2×** for
  Osman's pf1+pf2 (cninja instantiates 4× for its two tilegens). Ports: tile BRAM, rowscroll BRAM,
  32-bit gfx SDRAM. `pxl = {colour[3:0], pixel[3:0]}`.
- **`cores/cninja/hdl/jtframe_decospr.v`** — faithful `decospr.cpp` MXC-06/chip-52 sprite gen, 4bpp,
  256 slots × 4 words, `pxl = {epri, pri[1:0], colour[4:0], pixel[3:0]}`. **Instantiate 1×.** Matches
  Osman's DECO_SPRITE (colour base 0x200 = 5-bit colour ×16; `set_flip_screen(true)` → `flip`).
- **`jtcninja_colmix.v` / `jtcninja_video.v`** — reference for the pen+priority mux and palette-RAM
  read port; Osman's colmix is simpler (plain xBGR555, pf2→pf1→spr priority, one tilegen).
- cninja `doc/` + `mem.yaml`/`mame2mra.toml` — the deco16 gfx SDRAM layout + the **ROM_CONTINUE / map-
  digit** handling (directly relevant to Osman's tiles ROM_CONTINUE and the 4bpp plane split).

### B. CPU spine ← **nslasher clone** (reference only, rewritten fresh — cninja is 68000, no help)
- **Amber 2 ARM** — **VENDORED** into `cores/osman/hdl/amber/` (21 files, OpenCores permissive
  license), referenced via `files.yaml` `from: amber`. Decision: keep Amber (not an ARM6/3DO core)
  — DE156 is technically ARM6-class, but Amber's ARMv2a is proven to run these exact games
  bit-correctly on real HW (rejectedcoins' nslasher on DE10-Nano); no ARM6 exists in the tree.
  Revisit only if an instruction Amber mishandles turns up. (`from:` DOES pull hdl subfolders —
  the nslasher clone's "get forbids subdirs" note is wrong for jtframe.)
- **`jtnslasher_deco156.v`** — DE156 at-fetch decrypt → `jtosman_deco156.v`. Validate against
  `doc/mame/deco156_m.cpp` (algorithm identical across all DE156 games).
- **`jtnslasher_gfxdec.v`** — deco56 tile decrypt → `jtosman_gfxdec.v` (Osman tiles ARE deco56-
  encrypted; cninja tiles are not — cninja uses deco104/146 protection instead). deco56 tables
  regenerate from `doc/mame/decocrpt.cpp`.

### Osman-specific (write fresh)
`jtosman_game.v` (top), `jtosman_main.v` (ARM bus/decoder + IN0/IN1 + eeprom_w), `jtosman_video.v`
(2× deco16 + 1× decospr + colmix), `jtosman_colmix.v` (xBGR555 + priority), `jtosman_sdram.v`.
Sound = 2× **jt6295** (jtframe) + okimusic address-bitswap + bank; EEPROM = **jteeprom** (93C46).
**Drop vs nslasher:** Z80, YM2151, Ace blender, 5bpp sprites, deco74.

## Proposed SDRAM layout (finalize with rom-banking skill)
BRAM: main RAM 32K, systemram 4K, sprite RAM 8K, palette 4K, pf1/pf2 name+rowscroll.
SDRAM banks (main ROM deco156-decrypt-at-fetch, tiles deco56-decrypt-at-fetch, sprites plain):
- main ARM ROM 512K (32-bit) · tiles 2M (16-bit) · sprites 8M (4bpp) · okisfx 256K · okimusic 2M.

## Bring-up plan (canonical MAME-driven path)
0. [x] MAME driver as ground truth (doc/mame/, this STATUS).
1. [x] Scaffold DONE + **lint clean** (`./lint-core.sh osman`, exit 0, no warnings).
   - cfg/: files.yaml, macros.def, mem.yaml, mame2mra.toml, msg (base=nslasher stripped + cninja
     video-import). hdl/: jtosman_{game,main,snd,video,colmix,deco156,gfxdec}.v — structural
     skeleton, submodules tie-off stubs (cninja scaffold pattern). Amber vendored in hdl/amber/.
   - **Amber GATED** in files.yaml (commented `from: amber`): not instantiated yet + needs incdir for
     its internal `include files and exclusion of sim-only files (a23_decompile.v/global_defines.v).
     Wire it in step 2.
   - cfg TODOs: tiles ROM_CONTINUE map-digits byte-check; sprite 8MB plane-pack; decospr addr widen;
     PXLCLK/58Hz timing; OKI rsum tune; button names. mem.yaml audio channels = pcm1/pcm2 (14-bit).
2. [x] CPU spine BOOTS + **RUNS THE FULL GAME** — no longer freezes after the first screen.
   maxPC climbs to 0x0707ff (gameplay code); was stuck at 0x10010. Matches MAME boot 1-for-1
   (1600 PCs, `ver/osman/verify_arm_boot.sh`). Lint clean.
   - **Boot fix:** 32-bit ROM per-halfword byteswap (`rom_data[23:16],[31:24],[7:0],[15:8]`) — feeds
     deco156 the LE32 word (dec(0)=ea000169=B 0x5AC).
   - **Un-freeze fix:** cabinet inputs are JTFRAME **active-low idle=1 — do NOT invert.** I had
     inverted coins/service/cab_1p/dip_test, so the game read phantom presses and wedged. Found via
     a write-stream diff (identical to MAME for 4 frames, then 23 input-derived bytes diverged);
     idle now matches MAME (IN0=0x018f low nibble, IN1=0xffff). Also: byte-write enables + 32-bit
     (4-byte) stride on ALL work/video RAMs (the ARM addresses 16-bit devices at 32-bit spacing).
   - Remaining spine TODO: IN0 bit7 vblank read-phase, bit8 eeprom DO (EEPROM not preloaded yet);
     joystick bit order; ROM cache (speed).
3. [~] Video: vtimer (320x240) + palette (xBGR555) + pf/spr/rowscroll RAM + colmix backdrop DONE.
   Screen still black — osman's backdrop IS black; the whole picture is tiles+sprites. NEXT: wire
   2x jtframe_deco16 (via jtosman_gfxdec deco56) + jtframe_decospr, and the tiles ROM_CONTINUE MRA.
   - `jtosman_deco156.v` = faithful MAME `decrypt()` port (nslasher's, 17-bit word index for 512 KB).
   - `jtosman_main.v` = Amber `a23_core` via wishbone + deco156-at-fetch + simpl156 decoder + work RAM
     (BRAM: mainram 16b/32K, systemram 32b/4K) + `jt9346` EEPROM (clk=d5/di=d4/cs=d6, +oki bank d[2:0])
     + IN0/IN1 + OKI writes + VBL-IRQ (level). NO ROM cache yet (nslasher's speed opt; add if slow).
   - **Amber integration (hard-won):** includes rewritten `amber/<file>` to resolve via the hdl/ incdir
     (jtsim adds `-I$CORES/osman/hdl`, not subdirs). `sram_byte_en`/`sram_line_en` altsyncram → inferred
     RAM (portable). `cpu_export` gated behind `` `ifdef A23_CPU_EXPORT `` (off). `a23_decompile.v`
     excluded. a23 L1 cache is present but runtime-disabled (CP15) on the DE156 binary. Paced via
     `i_system_rdy = cen_arm`.
   - **NEXT: boot-trace vs MAME** (skill cpu-boot-trace). Watch: reverse=true 32-bit ROM byteswap
     (`OSMAN_ROM_BYTESWAP`, nslasher needed it), VBL-IRQ HOLD-vs-level + ack, BRAM 1-cycle ack timing,
     systemram byte-we, JTFRAME→simpl156 input bit remap.
3. [ ] First non-black frame: palette (xBGR555) + one tilemap layer.
3. [~] First non-black frame — **video pipeline ALIVE**: vtimer (320x240, VBL IRQ) + palette RAM
       (ARM-written) + colmix (xBGR555->RGB) produce visible, ARM-driven palette colours on screen.
       Backdrop-only render (layers still 0) so it shows the pen-0x100 fade bars, not the intro art.
   - Unlocks this turn: real vtimer LVBL; **one-shot VBL IRQ** (held level re-entered the handler
     forever); **ungated the a23** (`i_system_rdy=1`; cen_arm gating stalled it ~200x, 210K->43M
     fetches); **EEPROM preload** `eeprom_osman.hex` (osman won't boot without word[0]=0xffbe /
     word[0x20]=0x0088 — the decisive fix). vtimer H off-by-one: HB_START=319 for 320 wide.
### deco56 tile decrypt (jtosman_gfxdec) — DONE structurally, unconfirmed visually
Reused nslasher's deco56 decrypt VERBATIM (deco_consts.vh + deco56_address/xor/swap.hex — the
universal chip transform) wrapped as a 2-read at-fetch adapter feeding jtframe_deco16 from a 16-bit
encrypted-tiles SDRAM port. VERIFIED vs MAME dataeast/decocrpt.cpp: xor_masks + swap_patterns match
byte-for-byte; address/table indexing identical (addr={i[19:11],addr_tab[i&0x7ff]}, xor by
xor_tab[addr&0x7ff], swap by swap_tab[i&0x7ff]). Byte/plane order worked from tile_16x16_layout +
jtframe byte-p=plane-p: FRAC(0,2) word=planes2,3=high16, FRAC(1,2)=planes0,1=low16; SDRAM returns
BE-byteswapped (same as main ROM) so decode_word(bswap(sdr_data)). game.v post_addr undoes mcf-00's
ROM_CONTINUE (swap word bits [19]/[18]).
**CPU IS NOT STUCK** (earlier "stuck at 0x707ff" was a misread — 0x707ff is a data-table read, not code;
the boot.log maxPC tracks the highest ROM *address*, incl. data loads). Traced vs MAME: the ARM boots,
is vblank-IRQ-synced (main sets flag [r8+0x11]=1 @0x5970 & spins; IRQ @0x110 reads IN0+edge-detects,
dispatches frame work; attract entry 0xE7E0 IS reached), and consecutive same-field frames differ ~85%
(the tilemap IS being scrolled/animated). So the on-screen vertical stripes are the **tile decode still
wrong**, NOT a hung CPU. (Minor: FPGA doesn't reach MAME's deepest code 0xB168/0x30xxx — likely a later
sprite/object phase; secondary to the tilemap.)
NEXT: grade + fix the tile decode with SCENE-REPLAY — load a burst_* dump.bin (VRAM+palette+pfctrl) into
the video BRAMs, render NOMAIN, diff vs screen.png. The boot sim can't grade tiles (frames don't align
with MAME's + the scene animates). Candidate decode knobs left: input byteswap (BE vs LE), the W-map
half/subrow bits, pswap (plane-pair order), and the ROM_CONTINUE block-swap.

4. [~] pf1/pf2 tilemaps WIRED — 2x `jtframe_deco16` (u_pf1_eng/u_pf2_eng) fetch gfx, apply the
       ARM-written palette, and paint the framebuffer (84% lit, CPU still boots 0x707ff). Pixels are
       SCRAMBLED (vertical stripes) because tiles are fed RAW: deco56 tile-decrypt (jtosman_gfxdec)
       + the tiles ROM_CONTINUE / 4bpp plane-pack MRA are NOT done yet. gfx bus widened to 32-bit
       (mem.yaml BA1 gfx1a/gfx1b data_width:32; jtframe_deco16 needs a 32-bit rom_data = 8px x 4pl).
       NEXT: deco56 decrypt-at-fetch + MRA plane-pack (then stripes -> real tiles); then decospr.
5. [ ] Inputs (IN0/IN1, EEPROM 93C46, service).
6. [ ] Sound: 2× OKI M6295 (jt6295) + okimusic address descramble + bank.
7. [ ] Pixel-exact, MRA, hardware.

## Sim workflow gotcha (bit me hard)
The Verilator SDRAM model loads banks ONLY from `sdram_bank?.bin` (the cache). There is NO
direct preload from `rom.bin`. So if the cache is missing and you run WITHOUT `-load`, every
bank is EMPTY → the ARM fetches 0/garbage → `maxPC=0x10` (curPC bounces 0x0c/0x10 in the abort
vectors). This looks exactly like a dead-CPU regression but is not. Fix: run once with
`./sim-core.sh osman osman -load` (full SPI download; ~190 frames, slow, writes the 4 bank
files) then subsequent runs without `-load` are fast (download "shortened to 32 bytes", ROM
ready frame 0). ALWAYS `-load` after deleting the cache or changing mem.yaml bank layout.
