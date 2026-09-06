# jt05415x Verilog Implementation of the K054156/K054157 Pair

The K054156 and K054157 are a Konami tilemap generator pair. MAME models the
same family as `k054156_k054157_k056832`: K054156 is the common control/VRAM
side, while K054157 is the older rendering companion. The later K056832 is a
superset companion with higher color depth.

This module is being reconstructed from Furrtek's silicon reverse-engineered
schematics:

- `/nobackup/jtmisc/reverse/SiliconRE/Konami/054156`
- `/nobackup/jtmisc/reverse/SiliconRE/Konami/054157`

The converted and simplified source references are:

- `doc/054156/jt054156_all.v`: raw joined K054156 conversion.
- `doc/054156/jt054156.v`: simplified K054156 reference.
- `doc/054157/jt054157_all.v`: raw joined K054157 conversion.
- `doc/054157/jt054157.v`: simplified K054157 reference.
- `doc/mame/k054156_k054157_k056832.cpp`: MAME behavioral model.
- `doc/register_map.md`: CPU register mapping between MAME and the HDL.
- `cfg/mmr.yaml`: generated register-map description used by `hdl/jt05415x.v`.

MAME is useful as a behavioral guide, especially for layer/page concepts and
game-facing modes. The extracted HDL is the source of truth when MAME comments
and silicon-derived logic disagree.

## High-Level Function

The pair generates four tilemap layers, normally named A, B, C and D. Each
layer is built from VRAM pages rather than from one fixed rectangular memory
area. MAME describes each page as a 64x32 tilemap, or 512x256 pixels with 8x8
tiles. The four visible layers select rectangular groups of pages from a
conceptual 4x4 page grid.

The chip pair controls:

- CPU-visible tile RAM banking.
- Tile ROM readback/checksum addressing.
- Four scrollable tilemap layers.
- Per-layer page-grid origin and size.
- Per-layer X/Y scroll.
- Line scroll and row scroll.
- Global and per-layer flip controls.
- Tile attribute, palette, color, and tile-bank selection.
- VRAM address, data-bus, output-enable, and write-enable strobes.
- Video timing and IRQ/FIRQ/NMI generation.

The current HDL wrapper in `hdl/jt05415x.v` instantiates the generated MMR
blocks for the two CPU register banks, owns the CPU-visible VRAM window using
three 8-bit RAMs like the Moo Mesa schematic, and exports per-layer
`lyrf/lyra/lyrb/lyrc` tile requests after applying page layout, global
scroll, line scroll, row scroll, and global flip corrections. The graphics
fetch for each layer is expected to come from external SDRAM using those
per-layer address and chip-select outputs.

## K054156 Role

The K054156 is the control, CPU, timing, VRAM, and ROM-address side of the
pair. In the simplified HDL, `jt054156_connected` exposes the main hardware
boundary:

- CPU pins: address `AB[13:1]`, data `DB[15:0]`, read/write strobes, chip
  selects, and byte strobes.
- Video RAM pins: `VA[16:0]`, `VD[23:0]`, output enables, write enables, and
  chip selects.
- Tile ROM/checksum pins: `CA[18:0]`, `COL[7:0]`, and `VRC[1:0]`.
- Timing pins: dot clock, H/V sync, H/V blank, sub-clocks, and interrupt lines.

The HDL modules under `doc/054156/jt054156.v` split that behavior into CPU
front-end/register decode, horizontal/vertical timing, scroll arithmetic,
line-scroll control, VRAM address/control, DB/VD output muxes, and CA/COL/VRC
generation.

The first CPU register bank, 64 bytes wide, maps to the K054156. The generated
MMR names in `cfg/mmr.yaml` describe the effect of each register, such as
`glob_ctrl`, `flip_en`, `a_scry`, `a_scrx`, `lnscr_bank`, `cpu_bank`,
`rom_bank`, `tile_lut`, `hflip_corr`, and `vflip_corr`.

## K054157 Role

The K054157 is the older companion renderer. MAME treats the K054156/K054157
combination as supporting up to 5 bits per pixel, while K054156/K056832 can
reach 8 bpp.

The simplified K054157 HDL is organized around:

- CPU entry bits for the second 8-byte register bank.
- Clock fanout and internal counters.
- Horizontal-offset pipelines for the four layers.
- Color/attribute decode and output selection.
- RAM/readout paths and data-bus output muxing.

The second CPU register bank is not a full copy of K054156 registers `0x02`
through `0x07`, despite the older MAME comment. The HDL captures selected
low-byte bits only. Those bits currently control global H offset phase, clock
fanout, RAM/readout clock phase, per-layer H offset flip enables, RAM/DB output
muxes, readout direction, CROM decode, DB lane selection, and color source
selection.

## VRAM Organization

MAME models the family as having 4, 8, or 16 VRAM pages arranged within a 4x4
page grid. The simplified K054156 HDL validates the 4x4 logical grid used by
the video path, but it exposes it as address wiring rather than as a software
page table.

The hardware page address path is:

- `VA[10:0]`: intra-page address. Eleven bits are enough for 2048 entries,
  matching a 64x32 tile page.
- `VA[13:11]`: video page X field.
- `VA[16:14]`: video page Y field.
- `pagex[0]` and `pagey[0]` are forced to zero in the extracted equations.
  The effective video page coordinates are therefore `0, 2, 4, 6` in each
  direction, giving four X positions by four Y positions.
- `reg30_d` can replace the video page field for line-scroll/active-page
  access.
- `reg32_d` can replace the video page field for CPU-visible VRAM-bank access.

So the extracted HDL supports a 4x4 logical page grid for rendering and has six
external high address bits for bank/page selection. It does not, by itself,
show an explicit selectable 4/8/16 page-count mode; that remains MAME's
software-facing family model.

Layer layout is controlled per layer:

- `a_vgrid` through `d_vgrid`: vertical page-grid origin and height.
- `a_hgrid` through `d_hgrid`: horizontal page-grid origin and width.
- `a_scry` through `d_scry`: Y scroll.
- `a_scrx` through `d_scrx`: X scroll.

MAME's page association model gives ownership of each physical page to one
layer. The default association resolves overlaps by layer priority. Some games
depend on this to hide a lower-priority layer by assigning it a page already
claimed by another layer. This ownership policy is a MAME rendering model; the
HDL evidence found so far proves the page address generation, not a standalone
association table inside K054156.

## Tile Formats

MAME documents two tile RAM formats:

- 2 bytes per tile, with 0x1000-byte page banks. Attribute bits contain palette,
  X flip, a two-bit tile bank, and a 10-bit tile code.
- 4 bytes per tile, with 0x2000-byte page banks. Attribute and code are split
  across two words, with palette, X/Y flip, tile bank, and a larger code field.

The extracted HDL does not present this as a neat software structure. Instead,
the behavior appears through the K054156 VRAM address/source controls,
attribute/color lookup paths, VD latches, and K054157 color/readout logic. The
`attr_ctrl`, `irq_attr`, `addr_ctrl`, and `vram_ctrl` MMR fields are the main
configuration sources for these paths.

## Scroll Modes

Each layer has global X/Y scroll registers. The line-scroll control register
uses two bits per layer. MAME names the observed modes as:

- `0`: per-line line scroll. Each line gets its own horizontal scroll value.
- `2`: row scroll. One scroll value applies to a group of 8 lines.
- `3`: normal X/Y scroll. The layer uses the global X/Y scroll registers.
- `1`: unused or not fully understood in MAME.

MAME's line-scroll data comes from the line-scroll RAM bank. For 0x1000-byte
banks, each layer's data starts at `0x400 * layer`. For 0x2000-byte banks,
MAME uses `0x800 * layer + 2` and treats every other word as padding.

The simplified HDL supports the same broad behavior but exposes it through
lower-level signals: `lnscr_ctrl`, `lnscr_bank`, scroll capture, source muxes,
and the K054157 horizontal-offset pipeline.

## Flip and Correction

`glob_ctrl[4]` is global H flip and `glob_ctrl[5]` is global V flip. The
per-layer `flip_en` bitmap gates which layers respond to flip behavior. When a
global flip is active, K054156 also applies signed correction registers:

- `hflip_corr`: 12-bit horizontal correction for global H flip.
- `vflip_corr`: 11-bit vertical correction for global V flip.

MAME's newer comments match this interpretation, and the HDL routes these
registers into the scroll/timing arithmetic rather than treating them as
generic unknowns.

## Tile Banking and ROM Readback

`tile_lut` is a four-entry lookup table. Each entry is 4 bits selected by the
two tile-bank bits in tile data. MAME uses this to extend tile addressing and
also has a game-level `set_tile_bank` path for titles such as Asterix.

The CPU can also read tile ROM data for checksum or protection-style access.
MAME abstracts this as 0x2000-byte ROM banks and wraps the selected bank by the
actual graphics ROM size. It includes several game-specific readback layouts,
including 5 bpp, 6 bpp, 0x2000-byte, 0x4000-byte, and 0x8000-byte accessors.

The extracted K054156 hardware exposes:

- `rom_bank`: low ROM/checksum bank byte. Bit 0 feeds `CA11`; bits 1 through 7
  feed `CA12` through `CA18`.
- `rom_col`: output byte for `COL[7:0]` in ROM/checksum mode.
- `rom_vrc`: two secondary ROM/checksum bits on `VRC[1:0]`.
- `CA[18:0]`: the main external tile ROM/checksum address bus.

The direct pin budget therefore gives 19 CA bits plus 2 VRC bits for board-level
ROM selection. If a board decodes them as one contiguous byte address this is a
2 MiB address space, but the actual supported graphics ROM size is board
dependent. MAME's generic model instead computes the number of available banks
from the ROM region size divided by 0x2000.

One known MAME/HDL difference is register `0x36`: MAME describes four secondary
ROM-bank bits, while the extracted K054156 HDL captures only two `VRC` bits.

## CPU-Visible Windows

MAME describes four CPU-facing zones:

- 0x1000 or 0x2000 bytes of currently selected VRAM bank.
- 0x2000 bytes of read-only tile ROM/checksum window.
- 0x40 bytes of first register bank, mapped to K054156.
- 0x08 bytes of second register bank, mapped to K054157.

The current JT module starts from the two generated register banks. The full
VRAM and ROM windows still need to be implemented around the control wires
provided by `jt05415x.v`.

## Current Implementation Status

Implemented in source HDL:

- `hdl/jt05415x.v`: register banks, CPU-visible VRAM window, three byte-wide VRAMs, and per-layer scroll address generation.
- `hdl/jt054156_mmr.v`: generated from `cfg/mmr.yaml`.
- `hdl/jt054157_mmr.v`: generated from `cfg/mmr.yaml`.
- `cfg/files.yaml`: module file list and jtframe RAM dependencies.

Generate the ignored MMR RTL with `jtframe mmr --module jt05415x` before
linting or building a core that uses this module.

Documentation/reference HDL:

- The simplified HDL in `doc/054156/jt054156.v` and `doc/054157/jt054157.v`
  remains the reference for reconstructing the real chip logic.
- `doc/register_map.md` records the detailed CPU register interpretation and
  known MAME differences.

Next implementation work should build on the scan-side tile stream by adding
tile ROM fetch, K054157 color/readout behavior, palette/priority integration,
and ROM checksum/readback modes.
