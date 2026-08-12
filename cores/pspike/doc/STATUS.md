# jtpspike - status

Core folder `cores/pspike`. Video System Co. hardware from MAME `vsystem/pspikes.cpp`.
**Power Spikes** and **Turbo Force** both boot and render. Sound is wired but never heard.

Scope: originals only - pspikes/pspikesk/pspikesu/svolly91, turbofrc(+sets), and later
karatblz, spinlbrk, aerofgtb. All bootlegs are out (different sound hardware).

## Hardware

68000 @10MHz (XTAL 20/2), Z80 @5MHz (20/4), YM2610 @8MHz, C7-01 GGA video timing,
VS8904/VS8905 sprites, VS8803 (unemulated, unknown).

The GGA registers are decoded - the game writes a table at ROM `0x1202e`, H in units of
4 pixels and V in units of 2 lines, both biased one unit. It gives **456x256 total,
352x240 visible**, matching the 61.31 Hz measured on PCB with a 7.159 MHz pixel clock
(14.318181/2). See `HARDWARE.md`.

Clock: `jtframe_pll7159` -> 57.2727 MHz. **`JTFRAME_PXLCLK=6`** picks /4 and /8, giving
pxl2_cen 14.318 MHz and pxl_cen 7.159 MHz. (`=8` would give 9.545 MHz - the macro name
means MHz-at-48MHz, not a divider.)

## Files

```
hdl/jtpspike_game.v      top, BRAM port wiring, header instance
    _header.v            per game booleans from MRA header byte 0
                         bit0 pspikes, bit1 turbofrc
    _main.v              68000, both address maps, NOMAIN scene stub
    _snd.v               Z80 + jt10 (YM2610) + ADPCM A/B from SDRAM
    _video.v             vtimer, 2x scr, 2x obj, mixer
    _scr.v               tile layer, parametrised per game
    _obj.v / _objscan.v  VS8904/8905 sprite chip
    _colmix.v            xRGB-555 palette lookup
cfg/  macros.def mem.yaml files.yaml mame2mra.toml msg
doc/  HARDWARE.md BOOT_TRACE.md plds.md turbofrc.md  + mirrored MAME sources
ver/powerspikes/  scenes/ sim_results/ mame_scripts/dump_burst.lua
ver/turbofrc/     same
```

## Facts established the hard way - do NOT re-litigate

- **maincpu has TWO layouts in this driver** - the region is setname-qualified:
  - pspikes / turbofrc are `ROM_LOAD16_WORD_SWAP` -> load STRAIGHT (no `reverse`, no
    `width`). The download path already assembles the 16-bit word the way the 68000 wants.
  - aerofgtb / aerofgtc / sonicwi are `ROM_LOAD16_BYTE`, an even/odd pair -> need
    `width=16` to interleave AND `reverse=true` to put the odd file first.

  Check by decoding the blob reset vector *as the CPU sees it* (swap each byte pair, the
  blob is stored byte-swapped): pspikes SP=0x110000 PC=0x400, turbofrc SP=0x0CFA00
  PC=0x5BE, aerofgtb SP=0x0D0000 PC=0x45A. Reading the blob straight makes a wrong
  aerofgtb vector look right - it was the cause of the "aerofgtb never boots" stall.
- **Tiles and sprites need OPPOSITE packed->planar orders.** `jtframe_tilemap` wants the
  leftmost pixel in the MSB of each plane byte (hand-built in `_scr.v`); `jtframe_draw`
  consumes LSB first, so sprites just use `.PACKED(1)`.
- **Sprite tile address is `{code,Y,H}` not `{code,H,Y}`** - `gfx_16x16x4_packed_lsb` is
  row major. Wrong order gives scrambled quarters.
- **Transparent pen is 15, not 0.** `jtframe_obj_buffer` defaults `ALPHA=15` but
  `jtframe_objdraw` overrides to 0, so it must be set explicitly.
- **`HFIX(0)` on `jtframe_objdraw`.** HFIX assumes hdump wraps inside HS; ours wraps at
  H=451 and HS ends at 424, so hdfix never resyncs and the first ~53 pixels read the far
  end of the line buffer.
- **Sprite priority is paint order, first-drawn wins.** Implemented as keep-last with the
  walk reversed (slots ascending, pri==0 pass first) - equivalent, and avoids KEEP_OLD,
  whose registered read-back costs a pixel at every border (visible as bright specks).
- **Raster RAM is indexed by `vdump`, not `vrender`** - vdump already advanced at
  H_VNEXT=HS_START when HS latches scrx. Using vrender puts split-scroll boundaries one
  line early.
- **BRAM reads are one cycle late** (`qq1 <= mem[addr1]`). Cost several sprite bugs.
- **jt10.yaml in modules/jt12 is stale** (old `here:` schema, does not parse). Use bare
  `jt12:` in files.yaml, which pulls the module's own files.yaml.
- **`JTFRAME_SIM_GAMEID` is not valid here** - jtsim only accepts `JTFRAME_*` macros that
  appear in jtframe's macros.md. Scene replay uses core-local `-d SIM_TURBOFRC`.
- **Never compare MAME and FPGA by frame number.** Only scene replay compares pictures.

## Horizontal offsets - the current live question

`_video.v` feeds each layer an hdump running ahead of H:

```
hoff_scr = turbofrc ? 10 : 14      hoff_obj = hoff_scr - 9
```

14 was tuned for pspikes and includes its visarea offset (`set_visarea(0*8+4,...)`,
picture starts at x=4). Turbo Force is `set_visarea(0*8,...)`, x=0, hence 10. The other
10 is the tilemap pipeline.

On top of that `_scr.v` applies MAME's per layer bias, turbofrc only:

```
layer 0  rasterram[7] - 11        layer 1  scrollx1 - 7      both  scrolly + 2
```

**These two stack.** The last complaint was the turbofrc background shifted along the
scanline; the per-game lead is the newest attempt at it and is UNVERIFIED. If it is still
wrong, the suspects in order: the 10, the -11/-7, and whether jtframe_scroll's LATCH_SCRX
timing adds another pixel.

Turbo Force is ROT270: "horizontal" = along a scanline = scroll **X**; vertical alignment
across scanlines = scroll Y. The game scrolls via X. Y registers sit static at 0x1fe.

## Running a boot sim - EXACT invocation

```bash
ROMS_HOST=~/mameroms FRAMES=1000 ./sim-core.sh pspike aerofgtb
```

Setname is **positional**, not a flag. Do NOT add `-video`/`--video`: sim-core.sh already
runs `jtsim -setname X -video $FRAMES`, and a second `-video` leaves `MAXFRAME` empty so
the C++ harness fails to compile. `ROMS_HOST` is required whenever the network share at
`~/.mame/roms` is unmounted - the local copy is `~/mameroms` (NOT `~/.mame/roms-local`,
which is what the generic CLAUDE.md says).

Frames land in `cores/pspike/ver/game/frames/` as **`frame_NNNNN.png`**, written only when
the picture changes (so numbering has gaps). sim-core.sh's own ffmpeg step globs
`frame_*.jpg` and therefore silently skips - encode the mp4 by hand. Globbing for `.jpg`
also makes a perfectly healthy run look like it produced nothing.

## HARDWARE: CPU stalls immediately (sim is fine) - TOP OPEN ISSUE

On MiSTer the core loads ROMs, the system menu works, but the screen is black
and there is no sound. Read from the debug build (debug=true, START+UP steps
debug_bus, START+left/right toggles white debug_view / reddish sys_info):

  view 0  game flags     = 00000001  -> header decodes correctly on hardware
  view 1  ROM heartbeat  = 26 FROZEN -> ~38 fetches then the 68000 stalls
  view 3  main_addr[16:9]= FF        -> parked on an all-ones address

Reading: the CPU read 0xFFFF from SDRAM (unprogrammed returns all ones),
executed it, and hung. The reset vector worked, so the first region is fine and
a later access got no data. Suspect the ROM DOWNLOAD or the SDRAM bank map, not
the CPU logic - simulation cannot catch this because its SDRAM model is
preloaded from the .rom and has no latency.

PRIME SUSPECT - SDRAM IS OVERCLOCKED. pspike does NOT set JTFRAME_SDRAM96, so
jtframe_emu drives SDRAM_CLK = clk48sh = pll outclk_1. With jtframe_pll7159
that output is 57.272727 MHz, NOT 48 - the signal names keep saying clk48 while
the PLL family underneath decides the real frequency. So the SDRAM controller
runs ~19% over its nominal 48MHz. (The 114.5MHz clk96/clk96sh outputs are
unused without JTFRAME_SDRAM96.) pspike is the ONLY core in the repo on
pll7159, so nothing else has ever run the controller this fast. Simulation cannot see it - the Verilator
SDRAM model has no timing. Fits partial failure (bank 0 some traffic, banks
1-3 none) better than any logic bug, and fits every game being black on HW
while all render in sim.

SDRAM stats (sys_info, debug_bus=1000_00xx; bits1:0 = bank, /4096):
  bank 0 = 01 (~4-8k accesses/frame)   banks 1,2,3 = 00  ZERO TRAFFIC
Bank 0 holds maincpu + soundbank, so its traffic is probably the Z80 while the
68000 is parked. Banks 1 (ADPCM), 2 (tiles) and 3 (sprites) are never accessed
at all - that is black screen AND silence from one fault: the gfx/ADPCM read
paths never even issue requests on hardware. IOCTL says the download completed
(F0 = gfx_en 1111, ioctl_rom 0), so the data is there.

Old note: sys_info debug_bus=0111_0000 gives {gfx_en[0:3],0,ioctl_ram,ioctl_cart,
ioctl_rom}. ioctl_rom still asserted = download never finished. Download OK but
still stalled = bank map disagrees with what the MRA wrote. NOTE karatblz
introduced two ZERO-SLACK exact fits in the bank layout (adpcmb fills
PCMB_START->SPRLUT_START exactly; spritegfx fills BA3_START->OBJ1_START
exactly) - anything growing there shifts silently.

## Clocking - pll5369, verified in sim

JTFRAME_PLL name digits = pixel clock in kHz, and JTFRAME_MCLK = digits*8 (x2
with SDRAM96) - macros.go:435. So the PLL is chosen BY PIXEL CLOCK and every
mem.yaml cen rescales itself automatically. The 68000 is the ONLY hand-written
clock (CEN_NUM/CEN_DEN in _main.v) and must be recomputed per PLL.

  JTFRAME_PLL=jtframe_pll5369   clk = SDRAM_CLK = 42.954545 MHz
  JTFRAME_PXLCLK=8              M=3 -> pxl_cen = clk/6 = 7.159090 MHz (exact)
  CEN_NUM=44 CEN_DEN=189        42.954545 * 44/189 = 10.000 MHz (exact)
  jtframe_68kdtack_cen #(.W(8)) num[6:0] den[7:0], 189 needs 8 bits

Both ratios are exact: pxl = 315/44 MHz so mclk = 945/22 MHz. Sim: 61.33 Hz,
matching the 61.31 measured on PCB.

Beware the naming: clk48/clk48sh carry whatever the PLL family gives, NOT 48.
On pll7159 that was 57.27 on SDRAM_CLK. PXLCLK only accepts 8 or 6 (M=3 or 4).
SDRAM96 doubles clk AND SDRAM_CLK (85.9MHz here) - the whole design must then
close timing at that rate, and CEN_NUM halves to 22.

Earlier settings for reference: pll7159 = 57.272 MHz, CEN_NUM/DEN 11/63.
pll6671 = 53.365 MHz - with 11/63 the CPU runs 9.32MHz, hence "boots but slow".

## C7-01 GGA

`jtpspike_gga.v` replaces `jtframe_vtimer` - same counter body, parameters turned into
wires fed by the chip's 16x8 register file. Decode is `io_cs & A[10]` on every game
(fff400 pspikes, 0ff400 turbofrc, 0fe400 aerofgtb), write only, low byte, A[1] picks
data vs address latch.

Registers hold `(reg+1)*4` pixels (H) or `(reg+1)*2` lines (V). Captured from MAME, whose
skeleton device logs every write:

```
       reg  00   01   02   03   08   09   0a   0b     grid
  pspikes   352  400  424  456  240  244  248  256    352x240 on 456x256, 61.31 Hz
 turbofrc   identical to pspikes
 aerofgtb   320  376  400  456  224  226  230  250    320x224 on 456x250, 62.80 Hz
```

MAME's own visarea agrees: turbofrc `0..351 x 0..239`, aerofgtb `12..331 x 0..223`.
jtsim measured our output as 320x224 @ 62.80 Hz for aerofgtb, matching independently.

Two things the runtime version needs that the parameterised one did not:
- **reset defaults are the pspikes table**, else the download runs on a 4x2 grid
- **counter wraps compare `>=`**, so a register write below the current count cannot wedge

Consequences:
- `JTFRAME_WIDTH/HEIGHT` stay 352x240 (family max, one bitstream). aerofgtb sims need
  `-d JTFRAME_SIM_SKIP_VSIZE`. Deliberately NOT in macros.def - it would disable a valid
  regression check for the other two.
- `JTFRAME_SKIP_RATE_TEST` IS in macros.def: documented for exactly this case, software
  programmed counters, and the rate is genuinely per-game.
- aerofgtb's `hoff_scr=22` was tuned on the wrong 352x240 raster and must be re-derived.
  MAME's aerofgtb visarea starts at x=12, likely most of that 22.
- Scene replay is NOMAIN so the GGA keeps its defaults - right for pspikes/turbofrc,
  WRONG for any future aerofgtb scene. Its 12 registers must join the scene reg dump.

## Header - GENERATED, do not hand-write

`cores/pspike/hdl/jtpspike_header.v` is produced by `jtframe mra` from the
`[header] registers` block in mame2mra.toml, and is gitignored
(`.gitignore:75 cores/*/hdl/*_header.v`). It only gets generated when
`registers` is present - with plain `data=[...]` bytes, `MakeVerilog` returns
early and writes NOTHING, which is how it came to be hand-written and then
missing from the Quartus build.

For the same reason files.yaml uses the glob `jtpspike_*.v`: the generated file
cannot be listed by name, since a clean checkout would reference a missing file.

Flags live in header byte 1 (byte 0 is left for coremod): bit0 pspikes,
bit1 turbofrc, bit2 aerofgt. Verified in the blobs: 0001../0002../0004...

LOST in the conversion: the hand-written module had `SIM_TURBOFRC`/`SIM_AEROFGT`
overrides for scene replay and a $display probe. Scene sims must now rely on the
real header byte from the per-setname .rom - UNVERIFIED, needs one scene run.

## karatblz - CPU verified, palette base is wrong

CPU is CORRECT: the code-path diff against MAME passes - every one of the 2991
addresses MAME executes is reached by the FPGA (1988 extra are 68000 prefetch).
Captured with ver/karatblz/mame_scripts/trace_main_boot.mame, compared with
`MAME_TR=/tmp/kb_main.tr cores/pspike/ver/pspikes/verify_main_boot.sh`.

The black screen is the PALETTE BASE. Instrumented in _game.v under SIMULATION:

```
pal writes nonzero=10500  maxwaddr=3ff   CPU fills palette words 000-3FF
mix_addr max=4ae                          renderer indexes 400-4AE
idx_nz=116736 (whole frame) pal_nz=0      every lookup misses -> black
```

NOT a palette-base bug - that was a wrong first reading. o0_idx spans 0x400-0x4FF
and max is 0x4AE with EVERY pixel >= 0x400, so every pixel comes from sprite
chip 0: o0_op is opaque across the whole frame and hides both tile layers. The
sprite engine is producing garbage for karatblz. Compare turbofrc, which is
healthy: mix_addr max=400, pal_nz=114365.

Widening the sprite LUT read path (objl_addr 13 -> 15 bits, gated by wide_lut so
the 16kB games are bit-identical) did NOT change it. That widening is still
correct on its own - karatblz's LUTs are 64kB and the CPU fills them - but it is
not the cause. Ruled out so far, each by measurement, not argument:
- CPU (code-path diff vs MAME passes)
- palette base (writes are real, 0-3FF, with data)
- sprite LUT width (widened to 15 bits, no change)
- sprite priority: WRONG LEAD. set_pritype(1) belongs to spinlbrk (line 2574),
  not karatblz - read from a bare grep without checking the enclosing function.
  The change was reverted. ALWAYS resolve which machine_config a call sits in.
- transparent pen: MAME uses 15 for every game, same as us

METHOD (Andrea's, and it works): diff the machine_config of the broken game
against a working one call by call, then compare MAME's RAM buffers against
ours - sprite RAM, sprite list, palette. Do that BEFORE theorising.

karatblz vs aerofgtb config diff - identical gfx decode, identical
xRGB_555/1024 palette, identical two VSYSTEM_SPR2 + callbacks. Only:
  screen update   screen_update_karatblz   vs screen_update_turbofrc  <-- READ THIS
  sound ports     spinlbrk_sound_portmap   vs pspikes_sound_portmap
  sprite offsets  none                     vs set_offsets(3,-1)
karatblz is the ONLY game of our set with its own screen_update. Read it
(pspikes.cpp:613, on pspikes_sound_cpu_state) - vs screen_update_turbofrc:

                  turbofrc                        karatblz
  lyr0 scroll X   set_scroll_rows(512),           plain reg scrollx[0] - 8
                  per row rasterram[7] - 11       (NO raster RAM)
  lyr0 scroll Y   scrolly + 2                     scrolly[0], no +2
  lyr1 scroll X   scrollx[1] - 7                  scrollx[1] - 4
  lyr1 scroll Y   scrolly[1] + 2                  scrolly[1], no +2
  lyr1 draw       draw(...,0,1)  priority 1       draw(...,0,0)  priority 0
  sprites         same 4 calls                    same 4 calls

The compositing difference is the tilemap[1] draw priority: turbofrc marks the
priority buffer with 1 so layer 1 masks sprites; karatblz marks 0 so it does
not. Our mixer hardcodes turbofrc's scheme (s1_op beating sprites). That plus
the missing 0ff008 layer-0 scroll port are BOTH in this one function, and
neither is in the sprite engine.

THE remaining invariant: o0_op is asserted on all 116736 pixels while objscan
reports only 2 draws/line (chip 1: 0). The sprite line buffer is reading back
non-transparent where nothing was drawn. Look at jtframe_obj_buffer's clear/
readback for the karatblz case - ALPHA=15 is set, so why is the empty buffer
not returning 15.

Also done: I/O reads (DSW at A[4:1]=4, pending at 5 - both moved vs turbofrc),
I/O writes (sound latch at 0ff007 low byte, flip bit 7 of 0ff000, gfxbank
0ff002 bit0/bit3), P4 on IN3. STILL MISSING: layer 0 scroll X has no port
(0ff008; karatblz has no raster RAM), and rest2bin.sh does not know the
151562-byte dump layout.

JTFRAME_BUTTONS=4 widened the top-level joysticks to [7:0]; _main.v declared
[6:0] and was silently truncating button 4 for every game. Ports and all four
input packings were corrected.

## Scenes - capturing screen.png

Do NOT set snapname from Lua (`options.entries.snapname` has no working setter in
MAME 0.276 - both `:set_value()` and `.value =` fail silently or throw). Let MAME
use its default snapname into a scratch dir, then collate in capture order:

```bash
~/mame/mame <set> -rompath ~/mameroms -autoboot_script <dump_burst.lua> \
    -snapshot_directory <scratch> -video soft -window -nothrottle -noreadconfig -nowriteconfig
# then copy sorted(scratch/**/*.png) onto sorted(scenes/m*) 1:1
```

Never point `-snapshot_directory` at the scenes folder: MAME creates a `<set>/`
subdir there that then looks like an extra scene.

## Scenes

`MAMESET` is needed because the folder name is not the romset:

```bash
SIMARGS="-d SIM_TURBOFRC" MAMESET=turbofrc ROMS_HOST=~/mameroms \
    tools/scenesim/sim_scenes.sh pspike turbofrc [scene...]
MAMESET=pspikes ROMS_HOST=~/mameroms tools/scenesim/sim_scenes.sh pspike powerspikes
python3 tools/scenesim/build_diffs.py pspike <turbofrc|powerspikes>
```

Dumps are ONE `dump.bin` per scene split by `ver/game/rest2bin.sh`, which tells the two
layouts apart by size:

```
pspikes  29700 = vram 4096, rascr 4096, oram 1024, lut 16384, pal 4096, regs 4
turbofrc 57356 = vram0 8192, vram1 8192, rascr 4096, oram 2048,
                 lut0 16384, lut1 16384, pal 2048, regs 12
```

Registers must be captured because they live in 68000 registers, not RAM, and NOMAIN
would render them as zero. Read them from MAME memory **shares** - the sprite RAM is
mapped `writeonly()` and reads back as zeros through the CPU space.

Coverage gaps in the fixtures: pspikes `scrolly` is 0 in all 20 scenes; turbofrc scroll Y
is static and `flip` is 0 everywhere. Vertical scroll and flip are effectively untested.

turbofrc scenes m00300/m00600 were deleted - black boot screens, no content before ~1800.

## Speed

A turbofrc scene is ~3 minutes (four gfx engines), pspikes ~50 s. **No worktrees, no repo
copies** - Andrea's disk is small and stale copies get forgotten. Sim sequentially.

The SDRAM bank cache (`ver/game/sdram_bank?.bin`) is invalidated whenever
`mame2mra.toml` is newer, and jtsim moves the banks to `sdram.old` rather than deleting
them. After a config edit, copy them back and `touch` them to skip the re-download.

## aerofgtb - BOOTS

The stall was the maincpu ROM order (see the facts section): aerofgtb is
`ROM_LOAD16_BYTE`, not `ROM_LOAD16_WORD_SWAP`. With `width=16, reverse=true` a
1000-frame sim goes from 11 unique frames of static tiles to 104 and the game boots.

Header bit 2, MRA data "04". Confirmed live in sim by a $display in
jtpspike_header: `header byte0=04 -> pspikes=0 turbofrc=0 aerofgt=1`. The probe
is still in the module, it is cheap and answers this class of question fast.

ROM: `aerofgt.7z` is a good merged dump (has `aerofgtb/g26 g27 it-19-02..05`).
jtframe only reads .zip, so it was re-zipped to `~/mameroms/aerofgt.zip`
(7343570 bytes). `~/mameroms/aerofgtb.zip` is a symlink to it, needed because
sim-core.sh checks for `<setname>.zip` and clones have none.
NOTE `aerofgts.zip` is a DIFFERENT game (Sonic Wings Limited, VS9108 hardware).

Address map verified line by line against `aerofgtb_map` - it is turbofrc's
with three regions moved: palette `0fd000`, I/O `0fe000`, raster `0ff000`.

Two bugs found and fixed while adding it:
- **Sound port map is per game.** aerofgtb uses `pspikes_sound_portmap`
  (YM 00-03, bank 04, ack 08, latch read 0c); pspikes and turbofrc use
  `spinlbrk_sound_portmap` (bank 00, latch/ack 14, YM 18-1b). Despite the name,
  pspikes does NOT use pspikes_sound_portmap. Wrong map = the Z80 never
  acknowledges, snd_pending sticks, and a polling 68000 hangs.
- **turbofrc input layout is not pspikes'.** pspikes: IN0=player2, IN1=player1.
  turbofrc: IN0=player1 + system, IN1=player2, IN2=player3 with START3 in bit 7.
  It also has COIN3 (IN0 bit15), TILT (13), SERVICE1 (14), TEST (12), so `tilt`
  and `dip_test` are now routed into jtpspike_main.

**Still stuck after both fixes**: 1000 frames gives 11 unique frames, a static
repeating tile pattern. Ruled out: header bit, sound port map. Remaining
suspects in order: (1) run the cpu-boot-trace skill against MAME, which is what
found the pspikes byte order bug and beats guessing - two guesses have now
failed; (2) DSW2 at `0fe008` reads all ones, we only pass dipsw[15:0] and
aerofgtb has two 16-bit DIP ports; (3) GGA timing, least likely to stall a CPU.

aerofgtb also wants its own raster: GGA table `4f 5d 63 71 1f 00 6f 70 72 7c 1f 02`
= 456x250 grid, 320x224 visible, vs 456x256 / 352x240 for the other two. The
vtimer parameters and JTFRAME_WIDTH/HEIGHT are compile time, so one build cannot
emit both. The fix Andrea wants: copy jtframe_vtimer to jtpspike_gga.v, turn the
parameters into inputs, add the 12 register file written at fff400 / 0ff400 /
0fe400. Not a boot blocker - wrong constants move the picture, they do not stall
a CPU.

## Which other games this hardware buys

Cheapest first, all reusing what exists:

- **karatblz** (5 sets), same driver, same everything. Blocker is BRAM: its two
  sprite lookup RAMs are 64 kB EACH against turbofrc's 16 kB.
- **spinlbrk** (4 sets), same driver. Sprite lookup comes from ROM not RAM -
  `SPRLUT_START` is already reserved in the bank map for exactly this. No
  ADPCM-B, own tile decode.
- **f1gp** (`vsystem/f1gp.cpp`), 4 sets. Same 68000 @10MHz + Z80 @5MHz + YM2610
  @8MHz + GGA + **two VSYSTEM_SPR2**, so sound/sprites/timing transfer directly.
  Adds a second 68000 (0x20000 of code, IRQ3 from an ACIA6850 used for linked
  cabinets) and a K053936 roz layer - and **jt053936.v already exists** in
  `cores/rungun/hdl/`, with three wrappers to copy from (riders, rungun, prmr).
  ROM layout differs in kind though: user1 2MB at 0x100000, user2 2MB at
  0xa00000, so the bank map needs redoing.
  **f1gp2 is NOT this hardware** - it uses vsystem_spr.h, the VS9108.
- Same sprite chip elsewhere per `vsystem_spr2.cpp`: welltris (fromance.cpp),
  pipedrm. The GGA comment table also names hatris, idolmj, mjnatsu, mfunclub,
  daiyogen, nmsengen, fromance, tail2nos - but those are marked "8x4 tiles", a
  different geometry from our 8x8 jtframe_scroll, so the tile layer is real work.

## Not done

- flip screen (agreed to bolt on at the end) - sprite coordinate flip is not implemented
- turbofrc sprite-vs-tilemap priority is a HYPOTHESIS: layer 1 stamps priority 1 and masks
  `pri==0` sprites. Derived from the same code that read wrong for pspikes. Unverified.
- sound never listened to on hardware
- PLD equations in `plds.md` (14 devices, all decoded) are unused - pin mapping unknown
- karatblz / spinlbrk / aerofgtb. karatblz needs 64 kB lookup RAM per chip, a BRAM problem
- **nothing is committed.** `cores/pspike/` is untracked, `doc/mame.xml` modified (+20
  machines, merged surgically to preserve the CPS3 sets)

## Working with Andrea

Hand over renders and audio, never grade them - he judges. No speculative sims. Measure
before theorising: dumping MAME data found four of five sprite bugs, staring at frames
found none.
