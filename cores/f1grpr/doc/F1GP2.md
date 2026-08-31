# F-1 Grand Prix Part II - extension or new core?

MAME `vsystem/f1gp.cpp`, machine `f1gp2` (1992, one set, no clones). The driver holds
both games, which makes them look closer than they are.

## Verdict: new core

Not an extension of `jtf1grpr`. The CPU, link and sound half is shared almost line for
line; the **entire video back end is different hardware**, and two of the differences
are structural rather than switchable:

- the sprite chip is a **different part** - one VS9108 (`vsystem_spr`) against f1gp's
  pair of VS8904/VS8905 (`vsystem_spr2`). Not a mode, a different engine;
- the ROZ tile graphics move from **256 kB of CPU-written BRAM** (`rozgfxram` at
  `c00000`) to a **4 MB ROM region** (`roztiles`). That is a `mem.yaml` change, not a
  runtime one;
- there is **no GGA** - `config.device_remove("gga")` - so the raster is fixed and
  unknown, where f1gp's comes from the register file we already decode.

Add a different SDRAM budget (11.6 MB vs 9.4 MB) with a different set of regions, and
a header-bit approach would carry a dead sprite engine and a dead 256 kB BRAM in every
f1gp bitstream. The pspike core is currently being split for exactly this reason - see
`cores/pspike/doc/SPLIT_PLAN.md`.

Share the common HDL through `files.yaml`, the way jtcores cores already pull modules
from each other, rather than by header bit or by copy.

**Needs a name.** `f1grpr2` pairs with the existing folder. If the VS9108 engine gets
written, consider naming for the board instead - see "What this buys" at the end.

## What is identical (and can be pulled straight over)

| | |
|---|---|
| Main CPU | 68000 @ 10 MHz, IRQ1 on vblank |
| Sub CPU | 68000 @ 10 MHz, **the same `f1gp_cpu2_map`**, unmodified |
| ACIA | 6850 at `fff030` on the sub CPU, 20 MHz/16 = 78125 baud, IRQ3, dual DE-9 |
| Sound | Z80 @ 5 MHz + YM2610 @ 8 MHz, **the same `sound_io_map`** (`00` and `0c` are both bankswitch, latch/ack `14`, YM `18-1b`) |
| Audio routing | 0 -> both at 0.75, 1 -> L, 2 -> R at 1.0 |
| fg tilemap | 8x8x**8** raw, 64x32, transparent pen `0xff`, palette base 0 - byte identical decode |
| Palette | xRGB-555, 2048 entries at `ffe000-ffefff` |
| Work / shared RAM | `ff8000-ffbfff` and `ffc000-ffcfff` |
| ROZ chip | K053936, `jt053936.v` already in `cores/rungun/hdl` |

The `fff000` I/O block keeps the same shape too: INPUTS, WHEEL, DSW1, DSW2, the sound
latch with its pending read at `fff009`.

So `jtf1grpr_sub.v`, `jtf1grpr_snd.v`, `jtf1grpr_fg.v` and `jtf1grpr_colmix.v` are
reusable essentially as they stand.

## Main CPU map, diffed against f1gp

```
                     f1gp                          f1gp2
  000000-03ffff      ROM                           same
  100000-2fffff      user1 ROM                     same
  a00000-bfffff      user2 ROM (2 MB)              --- gone ---
  a00000-a07fff      ---                           sprite CG RAM, 32 kB, ONE chip
  c00000-c3ffff      rozgfxram, 256 kB (RAM!)      --- gone, tiles are ROM ---
  d00000-d01fff      rozvideoram .mirror(0x6000)   rozvideoram, NO mirror
  e00000-e03fff      SPR-1 CG RAM                  e00000-e00fff  sprite VRAM (4 kB)
  e04000-e07fff      SPR-2 CG RAM                  ---
  f00000-f003ff      SPR-1 VRAM                    ---
  f10000-f103ff      SPR-2 VRAM                    ---
  ff8000-ffefff      work / shared / fg / palette  same
  fff000             r INPUTS                      same
  fff000.b           ---                           w rozbank
  fff001.b           w gfxctrl                     same
  fff002-fff005      w fgscroll                    --- moved ---
  fff004 / fff006    r DSW1 / DSW2                 same
  fff009             latch + pending               same
  fff00a             ---                           r DSW3
  fff020-fff023      w GGA                         --- gone ---
  fff020-fff03f      ---                           w K053936 ctrl
  fff040-fff05f      w K053936 ctrl                --- moved ---
  fff044-fff047      ---                           w fgscroll
  fff050             r DSW3                        --- moved to fff00a ---
```

Note the ROZ VRAM loses the `mirror(0x6000)` that cost a debugging session on f1gp.
Do not carry the four-alias decode over; and do not assume it is absent either -
prove it with the write tap in `.claude/skills/mame-decoder` step 5.

## Work items

### 1. VS9108 sprite engine - the main work

`vsystem_spr.cpp` / `.h` are **not mirrored in this tree and not implemented anywhere
in jtcores**. Pull them down first; everything below is guesswork until they are read.

What the driver alone establishes:

```c
VSYSTEM_SPR(config, m_spr, m_palette, gfx_f1gp2_spr);
m_spr->set_tile_indirect_cb(FUNC(f1gp2_state::tile_callback<0>));
...
m_spr->draw_sprites(m_sprvram[0], 0x2000, screen, bitmap, cliprect);
```

- one chip, sprite VRAM `0x2000` bytes at `e00000`;
- indirect lookup, same shape as f1gp's: `m_sprcgram[0][code & (length-1)]`, a
  **power-of-two mask** over the 32 kB CG RAM at `a00000` (16384 words -> 14 bits);
- tiles `gfx_16x16x4_packed_lsb`, palette base `0x200`, 32 colours;
- `draw_sprites` takes no priority parameter - the VS9108 composites differently from
  the SPR2 pair, whose `pritype` we already model.

Budget this as a from-scratch engine, comparable to the VS8904/VS8905 work in pspike,
not as a variant of `jtf1grpr`'s.

### 2. ROZ from ROM, with a bank

```c
tileinfo.set(1, (code & 0x7ff) + (m_roz_bank << 11), code >> 12, 0);
```

against f1gp's `tileinfo.set(1, code & 0x7ff, code >> 12, 0)`. `rozbank_w` at `fff000`
is a full byte, so the tile index reaches 11 + 8 = 19 bits x 128 B = the full 4 MB
`roztiles` region.

Consequences: `jtf1grpr_roz.v` swaps its BRAM tile fetch for an SDRAM client, and
`roztiles` becomes the single heaviest bus in the core - a per-visible-pixel fetch off
a 4 MB region. It gets its own bank.

The ROZ tilemap is also **transparent on pen 0x0f** here (f1gp draws it opaque), and
`K053936` offsets change from `(-58,-2)` to `(-48,-21)`.

### 3. Compositing - four modes from `gfxctrl`

```
gfxctrl & 4  -> blank the screen to the black pen
gfxctrl & 3:
  0   ROZ (opaque)  ->  sprites  ->  fg
  1   ROZ (opaque)  ->  fg       ->  sprites
  2   fg (opaque)   ->  ROZ      ->  sprites
  3   unsupported (MAME logs it)
```

A real runtime layer-order mux, unlike f1gp where `gfxctrl` is a two-case kludge for
the "continue" screen. The mixer has to reorder layers per frame, so build it as an
order selector rather than a fixed chain.

The fg tilemap also carries a fixed offset here: `set_scrolldx(-80)`,
`set_scrolldy(-26)`.

### 4. Video timing without a GGA

`screen.set_visarea(0*8, 40*8-1, 0*8, 28*8-1)` = **320x224** at a nominal 60 Hz, on a
declared 512x256 grid. f1gp is 320x240 with the GGA supplying the real 456x256.

MAME's `set_size` is nominal and the GGA is gone, so the true grid is unknown. Do not
copy f1gp's numbers. Either measure on real hardware, or derive from the pixel clock
if the board still runs 14.318181/2: 224 visible lines at 60 Hz wants roughly a
456x262 grid. Flag it as unverified until something confirms it - wrong constants move
the picture, they do not stall a CPU, so this is not a bring-up blocker.

`JTFRAME_WIDTH/HEIGHT` become 320x224, and this core does **not** need the GGA
register file at all.

### 5. ROMs and SDRAM

| region | f1gp2 | f1gp |
|---|---|---|
| maincpu | 256 kB, `ROM_LOAD16_BYTE` | 256 kB |
| user1 | 2 MB, `WORD_SWAP` + `ROM_CONTINUE` halves swapped | 2 MB |
| user2 | **none** | 2 MB |
| sub | 128 kB, `ROM_LOAD16_WORD_SWAP` | 128 kB |
| audiocpu | 128 kB | 128 kB |
| fgtiles | 2 MB | 2 MB |
| sprites1 | 2 MB (one chip) | 1 MB + 512 kB (two chips) |
| roztiles | **4 MB** | none (RAM) |
| ymsnd:adpcmb | 512 kB | 1 MB |
| ymsnd:adpcma | 1 MB | 1 MB |

~11.6 MB against f1gp's ~9.4 MB, and a different set of regions - which is the
practical reason the bank map cannot be shared even if everything else were.

Watch `user1`: `ROM_LOAD16_WORD_SWAP("rom2", 0x100000, 0x100000)` followed by
`ROM_CONTINUE(0x000000, 0x100000)` - the two halves of a single 2 MB file are
**swapped** into the region. Reproduce that in `mame2mra.toml` with a `parts` map, and
verify with the reset-vector check before simming, exactly as `cores/pspike/doc/STATUS.md`
prescribes.

`maincpu` is `ROM_LOAD16_BYTE` (`width=16, reverse=true`); `sub` is
`ROM_LOAD16_WORD_SWAP` (straight, no width, no reverse). They are not the same, and
getting either wrong reads as "the CPU never boots".

### 6. DIPs and inputs

Same three DIP ports, DSW3 moved from `fff050` to `fff00a`. If DSW3 is again a region
jumper with only a few legal codes, apply the f1grpr treatment: delete MAME's raw
jumper and expose a small indexed `extra` decoded back in `_main.v`. Read the
`f1gp2` `INPUT_PORTS` before assuming - f1gp's region trap is documented in
`cores/f1grpr/cfg/mame2mra.toml` and was worth two root causes.

## What this buys

The driver's own opening note: *"f1gp2's hardware is very similar to Lethal Crash
Race, main difference being an extra 68000."* So a VS9108 + K053936 core is plausibly
two games, not one - worth reading `vsystem/crshrace.cpp` **before** naming the folder
and laying out the banks, so the name and the bank map do not have to change later.

## Order of work

1. Mirror `vsystem_spr.cpp` / `.h` into the new core's `doc/`, alongside `f1gp.cpp`
   and `k053936.*`. Read the sprite device before designing anything.
2. Read `crshrace.cpp` and settle the core name and scope.
3. Decoders per the mame-decoder skill, main and sub. Sub is a straight copy.
4. Bank layout + `mem.yaml`, then the reset-vector check on the generated blob.
5. Boot sim; trace against MAME if it stalls.
6. ROZ from ROM, then the fg layer (both are near-free reuse).
7. VS9108 sprite engine.
8. The four-way `gfxctrl` compositing mux.
9. Raster constants, last - they move the picture, they do not stall anything.
