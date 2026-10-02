# jtpspike - division plan

Where the core is now, what the real cost of keeping it as one core is, and how to
divide it. Written before spinlbrk goes in, because spinlbrk is the game that makes
the current shape untenable.

## Where we are

One core covers four hardware variants of `vsystem/pspikes.cpp`, selected at runtime
from MRA header byte 1:

| bit | family | sets | layers | sprite chips | sprite LUT |
|---|---|---|---|---|---|
| 0 | pspikes  | pspikes pspikesk pspikesu svolly91 | 1 | 1 | 16 kB RAM |
| 1 | turbofrc | turbofrc turbofrco turbofrcu turbofrcua | 2 | 2 | 16 kB RAM x2 |
| 2 | aerofgt  | aerofgtb aerofgtc sonicwi | 2 | 2 | 16 kB RAM x2 |
| 3 | karatblz | karatblz karatblzu karatblzj karatblza | 2 | 2 | 64 kB RAM x2 |

Everything downstream of the address decode is shared and works: the GGA, the
VS8904/VS8905 sprite engine, the Z80 + YM2610, the mixer, the palette.

**The divergence is almost entirely address decode plus a table of video constants.**
In `jtpspike_main.v` that is 44 `assign` lines of `ps_* / tf_* / kb_* / af_*` wires
feeding eleven four-way ternary chains:

```verilog
assign vram_cs = cpu_bus & (karatblz ? kb_vram0 : aerofgt ? af_vram0 : turbofrc ? tf_vram0 : ps_vram);
```

plus a 100-line register-write `always` block with three game branches, plus a
cabinet-read mux with three, plus ~12 ternary constant lines in `_video.v`.

## The two real costs

**1. Every new game edits every existing game's decode.** A ternary chain has no
seam. Adding spinlbrk means touching all eleven chains, and a typo in the karatblz
arm silently changes karatblz. This is not hypothetical - the two worst bugs of this
project were a decode that was one bit too wide (f1grpr ROZ mirror, stale road tiles)
and a decode that was too wide on the *read* side (the animated logo vanished because
an aliased range stopped returning `ffff`). Both were single-expression mistakes in
exactly this kind of chain.

**2. BRAM, on Pocket.** Current `mem.yaml` (addr_width is in bytes):

```
ram   64 kB   lut   64 kB
ram2  16 kB   lut1  64 kB
vram   8 kB   pal    4 kB
vram1  8 kB   oram   2 kB
rascr  4 kB   oram1  2 kB
                     ------
                     236 kB
```

- MiSTer `5CSEBA6`: ~690 kB M10K. 236 kB is ~34%, comfortable.
- Pocket `5CEBA4F23C8` (`modules/jtframe/target/pocket/pocket.qsf:40`): 308 M10K
  blocks = **385 kB**. 236 kB is **61%**, before jtframe's own line buffers, frame
  buffer and scaler.

`lut` + `lut1` are 128 kB of that 236, and they are 64 kB each **only because of
karatblz**. pspikes needs one 16 kB LUT and no `vram1`/`oram1`/`ram2`/`lut1` at all:
a pspikes-only core would use ~82 kB.

Nothing is oversized - every region is sized exactly to its map. The 236 kB is the
honest cost of one bitstream serving four boards.

## Recommendation

**Do the module split first (Option B). Treat the core split (Option A) as a
decision that only becomes forced if Pocket fitting fails.**

Option B costs a day, removes the "new game edits old game" hazard outright, and is
a strict prerequisite for Option A anyway - the per-game modules are what a second
core would take with it. Option A costs four sets of `macros.def` / `mem.yaml` /
`mame2mra.toml` / MRA plumbing and four copies of the sprite engine to keep in sync,
and buys nothing until the Pocket build actually fails to fit.

Check the fit before deciding: build once for pocket and read `Total block memory
bits` out of the fitter report. If it is under ~80% with the sprite buffers in, stay
on one core.

---

## Option B - named modules (do this)

### B1. One decoder module per hardware variant

```
hdl/jtpspike_dec.v        selector, one-hot case, no per-game logic
hdl/jtpspike_dec_ps.v     pspikes map
hdl/jtpspike_dec_tf.v     turbofrc map
hdl/jtpspike_dec_af.v     aerofgtb map
hdl/jtpspike_dec_kb.v     karatblz map
hdl/jtpspike_dec_sb.v     spinlbrk map          (new, see SPINLBRK_PLAN.md)
```

Every decoder has the **same port list** so the selector is mechanical:

```verilog
module jtpspike_dec_tf(
    input      [23:1] A,
    output            rom, ram, ram2, vram0, vram1, lut0, lut1,
                      oram, rascr, pal, io
);
```

and the selector is a `case(game)` on a one-hot vector, not a ternary chain:

```verilog
always @* begin
    { rom, ram, ram2, vram0, vram1, lut0, lut1, oram, rascr, pal, io } = 0;
    case( 1'b1 )
        game[SB]: {rom,ram,...} = sb_bundle;
        game[KB]: {rom,ram,...} = kb_bundle;
        ...
    endcase
end
```

The property that matters: **adding a game is one new file plus one new `case` line.
No existing game's expression is edited.** That is the whole point of the exercise.

`cpu_bus` gating, the byte-lane `*_we` construction and the `cpu_din` mux stay in
`_main.v` - they are identical for every game and do not belong in the per-game files.

Each `_dec_*.v` carries the MAME `address_map` pasted verbatim in its header comment,
per `.claude/skills/mame-decoder`. That is the file's specification, and reviewing it
becomes a line-by-line diff instead of a memory exercise.

### B2. Split the I/O block out

`hdl/jtpspike_io.v` - the cabinet read mux and the video/sound register writes, both
currently game-branched inside `_main.v`. Same shape: one module per family, or one
module with the port layout as a parameter table. The register file (`flip`,
`charbank`, `objbank`, `scry`, `scrx0/1`, `scry1`, `bankw[]`, `snd_latch`) is common;
only which address writes which field differs.

Note the two byte-lane conventions already discovered, which must survive the move:
pspikes and karatblz latch the sound byte on an **odd** address (LDS, `main_dout[7:0]`),
turbofrc and aerofgt on an **even** one (UDS, `main_dout[15:8]`).

### B3. Hoist the video constant table

`hdl/jtpspike_vidcfg.v` - a pure lookup, no logic:

```
visx  xoffs  xb0  xb1  obj_yoffs  cmask0  cmask1  pal bases
```

Today these are ~12 ternary lines scattered through `_video.v` (lines 113-133). As a
table they can be read against MAME's `screen_update_*` and `set_offsets` calls in one
sitting, and a new game adds one row.

### B4. Tile-format selector

`_scr.v` already carries three formats behind `two` / `kb` / neither. spinlbrk is a
fourth, and `two`/`kb` are already being asked to mean two different things (tile
format *and* map size *and* raster source). Replace the booleans with an explicit
3-bit `tilefmt` code and a `case`. Same argument as B1: the encoding stops being
implicit.

### B5. Regression gate

After each step, re-run the existing scene fixtures for pspikes and turbofrc and
diff the PNGs. The refactor is only correct if the pictures are **bit-identical** -
this is a pure re-arrangement, there is no "close enough". `tools/scenesim/` and
`build_diffs.py` already do this.

---

## Option A - separate cores (only if Pocket forces it)

If it comes to that, the hardware line to cut along is **one layer + one sprite chip
vs two + two**, not one core per game:

- **`jtpspike`** - pspikes, pspikesk, pspikesu, svolly91.
  1 tilemap (64x32), 1 sprite chip, 16 kB LUT RAM, per-line raster RAM, 24-bit map,
  ADPCM-B present. ~82 kB BRAM.
- **`jtturbof`** - turbofrc + aerofgt + karatblz + spinlbrk.
  2 tilemaps (64x64), 2 sprite chips, LUT RAM 16 or 64 kB, `global_mask(0xfffff)` on
  three of the four. ~236 kB BRAM, unchanged.

Everything after the decode is common to both, so they would share HDL through
`files.yaml` rather than by copy. That is the only split worth doing: cutting further
(a core per game) duplicates the sprite engine four ways for no resource gain, since
the four turbofrc-class games differ by decode and constants only.

What a split costs that Option B does not:
- four (or two) `macros.def` with their own SDRAM bank layouts
- separate `mame2mra.toml`, MRA sets and `.beta.yaml` entries
- the GGA, sprite engine, sound and mixer live in one core's folder and are pulled by
  the other through `files.yaml` - workable, but every fix now needs both cores
  re-simmed before it can be called done

## Order of work

1. B1 decoders + B5 regression (the hazard is here)
2. B2 I/O
3. spinlbrk lands as `_dec_sb.v` + an I/O variant + a `tilefmt` code - see
   `SPINLBRK_PLAN.md`
4. B3 / B4 when convenient
5. Build for pocket, read the fitter's memory figure, and only then revisit Option A

## Stale notes to fix while in here

- `STATUS.md` points at `doc/TASK_bank_relayout.md`, which does not exist.
- `STATUS.md` says `SPRLUT_START is already reserved in the bank map` for spinlbrk.
  It is not - `cfg/macros.def` has no such symbol. The bank map has to be redone for
  spinlbrk regardless (see SPINLBRK_PLAN.md).
