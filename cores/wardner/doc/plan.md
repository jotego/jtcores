# Wardner (Toaplan TP-009 / Taito B25, 1987) — jtcores bring-up plan

Status: **phases 1-5 verified in simulation, core assembled and linting clean.**
Sections 1-10 are the original plan, written before any HDL existed, and are kept
as the design record. **Start at "Picking this up on another machine" directly
below** — it is the current state and everything needed to resume. Section 11
onward is the running progress log.

---

# Picking this up on another machine

Written 2026-09-07 at the end of the cloud session, for a fresh local session on
macOS or the gunmetal x86 box. Nothing here assumes memory of the conversation.

## Where the work lives

Branch `claude/wardner-backup` on the `memmerson/jtcores` fork. It is a
temporary backup branch, not a pull request.

```bash
git clone <your fork> jtcores && cd jtcores
git checkout claude/wardner-backup
git submodule update --init                  # jtopl for the YM3812, and the CPU cores
```

`modules/jtframe` and `modules/jt32010` are tracked directly, not as
submodules, so a plain clone already has them. Do **not** use `--recursive`:
jtframe's nested Pocket target is an SSH-only URL and will fail without keys,
and nothing here needs it.

## What state the core is in

| Part | State | Evidence |
|---|---|---|
| TMS320C10 core (`modules/jt32010`) | done | 81 programs x 20000 instructions exact against a C model transcribed from MAME |
| DSP wrapper (`hdl/jttoaplan1_dsp.v`) | done | 6/6 transaction cases; real Wardner program, 480000 instructions over 16 seeds; 9/9 mutations caught |
| Main Z80 (`hdl/jtwardner_main.v`) | done | boots the real ROM through POST, DSP handshake, display enable |
| Sound (`hdl/jtwardner_sound.v`) | done | 288 key-ons in the subsystem bench and 163 in the whole core; envelopes match MAME 0.289 at r = 0.95-0.98 |
| Video (`hdl/jtwardner_video.v`) | done | pixel-exact against a MAME-transcribed reference on 9 game snapshots spanning 71 s of attract, two of them the demo playing with sprites over the foreground layer, and 72 random ones, both flip states |
| Core assembly (`cfg/*`, `hdl/jtwardner_game.v`) | done | official linter clean; whole core simulates at 54.8814 Hz; ROM layout verified byte for byte |
| MRA | done | every region byte-identical to the known-good image except the 2 known DSP words; a byte-reversed DSP region found and fixed |
| Synthesis (MiSTer) | done | fits and closes timing on a 5CSEBA6U23I7: 61% ALMs, 27% RAM blocks, 43% DSP, all slacks positive, `--nodbg` release build |

## Tools you will need

`verilator` (5.020 works, newer is better), `iverilog`, `gcc`, `python3`, `go`
(for the `jtframe` tool), and for the remaining work **MAME** and **Quartus**.

Two shims were needed in the cloud container and are **not** needed on a normal
machine: `envsubst` (from gettext, jtsim uses it once) and a `verilator` wrapper
dropping `--quiet-stats`, which Verilator 5.020 does not know. If your Verilator
is recent and gettext is installed, ignore both. See `ver/game/README.md`.

Standard jtcores environment, from the repository root:

```bash
source modules/jtframe/bin/setprj.sh   # JTROOT, JTFRAME, MODULES, CORES, ROM, JTBIN, PATH
```

`$ROM` lands at `$JTROOT/rom`; that is where `jtsim` looks for `wardner.rom`.

## Nothing ROM-derived is in git — regenerate it

`.gitignore` line 132 ignores `/cores/*/ver/**`, so every file under `ver/` was
force-added; anything not listed by `git ls-files` is generated. **Never commit
ROM data.** Point `$ROMDIR` at a directory holding a Wardner set (the bootleg
`wardnerb` works for everything except the MRA):

`ver/main/run.sh` and `ver/dsp/run_real.sh` rebuild what they need themselves,
so in practice you only have to make the graphics and the whole-core image:

```bash
cd cores/wardner
python3 ver/video/mkgfx.py $ROMDIR ver/video          # gfx_*.hex and .bin
python3 ver/game/mkrom.py  $ROMDIR $ROM/wardner.rom   # whole-core image
```

The rest, if you want them standalone (note `mkrom.py` writes the sound hex to
its third argument, defaulting to `snd.hex` in the current directory):

```bash
cd cores/wardner/ver/main
python3 ../dsp/dsp_from_proms.py $ROMDIR dsp_real.hex
python3 mkrom.py                 $ROMDIR main.hex snd.hex
```

The bootleg set carries the DSP as eight nibble-wide PROMs; `dsp_from_proms.py`
rebuilds the mask ROM from them and self-checks (0x600 words, CRC32 `273bf449`,
vectors `B $304` and `B $30b`). The parent `wardner` set instead has the single
dump `d70012u_gxc-02_mcu_71001`, which `ver/game/mkrom.py` prefers when present.

## Running the four verification suites

All four passed at commit `9631a4a` on gunmetal. Run them first to confirm the
checkout is sound before changing anything.

Three things had to be fixed before they would run on a stock local toolchain,
none of them in the design (commit `9631a4a`):

- **Icarus Verilog 13 rejects a signal used before its declaration appears.**
  `jt32010.v`'s `ram_q` and `tb_dsp.v`'s `viol` both relied on the older
  tolerance. Their declarations moved up.
- **`ver/main/run.sh` never listed `jtwardner_sound.v` or the jtopl sources**,
  so that bench could not build at all once the sound CPU joined `tb_main.v`.
- **`git submodule update --init` half-fails**: `jt539` and jtframe's `pocket`
  target need credentials, and the abort leaves `jtopl` cloned with an empty
  working tree. `git -C modules/jtopl checkout -f <sha>` finishes the job.

```bash
cd modules/jt32010/ver/cpu && ./regress.sh          # ~2 min, prints PASS
cd cores/wardner/ver/dsp   && ./run.sh              # transaction bench, 6 cases
cd cores/wardner/ver/dsp   && ./run_real.sh $ROMDIR # real program, 16 seeds
cd cores/wardner/ver/main  && ./run.sh $ROMDIR 3000 # boots the real ROM
cd cores/wardner/ver/video && ./fuzz.sh 24 1        # frame diff vs the reference
```

`ver/dsp/run.sh` takes an **activation count**, not a ROM directory. Passing a
path silently runs forever and races the shared log files. It cost an hour once.

## Running the whole core

`jtsim` insists on being run from a directory named after the set:

```bash
mkdir -p cores/wardner/ver/wardner && cd cores/wardner/ver/wardner
jtsim -verilator -load -video 4     # full ROM download, dumps sdram_bank*.bin
jtsim -verilator -video 240         # later runs preload the banks, much faster
```

A fast run does not stream the ROM through the download path, so the DSP mask
ROM never reaches its block RAM. Generate its two sim files once:

```bash
python3 - <<'EOF'
rom=open('../../../../rom/wardner.rom','rb').read(); dsp=rom[0x048000:0x049000]
open('dsprom_lo.bin','wb').write(dsp[0::2]); open('dsprom_hi.bin','wb').write(dsp[1::2])
EOF
```

Roughly 2.4 s of wall time per emulated frame, so 240 frames (4.4 s of game
time) takes about 9 minutes.

## What is left, in priority order

**1. ~~A gameplay frame with sprites and the foreground layer.~~ Done
2026-09-08 on gunmetal.** Nine snapshots from one 31000 ms boot, all
pixel-exact against the reference; `snap20000` and `snap25000` are the attract
demo playing, with 111 and 104 sprites over a populated foreground layer, and
match at ROM latency 0 to 4. The recipe is now:

```bash
cd cores/wardner/ver/main
MAXIO=20000000 ./run.sh $ROMDIR 31000 \
    +snap=2000,4000,6000,9000,12000,16000,20000,25000,30000    # ~65 min
cd ../video
for d in ../main/snap*; do ./run.sh $d; done
python3 ppm2png.py ../main/snap25000/rtl.ppm out.png 2
```

Two bugs stood between the old recipe and a sprite, both now fixed:

- The freeze delay was milliseconds times 1e6 in **32-bit arithmetic**, which
  wraps above 4295 ms. `+snap=14000` froze the game at 1115 ms and the
  suggested `+snap=22000` would have frozen it at 525 ms. So the "title screen
  at 14 s" was a screen 1.1 s into the boot, and the reason no snapshot ever
  held a sprite was arithmetic, not the game.
- `+snap=` now takes a list, so one boot leaves every snapshot behind.

A third finding, kept rather than fixed: **the boot bench's reference clock is
100 MHz where its dividers describe 42**, because `always #5` with a 1 ns time
unit is a 10 ns period. Measured: one simulated millisecond produces 100000
clock edges, 14285 "6 MHz" enables and 8333 "3.5 MHz" enables. Every ratio is
still exact, so the board simply runs 100/42 = 2.381 times faster than the real
one on a compressed time axis, which is what makes a 71-second attract sequence
reachable at all. It does mean **every millisecond that bench has ever printed
is 2.381 times shorter than it reads** - notably the audio observation "no note
keyed on within 4.4 s" covers 1.85 s of board time. `ver/game` under jtsim uses
jtframe's real clocking and is unaffected.

**2. ~~Audio output.~~ Done 2026-09-08.** The core makes sound at both levels,
and getting there found a real bug. Nothing was ever wrong with the audio
path; three things were hiding it.

- **Nobody had ever run long enough.** MAME 0.289 on the same set is silent
  for its first 49.5 seconds of board time, then plays discrete attract-demo
  sound effects with gaps between them. The standing "no note keyed on within
  4.4 s" observation was 1.85 s of board time (see the clock note above) of a
  game that makes no sound for fifty.
- **jtsim's default DIP switches say "no sound".** `FFFFFFFF` sets DSWA bit 3,
  which MAME's XML names Demo Sounds, `Off=0x08`; bit 2 is Service Mode. Use
  `-dipsw 1`, MAME's own default. **Real hardware had the same fault**, for a
  different reason - see section 18. The claim once made here, that the MRA's
  power-on default is built from MAME's `default="yes"` values and so hardware
  is unaffected, was read off the generator source and never checked against
  the MRA it produced.
- **`jtwardner_game.v` was missing two inverters.** `dip_test` and `tilt`
  reached the Toaplan SYSTEM port uninverted while the other seven bits were
  inverted, so the board saw the test switch held down and the tilt sensor
  tripped for every run. The `ver/main` bench could not catch it, because it
  drives those inputs from a plusarg that defaults to zero.

With all three addressed: 163 key-ons over 53 s of board time, `test.wav`
peaking at 3886 against MAME's 3962, and the first writes ever seen to the
envelope registers (bands `60` and `80`). On 10 ms RMS envelopes the whole
core lags MAME by 320 ms — 0.6% over 50 s, which is SDRAM latency against
MAME's zero-wait memory — and correlates at **r = 0.9762**; the `ver/main`
bench, whose ROM answers in one clock, sits at **zero lag, r = 0.946** over a
longer 14-second window.

One difference left open: the subsystem bench's RMS is 1.2 to 1.9 times
MAME's per burst although the peaks agree within 3 to 13%, so its waveform
carries more energy between peaks. Candidates are MAME 0.289's default audio
effects chain (the cfg it writes lists Filters, Compressor, Reverb and
Equalizer, and the command line cannot disable them), its resampling of
49.7 kHz to 48 kHz, and a real difference between jtopl2's envelope decay and
ymfm's. Ruling out the first needs MAME's mixer UI, which needs a display.

**3. Verify the MRA.** This needs MAME. It is installed on gunmetal and is
0.289, the same version as the sources vendored in `doc/`.

MAME will not read `~/Downloads/wardner` as it stands: the files carry an older
naming (`b25-01.rom`, `wardner.17`) and 0.289 wants `b25-01.14c`, `b25-31.6m`
and so on. All 33 files match `wardnerb` by CRC32, so build a rompath by
matching CRCs against `mame -listxml wardnerb` and copying to the names it
gives. `mame -rompath <dir> -verifyroms wardnerb` then reports the set good.
The parent `wardner` cannot be completed here: it needs
`d70012u_gxc-02_mcu_71001`, which this set does not have.

Headless runs want `SDL_VIDEODRIVER=dummy` and the XDG variables set, and go at
about 2200% speed:

```bash
mame -rompath <dir> wardnerb -video none -sound none -nothrottle \
     -snapshot_directory <dir> -snapname t050 -str 50
```

That is how the attract timeline below was established, and it is worth having
for the MRA work too:

```bash
mame -listxml > doc/mame.xml          # or merge the Wardner machines into it
jtframe mra wardner
```

Then build the `.rom` it produces and diff it against `ver/game/mkrom.py`'s
output, which is known good: the whole core boots from it and all four SDRAM
banks match it byte for byte. If they differ, fix the `sequence` lists in
`cfg/mame2mra.toml`, not the RTL. The 32-bit byte order is already settled —
`jtframe_rom_2slots.v`'s own self-check compares a read against
`{ mem[a+1], mem[a] }` over little-endian 16-bit words, so plane 0 goes first.

**4. Synthesis on gunmetal.** Delete `cfg/skip` first — it exists solely to keep
the core out of the linter and every compile matrix while it was incomplete.

```bash
rm cores/wardner/cfg/skip
jtcore wardner -mister
```

`[mist|sidi] JTFRAME_SKIP` is set in `cfg/macros.def` on the *expectation* that
the tile, sprite, palette and DSP memories will not fit an EP3C25. That is a
prediction, never measured. Two things in `jtwardner_video.v` are known not to
be synthesis-friendly as written and want moving on to jtframe memories: the
sprite line buffer has two write ports, and the touched-pixel vector is 512
flip-flops.

**5. Loose ends.** The joystick bit order in `jtwardner_game.v` is inferred from
the *name* of MAME's `TOAPLAN_JOY_UDLR_2_BUTTONS` macro, whose definition is not
vendored here; check it against `toaplipt.h`. There is no `cfg/reg.yaml` (the
debug register viewer) — 74 of 93 cores have one. Screen flip matches MAME but
MAME itself looks wrong: see "Notes on screen flip" below before offering
cocktail mode.

## Starting a fresh session

Point a new session at this handover, at the working agreement the existing
work follows, and at whatever is still open in "What is left" below. The
resumption prompt that used to live in `doc/resume-prompt.md` has been removed:
it described the state before the core ran on hardware and would now mislead.

**Machine choice: the x86 workstation (Ryzen 7 5800X3D, 32 GB), not the M1
Pro Mac.** Two reasons.

Quartus has no macOS build, on Apple Silicon or Intel, so synthesis can only
happen on x86 Linux or Windows. That alone rules the Mac out for finishing the
job.

Beyond that, the 5800X3D's 96 MB L3 suits the remaining work: the whole-core
simulation's hot working set is the C++ SDRAM model, four banks of 8 MB, plus
the Verilated design state, and it is touched continuously. That fits in L3
there and would spill to main memory on the Mac. **[I]** — reasoned from the
model's size, not benchmarked on either machine. Build times also improve a
lot over the 4-core cloud container: a large part of each rebuild is Verilator
and GCC compiling the 21k-line T80, and jtsim already passes `-j`.

Doing synthesis early is worth considering rather than leaving it last: the
sprite line buffer's two write ports and the 512-flip-flop touched vector in
`jtwardner_video.v` are known not to be synthesis-friendly as written, and the
BRAM fit on the smaller targets has never been measured. If either forces an
RTL change, the frame-diff harness re-verifies it in seconds.

## Things that will bite you

- **`git add -f` is required** for anything under `ver/`, because of the
  `/cores/*/ver/**` ignore rule. Check `git diff --cached --name-only` for
  `.hex`, `.bin` and `.rom` before every commit.
- **`ver/dsp/run.sh` takes an activation count**, not a path (see above).
- **SDRAM bank dumps are big-endian per 16-bit word**; byte-swap before diffing
  them against a `.rom`.
- **jtsim writes `frame.raw` from a forked child**, and only when a frame
  differs from the previous one. `ver/game/raw2png.py` converts it without
  ImageMagick.
- **The MAME sources in `doc/` are the oracle** for the video and DSP work. The
  reference renderer `ver/video/render_ref.py` is a transcription of them, not a
  recollection; keep it that way, and change it and the RTL together.

---

Evidence discipline used throughout:

- **[V]** = verified in this session by reading a primary source or running a command.
- **[I]** = inference from those sources. Not tested. Treat as a hypothesis to be
  falsified in simulation.

Primary sources read in full, MAME 0.289 (`mame0289` tag), vendored alongside this
file in `cores/wardner/doc/`:
`wardner.cpp`, `twincobr.cpp`, `twincobr.h`, `twincobr_m.cpp`, `twincobr_v.cpp`,
`toaplan_scu.{h,cpp}`, `toaplan_dsp.{h,cpp}`.

MAME was **not** run in this session — this is a remote Linux container with no MAME,
no ROMs and no Quartus. Everything MAME-derived below is source reading, not
execution.

---

## 0. Corrections to the prior session's findings

Almost all of it held up. Four corrections, one of which is material.

| Prior finding | Verdict | Correction |
|---|---|---|
| Z80 main 6 MHz, Z80 audio 3.5 MHz, DSP 14 MHz, YM3812 3.5 MHz, HD6845S, 320x240, 54.878 Hz | **[V] Correct** | — |
| No jtcore uses a Toaplan driver | **[V] Correct** | Grepped all 92 cores. Zero hits for `toaplan`, `wardner`, `twincobr`, `tms320` outside KiCad symbol tables. |
| DSP is required, not stubbable | **[V] Correct** | `toaplan_dsp.cpp` confirms it reads *and writes* main CPU RAM, sprite RAM and palette RAM, and drives the Z80 HALT line. |
| `modules/jttms` is a red herring | **[V] Correct** | It is an empty submodule pointing at `jotego/jttms` (TMS video). Also empty here: `jtdsp16`, `jtopl`, `jt12` and others — submodules are not checked out in this container. |
| va7deo README's "Not Implemented" is stale | **[V] Correct** | `demonswld/files.qip` contains `rtl/TMS320C1X/TMS320C1X.qip`, and `demonwld.sv:789` instantiates `TMS320C1X dsp` with a BRAM program ROM and a dual-port shared RAM. It ships. |
| **"1 KB `ROM_REGION16_BE`"** | **[C] Minor** | The region is `0x1000` bytes; the dump is `0xc00` bytes = `0x600` 16-bit words. The DSP's internal mask ROM is 1536 words. |
| **"Z80 main @ 6 MHz"** | **[C] Incomplete, and it matters** | The board has **two crystals**. Main Z80 is `24 MHz / 4`. *Everything else* — DSP, audio Z80, YM3812, CRTC and the 7 MHz pixel clock — derives from a **14 MHz** crystal. See §5.1; this is the single biggest clocking decision in the core. |
| **"licence depends on whether the files are v2-or-later"** | **[C] Materially wrong framing** | It is worse than that. See §2.1. |

---

## 1. Hardware, as established from source **[V]**

### 1.1 Clocks and raster

```
XTAL 24 MHz ──/4──► Z80 main        6.000 MHz
XTAL 14 MHz ──────► TMS320C10      14.000 MHz  (CLKIN; internal machine cycle = CLKIN/4)
            ──/4──► Z80 audio       3.500 MHz
            ──/4──► YM3812          3.500 MHz
            ──/4──► HD6845S CRTC    3.500 MHz  (char_width = 2, so 2 px per CRTC char)
            ──/2──► pixel clock     7.000 MHz
```

`m_screen->set_raw(14_MHz_XTAL/2, 446, 0, 320, 286, 0, 240)`
→ 7 000 000 / (446 × 286) = **54.878 Hz**, 320×240 visible, horizontal orientation.

Twin Cobra is the same raster from a 28 MHz crystal (`28/4 = 7 MHz`, same 446×286).
The two boards are timing-identical on the video side. **[V]**

### 1.2 Main Z80 memory map

```
0000-6FFF  ROM (fixed, 28 KB)
7000-7FFF  Work RAM, 4 KB          ← DSP-accessible (segment 0x7000)
8000-8FFF  Sprite RAM, 4 KB        ← DSP-accessible (segment 0x8000)   write always; read only when bank==0
A000-AFFF  Palette RAM, 4 KB       ← DSP-accessible (segment 0xA000)   write always; read only when bank==0
C000-C7FF  Sound shared RAM, 2 KB  write always; read only when bank==0
8000-FFFF  ROM bank window (32 KB) when port 70 != 0
```

The `0x8000-0xFFFF` region is a **memory view**: writes to sprite/palette/sound RAM
always land, but *reads* return either those RAMs (bank select = 0) or the banked ROM.
Bank register is `port 0x70`, `data & 7`, times `0x8000` into a `0x40000` region.
Banks 1 and 6 are unpopulated (`ROMREGION_ERASEFF`). **[V]**

### 1.3 Main Z80 I/O map

| Port | Direction | Function |
|---|---|---|
| `00` / `02` | W | 6845 address / data |
| `10-13` | W | text layer scroll Y lo/hi, X lo/hi |
| `14-15` | W | text VRAM address latch lo/hi |
| `20-25` | W | bg layer scroll + address latch |
| `30-35` | W | fg layer scroll + address latch |
| `40-43` | W | spare 4th layer scroll (**unused on this PCB**) |
| `50` / `52` | R | DSW A / DSW B |
| `54` / `56` | R | P1 / P2 |
| `58` | R | system: service, tilt, test, coins, starts, **bit 7 = VBLANK** |
| `5A` | W | LS259 "coinlatch", nibble `D3..D1` = bit index, `D0` = value |
| `5C` | W | LS259 "mainlatch", same encoding |
| `60-65` | R/W | text / bg / fg VRAM data through the address latch, lo/hi byte |
| `70` | W | ROM bank select |

LS259 bit assignments **[V]**:

```
coinlatch (port 5A)              mainlatch (port 5C)
 0 : DSP INT / run               2 : IRQ enable (VBLANK IRQ to main Z80)
 4 : coin counter 1              3 : flip screen
 5 : coin counter 2              4 : bg VRAM bank (0x1000 word offset)
 6 : coin lockout 1              5 : fg tile ROM bank (wired, unused on Wardner)
 7 : coin lockout 2              6 : display enable (blank to black when 0)
```

Note the asymmetry with Twin Cobra: on Twin Cobra the DSP-run bit is
`mainlatch` bit 6 and display-enable is bit 7; on Wardner the DSP-run bit moved to
`coinlatch` bit 0 and display-enable to `mainlatch` bit 6. **[V]**

### 1.4 Audio Z80

```
program: 0000-7FFF ROM (32 KB)
         8000-807F RAM (128 B)
         C000-C7FF shared with main Z80
         C800-CFFF private RAM (2 KB)
io:      00-01     YM3812
```
IRQ comes from the YM3812 IRQ pin. No sound latch, no NMI handshake — the two Z80s
communicate purely through the 2 KB shared RAM. **[V]** That is unusually simple and
removes a whole class of latency-tuning problems.

### 1.5 Video

Three 8×8 tilemaps plus one sprite layer. None of the VRAM is memory-mapped; it is
all reached through an address-latch + data-port pair, 16-bit words assembled from
byte writes. **[V]**

| Layer | Map | Tile bits | Colour bits | bpp | Tiles | Palette range |
|---|---|---|---|---|---|---|
| text | 64×32 | `code & 0x07FF` | `code >> 11` (5 bits, 32 sets) | 3 | 2048 | 1536-1791 |
| fg | 64×64 | `code & 0x0FFF` | `code >> 12` (4 bits, 16 sets) | 4 | 4096 | 1280-1535 |
| bg | 64×64, banked ×2 | `code & 0x0FFF` | `code >> 12` | 4 | 4096 | 1024-1279 |
| sprites (SCU) | 512 entries | `word0 & 0x07FF` | `word1 & 0x3F` (64 sets) | 4 | 2048 16×16 | 0-1023 |

Draw order, back to front: bg (opaque) → fg (pen 0 transparent) → text (pen 0
transparent) → sprites, where each sprite carries a 2-bit priority that selects which
of those three layers it is allowed to cover:

```
priority 0 : not drawn at all
priority 1 : above bg only
priority 2 : above bg and fg
priority 3 : above everything
```
**[V]** — `toaplan_scu.cpp` skips priority 0 outright, and `twincobr_state::pri_cb`
builds the mask from `GFX_PMASK_{1,2,4}` against the layer priority codes 1/2/4.

SCU sprite word format **[V]**:
```
word0  ---- -xxx xxxx xxxx  tile index
word1  ---- xx-- ---- ----  priority
       ---- --x- ---- ----  flip Y
       ---- ---x ---- ----  flip X
       ---- ---- --xx xxxx  colour set
word2  xxxx xxxx x--- ----  X position (>>7)
word3  xxxx xxxx x--- ----  Y position (>>7); the value 0x100 means "skip"
```

Fixed offsets **[V]**: tilemaps `scrolldx = -55` normal / `-134` flipped,
`scrolldy = -30` / `-243`. Sprites `x - 32` normal, `x - 14` when flipX, `y - 16`.

Palette: 4 KB of byte-writable RAM = 2048 entries, format `xBGR555`, 1792 in use.
The Z80 can write it but the DSP can too (segment `0xA000`). **[V]**

**The 6845 does nothing.** In `wardner_state::wardner()` the CRTC is configured with
`set_screen`, `set_show_border_area(false)` and `set_char_width(2)` — and *nothing
else*. No `set_update_row`, no output callbacks, no `de`/`vsync` handlers. Screen
timing comes from `screen.set_raw()`, not from the CRTC's programmed registers. **[V]**
→ **[I]** We can therefore ignore CRTC register writes entirely and hardcode the
446×286 raster in `jtframe_vtimer`, which is what every other jtcore does. jtframe
ships no 6845 model and does not need one here.

### 1.6 ROM regions (parent set `wardner`) **[V]**

| MAME region | Size | Contents |
|---|---|---|
| `maincpu` | `0x40000` (sparse) | fixed 32 KB @0, banks at 0x10000/0x20000/0x38000 |
| `audiocpu` | `0x8000` | audio Z80 |
| `dsp:dsp` | `0xc00` used of `0x1000` | TMS320C10 program, 16-bit big-endian |
| `chars` | `0xc000` | 3 planes × 16 KB |
| `fg_tiles` | `0x20000` | 4 planes × 32 KB |
| `bg_tiles` | `0x20000` | 4 planes × 32 KB |
| `scu` | `0x40000` | 4 planes × 64 KB, sprites |
| `proms` | `0x260` | 5 PROMs, **unused by MAME** |

Sets: `wardner` (World), `wardnerj` (Japan), `pyros` (US), plus two bootlegs.
All share every graphics ROM except `chars`, and all share the audio ROM.

---

## 2. The DSP route — decide this first

### 2.1 Licensing: the blocker is worse than "v2 vs v2-or-later" **[V]**

I traced the implementation to its origin.

- `va7deo/demonswld/rtl/TMS320C1X/` contains `TMS320C1X.sv` and `TMS320C1X_pkg.sv`.
  **Neither file carries any copyright notice, licence header or SPDX tag.**
- The upstream is **`srg320/TMS320C1X`**. I fetched it. `TMS320C1X_pkg.sv` there is
  **byte-identical** to va7deo's copy (`diff` clean). `TMS320C1X.sv` differs only by
  va7deo's port changes: `PC`/`ROM_Q` exported, internal ROM/RAM instantiations
  commented out and replaced with `dual_port_ram`, `RDY` removed, and a
  `parameter rom_file = "bsmt2000.mif"` dropped — that default filename tells you
  srg320 wrote it for the BSMT2000 sound chip, which embeds a TMS320C15.
- **`srg320/TMS320C1X` has no `LICENSE`, no `COPYING`, and no `README`.** All four
  probes returned 404. There is no licence grant of any kind.

So: va7deo's repository-level GPL-2.0 `LICENSE` file cannot convey rights to code
va7deo does not own. The question is not "is it v2-or-later, and can that go into a
GPL-3.0 project?" — it is "**has anyone granted a licence to this code at all?**"
Absent a grant, it is all-rights-reserved by default.

**[I]** Consequence: copying these files into jtcores is not a decision you or I can
make. It needs srg320 to state a licence (ideally GPL-3.0-or-later or a
GPL-2.0-**or-later** that jtcores can upgrade), and it needs jotego's assent to
carry third-party RTL. Asking costs one GitHub issue and is worth doing early
regardless of which route you take, because a "yes" collapses this task from weeks to
days.

### 2.2 The three routes

| | **A. Reuse srg320's core** | **B. Write a fresh TMS320C10** | **C. Wait for jotego** |
|---|---|---|---|
| Effort | ~2 days integration | **~3-5 weeks** | 0, but indefinite |
| Licence risk | **Blocking today** | None | None |
| Correctness risk | Low — it runs Demon's World in a shipped core | Medium-high — a CPU is where subtle bugs hide | — |
| Verifiable? | Yes, against MAME | Yes, against MAME | — |
| Availability | Needs srg320 to answer | Always | **Nothing exists.** `git log --all --grep` over jtcores and jtframe returns zero hits for tms320/toaplan. **[V]** |

**Recommendation: B, write a fresh one — and open the licence question with srg320 in
parallel.** Reasoning:

1. Route C is not a route. There is no jotego TMS320 work in progress. **[V]**
2. Route A is blocked on a third party who may never reply, and jtcores' uniform
   `GPL-3.0-or-later` headers (654 of them **[V]**) suggest jotego cares about
   provenance. Making the whole core contingent on that answer is bad project risk.
3. The TMS320C10 is genuinely small. It is a Harvard-architecture 16-bit DSP with:
   two auxiliary registers, a 4-level hardware stack, a 32-bit accumulator, one
   16×16 multiplier feeding a 32-bit P register, a barrel shifter on the ALU input,
   a 1-bit status word of consequence (`OV`/`OVM`/`ARP`/`DP`/`INTM`), 144 words of
   internal data RAM, one `INT` line and one polled `BIO` input. Roughly **60
   opcodes**. That is smaller than a Z80 by a wide margin.
4. And critically — you are not writing it blind. You have **three** independent
   references: MAME's `tms320c1x.cpp` (38 KB, the behavioural spec), srg320's RTL
   (readable as documentation even if not copyable), and TI's published TMS32010 user
   guide. Plus a real conformance oracle (§6).

**[I]** If srg320 grants a licence before you reach phase 3, switch to A and save
three weeks. Nothing else in the plan changes — the DSP is behind a clean interface.

### 2.3 How accurate must the DSP be? **[I] — this is the key design insight**

Read `toaplan_dsp.cpp` closely and the answer is: **functional accuracy is enough.
Cycle accuracy buys you nothing.** Here is why, in hardware terms.

The DSP and the main Z80 **never run at the same time during a DSP transaction.**
`dsp_int_w(1)` does three things atomically: releases the DSP from HALT, asserts the
DSP's `INT`, and **asserts the main Z80's HALT line**. The Z80 stops. The DSP then
walks the Z80's address space as sole master. When it is finished it releases the
Z80's HALT itself.

That has three consequences:

1. **There is no bus arbitration to model.** Two masters, mutually exclusive by
   construction. In FPGA terms the DSP can simply be muxed onto the Z80's side of
   each RAM while the Z80 is halted — no second BRAM port needed, no contention
   logic, no wait states.
2. **DSP execution time does not shift game logic.** The Z80's frame is paced by the
   VBLANK IRQ, not by a cycle budget. A DSP that finishes its routine in half the
   real time just hands the Z80 back more idle cycles inside the same frame. The only
   failure mode is a DSP so slow it does not finish within a frame, and we will be
   running it at or above the real 14 MHz.
3. **The handshake is a strict serial protocol**, so it can be verified by comparing
   *transaction sequences* rather than waveforms — much easier to test (§6.2).

What *must* be exact: every opcode's arithmetic result, the overflow/saturation
behaviour (`OVM`), `SUBC`, the barrel shift on ALU input, `ARP`/`DP` addressing
side effects, the 4-level stack, and the `INT`/`BIO` semantics. Those are
correctness, not timing.

**[I] Caveat to test, not assume:** after the DSP releases the Z80's HALT, the DSP
keeps running until the Z80 clears the `coinlatch` bit 0. There is a short window of
genuine concurrency. My reading is that the DSP is spinning on `BIO` in that window
and touches nothing, but I have not proven it. Mitigation: give the shared RAMs true
dual ports anyway (jtframe's `jtframe_dual_ram` costs nothing extra in M10K), so a
stray access is harmless rather than corrupting. Cheap insurance.

### 2.4 The DSP↔host protocol, as pseudocode **[V]**

Numbered reduction of `toaplan_dsp.cpp` + `wardner_state::dsp_host_*_cb`, control
flow and side effects only:

```
DSP-side I/O ports (the DSP's OUT/IN instructions):
  1. OUT port 0, value V  → latch an address into the host window:
        seg  := V & 0xE000 ;  if seg == 0x6000 then seg := 0x7000
        addr := (V & 0x07FF) << 1        (word-aligned byte offset)
  2. IN  port 1           → read 16 bits from host space at seg+addr,
                            little-endian (low byte first). Legal segs: 7000, 8000, A000.
  3. OUT port 1, value D  → write 16 bits to host space at seg+addr, little-endian.
                            SIDE EFFECT: if seg == 0x7000 and addr < 3 and D == 0,
                            arm the "release host" flag.
  4. OUT port 3, value B  → if bit 15 of B is set, deassert BIO.
                            if B == 0:
                                 if "release host" flag is armed:
                                       deassert the main Z80's HALT line
                                       clear the flag
                                 assert BIO.
  5. IN  BIO              → polled by the DSP's BIOZ branch instruction.

Host-side control (main Z80 OUT to port 0x5A with D3..D1 == 000):
  6. D0 = 1 → release DSP from HALT, assert DSP INT, assert main Z80 HALT.
  7. D0 = 0 → deassert DSP INT, assert DSP HALT.

Resulting whole-transaction sequence:
  8.  Z80 writes command words into work RAM at 0x7000..
  9.  Z80 sets coinlatch bit 0 → step 6 → Z80 freezes, DSP wakes on INT.
  10. DSP reads/writes 0x7000 (work RAM), 0x8000 (sprite RAM), 0xA000 (palette RAM)
      via steps 1-3, computing shots, angles, collisions, sprite placement.
  11. DSP writes 0 to 0x7000+{0 or 2} → arms the release flag (step 3).
  12. DSP writes 0 to port 3 → Z80's HALT released (step 4). Z80 resumes mid-frame.
  13. DSP loops on BIO.
  14. Z80 clears coinlatch bit 0 → step 7 → DSP halts. Idle until step 9 again.
```

Twin Cobra runs the **identical protocol**; only step 1's address decode differs
(`seg = (V & 0xE000) << 3`, `addr = (V & 0x1FFF) << 1`, segments `0x30000/0x40000/0x50000`,
16-bit accesses because the host is a 68000). **[V]** So a `jtwardner_dsp_ctrl` module
written now needs one parameterised address decoder to serve both boards later.

---

## 3. Wardner vs Twin Cobra: precise shared/different map **[V]**

| Block | Shared? | Detail |
|---|---|---|
| TMS320C10 CPU | **Identical** | Same part, same 14 MHz-class clock (TC uses 28/2). MCUs interchangeable per MAME. |
| DSP↔host handshake FSM | **Identical** | `toaplan_dsp.cpp` is one device serving both. |
| DSP address decoder | **Different** | Wardner: 3-bit seg, 11-bit addr, byte-pair access. TC: 3-bit seg <<3, 13-bit addr, word access. |
| `toaplan_scu` sprites | **Identical logic** | Only `set_xoffsets`: Wardner (32, 14), TC (31, 15). |
| Tilemaps, scroll, VRAM-via-port | **Identical** | Same `twincobr_v.cpp` code, same sizes, same scroll offsets, same priorities. |
| Palette | **Identical** | xBGR555, 1792 colours, same layer bases. |
| Raster | **Identical** | 7 MHz pixel, 446×286, 320×240, 54.878 Hz. |
| CRTC | **Identical** | HD6845S @3.5 MHz, char_width 2, functionally inert. |
| YM3812 + audio Z80 | **Identical** | 3.5 MHz each, shared-RAM comms. |
| **Main CPU** | **Different** | Wardner: Z80 @6 MHz, banked, byte-wide, ports. TC: 68000 @10 MHz, memory-mapped. |
| LS259 bit assignment | **Different** | DSP-run and display-enable bits swap latches (§1.3). |
| Sprite RAM buffering | Same idea | Wardner buffers 8-bit on VBLANK rising, TC 16-bit. Both double-buffer. |

**[I]** Practical read: about **80 % of the RTL is board-common**. If the modules are
named `jttoaplan1_*` rather than `jtwardner_*` from day one, Twin Cobra / Flying Shark
/ Sky Shark become "swap the main CPU and the address decoder", not a second core.
That is the strongest argument for framing this as **Toaplan Twin Cobra hardware**,
with Wardner as the first supported set — and it costs nothing extra now.

---

## 4. jtcores conventions for a new core **[V]**

### 4.1 Which existing core to model on

I looked at `harier` (newest, Sept 2026), `moo`, `taitox`, and the cores that use
`jtopl2`: `bubl`, `castle`, `kunio`, `pktgal`, `pang`, `cop`.

**Model on `bubl` (Bubble Bobble).** Not `karnov` — Karnov is a 68000 core and its
shape does not match. Not `toki` — Toki is 68000 + Seibu sound. `bubl` is the right
model because it is structurally the same problem:

- three CPUs (main Z80 + sub Z80 + sound Z80) → we have main Z80 + audio Z80 + DSP;
- a **coprocessor whose program ROM lives in BRAM**, loaded from the ROM download by
  an offset trick in `mem.yaml` — exactly what the DSP needs;
- banked main ROM in SDRAM;
- an OPL-family FM chip through `jtopl`.

Take the **sound** shape from `pktgal`/`kunio` instead, since Wardner's chip is a
YM3812 = `jtopl2`, and `bubl`'s is a YM3526 = `jtopl`. Verified instantiation, from
`cores/pktgal/hdl/jtpktgal_sound.v:155`:
`jtopl2(.rst, .clk, .cen, .din, .addr, .cs_n, .wr_n, .dout, .irq_n, .snd, .sample)`.

### 4.2 Required layout

```
cores/wardner/
  README.md                 core description, credits
  cfg/
    macros.def              core name, video geometry, rate, SDRAM bank starts, per-target overrides
    mem.yaml                clocks (cen signals), audio mixer, SDRAM banks/buses, BRAM blocks
    mame2mra.toml           sourcefile, ROM region order/transforms, DIPs, buttons, header
    files.yaml              which HDL files and which shared modules to pull in
    reg.yaml                simulation input mapping (points at a .cab file)
    msg                     the OSD splash text
  doc/                      vendored MAME sources  ← already populated
  hdl/
    jtwardner_game.v        top level, wiring, SDRAM buses
    jtwardner_main.v        main Z80, banking, LS259s, port decode
    jtwardner_sound.v       audio Z80 + jtopl2
    jtwardner_dsp.v         TMS320C10 wrapper + handshake FSM + host-window decode
    jtwardner_video.v       vtimer + layer arbitration
    jtwardner_scroll.v      the three tilemaps
    jtwardner_obj.v         SCU sprite engine
    jtwardner_colmix.v      palette lookup + priority mux
  ver/
    game/                   sim.sh, trace scripts
    <setname>/*.cab         recorded input scripts for regression
```

`cfg/mem.yaml` is the important one — `jtframe mem` generates the game module's port
list from it, so it defines the interface before you write any HDL. Confirmed
features we need **[V]**: `clocks:` with `freq:` entries that are PLL-aware,
`sdram.banks[].buses[]` with per-bus `addr_width`/`data_width`/`offset`, and `bram:`
entries supporting `dual_port:` (independent addr/din/dout/we) and
`rom: { offset: ... }` to load a BRAM from the downloaded ROM file.

---

## 5. The design

### 5.1 Clocking — the one real decision

Two crystals, and 6 MHz and 14 MHz have no useful common multiple near jtframe's
48 MHz.

**Option 1 — default `jtframe_pll6000`, 48/96 MHz.** 6 MHz main Z80 is an exact `/8`.
Everything on the 14 MHz side becomes a fractional clock enable via
`jtframe_frac_cen` (14 = 48 × 7/24, 3.5 = 48 × 7/96, pixel 7 = 48 × 7/48).
Fractional cens are standard practice in jtcores and average out exactly; they add
period jitter of one 48 MHz tick, which is invisible to everything here.

**Option 2 — `jtframe_pll7000`.** This exists **[V]** and gives 56 / 28 / 112 / 7 MHz.
56 MHz is exactly 4 × 14 MHz, so DSP (`/4`), audio Z80 (`/16`), YM3812 (`/16`),
CRTC (`/16`) and pixel clock (`/8`) are all **exact integer divides**. The 6 MHz main
Z80 becomes the fractional one (6 = 56 × 3/28). But `pll7000` is built for the
**MiSTer target only** — the `mist`, `sidi`, `sidi128` and `pocket` trees have no
`pll7000`, and `cps3` (its only current user) carries `JTFRAME_SKIP` for all of them. **[V]**

**Recommendation: Option 1.** Take the default PLL and put the fractional cen on the
14 MHz domain. It keeps every target buildable, it is what most jtcores do, and the
exactness Option 2 buys is not audible or visible — the YM3812's output is resampled
anyway and 54.878 Hz is set by `JTFRAME_RATE`, not by the cen jitter.

**[I]** BRAM is the real target constraint, not the PLL. Rough budget: main RAM 4 K +
sprite RAM 4 K + palette 4 K + sound shared 2 K + sound private 2 K + text VRAM 4 K +
fg VRAM 8 K + bg VRAM 16 K + DSP program 4 K + DSP data RAM 0.5 K ≈ **49 KB**, before
jtframe's line buffers and OSD. Comfortable on MiSTer's Cyclone V (553 KB M10K).
Likely **not** buildable on MiST/SiDi's EP3C25 (66 KB) — expect to add
`[mist|sidi] JTFRAME_SKIP`, exactly as `bubl` and `harier` do. **[V]** that those
cores do it; **[I]** that we will need to.

### 5.2 SDRAM layout

Total ROM ≈ 851 KB — trivial. Split across banks by access pattern, not by size:

| Bank | Buses | Width | Notes |
|---|---|---|---|
| 0 | `main` | 8 | 256 KB region, sparse; fixed 28 KB + 8 banks × 32 KB |
| 1 | `snd` | 8 | 32 KB audio Z80 |
| 2 | `char`, `scr1`, `scr2` | 32 | three tilemap ROMs, one 32-bit fetch = one tile row |
| 3 | `obj` | 32 | 256 KB sprite ROM |

**[I]** Widths chosen so a single SDRAM read yields a whole 8-pixel row: for the 4bpp
layers the four planes are contiguous 32 KB apart, so a 32-bit read with the planes
interleaved at MRA build time gives 8 pixels per access. The text layer is 3bpp and
gets padded to 4. This is the standard jtcores tile-fetch idiom.

### 5.3 The DSP integration, concretely

```
             ┌──────────────────┐
   coinlatch │  jtwardner_dsp   │
   bit 0 ───►│                  │
             │  handshake FSM   │──── halt_z80 ──────────────► main Z80 WAIT/BUSRQ
             │        │         │
             │  ┌─────▼──────┐  │
             │  │ TMS320C10  │  │◄── program ROM  (BRAM 2048×16, from ROM download)
             │  │   core     │  │◄── data RAM     (BRAM  256×16, internal)
             │  └─────┬──────┘  │
             │        │ ports 0/1/3
             │  ┌─────▼──────┐  │
             │  │ host window│  │
             │  │  decoder   │  │──── 16-bit access to work / sprite / palette RAM
             │  └────────────┘  │     (muxed onto the Z80 side while Z80 is halted)
             └──────────────────┘
```

**Halting the Z80.** MAME asserts `INPUT_LINE_HALT`. In real hardware the DSP asserts
the Z80's `BUSRQ` and waits for `BUSAK`, or holds `WAIT`. **[I]** With T80 in jtcores
the cleanest model is to gate the Z80's clock enable — hold `cen` low and the CPU
freezes exactly where it is, which is behaviourally what we need and avoids relying on
T80's `BUSRQ` timing. This is a decision to validate in sim, not to assume.

**Program ROM loading.** Follow `bubl`'s pattern exactly **[V]**: a `bram:` entry with
`rom: { offset: "((`DSP_START-`JTFRAME_BAn_START)>>1)|24'h800000" }`. The `>>1` is
because the BRAM is 16 bits wide and the download is byte-addressed.

**Endianness.** MAME's region is `ROM_REGION16_BE` — the file is big-endian words —
but the DSP's *view of host memory* is little-endian (low byte at even address). **[V]**
Two different orderings in the same subsystem; getting this wrong is the single most
likely early bug. Test it explicitly (§6.1).

### 5.4 Video pipeline

Standard jtcores shape, no surprises:

```
jtframe_vtimer  (446×286, 320×240 visible, hardcoded — no 6845 model)
      │
      ├─ jtwardner_scroll  ─ bg  (64×64, banked, 4bpp, opaque)
      │                    ─ fg  (64×64, 4bpp, pen 0 transparent)
      │                    ─ text(64×32, 3bpp, pen 0 transparent)
      │
      ├─ jtwardner_obj     ─ 512 sprites, 16×16 4bpp, 2-bit priority,
      │                      double-buffered on VBLANK rising edge
      │
      └─ jtwardner_colmix  ─ priority resolution → palette RAM → xBGR555 → RGB
```

Priority resolution **[I]**: rather than MAME's bitmask approach, generate a 2-bit
"layer depth" per pixel (bg=1, fg=2, text=3) and compare against the sprite's
priority code — a sprite wins where `spr_pri >= layer_depth` and its pixel is
non-transparent, with priority 0 sprites suppressed entirely. That reproduces the
mask table in `pri_cb` with a comparator instead of a lookup. Needs proving against
MAME frames, especially the shop scenes that `twincobr_v.cpp`'s own header comment
flags as anomalous.

### 5.5 MRA / ROM assembly — one known limitation **[V]**

`jtframe`'s `mame2mra` supports `sequence`, `width`, `reverse`, `rom_len`, `mirror`,
`splits` (halves) and `patches`. It has **no nibble-interleave transform.**

That matters because the bootleg set `wardnerb` stores the DSP program in eight
82S131/82S137 PROMs combined with `ROM_NIBBLE | ROM_SHIFT_NIBBLE_HI/LO | ROM_SKIP(1)`.
The MRA cannot reconstruct those words.

→ **Target the parent `wardner` set**, which has a single flat `0xc00`-byte DSP dump.
It is flagged `BAD_DUMP` in MAME only because the true Wardner MCU (71900) is
undumped and MAME substitutes the Flying Shark / Twin Cobra MCU (71001) — which the
MAME comment states, and the family's documented interchangeability supports, is the
same program. **[V]** that MAME does this; **[I]** that it is faithful.

If bootleg support is later wanted, the fix is a small upstream contribution to
`mame2mra`'s region transforms — worth flagging to jotego but not a phase-1 problem.

---

## 6. Verification strategy

Evidence over inspection, in three tiers. Each tier is a hard gate.

### 6.1 Tier 1 — DSP conformance against MAME, before any video exists

This is the highest-value test in the whole project and it needs **no ROM dump of
Wardner's graphics** — only the DSP program, which is 3 KB.

1. Run MAME with `-debug -debugscript`, tracing the TMS320C10 only: PC, ACC, AR0/AR1,
   T, P, ST, and every port 0/1/3 transaction, one line per instruction. (Your note
   that headless MAME never exits is expected — kill it and use the partial trace.)
2. Feed the same program ROM into an iverilog testbench wrapping the new DSP, with
   the host window backed by a plain array preloaded from MAME's memory dump at the
   same instant.
3. Diff the two traces. First divergence = first wrong opcode, with the exact
   instruction word in hand.

**[I]** This converts "write a CPU core" from an open-ended risk into a bounded
debugging loop with an oracle. It is also why I am comfortable recommending route B.

Secondary oracle: `unidasm` the DSP ROM to get a full listing of the 1536 words, so
you know which of the ~60 opcodes the program actually uses — likely far fewer, which
lets you prioritise.

### 6.2 Tier 2 — transaction-level equivalence

Because the protocol is strictly serial (§2.4), the *sequence* of
`(seg, addr, read/write, data)` tuples per DSP invocation is a complete behavioural
signature. Log it from both MAME and the sim and diff. This catches address-decode
and endianness bugs immediately, and it is far more diagnostic than a screenshot.

### 6.3 Tier 3 — frame comparison

`cores/karnov/ver/game/` has `mksnap.mame`, `mksnap.sh`, `cpsnap.sh` and `trace.mame`
**[V]** — the established jtcores harness for dumping MAME frames and comparing them
against simulation output. Reuse it verbatim. Record `.cab` input scripts under
`ver/wardner/` for: boot + POST, attract loop, coin-up + level 1, and the shop scene
(the priority edge case).

### 6.4 Lint discipline

`jtsim -verilator -lint` on every change (your ~7 s figure). Long simulations only
after lint is clean.

---

## 7. Phased order of work — risk first

| Phase | Work | Gate | Needs ROM? |
|---|---|---|---|
| **0** | Ask srg320 for a licence on `TMS320C1X`. Ask jotego whether a Toaplan/TMS320 core is wanted and whether third-party RTL is acceptable. Set up the space-free git worktree for sim. | Both questions asked | No |
| **1** | **TMS320C10 core.** Opcode-complete, testbench-driven, verified by trace diff against MAME (§6.1). Nothing else. | Trace diff clean over a full DSP invocation | **DSP ROM only (3 KB)** |
| **2** | **DSP wrapper + handshake FSM + host-window decode.** Standalone testbench with a fake host RAM. Verified by transaction diff (§6.2). | Transaction diff clean | DSP ROM only |
| **3** | **Core skeleton.** `cfg/*`, `jtwardner_game.v`, main Z80 + banking + LS259s + port decode + work RAM. Boot to the point where the Z80 first pokes the DSP. | Z80 reaches the DSP handshake, main ROM checksum passes | **Yes — full set** |
| **4** | **Sound.** Audio Z80 + `jtopl2` + shared RAM. | Music and SFX play | Yes |
| **5** | **Video.** vtimer, three tilemaps, palette, colmix. Sprites last. | Frame-compares against MAME | Yes |
| **6** | **Sprites + priority.** The SCU, double buffering, the priority comparator. | Shop scene matches | Yes |
| **7** | **Polish.** Flip screen, DIPs, MRA for all four playable sets, cheat/NVRAM, `msg`. | `jtcore wardner -mister` builds clean on gunmetal | Yes |
| **8** | *(optional)* Rename modules `jttoaplan1_*` and add Twin Cobra / Flying Shark. | — | Their ROMs |

Phases 1-2 are ~60 % of the total effort and need **only the 3 KB DSP ROM**, not a
Wardner set. That is a deliberate ordering choice: it front-loads the risk and defers
the dependency.

> **Point of dependency, stated plainly:** you said you do not have a Wardner ROM
> dump. **Phases 0-2 do not need one** beyond the DSP program. **Phase 3 onward
> cannot start without the full `wardner` set** — there is no way to bring up a main
> CPU without its ROM. Please have that sorted before phase 3, or phase 1 will
> complete and the project will stall.

---

## 8. Honest scale estimate, and whether to do it

### Scale

| Component | New or reused | Estimate |
|---|---|---|
| TMS320C10 core | **New** (route B) | 3-5 weeks |
| DSP wrapper + handshake | **New** | 3-4 days |
| Main Z80 subsystem | T80 reused, glue new | 4-5 days |
| Sound subsystem | `jtopl2` + T80 reused, glue new | 2-3 days |
| Tilemaps | New, conventional | 1 week |
| SCU sprites + priority | New | 4-5 days |
| Palette / colmix | New, small | 2 days |
| MRA, DIPs, config, polish | New | 3-4 days |
| Verification harness | Adapted from `karnov` | 3-4 days |
| **Total, route B** | | **~10-13 weeks** part-time |
| **Total, route A** (licence granted) | | **~6-8 weeks** |

Calibration: you have no Verilog experience. **[I]** For a first FPGA project this is
a hard one — the DSP alone is a bigger task than most complete first cores, and the
board has three processors. A reasonable expectation is that the *stated* estimate is
the experienced-developer figure and a first-timer should roughly double it, with the
learning concentrated in phases 1 and 5.

That is not an argument against doing it. It is an argument for taking phase 1
seriously as a self-contained project with its own oracle, and for not starting phase
3 until phase 2's transaction diff is clean.

### Is it worth doing at all?

**Yes, and the DSP is the reason.** The case:

- **Nothing else fills this gap.** No MiSTer core, no openFPGA core, no jtcore covers
  Wardner or Twin Cobra. `va7deo`'s Toaplan V1 core deliberately covers only the
  DSP-less titles. **[V]**
- **One DSP unlocks a family.** Wardner, Twin Cobra, Flying Shark, Sky Shark and
  Demon's World all use the TMS320C10, and MAME documents the Wardner / Flying Shark /
  Sky Shark MCUs as interchangeable. **[V]** With §3's 80 % commonality, the marginal
  cost of the second and third games is small.
- **It is reusable beyond Toaplan.** The TMS320C1x turns up in the BSMT2000 (whence
  srg320's original), in Taito's and Konami's later boards, and elsewhere. A
  GPL-3.0-or-later TMS320C10 with a MAME-verified trace suite is a genuinely useful
  contribution to jtcores as a `jt32010` module, a sibling of `jtdsp16` (name follows `jt6295`/`jt7759`).

### The alternative: contribute the DSP to va7deo instead

Worth naming honestly. `va7deo/demonswld` already has a working TMS320C1X, so it does
**not** need one; contributing there would mean contributing a *Wardner core* to a
different framework, not a DSP. And their framework is a different (non-jtframe) one,
GPL-2.0, with hand-rolled SDRAM and no MRA-generation tooling.

**[I]** Recommendation: build it in jtcores. Write the DSP as
a standalone `jt32010` repository from the start, in the `jtdsp16` pattern — a standalone, separately-testable, GPL-3.0-or-later
module with its own testbench — so that even if the Wardner core stalls, the DSP is a
finished, useful artifact. That structure also makes it trivially droppable if
srg320's licence comes through and you decide to swap implementations.

---

## 9. Open questions for you

1. **Route A or B?** My recommendation is B (write fresh) with the licence question
   asked in parallel. Say the word if you would rather block on srg320's answer.
2. **PLL:** default 48 MHz + fractional 14 MHz cens (portable), or `pll7000`
   (exact clocks, MiSTer-only)? I recommend the former.
3. **Scope:** name it `wardner` now, or `toaplan1`/`twincobr` with Wardner first? I
   recommend module names that are board-generic from day one, whatever the core is
   called — it costs nothing now and saves a fork later.
4. **ROM dump:** needed before phase 3. Parent `wardner` set.
5. Do you want me to open the licence issue on `srg320/TMS320C1X` and the core
   proposal with jotego, or will you?

---

## 10. Decisions taken (2026-09-06)

| Question | Decision | Consequence |
|---|---|---|
| DSP route | **B — write a fresh TMS320C10.** Licence request to srg320 sent in parallel. | Phase 1 is a from-scratch CPU. If a licence lands before phase 3, route A remains an option. |
| PLL | **Default `jtframe_pll6000`**, fractional cens on the 14 MHz domain. | All targets remain buildable. `pll7000` not used. |
| Naming | **Board-generic module names** from day one. | Core folder stays `wardner`; HDL modules are `jttoaplan1_*` (subject to jotego's preference). The DSP is a standalone `jt32010` repo. |

A licence request to srg320 accompanied this decision at the time. The
from-scratch route was taken and `modules/jt32010` owes nothing to that
implementation, so the question never needed answering.

Drafts of the messages to jotego - one offering the finished core, one asking
which DSP dump the MRA should carry - are deliberately not in this branch. They
are addressed to the person the branch would be shown to, so they live outside
the repository.

### CI note for phase 3 **[V]**

`lint-all.sh` iterates every directory under `cores/` and `lint-one.sh` skips only
when `cfg/macros.def` is absent or `cfg/skip` exists. The compile matrices in
`q13.yaml`, `q20.yaml`, `pocket.yaml` and `debug-builds.yaml` use the same test.
So the docs-only `cores/wardner/` is invisible to CI today, but **the commit that
adds `cfg/macros.def` puts `wardner` into the linter and every compile matrix.**
Add `cfg/skip` in that same commit and remove it in the PR that makes the core lint
clean. (Note: `memmerson/jtcores` currently has GitHub Actions disabled — zero
workflow runs — so none of this fires on the fork until Actions is enabled.)

---

## 11. Progress log

| Phase | State | Evidence |
|---|---|---|
| 1 DSP core | done | `modules/jt32010/ver/cpu`: 1.62 M fuzzed + 480 k real-ROM instructions exact against `ref32010.c` |
| 2 DSP wrapper | done | `ver/dsp`: transaction diff, property checks, 9/9 mutations caught, real ROM exact |
| 3 main Z80 | done | `ver/main`: real ROM boots, POST, DSP handshake, display enable; CRTC-derived raster matches |
| 4 sound | done | main writes $AA handshake to shared RAM; 34 k YM3812 writes; bidirectional shared traffic |
| 5 video | done | `ver/video`: pixel-exact vs `render_ref.py` on the title screen (14 s), four earlier game snapshots and 72 random ones covering both flip states; 9 mutations caught |
| 6 sprites | folded into 5 | line buffer with MAME's priority-31 quirk as a multi bit |
| 7 polish | part | cfg/* and the game top level done and linting clean; MRA written but unverified; synthesis not attempted |

### Notes from phase 5 **[V]**

- The §5.4 "comparator" idea (`spr_pri >= layer_depth`) is equivalent to MAME's
  pmask table for a single sprite, but not for overlapping sprites: MAME sets
  the priority bitmap to 31 on every non-transparent sprite pixel it visits,
  drawn or not, so a sprite processed later (lower entry number) is never
  hidden where an earlier one touched. Implemented as a per-pixel `multi` bit.
- Background VRAM is 0x2000 words (two banks of 0x1000), the bank bit being the
  address MSB. `jtwardner_main.v` had it at 0x1000; fixed.
- The game runs a video RAM test after POST (walking-bit pattern in sprite RAM
  by 2.5 s, background banks at 3.1-6 s, foreground at 9 s); the title screen
  is up by 14 s. Simulation costs ~3 min of wall time per second.
- Sprite time per line: 512-clock scan + ~30 clocks a sprite in 2676. `obj_ovf`
  flags overflow. Not observed on any snapshot so far.

### Notes on screen flip **[V unless marked]**

MAME flips Wardner by setting `TILEMAP_FLIPX|TILEMAP_FLIPY` on the three
tilemaps, which mirrors the pixmap and swaps in the second scroll offsets
(`-134`, `-243`). Folding the mirror into the sampled coordinate cancels the
map size and leaves `px = (453 + scrollx - screen_x) mod W`,
`py = (482 + scrolly - screen_y) mod H`, so the RTL only walks the map
backwards. Verified pixel-exact against the reference on 39 flipped snapshots,
with five flip-specific mutations caught.

Two behaviours are matched to MAME but should not ship as cocktail support
without a hardware check **[I]**:

- Sprites are never flipped; the sprite generator does not read the screen flip.
- The flipped view is displaced from a true 180 degree mirror by a constant
  79 pixels horizontally and 213 vertically. Wardner and the Twin Cobra family
  share the same 446x286 raster, so geometry does not explain it.

### Core assembly **[V unless marked]**

`cfg/macros.def`, `cfg/mem.yaml`, `cfg/files.yaml`, `cfg/msg`,
`cfg/mame2mra.toml` and `hdl/jtwardner_game.v` are in place. `jtframe mem
wardner` generates the wrapper and port list, and Verilator elaborates the
whole core with jtcores' own lint flags and no warnings.

Clocking follows §5.1 option 1: 6 MHz is an exact divide of the 48 MHz clock,
and one fractional chain (48 * 7/24) gives 14 MHz for the DSP, halved to the
7 MHz pixel clock and again to the 3.5 MHz audio clock, which is how the board
derives them from its second crystal.

SDRAM map:

| Bank | Contents | Start |
|---|---|---|
| 0 | main Z80, sparse, bank gaps stay 0xFF | 0x000000 |
| 1 | sound Z80 0x8000, then the DSP mask ROM | 0x040000 / 0x048000 |
| 2 | char 0x10000, bg 0x20000, fg 0x20000 | 0x049000 |
| 3 | sprites 0x40000 | 0x099000 |

The DSP mask ROM is a 16-bit `jtframe_bram_rom` snooped out of the download
stream rather than an SDRAM bus: it fetches an instruction every machine cycle
at 14 MHz, so it must not queue behind anything.

All four verification suites were re-run after those width fixes, since they
touch code that was already signed off:

| Suite | Result |
|---|---|
| `modules/jt32010/ver/cpu` regression | PASS, 81 programs x 20000 instructions |
| `ver/dsp` transaction bench | PASS, 6/6 cases (2 programs x 3 host idle times) |
| `ver/dsp` real Wardner program | PASS, 480000 instructions and 580 events over 16 seeds |
| `ver/video` frame diff | pixel-exact on the game snapshots and the fuzz seeds |

Still open:

- **The MRA is unverified [I].** `doc/mame.xml` has no Wardner machine, so
  `jtframe mra wardner` cannot run in this environment and the plane
  interleave has only been reasoned from the generator source. The recipe for
  checking it against the known-good `ver/video/gfx_*.bin` is in
  `ver/video/README.md`.
- ~~The joystick bit order is inferred~~ **Settled 2026-09-09, and it was
  wrong.** See section 17.
- `cfg/skip` is still present, so the core stays out of CI. Remove it once the
  MRA is checked and a target actually builds.
- No synthesis has been attempted. `[mist|sidi] JTFRAME_SKIP` is set on the
  expectation that the video and DSP memories will not fit an EP3C25; that is
  a prediction, not a measurement.

### Whole-core bench **[V]**

`ver/game` runs `jtwardner_game.v` under jtcores' own `jtsim` harness with the
real SDRAM controller, using `ver/game/mkrom.py` to assemble the .rom that the
MRA is meant to produce.

- The core simulates end to end and measures **54.8814 Hz** against the
  board's 54.878, exercising the whole clocking chain.
- Every ROM region lands where `cfg/macros.def` says: the four SDRAM banks
  dumped after a full download match `wardner.rom` byte for byte.
- The 32-bit byte order is settled from `jtframe_rom_2slots.v`'s own
  self-check, which compares a read against `{ mem[a+1], mem[a] }` over little
  endian 16-bit words. Plane 0 goes first in the file. The MRA now has a
  golden image to be diffed against rather than an open question.
- Audio is silent so far, and that matches the subsystem bench exactly: 7302
  YM3812 writes but no key-on in either, so the game has not started music by
  4.4 s. Audio output remains unverified in the positive sense.

This environment needs two shims to run the stock harness - `envsubst` is
missing and Verilator 5.020 rejects `--quiet-stats` - neither of which changes
what is simulated. Both are documented in `ver/game/README.md`.

---

## 12. Attract mode reached, and a gameplay frame diffed **[V]**

Session of 2026-09-08 on gunmetal (Ryzen 7 5800X3D, Fedora, Verilator 5.052,
Icarus 13.0, MAME 0.289, Quartus 25.1std).

### The attract timeline, from MAME

MAME 0.289 running `wardnerb` headless at 2200% speed puts the sequence at, in
board seconds: power-on tile and colour tests to about 30, the intro story
scene near 45, the attract demo playing from about 50 to 60, and the title
screen later. That is what told the boot bench where to aim, instead of
guessing.

The bench's own timeline agrees independently: `snap12000`, which is 28.6 s of
board time, renders the same GFX ROM test checkerboard MAME shows at 28 s.

### Nine snapshots, one boot

| snapshot | board time | screen | sprites drawn | result |
|---|---|---|---|---|
| `snap2000`  |  4.8 s | text-layer glyph grid, one sprite |  48 | exact |
| `snap4000`  |  9.5 s | tile test over text               | 114 | exact |
| `snap6000`  | 14.3 s | tile test                         | 114 | exact |
| `snap9000`  | 21.4 s | tile test, foreground bank filled | 114 | exact |
| `snap12000` | 28.6 s | GFX ROM checkerboard              | 114 | exact |
| `snap16000` | 38.1 s | high-score table                  | 114 | exact |
| `snap20000` | 47.6 s | gameplay, forest, GAME OVER       | 111 | exact |
| `snap25000` | 59.5 s | gameplay, player, enemies, chest, HUD | 104 | exact |
| `snap30000` | 71.4 s | title screen                      | 102 | exact |

"Exact" is 0 of 76800 pixels differing from `render_ref.py`. `snap20000` and
`snap25000` were also run at ROM latency 1, 2, 3 and 4: exact at every one.
`snap25000` has all three layers scrolled differently - text 457,226,
background 663,498, foreground 870,498 - which no earlier snapshot did, and it
is the first frame here to exercise the sprite priority-31 quirk from real game
data: rendering the reference with `--no-pri31` differs on 4 pixels.

The run cost 3928 s of wall clock for 30055 ms of simulated time, 7.65 ms/s,
after building the model with `-O2 -march=native` (5.76 ms/s before).

### What the long run showed that no short one could

The boot bench's README recorded two behaviours from six-second runs that do
not survive contact with attract mode, and are now qualified there:

- the vertical blanking interrupt **is** enabled, at 13000 bench ms (31 s of
  board time), having been off through the whole power-on phase;
- the DSP is **not** invoked once and forgotten. It halts the main CPU for
  51004344 clocks over the run against the 253276 of the boot handshake, which
  is the DSP driving enemy fire, collisions and sprite placement during play,
  exactly as `toaplan_dsp.cpp` describes;
- the bank window is read for the first time (158709 reads), so the game is
  executing out of banked ROM.

### Still open on the video side

- **No flipped frame of the running game.** Every game snapshot has `flip=0`;
  the flip path is covered only by the 39 flipped random snapshots. Flip is a
  cabinet DIP, so this needs the boot bench run with that switch set.
- The sprite-per-line limit (about 70) is still an RTL invention; MAME has no
  such limit and the real board's is unknown. `obj_ovf` stayed clear on every
  snapshot here.

---

## 13. Audio, and a bug the subsystem benches could not see **[V]**

Same session, 2026-09-08.

### MAME first, as the oracle

MAME 0.289 running `wardnerb` headless, `-noreadconfig -nowriteconfig
-wavwrite`, is **silent for its first 49.5 seconds** of board time and then
plays discrete bursts with gaps - attract-demo sound effects, not music.
Quarter-second peaks: first onset in the 49.75 bucket, then 53.25, 55.00,
58.25, 60.50, 61.50 (the loud one, 8480) and 62.25, silent from 63 through 66.

The `-noreadconfig -nowriteconfig` matters. A cfg written while a dummy audio
driver was in use pins the mixer to a node that no longer exists, after which
MAME exits instantly with status 0 and no message at all.

### The subsystem bench

`ver/main` now captures audio (`+wav`), logs every FM write (`+fmlog=N`,
replacing a hardcoded 400) and detects key-on: the chip takes a register
address on port 0 and its value on port 1, and registers B0-B8 bit 5 is the
one write that makes it audible.

A 28000 ms run, 66.7 s of board time: **first key-on at 49819 ms of board
time, 288 in total**, peak 8158, 3240740 samples at a measured 48611 Hz -
exactly 3.5 MHz / 72, which confirms the sound clock chain from the 14 MHz
crystal to the chip's output rate by measurement.

Against MAME every burst and gap coincides; on 10 ms RMS envelopes over
49-63 s, **r = 0.946 at zero lag**, best alignment zero, and the two agree on
which frames are silent for 1328 of 1401 points.

Two corrections to the record while doing this. jtopl2's `sample` is the slot
counter passing zero - a level held for a whole operator period, not a pulse -
so counting levels gave 8333328 "samples" in 1.5 s; edged it is 48611 Hz. And
the silence before 14 s of board time is not nothing: `snd` holds a decaying
positive DC offset, 2586 to exactly zero, the envelope generators settling
from power-on.

### The whole core, and the bug

`jtsim -verilator -time 53000` first produced a `test.wav` that was bit-zero
for all 53 s. Two separate causes, found in order:

1. **jtsim defaults the DIPs to `FFFFFFFF`**, and the core wires them straight
   to port `50`. MAME's XML names DSWA bit 3 Demo Sounds with `Off=0x08` and
   bit 2 Service Mode. The game was correctly obeying a switch that says make
   no sound. `-dipsw 1` is MAME's own default.
2. **`jtwardner_game.v` was missing two inverters.** With the DIPs corrected
   the core still only reached peak 11 and 16 key-ons. `dip_test` and `tilt`
   were passed to the Toaplan SYSTEM port uninverted while the other seven
   bits were inverted, so the board saw TEST held and TILT tripped for every
   run. Both are active low: `jtframe_dip.v` says of `dip_test` "assumes it is
   always active low" and drives it to zero to *assert* test under `DIP_TEST`,
   and the CPS cores tie an unused `.tilt( 1'b1 )`. MAME declares both port
   bits `IP_ACTIVE_HIGH`.

| | DIP `FFFFFFFF` | DIP `1`, polarity broken | DIP `1`, fixed | MAME |
|---|---|---|---|---|
| `test.wav` peak | 0 | 11 | **3886** | 3962 |
| key-ons in 53 s | 0 | 16 | **163** | - |
| attack/decay writes (60-6f) | 0 | 0 | **16** | - |
| sustain/release writes (80-8f) | 0 | 0 | **16** | - |

The envelope registers are the diagnostic. The zeros in bands `60` and `80`
that §11 recorded as normal were the test switch, not the game: no simulation
of this core had ever seen a write to them until the inverters went in.

On 10 ms RMS envelopes over 48-53 s the fixed core **lags MAME by 320 ms** -
0.6% over 50 s, which is real SDRAM latency against MAME's zero-wait memory -
and at that alignment correlates at **r = 0.9762**.

### Why the earlier benches could not have caught it

`ver/main` drives `cab_sys` from a plusarg that defaults to zero, so its test
and tilt bits were clear by accident, and it has a one-clock program ROM
rather than SDRAM. `ver/dsp` and `ver/video` do not instantiate the game
module at all. The whole-core bench is the only one that exercises jtframe's
cabinet inputs and its mixing path, which is an argument for running it early
on the next core rather than last.

An experiment that did **not** work, recorded so it is not repeated: running
the boot bench at 2600 ms with `+sys=0` and `+sys=6` produced byte-identical
VRAM. At 2.5 s the game is still in POST and has not yet branched on the
SYSTEM port, so the comparison says nothing either way. Testing this needs a
run long enough to reach the attract decision.

---

## 14. The MRA, verified at last **[V]**

Same session, 2026-09-08, once the parent set's DSP dump was available.

`doc/mame.xml` carried no Wardner machine, which is why this had never run.
Regenerating it from MAME 0.289 through `jtframe mra --reduce` is strictly
additive against the old file: **no machine removed, 18 added**, four of them
the Wardner sets and the rest sets MAME has gained since.

### The result

`jtframe mra wardner --path <dir>` produces an 889440-byte `.rom`. Against
`ver/game/mkrom.py`'s image:

| region | result |
|---|---|
| main, snd | byte identical |
| char, bg, fg, obj | byte identical |
| proms | byte identical |
| dsp | 4002 of 4096 bytes differed |

The graphics regions matching is the answer to the open question: the tile and
sprite plane interleave, which `ver/video/README.md` called unverified and
reasoned only from the generator source, is correct.

### The bug

```
mra   f9 00 03 04     big endian, as MAME stores it
mkrom 00 f9 04 03     low byte first, as jtframe loads it
```

MAME holds the DSP mask ROM in a `ROM_REGION16_BE`; jtframe's download fills
each 16-bit word low byte first, because `jtframe_bram_rom` drives `we_lower`
from `prog_mask[0]`. **As generated, the DSP would have executed every
instruction byte reversed.** `width=16, reverse=true` on that region fixes it -
the idiom `cores/cop` uses for its 68000 program. The plan predicted the fix
would be in the TOML and not the RTL, and it was.

After the fix the two images differ in **2 bytes of 889440**, both the known
parent-versus-bootleg DSP words from §13's sibling finding.

### The MRA's own ROM boots

A whole-core run with `-load`, so the DSP mask ROM reaches its block RAM
through the download stream rather than a simulation preload: 54.88 Hz, bank 0
matching the image, and 4998 YM3812 writes in four seconds of board time. The
sound CPU only leaves its wait loop after the main CPU answers at the end of
POST, and POST includes the DSP handshake, so those writes are evidence the
DSP ran on the MRA's data.

### Two smaller things

- jtframe pads between regions with `0xFF`, hardcoded in `fill_upto` with no
  TOML control, where `mkrom.py` left `0x00` above the DSP program. `mkrom.py`
  now matches the generator, since the MRA is what ships. MAME itself declares
  the region `ROM_REGION16_BE(0x1000,"dsp:dsp",0)`, i.e. zero fill, so MAME and
  jtframe simply differ there; nothing correct ever reads it.
- `mkrom.py` silently preferred the parent set's DSP dump when it was present
  in the ROM directory, so dropping that file in changed what it built without
  saying so. It now names the source it used.

### The DSP dump can come from either zip

MAME lists `d70012u_gxc-02_mcu_71001` in the Wardner sets, but the only copy it
does not flag as a bad dump lives in `fshark`, so that is where most
collections keep it - and a `wardner.zip` assembled before the dump existed
will not have it at all. Loading such a set on a MiSTer gives

```
d70012u_gxc-02_mcu_71001 NOT FOUND
```

`zip.alt="fshark.zip"` in `[global]` makes the MRA emit
`zip="wardner.zip|fshark.zip"`, and both MiSTer's firmware and jtframe's own
`mra2rom` search the list in order. This is the same mechanism cps15 and cps2
use to reach `qsound.zip` and rastan uses for `cchip.zip`.

Verified by deleting the file from `wardner.zip` and putting `fshark.zip`
beside it: `jtframe mra2rom` assembles a `.rom` byte-identical to the one built
when `wardner.zip` carried it.

### Open, and a question for jotego

The MRA can only assemble the parent set's DSP dump. That is the Flying Shark
MCU MAME substitutes because no genuine Wardner DSP has ever been read, and it
is BAD_DUMP in every Wardner set. The bootleg PROMs are a direct dump of the
DSP on a Wardner board, they cannot be expressed in the MRA format because it
has no nibble interleave, and the two differ at `$034` and `$36d`. Nothing
tested reaches either address, so this cannot be settled here.

## 15. Getting Quartus to build at all **[V]**

Three things stood between a working Quartus install and a build, none of them
obvious, all of them silent failures.

**No device family was installed.** Quartus 25.1std Lite ran, and would even
accept `5CSEBA6U23I7` in a project file, but any real compile died with

```
Error (20004): Your design targets the device family "Cyclone V". The specified
family is not a valid device family, is not installed, or is not supported in
this version of the Quartus Prime software.
```

Cyclone IV E, Cyclone V, Cyclone 10 LP and MAX 10 all failed the same way;
`get_family_list` returned empty and `get_part_list -family "Cyclone V"` gave
0 parts. Fixed by installing the `cyclonev-25.1std.0.1129.qdz` package.

**The device installer needs `--enable-components` and ignores
`--downloaddir`.** Without the flag it runs to "Installation completed" with
exit code 0 and installs nothing, and its log shows no "Unpacking files" line.
The `.qdz` also has to sit in the installer's own directory; a symlink is
enough. What works:

```bash
DD=~/altera_lite/25.1std/quartus/common/devinfo/dev_install
ln -sf ~/Downloads/cyclonev-25.1std.0.1129.qdz $DD/
$DD/dev_install.run --mode unattended --accept_eula 1 \
    --installdir $HOME/altera_lite/25.1std --enable-components cyclonev
```

The install grows from 8.5 GB to 9.9 GB when it has actually worked.

**`jtcore` requires the literal string `intelFPGA_lite` in the Quartus path.**
`jtcore:153` tests `which quartus_sh | grep intelFPGA_lite`, and on failure
looks only in `/opt/intelFPGA_lite`. An install under `~/altera_lite` is
rejected with "Cannot find Quartus in /opt/intelFPGA_lite". No root needed to
satisfy it:

```bash
mkdir -p ~/intelFPGA_lite
ln -sfn ~/altera_lite/25.1std ~/intelFPGA_lite/25.1std
export PATH=$HOME/intelFPGA_lite/25.1std/quartus/bin:$PATH
```

## 16. The core fits, and closes timing **[V]**

`cfg/skip` is gone - `lint-one.sh wardner -mister` is clean - and
`jtcore wardner -mister` completes in **9 minutes with 0 errors**, producing
`release/mister/jtwardner.rbf`. The figures below are the rebuild of
2026-09-09, after the joystick fix of section 17; the first build is in
brackets where it differed.

| Resource | Used | Available | % |
|---|---|---|---|
| Logic (ALMs) | 25,764 | 41,910 | 61 |
| Registers | 36,801 | - | - |
| Block memory bits | 969,622 | 5,662,720 | 17 |
| RAM blocks (M10K) | 147 | 553 | 27 |
| DSP blocks | 48 | 112 | 43 |
| PLLs | 3 | 6 | 50 |
| Pins | 145 | 314 | 46 |

Timing closes on every clock, all slacks positive and total negative slack
zero. The tightest setup is the HDMI PLL at **+0.339 ns** (+0.503 on the first
build); the core's own PLL has **+4.758 ns** (+3.258), and the worst hold
anywhere is +0.244 ns.

The figures above are the final `--nodbg` release build. Development builds ran
between 62% and 64% and 142 RAM blocks; the differences across rebuilds of
nearly identical RTL are fitter placement noise rather than the edits, since
the seed was 1 every time. The release build drops `jtframe_debug`, which is
what removes the 8-bit binary and hex readout it otherwise draws across the
bottom of every screen, and costs five more RAM blocks in the rearrangement.

**The two RTL worries were unfounded.** The sprite line buffer, flagged as
having two write ports and so possibly not inferrable, became a Simple Dual
Port ALTSYNCRAM of 2048x16 bits across 4 M10K blocks. The 512-flip-flop
touched-pixel vector is simply flip-flops and the design still sits at 61%
ALMs. Neither needs moving on to jtframe memories for this target.

### Still unmeasured: the MiST and SiDi fit

`[mist|sidi] JTFRAME_SKIP` in `cfg/macros.def` remains a prediction. Measuring
it needs the Cyclone IV E device package, which is not installed, and Quartus
13.1 in `/opt/altera/13.1`, which `jtcore` insists on for the `mist` target.
The MiSTer numbers are only a weak guide: 142 M10K on a device with 553 says
little about an EP3C25's 66 M9K, and 25,764 ALMs is roughly 51,500 logic
elements against that part's 24,624.

---

## 17. The joystick order was wrong in both halves **[V]**

`toaplan_joy` in `jtwardner_game.v` was written from the *name* of MAME's
`TOAPLAN_JOY_UDLR_2_BUTTONS` macro, whose definition is not vendored, and its
comment recorded that as unverified. Both halves of the assumption were wrong.

**The Toaplan side**, read out of MAME 0.289's own running machine with a Lua
autoboot script rather than from a header - `mame wardnerb -autoboot_script`
dumping `manager.machine.ioport.ports[":P1"].fields`:

```
PORT :P1
  mask 0x01  P1 Up        mask 0x10  P1 Button 1
  mask 0x02  P1 Down      mask 0x20  P1 Button 2
  mask 0x04  P1 Left      mask 0x40  Skip Video RAM Tests
  mask 0x08  P1 Right
```

so up, down, left, right after all - the macro name was honest.

**The jtframe side** was the wrong half. The comment said "JTFRAME orders its
joystick bits right, left, down, up", which is `JTFRAME_JOY_RLDU`. That is not
the default and this core does not select it. `jtframe_joysticks.v`:

```verilog
reorder = joy_in; // default order up, down, left, right
`ifdef JTFRAME_JOY_RLDU reorder[3:0]={joy_in[0], joy_in[1], joy_in[2], joy_in[3]}; `endif
```

`cfg/macros.def` sets no `JTFRAME_JOY_*` macro, so the game module receives
up, down, left, right - the same order the board wants.

**So the two agree bit for bit and the function only ever had to invert**, but
it also permuted:

```verilog
toaplan_joy = { 2'b00, ~j[5], ~j[4], ~j[1], ~j[0], ~j[2], ~j[3] };
```

which sends bit 0 (Up) `~j[3]`, bit 1 (Down) `~j[2]`, bit 2 (Left) `~j[0]` and
bit 3 (Right) `~j[1]`. In play that is:

| player presses | game sees |
|---|---|
| Up | Left |
| Down | Right |
| Left | Down |
| Right | Up |

a 90 degree rotation. Buttons 1 and 2 were correct throughout. Now:

```verilog
toaplan_joy = { 2'b00, ~j };
```

Bit 6 of P1 is "Skip Video RAM Tests" and stays inactive, so the power-on
tests run, which is MAME's default for that field.

Worth noting how long this survived: no bench here drives the joystick. The
boot bench takes `+joy1=` but nothing in attract mode reads it, and `ver/dsp`
and `ver/video` never see the game module. A wrong control map is invisible to
every test in this project and would only have shown up on a real cabinet.

---

## 18. The MRA shipped every DIP switch inverted **[V]**

2026-09-09. The core ran on a real DE10-Nano with correct sound but wrong
colours, layers drawn that should not have been, and the player sprite behind
things it should be in front of. A photograph of the title screen showed a
green tiled background where MAME 0.289 and this project's own reference render
both show black, plus a numeric readout along the bottom of every screen.

`cfg/mame2mra.toml` carried

```toml
defaults = [
    { value="ff,ff" },
]
```

an unconditional override. `jtframe mra -v` shows the generator computing the
right answer from MAME's own defaults and then discarding it:

```
Default string before applying TOML overrides: 01,00 (bit count=16)
DIP sw default overriden to ff,ff
```

`ff,ff` is correct for the many cores whose DIP inputs are active low and are
inverted inside the core. Wardner's are active high and `jtwardner_main` hands
`dipsw_a` straight to port `50`, so all-ones means **Service Mode on, Demo
Sounds off, Flip Screen on and four coins per credit** - the game boots into
its test screens, which is what the photographs show.

Removing the override leaves `default="01,00"`: cabinet upright, everything
else off, one coin one credit, normal difficulty, three lives. That is MAME's
own default and the same value `-dipsw 1` supplies in simulation. The `.rom` is
byte identical either way, so only the `.mra` needs replacing, not the `.rbf`.

### How it survived

Section 13 diagnosed exactly this condition in simulation and then wrote, here
and in a commit message, that real hardware was unaffected because the MRA's
default is built from MAME's `default="yes"` values. That was read off
`make_switches` in the generator source and never checked against the generated
MRA, where a single `grep default=` would have shown `ff,ff`. **Reading the
generator is not checking the output.** The MRA verification in section 14
would have caught it had it looked at anything beyond the `.rom` bytes - a
`.mra` is a program, and only its data was checked.

---

## 19. On real hardware: five bugs, none of them in the emulation **[V]**

2026-09-09 and 10. The core was flashed to a DE10-Nano and the game ran. Every
fault found from that point lived in the layer between the verified emulation
and jtframe, and **not one was visible to a bench that passed everything**.

| fault | symptom on the cabinet | found by |
|---|---|---|
| MRA forced every DIP to `ff,ff` | service mode, no demo sounds | the owner |
| Tile ROM offsets in 32-bit words, not 16 | wrong layers, wrong colours | whole-core sim vs MAME |
| Joystick direction nibble reversed | up-right and left-down swapped | the owner, at the cabinet |
| `dip_test` and `tilt` missing inverters | board held in test mode | whole-core sim |
| Pen bits reversed on all four layers | colours wrong, shapes perfect | MAME's `gfx_layout`, read directly |

One reported symptom turned out **not** to be a fault: the foreground passing in
front of sprites is what the hardware does, re-derived from `twincobr_v.cpp`'s
`pri_cb` and `screen_update` on both sides.

### The pen order, and why every test missed it

MAME's `gfx_layout` lists `planeoffset` from the most significant pen bit down.
`charlayout`'s `{ RGN_FRAC(0,3), RGN_FRAC(1,3), RGN_FRAC(2,3) }` makes the
first slice of the region pen bit 2; `tilelayout` and the SCU's `spritelayout`
do the same with four planes. The RTL and `render_ref.py` both took the first
slice as bit 0.

Bit reversal maps 0 to 0. Pen 0 stayed transparent, so every shape, silhouette
and priority decision was exactly right and only non-zero pens took the wrong
colour. In text colour set 22, pen 1 is `009f` bright red and pen 4 is `0000`
black - `001` against `100` - and those two pens are 26252 pixels of the intro
screen.

**`render_ref.py` is a transcription made by the same hand as the RTL, and it
carried the same misreading.** The frame diff was comparing two copies of one
mistake and reporting 0 of 76800 pixels on every snapshot while the picture was
visibly wrong. That number was true and worthless.

### What this changes about the method

- **A transcription is not an oracle.** `render_ref.py` has to be checked
  against MAME's *own output* from time to time, not only against the RTL. The
  check is cheap: `mame wardnerb -video none -snapname X -str N` gives a PNG,
  and comparing colour sets and pixels against a bench render takes seconds. On
  the fixed intro: 42 colours each, all 42 shared, 125 of 76800 pixels
  differing, and those are animated flames 0.24 s apart.
- **`ver/video` should be fed from the real `.rom`,** not from `mkgfx.py`.
  Because the bench builds its own `gfx_*.hex`, the SDRAM offsets do not exist
  in it, so the tile ROM offset bug was structurally invisible there too. Two
  independent generators of the same data hid a third bug when they were only
  ever compared with each other.
- **Run the whole-core bench early and look at its frames.** It was built,
  measured for frame rate, ROM layout and audio, and never once had a frame
  compared against anything until the hardware disagreed. Both the offset bug
  and the pen bug reproduce in it in minutes.
- `tb_video` now takes `+gfxen=N` to switch a layer off, the same bits the OSD
  debug keys drive. Turning the text layer off is what identified it as the one
  drawing the red field.

### Debug features in a shipping core

`jtframe_board.v` instantiates `jtframe_debug` under `ifndef JTFRAME_RELEASE`,
and it draws an 8-bit value over the game image in binary and hex - `00000101`
and `05` along the bottom of every screen. Build with `jtcore wardner -mister
--nodbg` for anything a player will use; the development build keeps the
per-layer `gfx_en` keys (F7 text, F8 background, F9 foreground, F10 sprites)
which need `func_key[10:7]` from a USB keyboard.
