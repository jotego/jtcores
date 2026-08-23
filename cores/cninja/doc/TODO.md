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
