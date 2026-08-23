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

## Protection LUT — does not scale to a second table

`jtcninja_deco104` holds its 1024-entry port table in a `jtframe_prom` with
`SYNHEX`, i.e. Quartus bakes the contents into the bitstream's BRAM init. There
is no runtime selection: **whatever tables exist are all in the RBF, always.**

### Size

1024 entries x 36 bits = 36,864 bits (36 kbit).

| device | block | widest mode | blocks |
|---|---|---|---|
| M9K (Cyclone III, MiST/SiDi) | 9216 bit | 256x36 | 4 |
| M10K (Cyclone V, MiSTer) | 10240 bit | 256x40 | 4 (4 bits/word wasted) |

Arithmetic, not a fitter report — it assumes Quartus infers the widest mode for
what is a single-port ROM here (`we` is tied low). If it settles on x18 instead
it is 8 blocks. Confirm against a real fit log.

### What happens when a second protection table arrives

edrandy needs the DECO 146 table, which is a *different* 1024-entry table in the
*same* 36-bit packing (`gen_deco146_table.py` produces the identical format; only
the contents and the xor/nand/magic constants differ).

The `cninja2` branch solved it by parametrizing `jtcninja_deco104` and
instantiating it **twice**, muxed by game. That duplicates not just the 4 blocks
of table but the whole chip: nibble unpack, reorder, xor/nand datapath, rambank.

Three options, increasing work:

1. **One instance, double-depth table.** The packings are identical, so
   concatenate both into 2048x36 and make the game boolean the top address bit
   (`AW(11)`, `tidx = {is146, ra_xor[10:1]}`); the constants become muxed wires
   instead of parameters. Same total memory as two instances (8 blocks) but ONE
   copy of the chip logic and one BRAM primitive. Strictly better than
   duplicating the instance, and local to the core.
2. **Load the table from the ROM blob** — the only option that loads just what
   the running game needs: one BRAM, filled at download time from whichever MRA
   is loaded, scaling to any number of variants at zero extra BRAM. Blocked in
   the framework: the table is generated, not a MAME ROM, and `mame2mra` cannot
   emit literal region data (`Parts`/`Files` resolve against real files; literal
   bytes exist only for the header and NVRAM defaults). Needs a jtframe change -
   an inline-data region, or a `Custom{Dev}`-style hook that runs a generator.
   ~5 kB per MRA against a 5.4 MB blob. Worth raising upstream: any core with
   per-game LUTs hits this.
3. **Derive one table from the other.** Unexamined. If the 104 and 146 differ by
   a permutation rather than arbitrarily, one table plus a transform serves both.
   Could equally be that they are unrelated dumps.

Related: the same "generated table with nowhere good to live" problem is why
`jtcninja_deco104_table.hex` is a tracked build artifact rather than blob
content, and it is why the `LOADROM`-suppresses-`SIMHEX` bug (fixed in
`jtframe_prom`) was able to leave this table reading all zeros in every real-ROM
sim without any warning.

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
