# Moo Mesa JTFRAME core

Target: MiSTer DE10-Nano arcade framework for the Moo Mesa/Wild West C.O.W.-Boys
GX151 PCB. The board profile remains under evidence-backed implementation.

The primary PCB source is the direct KiCad capture at
`D:\Arcade\AI\aCORES\Moo\docs\moomesa`. It is parsed by
[`tools/parse_moomesa_kicad.py`](tools/parse_moomesa_kicad.py); the resulting
source receipt and chip-by-chip disposition are in
[`HARDWARE.md`](HARDWARE.md). Rendered schematic documents are not used as
the active electrical source.

The project follows Jotego's four-stage JTFRAME process (memory design, core
design, simulation, synthesis); the captured process record is in
[`doc/jtframe-design-process.md`](doc/jtframe-design-process.md).

## Features in the OSD

The core exposes the JTFRAME test/status path, stereo output plumbing, two
documented action buttons per player (`Shoot` and `Jump`), cabinet input lanes,
and deterministic reset. The third JTFRAME action slot is unused for Moo Mesa.

Video output is wired to the standard JTFRAME MiSTer boundary: native
384x224/59.185606 Hz timing, direct-video selection for a compatible 15 kHz
DAC/CRT, processed HDMI output for normal displays, and the DB15 analog VGA
path with framework scan-doubler/scanline controls. See the
[`video-output-contract.md`](doc/video-output-contract.md) audit. A fresh
managed Quartus build has produced a local release-candidate RBF, but no
real-MiSTer display capture has been completed. The 128-byte EEPROM has a byte-addressed
JTFRAME load/dump/save transport, and the save-focused lifecycle bench covers
full load, reread, lane, bounds, soft-reset retention and reload behavior. It
does not exercise the game CPU's actual hi-score writes and rereads, so full
hi-score persistence is not yet claimed. Factory/default contents and
physical-device validation remain open. The generated MRA names the available
`Start`, `Coin`, `Test`, and `Service` controls.

## PCB Accuracy

| Area | Status | Evidence |
|---|---|---|
| Board population and clocks | documented | Direct KiCad sheets and source receipt in [`HARDWARE.md`](HARDWARE.md); the PCB layout file is explicitly empty |
| Main bus and decoder population | documented | `main.kicad_sch`: MC68000, 053990, PAL20RS10, 74LS138/148/174/74xx, RAM, ROM lanes, strobes and DTACK network |
| 2/3/4-player input wiring | documented | `io_cabinet.kicad_sch`: 005273 arrays, 74LS257 muxes, Q4 latch, connector and EEPROM nets |
| Tile/object chip population and buses | documented | `objects.kicad_sch` and `scroll.kicad_sch`: 053246/053247, 054156/054157, `065A08` ROMs, VRAM and 32-bit graphics buses |
| Sound chip population and signal chain | documented | `sound.kicad_sch` and `054986A.kicad_sch`: Z80, YM2151, 054539, 054321, 054986A, AD1868R and LA4705 |
| Colour pipeline population | documented | `053252.kicad_sch` and `rgb.kicad_sch`: 053251, 053252, 054338, palette SRAM and RGB outputs |
| K053251/K054338/K053252/K054539 behaviour | partial boundaries | Direct KiCad population plus separately identified silicon/reference evidence; exact live phase remains open |

This table deliberately omits unverified timing, protection, tile, sprite,
PAL, and analog claims.

## Supported games

The ROM manifest covers the four original GX151 profiles: `moo`, `moomesaaab`,
`moomesauab`, and `moomesauac`, corresponding to MAME sets `moomesa`,
`moomesaaab`, `moomesauab`, and `moomesauac`. The bootleg profile is
intentionally excluded because its PCB evidence is not in scope.

The MRA control contract is `Shoot`, `Jump`, `Start`, `Coin`, `Test`, and
`Service`. The action labels follow the Moo Mesa panel/manual terminology; the
raw positions and active-low behavior remain tied to the pinned MAME input
macro and the live cabinet-mux RTL.

These are four packaging profiles, not a claim that every gameplay path is
complete; actual game hi-score writes/rereads remain an explicit verification
gap. Each clone MRA uses the project's pinned parent-first archive assembly
contract (`parent.zip|clone.zip`) for merged and non-merged inputs. The
generator and validator reject any other archive ordering.

## Hardware emulated

| Device/subsystem | Interface | State |
|---|---|---|
| MC68000 main CPU | GX151 main bus | JTFRAME fx68k ROM bus/wait shell; sheet-2 M6B/L6B decode plus G7 BDS primitive in `jtmoomsa_main_decode.v`; PAL data mux pending |
| Z80 + YM2151 | 18.432 MHz sound domain | JTFRAME/JT51 boundary with tested 054744 selects, 4-bit 27C020 bank register, and direct active-low FM-IRQ/NMI-clear latch semantics; E7 equations and final FM mix remain open |
| K054156/K054157 | tile VRAM and tile ROM | Live `jtmoomsa_tilemap.v` owner under `jtmoomsa_video`, based on the direct G4/J1 `scroll.kicad_sch` boundary and existing JTFRAME tilemap clients; the externally proven J1 groups are mapped as F=9, A=7 connected, B=8 bits at the K1 boundary, while K054157 internal packing/fetch latency, VRAM bank/page semantics and P6 timing remain pending |
| K053246/K053247 | object RAM and graphics ROM | JTFRAME/JTCORE structural donor boundary; direct `objects.kicad_sch` ROM/latch wiring, board DMA timing pending |
| K053251 | priority/palette index | Moo-local mapper preserves direct CI0=object, CI1=ground, CI2=9-bit F, CI3=7 connected-bit A plus explicit zero padding, and CI4=8-bit B into the JTCORE primitive; fourth renderer fetch/storage remains internal because K1 has no proven colour consumer for it |
| K054338 | palette/color math | SiliconRE register/mix shell with Reg15 delay/clamp controls; three-bank HM6116 palette boundary isolated |
| K053252 | programmable raster/interrupt; 32 MHz input, 8 MHz equivalent raster cadence | Standard-register shell with direct `32CLK`/`cen_32` boundary, 512x264 total, 384x224 active, and 59.185606 Hz declared timing; exact silicon edge phase remains open |
| K054539 | 18.432 MHz PCM state shell | physical cadence, key/control/address ports, `{REG22E[3:0],ADDRCNT[16:0]}` boundary, and C5 POST-RAM transport; EOF/mixer pending |
| K051550 | system timer/watchdog/coin-counter pins | populated G3 `K051550_CLK`/`~RESET`/`K51550_SI`/`CNT1/2` continuity documented; exact timeout, reset, counter and phase behavior blocked |
| K053990 | main-bus arbitration/protection | direct N4 bus boundary plus active-low lane register shell in `hdl/jtmoomsa_053990_regs.v`; DMA/protection behavior remains open |
| ER5911/EVQQ5911/005273/74LS257 | 128x8 EEPROM, cabinet inputs and save transport | Direct sheet-7 population and mux boundary; save-focused JTFRAME lifecycle transport bench passes; actual game hi-score writes/rereads, DIP/EEPROM CPU-map and factory-seed validation remain open |

## Credits

JTFRAME and reusable infrastructure are from the pinned canonical jtcores
checkout. All board claims come from the direct KiCad source and the evidence
ledger in `doc/sources.md`. Imported source notices remain with each donor
wrapper. The action labels are cross-checked against the
[Moo Mesa arcade manual](https://arcarc.xmission.com/PDF_Arcade_Manuals_and_Schematics/Cowboys%20of%20Moo%20Mesa.pdf);
raw input positions remain pinned to MAME `moo.cpp`/`konamipt.h` and the live
cabinet-mux RTL. The MRA format and output-mode behavior follow the official
[MiSTer MRA documentation](https://github.com/MiSTer-devel/Wiki_MiSTer/wiki/Arcade-Roms-and-MRA-files)
and [Direct Video documentation](https://github.com/MiSTer-devel/Wiki_MiSTer/wiki/Direct-Video).
No copyrighted ROM or factory NVRAM image is included in this repository.

## License

The core is GPL-3.0-or-later.  JTFRAME, CPU, and donor modules retain their
upstream license headers and provenance records.

## How to install

Place the accepted RBF and matching MRA files in `/media/fat/_Arcade/` (or the
equivalent MiSTer release folder). Automatic installation uses:

```ini
[meathax/meatcores]
db_url = https://raw.githubusercontent.com/meathax/meatcores/db/downloader_meathax_meatcores.zip
```

After adding the entry, run **Update All**. The local release-candidate RBF is
[`releases/Arcade-jtmoomsa_20260830.rbf`](releases/Arcade-jtmoomsa_20260830.rbf).
The canonical EAB MRA is in [`releases/`](releases/); AAB, UAB, and UAC
alternatives are under [`releases/_alternatives/moomesa/`](releases/_alternatives/moomesa/).
Regenerate and validate them with [`tools/generate_mra.py`](tools/generate_mra.py)
and [`tools/validate_mra.py`](tools/validate_mra.py). Real-MiSTer video/audio
and input validation remains open.
