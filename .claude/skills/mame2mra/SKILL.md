---
name: mame2mra
description: Write a core's cfg/mame2mra.toml from the MAME driver and the jtframe docs. Use when creating or fixing MRA generation for a jtcores core. Never copy another core's toml - boards differ wildly.
---

# Writing cfg/mame2mra.toml

Authoritative sources, in order:
1. `modules/jtframe/doc/jtframe-mra.md` — element reference. Read it first.
2. `modules/jtframe/src/jtframe/mra/` Go source — exact semantics when the doc
   is thin (`types.go` for the schema, `corerom.go` for region/interleave logic).
3. The MAME driver (`cores/<core>/doc/<driver>.cpp`) and the machine entries in
   `$JTROOT/doc/mame.xml` — the ROM truth. `mame.xml` must already contain the
   sets (see `jtframe mra --reduce`).

Do NOT start from another core's toml. Derive every line from the sources above.

## Method

1. **List the MAME regions** from the driver's ROM_START blocks and match them
   against the core's SDRAM/BRAM layout in `cfg/mem.yaml` + the `*_START`
   macros in `cfg/macros.def`. Every region the core downloads needs an entry
   in `[ROM].regions` and a slot in `[ROM].order`; the first region in `order`
   starts at 0, each next one must line up with the matching `JTFRAME_BAx_START`
   / custom start macro (`start="MACRO_NAME"` asserts it).

2. **Know what mame.xml does NOT tell you.** `-listxml` flattens ROM_CONTINUE:
   a split-loaded file shows as one entry at its first offset. The MRA dumps
   files, not address maps — so design the core's address mapping around the
   *file-linear* layout, or use `splits` when the two halves must land apart.

3. **Region entry decisions** (each maps to a RegCfg field, see types.go):
   - Plain byte ROMs in file order: bare `{ name="..." }`.
   - MAME offsets with gaps (e.g. ROMs at 0x8000 of a 64KB region): add
     `no_offset=true` to pack files back-to-back; otherwise the tool inserts
     FF fillers up to each file's MAME offset.
   - 16/32-bit buses: `width=16|32`. mame.xml region entries carry per-file
     offsets that imply the interleave; when files pair by halves of one chip
     use `singleton=true`.
   - Planar GFX (RGN_FRAC in the driver): `frac={ bytes=N, parts=M }` makes
     M/N-byte output words taking N byte(s) per file. If file count is not a
     multiple of `parts`, the LAST file of each group is duplicated into the
     filler lane (corerom.go make_frac) — safe if the core ignores the extra
     plane, but account for it in the pixel logic.
   - Region renames (`audiopcb:melodycpu` etc. contain colons and are unwieldy):
     `rename="melody"`.
   - Reorder/repeat files: `sequence=[...]` (indexes into the file list).
   - Drop regions the core never loads (plds, nvram is automatic): `skip=true`.
   - Devices with no dump or replaced by HDL (protection PALs modelled in RTL):
     skip them and note it in the core docs.

4. **DIP switches.** jtframe packs MAME's DIP ports into the 32-bit `dipsw`
   bus in tag order, but a third 8-bit port can land past bit 31 when ports
   are placed on 16-bit boundaries. Use `[dipsw] offset` entries
   (`{ name="TAG", value=N }`) to force each MAME tag's base bit. Check the
   core reads `dipsw[23:16]` etc. consistently. `delete` the Unused/Unknown
   entries. `defaults` sets the MRA default bytes LSB-first.

5. **Buttons**: `[buttons] names=[{ names="A,B" }]` — count must match
   `JTFRAME_BUTTONS`.

6. **Header** (only if the core needs per-set configuration, e.g. game id for
   protection variants): set `JTFRAME_HEADER=len` in macros.def and use
   `[header] data` or `registers`.

7. **Validate**: run `jtframe mra <core> --path /tmp` (docker if no local Go
   binary) and inspect the generated .mra: check region byte offsets against
   the `*_START` macros (values are BYTE addresses; `start=` macros too),
   interleave maps, dipsw defaults, and that every set of the driver came out.
   If the ROM zips are available, build the .rom and check total length ==
   `JTFRAME_PROM_START` + prom bytes.

## Gotchas

- `start=` macro values are byte offsets in download space; SDRAM bus
  `offset:` values in mem.yaml are 16-bit word offsets. Factor 2.
- `order` is mandatory when more than one region is listed; regions not in
  `order` are not downloaded.
- `[parse] sourcefile` must match the driver file name as MAME reports it
  (see the `sourcefile` attribute in mame.xml, path prefix not needed).
- proms regions: dump order = file order in mame.xml; if the core splits
  PROMs into separate BRAMs (`prom: true` entries in mem.yaml), their download
  order is the bram list order — keep both aligned.
- A dull MRA (no ROM node) is valid for ROM-less test cores: omit
  `[parse].sourcefile` and `[ROM]`.
