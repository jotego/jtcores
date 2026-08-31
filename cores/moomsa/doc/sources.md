# Clean-room sources and provenance

## Primary PCB evidence

- `D:/Arcade/AI/aCORES/Moo/docs/moomesa/` — the user-supplied direct KiCad
  source capture of the real Moo Mesa PCB. The 14 `.kicad_sch` files are the
  active electrical source; `moomesa.kicad_pcb` is retained as an explicitly
  empty layout receipt.
- `cores/moomsa/tools/parse_moomesa_kicad.py` — deterministic, standard-library
  parser for the direct source. It records raw components, properties, pins,
  labels, buses, junctions, bus entries, sheet hierarchy and file hashes.
- `cores/moomsa/doc/moomesa-kicad-audit.json` — generated source receipt,
  validated with `--check`; see `cores/moomsa/HARDWARE.md` for the reviewable
  chip-by-chip matrix.
- `cores/moomsa/doc/pcb-chip-inventory.md` is retained as a historical ledger;
  the direct-source matrix in `HARDWARE.md` supersedes any older rendered-sheet
  wording or device identity in that file.

The previously retained rendered schematic artifact is not used as the active
PCB source for implementation decisions. It may remain for provenance and
historical comparison, but it cannot override the direct KiCad component,
pin, label or bus records.

- `D:/Arcade/AI/aCORES/Moo/docs/README_FIRST.txt`
- `D:/Arcade/AI/aCORES/Moo/docs/01_Official_Konami_Manual/`
- `D:/Arcade/AI/aCORES/Moo/docs/02_PCB_Photos_Repair_Logs/`
- `D:/Arcade/AI/aCORES/Moo/docs/06_Related_Same_PCB_Bucky_OHare_Manual/`
- `D:/Arcade/AI/aCORES/Moo/docs/07_SiliconRE_Real_Chip_Evidence/`
- `D:/Arcade/AI/aCORES/Moo/docs/08_Custom_Module_Physical_RE/`
- `D:/Arcade/AI/aCORES/Moo/docs/09_Manufacturer_Datasheets/`
- `D:/Arcade/AI/aCORES/Moo/docs/10_PLD_Dumps_and_Photos/`
- `D:/Arcade/AI/aCORES/Moo/docs/10_PLD_Dumps_and_Photos/PLD_Archive_Moo_Mesa_page_Wayback_20241011.html`
  identifies the board PLDs as E7 `054744` (GAL16V8, tested) and P6 `055373`
  (PAL20L10 family, untested; Porchy). The direct schematic's P6 marking is
  retained as PAL20RS10; the package-family discrepancy is unresolved.
- `D:/Arcade/AI/aCORES/Moo/docs/10_PLD_Dumps_and_Photos/PLD_Archive_055373_page_Wayback_20241011.html`
  is the device-index page for ID `055373`; it only links the Moo Mesa board.
- `D:/Arcade/AI/aCORES/Moo/docs/jed/Konami_055373.jed`, SHA-256
  `17B71DEA7134088749DA8427532291DB4AED42FA8AA1DC95D7071A01DC97093D`,
  is the locally supplied fuse artifact. Its CUPL header records device
  `g22v10`, `QF5892`, created 2015-09-27. MAME `jedutil -view GAL22V10`
  recovers ten combinational active-low equations. Those equations are used
  as **INFERRED board decode evidence** only after alignment with the direct
  schematic pin fanout; the artifact's bytes/header are **KNOWN**, while its
  exact match to populated P6 is not.
- `D:/Arcade/AI/aCORES/Moo/docs/10_PLD_Dumps_and_Photos/JAMMArcade_Moo_Mesa_PAL_dump_post.html`
  records that the `055373` PAL20L10 dump came from a non-working Moo Mesa PCB
  and was explicitly untested. This bounds the recovered equations' authority
  and prevents silently treating the conflicting PAL20RS10/PAL20L10/G22V10
  labels as one proved device identity.
- `D:/Arcade/AI/aCORES/Moo/docs/02_PCB_Photos_Repair_Logs/log2/repair_log_2.html`
  directly records the four 005273 and four-74LS257 Moo input path.
- `D:/Arcade/AI/aCORES/Moo/docs/06_Related_Same_PCB_Bucky_OHare_Manual/Konami_Bucky_OHare_Instruction_Manual.pdf`, p.18, is the supplied GX173
  comparative schematic; it is not treated as GX151 truth.

## Approved open-source infrastructure

## Silicon reverse-engineering evidence used at the tilemap boundary

- Furrtek/SiliconRE 054156 and 054157 evidence is pinned to commit `a5c1b3101ee00e71a157d9d86ad9f84fe512e2a`. The immutable upstream artifacts are the 054156 [README](https://github.com/furrtek/SiliconRE/blob/a5c1b3101ee00e71a157d9d86ad9f84fe512e2a/Konami/054156/README.md), [datapath diagram](https://github.com/furrtek/SiliconRE/blob/a5c1b3101ee00e71a157d9d86ad9f84fe512e2a/Konami/054156/054156_diagram.odg), [schematic](https://github.com/furrtek/SiliconRE/blob/a5c1b3101ee00e71a157d9d86ad9f84fe512e2a/Konami/054156/054156_schematic.pdf), [pinout](https://github.com/furrtek/SiliconRE/blob/a5c1b3101ee00e71a157d9d86ad9f84fe512e2a/Konami/054156/054156_pinout.ods), and the 054157 README.
- The local 054156 schematic PDF has SHA-256 `1887D0C78FF53F92E47D946CD6BEF60D34195701161D7FF9A1DC3E0819775C9E`, the datapath diagram has `BF51A7C67A89C2B0410AA4F29A88DA17937B0C4088C8EC161CE8667DE2B4C5FF`, and the pinout table has `B65CEC5CD9720C5B7B55340327EAD11438F8E767A354555B656215FD14723AB9`. These hashes bind the local evidence used by the tilemap review.
- The 054156 README supports the scroll-layer role, 3-byte or 2-byte tile storage, attribute selection, VRAM/line-scroll/page banking, and ROM-bank register roles. The diagram and pinout establish internal signal roles and widths, but they do not uniquely prove the Moo normal-mode tile-field permutation or fetch cadence.
- The 054157 notes are used with the direct Moo J1 continuity only at the external boundary. The physical silicon outputs are ACOL/BCOL/CCOL/DCOL; historical DFI/DSA/DSB strings are board-audit labels, not recovered internal nets. Source selection, ROM packing, page scheduling, and output latency remain open; no unverified internal permutation is promoted into RTL.

## JTFRAME maintainer process evidence

- `D:/Downloads/JTCORES_JTFRAME.pdf` — Jotego presentation dated 2024-04-06,
  14 pages, SHA-256
  `4E196D0816E04D095A82B3B9EE5E5905DB7BD15921AB6FE6EF45E0ECD5898D50`.
  It defines the four-stage Memory Design → Core Design → Simulation →
  Synthesis workflow, JTFRAME folder roles, `mem.yaml`/MRA generation,
  headless simulation/debug facilities, audio filtering guidance, and managed
  `jtcore`/`jtsim`/`jtframe`/`jtbin2mr` tooling. It is direct maintainer process
  evidence, not a source of Moo Mesa electrical behavior.

- Canonical jtcores/JTFRAME checkout pinned to
  `3278a82b948a91c23a8d2165a5ae545a6dae8994`.
- JTFRAME generator executable used for the current memory/source closure has
  SHA-256 `FE380FB9705552FFF3CC5F1ED290DA9042841BCC29F1190ECD678A2400D9BE56`.
- Generic JTFRAME CPU, memory, video, EEPROM, and audio infrastructure only
  after interface and license review.
- `modules/jtframe/bin/jtsim`, `modules/jtframe/bin/jtsim-funcs`, and
  `modules/jtframe/doc/sim.md` are the pinned JTFRAME simulation workflow;
  `tools/jtsim_smoke.ps1` and `tools/jtframe` are local path-normalizing
  adapters only and do not alter the vendored model.
- `modules/fx68k` at `1217ab8dc600de070c6adb71ea6fe69de8855362` (GPL-3.0),
  origin `https://github.com/jtfpga/fx68k`, supplies the only accepted main-CPU
  implementation. `jtmoomsa_fx68k.v` fixes selection to that untouched source;
  `tools/validate_fx68k_contract.py` enforces origin, gitlink, commit, clean
  state, source inventory and the absence of an alternate Moo CPU path.
- `modules/jt51` at `985a573dcfc1ff135553a39f7eae21d18ba57cbe` (GPL-3.0)
  supplies the YM2151 implementation used by the isolated sound boundary.
- `modules/jteeprom` at `9c68ce841f4ec560ca6f228c8af6301129fd95fa` supplies
  the `jt5911` EEPROM state machine behind the sheet-7 serial latch boundary.
  `modules/jt8255` at `3bb5f7ea461fc7d72b847ec55ce997e5d5bc1754` remains
  available for later board-map closure.
- `jtcolmix_053251.v` and related device modules are donors, not physical
  truth; each must pass a Moo-specific contract review.
- `jtcolmix_053251.v` is imported from the pinned `cores/simson/hdl` path and
  remains behind `jtmoomsa_colmix.v`; its K053251 contract is cross-checked
  against the supplied 053251 SiliconRE schematic and register evidence.
- The graphics boundary imports `jtxmen_video.v`, `jtxmen_colmix.v`,
  `jtsimson_obj.v`, `jt053246.sv`, `jt053246_scan.sv`, and
  `jtframe_8x8x4_packed_msb.v` from that same immutable checkout. Their
  retained GPL-3.0-or-later headers and donor paths are the provenance; they
  are structural references, not Moo-specific hardware truth.
- `cores/xmen/sch/moomesa/` is a historical comparative KiCad board
  reconstruction only. The direct KiCad capture above is the active board
  source and supersedes it; the comparative tree cannot justify a new Moo
  connectivity or timing claim.
- `cores/riders/pal/xmen/054744.txt` is the pinned tested Konami 054744 PAL
  equation donor for the shared sound-family select terms. Its `/BANK` term
  is used with the Moo E7 `~SBANK_WR` net; bank/NMI implementation remains
  isolated from the unproven PCM/sample behavior.
- `cores/riders/hdl/jt054321.v` is the pinned JTCORE K054321 main/sound latch
  bridge at checkout `3278a82b948a91c23a8d2165a5ae545a6dae8994`, retained
  under its GPL-3.0-or-later header. Its Moo wrapper is
  limited to the direct sheet-10 `PAIR~CS`, `SDON`, `SND_A[1:0]`, and Z80 bus
  boundary; Moo K054986A select and wait timing remain unproven.
- `cores/rungun/doc/053252.v` and `74163.v` are the pinned Jotego/furrtek
  silicon-traced K053252 donor sources used only in the isolated
  `053252-donor-characterization.md` bench. Their counter, comparator, delay,
  and interrupt equations are checked against the supplied 053252 SiliconRE
  README/schematic before any Moo integration; current Moo clock/SEL phase is
  not assumed.
- `docs/07_SiliconRE_Real_Chip_Evidence/054156/054156_schematic.pdf` and
  `054156_pinout.ods` define the isolated K054156 CPU/register boundary and
  traced register fields. No donor fetch behavior is promoted from this source.
- `docs/07_SiliconRE_Real_Chip_Evidence/054539/054539_steps.ods` is the source
  for the one-clock ROMA address/data latency used by the PCM request shell.
- The direct `D:/Arcade/AI/aCORES/Moo/docs/moomesa/rgb.kicad_sch` and
  `io_cabinet.kicad_sch` are the active palette/DIP/input evidence. The pinned
  comparative checkout is not used to override them and is not copied from
  the excluded AI-derived core.

Sheet 7 directly ties Q4 `MAIN_D[5:0]` to the ER5911 serial control nets:
Q0/Q1/Q2 reach `DI/CS/CLK`, Q3 reaches K051550 `SI`, and Q5 reaches
`IRQ_SET`; J7B forms its clock as `~LDS | ~REG_WRITE`. The direct source ties
ER5911 `ORG` to `VSS`. 16A1 `EVQQ5911` is a separate four-pin passive switch,
not an EEPROM organization input. The edge-qualified wrapper preserves the
proven serial boundary; switch use, EEPROM persistence and exact phase remain
open.

Sheet 5 directly ties C7 74LS157 inputs `SND_A14`/VSS and `SBANK[3:0]` to
select `SND_A15`, with its four outputs feeding the sound-ROM address path.
`jtmoomsa_sound_bank_mux.v` is the single live RTL owner of that truth table;
the exact downstream socket continuity remains separately tracked.

## Prohibited sources

- The currently available AI-derived Moo Mesa core and every fork or derivative.
- Any MAME source, MAME-derived behavioral model, MAME trace, expected value,
  or metadata. ROM packaging uses the checked-in socket manifest and supplied
  archive hashes instead.
- The `jlrh/konami-fpga` Moo Mesa implementation and any code validated from it.

Every imported source must retain its immutable commit, license, and wrapper
record before it can move beyond `planned`.
