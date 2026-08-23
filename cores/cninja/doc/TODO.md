# TODO

## Priority PROMs — currently skipped, probably recoverable

`cfg/mame2mra.toml` has `{ name="proms", skip=true }`, so these are not assembled
into the ROM blob:

| game | PROM | size | organisation | MAME comment |
|---|---|---|---|---|
| cninja | `mb7122h.7v` | 1 KB | 1024x4 | `/* Priority  Unused */` |
| cbuster | `mb7114h.18e` | 256 B | 256x4 | `// Priority (not used)` |
| vaportra | `fj-27.bin` | 512 B | ? | none |
| darkseal | — | — | — | has no PROM at all |
| edrandy | `ge-12.v7` | 1 KB | 1024x4 | `Priority Unused, same as Robocop 2` |

They are **priority** PROMs, not colour PROMs. "Unused" means MAME does not read
them — it reimplements priority in C++ (`screen_update` plus the decospr
`pri_callback`) — not that the chip is idle on the PCB. On hardware the PROM
does the job `jtcninja_colmix` currently does with hand-written if/else ladders:
take the layer opacity and priority bits, output which layer wins.

### What the cninja PROM data looks like

Measured from `mb7122h.7v` in the romset:

- Every high nibble is 0 → genuinely 4-bit wide (MB7122 = 1024x4).
- **Every even address reads 0.** `A0` acts as a strobe or blank: low → output 0
  (backdrop). The real table is 512 entries indexed by `A[9:1]`.
- Only five output codes appear: `1, 2, 3, 12, 13`. Bit 3 (`0xC`/`0xD` =
  `1100`/`1101`) looks like a flag on top of a small layer-select field.
- All nine remaining address bits are live, very unevenly. Number of the 256
  input pairs where flipping that bit changes the output:

  | bit | A1 | A2 | A3 | A4 | A5 | A6 | A7 | A8 | A9 |
  |---|---|---|---|---|---|---|---|---|---|
  | pairs | 156 | 16 | 118 | 60 | 48 | 88 | 68 | 162 | **2** |

  `A8`/`A1` dominate; `A9` matters in 2 of 256, the signature of a mostly
  don't-care input.

That is a legible lookup table, not noise.

### Why it is not used

**The pin mapping is unknown** — which signal drives each of `A0..A9`, and what
the 4-bit output selects. MAME never reads the PROM so it documents nothing, and
the romset gives contents without a convention. Contents plus an unknown address
assignment are unusable: you would be guessing which bit is "sprite pri 0" and
which is "mg opaque". Normally the schematic supplies this; there is none for
cninja (MAME-driven bring-up).

### The way in

The mapping can be **solved for** rather than guessed, because colmix already
implements the correct priority function (derived from MAME, validated on
screen). Search candidate assignments of the known signals — `fg`/`mg`/`bg`/
`pf1b` opacity, `obj_pri[1:0]`, `epri`, sprite opacity — onto `A[9:1]`, and keep
any under which the PROM reproduces what colmix computes. With five output codes
over 512 entries a wrong mapping should contradict itself quickly, so a match
would be evidence rather than coincidence.

If a mapping is found: replace the hand-written ladder with a faithful LUT, and
very likely settle cbuster's priority bands, which are the longest-standing
"fixed order for now" part of colmix.

### Risks

- The PROM may take inputs the core does not model — raw tile-priority bits
  before our decode, for instance. `A9` being near-dead hints at an input we may
  not have.
- Each board needs its own solution, and **darkseal has no PROM**, so it resolves
  priority some other way entirely — whatever that is, it also applies to the
  others and may make the PROM redundant rather than authoritative.
- Using them means un-skipping the region: blob layout, MRA and a BRAM to hold
  the table.

## Protection LUT — the second table has landed

`jtcninja_deco104` is parametrized (TABLE / USE_MAGIC / XOR_PORT / NAND_PORT /
SND_PORT / BANK_PORT) and instantiated **twice**: the 104 for cninja and the 146
for edrandy, muxed by board. Both `jtframe_prom` tables use `SYNHEX`, so Quartus
bakes both into the bitstream and **both are always present, whichever game is
running**.

### Size

1024 entries x 36 bits = 36,864 bits per table, so 73,728 bits for the pair.

| device | block | widest mode | blocks per table | pair |
|---|---|---|---|---|
| M9K (Cyclone III, MiST/SiDi) | 9216 bit | 256x36 | 4 | 8 |
| M10K (Cyclone V, MiSTer) | 10240 bit | 256x40 | 4 (4 bits/word wasted) | 8 |

Arithmetic, not a fitter report — it assumes Quartus infers the widest mode for
what is a single-port ROM here (`we` is tied low). If it settles on x18 instead
it is 16 blocks. Confirm against a real fit log.

### What is duplicated

Only the table needs to be. The two instances also duplicate the whole chip —
nibble unpack, reorder, xor/nand datapath, rambank — which the parametrization
made cheap to write but does not make cheap to fit.

Two ways to claw it back, in increasing order of work:

1. **One instance, double-depth table.** The packings are identical, so
   concatenate both into 2048x36 and make the board boolean the top address bit
   (`AW(11)`, `tidx = {is146, ra_xor[10:1]}`); the constants become muxed wires
   instead of parameters. Same total memory (8 blocks) but ONE copy of the chip
   logic and one BRAM primitive. Strictly better than what is there now, and
   local to the core.
2. **Load the table from the ROM blob** — the only option that loads just what
   the running game needs: one BRAM, filled at download time from whichever MRA
   is loaded, scaling to any number of variants at zero extra BRAM. Blocked in
   the framework: the tables are generated, not MAME ROMs, and `mame2mra` cannot
   emit literal region data (`Parts`/`Files` resolve against real files; literal
   bytes exist only for the header and NVRAM defaults). Needs a jtframe change -
   an inline-data region, or a `Custom{Dev}`-style hook that runs a generator.
   ~5 kB per MRA against an 8.6 MB blob. Worth raising upstream: any core with
   per-game LUTs hits this.

Related: the same "generated table with nowhere good to live" problem is why
`jtcninja_deco104_table.hex` and `jtcninja_deco146_table.hex` are tracked build
artifacts rather than blob content, and it is why the `LOADROM`-suppresses-
`SIMHEX` bug (fixed in `jtframe_prom`) was able to leave a table reading all
zeros in every real-ROM sim without any warning.

## Tile line buffers — removable, and worth trying

Each `jtcninja_deco16` renderer ends in a `jtframe_linebuf #(.DW(8),.AW(9))`.
Two renderers per deco16ic and two chips = **4 buffers**, 1024x8 = 8192 bits
each (two 512-pixel halves, double buffered), 32 kbit in total.

| device | block | mode | per buffer | all four |
|---|---|---|---|---|
| M9K (Cyclone III) | 9216 bit | 1024x9 | 1 | 4 |
| M10K (Cyclone V) | 10240 bit | 1024x10 | 1 | 4 |

Arithmetic, not a fit report.

### Why they are there

Not throughput. At 48 MHz with `JTFRAME_PXLCLK=6` a line is 376 px x 6 = 2256
clocks and the engine needs 34 columns x ~15 = ~510, under a quarter of the
budget. The problem is **burstiness**: `WR` emits 8 pixels in 8 consecutive
48 MHz clocks - six times faster than the display drains them - then stalls for
the next column's three reads (colscroll BRAM, tile BRAM, gfx SDRAM). The buffer
is the rate matcher between a bursty producer and a constant-rate consumer.

### Why removing them is worth it

- deletes one **line** of latency from every playfield;
- deletes the no-clear trap: `jtframe_linebuf` has no clear, so a layer whose
  enable drops replays its last two lines until something overwrites them. That
  was the cninja level-2 waterfall bug, now papered over by gating `pxl` on `en`
  in `jtcninja_deco16`. A just-in-time renderer has nothing to replay.

### What blocks it

`jtframe_tilemap` / `jtframe_scroll` are already just-in-time - they pace
fetches to `pxl_cen` and shift pixels out of a register - but neither supports
per-column colscroll, which is what forces our hand: a column's Y is not known
until its scroll-table entry comes back, and that table is one BRAM shared with
the other playfield through the 2-phase arbiter in `jtcninja_deco16ic` (the
`XW*`/`CW*` wait states). Going JIT means prefetching that lookup a column ahead
through the arbiter. Real work, not a tidy-up.

### Priority

Low as a BRAM play - 4 blocks against a design asking >=250 M9K, under 2%. The
protection tables are twice that and have a cheaper fix (see above). Do this one
for the latency and the no-clear trap, not for the memory.

## Smaller items

- **vaportra `tiles1`** is the only gfx region still rotated by `post_addr` in
  `jtcninja_game.v`; the other seven moved to `mame2mra` `parts`/`map` and were
  verified byte-identical. Finding its MRA form is what would let `post_addr` be
  dropped — along with cninja's row-major rotate, which is a different transform
  (a page-hit optimisation) and would have to become a `gfx_sort`.
- **`jtframe_objdraw`/`jtframe_objscan` in `jtcninja_decospr`** — attempted and
  reverted (58 of 63 frames differed). Two findings worth keeping: `jtframe_draw`
  reads the gfx LSB-first (`{24,16,8,0}`, shift right) starting on ROM half
  `hflip`, while the DECO tiles are MSB-first (`{31,23,15,7}`, shift left)
  starting on half `~hflip`; and it is not a throughput problem, `jtframe_draw`
  prefetches the second half exactly as the hand-rolled engine does. Note this is
  a code-size win only: `jtframe_objdraw_gate` instantiates the same
  `jtframe_obj_buffer` decospr already has, so no BRAM is saved.
- **MiST does not fit.** The design asks for >=250 M9K against 66 available;
  `fx68k`'s microcode ROM alone needs 66. Not reachable regardless of what this
  core saves.
- **Every blob is now 8640 kB.** The BA0 sprite slot is sized for edrandy's 5MB
  and the 68k slot for its 1MB program, so cninja pads BA0 with 3MB of 0xFF and
  darkseal/vaportra with 4MB. `start=` takes a macro name and macros are per
  core, so one family cannot have per-game bank maps. Splitting the boards into
  separate cores is what removes this.
