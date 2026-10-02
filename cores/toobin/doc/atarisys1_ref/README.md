# Atari System 1 VHDL — REFERENCE ONLY (do not synthesize / do not copy verbatim)

Source: https://github.com/MiSTer-devel/Arcade-Atari-system1_MiSTer (branch `main`)
Author: **d18c7db**. License: **GPL-3**. Reconstructed from Atari schematics
(SP-276 Marble Madness, SP-277, SP-280, SP-286, SP-298) — chip-level, real custom part numbers.

**Why it's here:** System 1 is not Toobin' (Toobin' is a System-2-class board), but they share the
Atari video lineage — motion-object engine, tilemaps, palette and sync chain. These files are kept
as a **behavioral reference / cross-check** alongside the MAME driver and the Toobin' schematics
(`../Toobin.pdf`). Our implementation is **clean-room Verilog in `cores/toobin/hdl/`**, written from
the Toobin' schematics (source of truth) with these used only to understand the customs. Do NOT
vendor any of this VHDL into `hdl/` or carry it into the build — it's a third party's GPL-3 work.

## File → Toobin' subsystem it informs

| file | Atari custom / sheet | use for |
|---|---|---|
| `GPC.vhd` | 137419-101, SP-277 | **graphics priority** — the merge MAME marks "not verified (PAL)" |
| `SYNGEN.vhd` | 137419-103, SP-277 | clock/sync chain, H-counter timing diagram → jtframe_vtimer params |
| `MOHLB_LSI.vhd` / `MOHLB_TTL.vhd` | SP-286 sheet 7 | **motion-object horizontal line buffer** (sprite line buffer) |
| `SLAGS.vhd` | 137415-101, SP-276 | graphics shifter (tile/sprite pixel serializer) |
| `PFHS.vhd` | 137419-104, SP-277 | playfield horizontal scroll |
| `RGBI.vhd` | — | palette `Intensity*Color/16` (Toobin' brightness bit15 + intensity reg) |
| `LINEBUF.vhd` / `LINECTR.vhd` | — | line-buffer + line-counter glue around MOHLB |
| `CRAMS.vhd` / `VRAMS.vhd` | — | color-RAM / video-RAM organization |
| `LS299.vhd` | 74LS299 | shift register in the gfx serial path |
| `VIDEO.vhd` / `ATARISYS1.vhd` / `MAIN.vhd` | tops | how the customs wire together; main-board address decode |
| `leta_rep.vhd` / `quad.vhd` | LETA (JROK, freeware) | roller/paddle **quadrature** decode → Toobin' FF8800 paddle bits |
| `POKEY.vhd` / `m6522.vhd` | — | POKEY (JSA-I) + 6522 comm reference |
| `SLAPSTIC.vhd` | 137412-xxx | DEAD REFERENCE — Toobin's `SLAPSTK4` is **not stuffed** (no banking); kept only for the chip family. See `../SCHEMATIC_DECODE.md` §5 |

**Not copied (irrelevant to Toobin'):** CART (cartridge
board), TMS5220 (Toobin' JSA-I has it removed), T65/TG68K CPU cores (jtframe has its own), the
MiSTer `sys/` framework, PLLs, SDRAM models.
