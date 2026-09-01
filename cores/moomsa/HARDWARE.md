# Moo Mesa GX151 hardware audit
This is the active hardware audit for the JTFRAME core. The source of truth
for PCB population and connectivity is the KiCad source tree at
`D:\Arcade\AI\aCORES\Moo\docs\moomesa`. Rendered documents are not used as
the electrical source for this audit.

The audit is generated from the source files by
[`tools/parse_moomesa_kicad.py`](tools/parse_moomesa_kicad.py). The checked
receipt is [`doc/moomesa-kicad-audit.json`](doc/moomesa-kicad-audit.json).
The parser preserves sheet-local pins, labels, buses, junctions and
bus-entry geometry. It deliberately does not pretend that an empty PCB file
or an unresolved PAL equation proves behaviour.
The literal component-reference coverage check is recorded in
[doc/component-matrix-coverage-20260824.txt](doc/component-matrix-coverage-20260824.txt).
It is an index aid, not component-record or implementation closure: duplicate
references across sheets/values and live RTL consumption require separate audit.

Current N4 update (2026-08-25): the direct 053990 CPU register boundary is now
represented by `hdl/jtmoomsa_053990_regs.v` behind the existing M6B
`OBJ_REG_SEL` timing select. This is a partial register/lane/reset/readback
boundary; protection/DMA transform, arbitration, `/DTACK`, `/IPL0` and reset
phase remain open. See
[`doc/k053990-register-boundary-20260825.txt`](doc/k053990-register-boundary-20260825.txt).

## K053246 object-DMA trigger boundary — 2026-08-26

**KNOWN:** the direct F10/J10 source names the OBJDMA boundary, and the
Moo-local object wrapper reaches it from the established K053246 DMA block.
The pinned MAME startup trace records the short K053246 enable transition
`0x30 -> 0x00`.

**INFERRED:** the Moo board requires the established edge-trigger mode for
this short enable pulse. `jtmoomsa_obj` therefore selects
`jt053246_dma #(.EDGE_TRIGGER(1))`; this is an FPGA-native behavioral choice
consistent with the Jotego abstraction rule, not a literal reconstruction of
the PCB PAL/high-impedance implementation.

The edge-pulse bench fails with the default trigger and passes with the
Moo-local edge-trigger selection. The current full-top diagnostic replay also
shows a bounded DMA busy/write interval with balanced memory responses. The
exact PCB trigger equation, P6 ownership, arbitration and raster cadence
remain open; see
[`doc/object-dma-edge-trigger-20260826.txt`](doc/object-dma-edge-trigger-20260826.txt).

The pinned MAME source provides a lower-tier supplemental operation for this
window: a write to offset 0x0c triggers word reads from programmed source
addresses, computes src1_word + 2*src2_word, writes the destination and
advances all three addresses. This behavior is not yet promoted to production
RTL because the direct source does not expose the internal operation cadence,
bus grant/ready ordering or interrupt ownership. The bench-only probe attempt
timed out before returning an accepted N4 access trace; see
doc/mame-protection-probe-20260825.txt.

## Control2 / REG_WRITE boundary — 2026-08-25

**KNOWN:** direct KiCad decode labels L6B O7 `REG_WRITE`; G7 is the populated
74LS08 BDS stage. The same source
connects that strobe into the Q4/N6 control fanout. The pinned local MAME map
uses the corresponding `0x0DE000..0x0DE001` word window as `control2_r/w` and
keeps `0x0CE000..0x0CE01F` separate for K053990 protection.

**PARTIAL:** the isolated CPU diagnostic reaches and accepts the two early
control2 writes, but production ownership remains distributed across the
schematic REG_WRITE/Q4/N6/EEPROM/K051550/IRQ paths. No standalone generic
control2 register is claimed, and the P6 `PRE_~DTACK` equation, readback
semantics, side-effect ownership and interrupt cadence remain open. See
[`doc/control2-boot-diagnostic-20260825.txt`](doc/control2-boot-diagnostic-20260825.txt).

## K053252 reset contract — 2026-08-25

**KNOWN:** direct KiCad proves the populated L4 K053252, `32CLK`, CPU data and
address boundary, fixed `SEL=000` ties and direct `INT1` route. **INFERRED:**
the reset register contents are `REG0=0x03`, `REG4=0x01`, and `REG8=0x01`
from the established reverse-engineered device model. The KiCad source does
not encode those internal reset bytes, and the pinned MAME software reset is
not treated as physical truth here. Exact PCB power-on contents/release phase
remain open. Evidence is recorded in
[`doc/k053252-reset-reconciliation-20260825.txt`](doc/k053252-reset-reconciliation-20260825.txt).

Evidence labels are strict:

- **KNOWN** — directly present in the KiCad source or in the current RTL.
- **INFERRED** — a structural reuse or cross-source interpretation that still
  needs Moo-specific phase, packing or runtime evidence.
- **HYPOTHESIS** — a testable possibility, not an implementation contract.

## Current live tile and colour disposition — 2026-08-28

Direct K1 CI ownership was corrected in this iteration: `CI2=FCOLR/FPAL`
receives the renderer F stream, `CI3=ACOL/APAL` receives A, and
`CI4=BCOL/BPAL` receives B. CI0 remains the isolated object boundary and CI1
is grounded as shown on the direct sheet. The fourth renderer fetch/storage
stream remains internal for cadence but is no longer exposed as a live K1
colour input. SiliconRE identifies the physical K054157 output fields as
ACOL/BCOL/CCOL/DCOL; older DFI/DSA/DSB strings are retained only as
board-audit labels, not internal field names. Focused result:
[`doc/k053251-map-regression-20260825.txt`](doc/k053251-map-regression-20260825.txt).

| Hardware block | Direct-source / reference evidence | Current RTL disposition | Verification | Remaining limitation |
|---|---|---|---|---|
| K056832 CPU windows | **KNOWN:** direct main-bus window contract is recorded in `hdl/jtmoomsa_k056832_windows.v`; **INFERRED:** exact Moo map is cross-checked against pinned MAME 0.289 | Live Moo-local register, B-window, VRAM and tile-ROM window owner; the layer-mode field uses packed index `5'h04`/device byte offset `0x08`, and reset defaults the supported tile path to `4'hf` | Current focused Icarus control/live benches and generated game-select closure; historical strict focused lint predates the reset correction, whose current rerun is ACL-blocked | PAL-qualified aliases and exact board DTACK/reset phase remain open |
| K056832 VRAM | **KNOWN:** direct scroll sheet exposes the 16-bit CPU boundary and VRAM address/control nets; **INFERRED:** byte-wide FPGA banks preserve the two lane contract | Two `jtframe_dual_ram` byte banks with registered renderer/CPU reads and explicit one-cycle completion | `tb_k056832`, `tb_k056832_live`, strict full-game lint | Physical RAM bank/page arbitration and reset/read-during-write behavior remain to be compared |
| L10/N10/M10 scroll SRAM | **KNOWN:** direct KiCad `scroll.kicad_sch` proves `SCRAMA[12..0]`, `VD[7..0]`, `VD[15..8]`, `VD[23..16]`, and independent active-low `RWE1..3`/`ROE1..3` controls | Isolated `jtmoomsa_scroll_vram_lanes` preserves all three byte lanes and uses an explicit FPGA owner: inactive lanes drive zero rather than high impedance | `tb_scroll_vram_lanes`; strict one-thread headless Verilator lint; receipt `doc/scroll-vram-lanes-abstraction-20260825.txt` | Not yet the live K054156/K054157 owner; CPU mapping, bank/page selection, arbitration, read-during-write and fetch phase remain open |
| K056832 tile renderer | **KNOWN:** direct MAME `charlayout4` x offsets and project MRA interleave establish the tile-row nibble positions; **INFERRED:** Moo-local owner/fetch cadence | Four-layer fetch/storage cadence with three live K1-facing pixel streams, Moo offsets `{-1,3,5,7}`, direct charlayout4 nibble decoder, line buffers and held `rom_ok` requests; the fourth stream is intentionally not exposed because direct K1 CI1 is VSS | `tb_k056832_tile_decode`, `tb_k056832_live` and reset assertion pass; tainted real-bank replay completes two frames with `errors=0` and exact tile request/response counts | `rgb_nonzero=0` and object requests remain zero; exact K054156/K054157 fetch phase, line-map/line-scroll/page-height semantics, raster phase and real frame pixels remain open; receipt `doc/k056832-charlayout4-fix-20260825.txt` |
| K053246/K053247 objects | **KNOWN:** direct F10/J10 sheets prove the CPU bus, `~REG`, `CR~CS`, `~UDS/~LDS`, object ROM/latch/buffer/SRAM scalar lanes and OBJDMA boundary; F7/F6/F9/E9 prove the physical RAM address order; M6B O3/O4 object selects are no-connects. **INFERRED:** pinned MAME maps the sprite-RAM CPU window at `0x190000-0x19ffff`; established JTCORE scan/DMA/draw behavior is reused behind a Moo-local wrapper; the short observed enable pulse selects the established edge-trigger DMA mode | `jtmoomsa_053246_regs` preserves the CPU-visible four-word register boundary; M6B O2 `CR~CS` reaches the object-system read boundary; `jtmoomsa_objram_addr_map` plus one `jtmoomsa_objram_cpu` owner preserve the direct RAM permutation and qualified byte-lane CPU path; `jtmoomsa_obj` supplies a partial live DMA/scan/draw path to K1 CI0/OCOL with `.EDGE_TRIGGER(1)` | `tb_053246_regs`, `tb_game_crtc_select`, `tb_main_decode`, `tb_objram_cpu`, `tb_moomsa_obj`, `tb_moomsa_obj_dma_edge`, object/RGB boundary, address-width and exhaustive 13-bit RAM-map benches pass; current 1.3M-cycle full-top replay shows DMA busy/write completion and balanced responses with `errors=0`; canonical guarded/full-graphics smoke pass | Exact PCB trigger equation/P6 `ORAM~WE`/`~EDE`, CPU mirrors, DMA ownership/cadence/arbitration, object-ROM `OBJCHA`/lane/latch/packing/ready phase, K1 `OPRI`/`SHD` priority/shadow path and real sprite pixels remain unresolved |
| K053251/K054338 colour path | **KNOWN:** K1 CI0=`OCOL`, CI1=`VSS`, CI2=`FCOLR/FPAL`, CI3=`ACOL/APAL`, CI4=`BCOL/BPAL`; K1/J1/G8/G9/H8/H9/L5/K5/K054338/palette SRAM continuity is parser-asserted. SiliconRE separately identifies K054157 physical outputs as ACOL/BCOL/CCOL/DCOL; internal source and board-group selection remain open | `jtmoomsa_k053251_map` preserves the direct CI group order; the K053251 primitive, three palette RAM lanes and board-mode K054338 form one behavioral FPGA boundary. The renderer’s fourth fetch/storage stream is not a K1 input. Plane 0 uses the MAME-supplemented `0x70` base at the palette address boundary | `tb_k053251_map`, post-cleanup live K056832, board/bridge checks and generated smoke | Exact K1 field packing/phase, OPRI/object producer, CRAM~CS, MIX1/BRI1, priority contents and analog DAC behavior remain open |
| K053252/raster | **KNOWN:** direct CPU/clock/INT1 boundary is parser-asserted; **INFERRED:** SiliconRE `SEL=000` `/4` cadence, MAME Moo porch/offset interpretation and device reset defaults `REG0=03`, `REG4=01`, `REG8=01` | Standard-register FPGA-native shell is live at the CPU/IRQ boundary on `cen_32`; reset applies the reconciled device defaults and the programmed CRTC supplies the K056 renderer’s sync/blanking/counter handoff | `tb_053252` exact Moo vector; programmed-CRTC `tb_k056832_live` (`cycle=49396`, `tile_reads=6447`); parser; receipt `doc/k053252-reset-reconciliation-20260825.txt` | Exact PCB reset release phase, K053252 edge phase, `CLK3` use, K054156 latch phase and downstream analog blanking remain open |
| P6 PAL20RS10 / decode gates | **KNOWN:** direct pin continuity and named fanout are parser-asserted; **UNKNOWN:** equations | `pale` is not guessed into the live decode; unresolved outputs are not promoted | P6 continuity/gate benches | RAMCS/PALE/DTACK/ORAM~WE aliases and high-address qualification require equations or traces |

The FPGA implementation follows the project Jotego abstraction rule: these
blocks are modeled at their observable bus/video boundary, not as a literal
74LS netlist with high-impedance replication. This table therefore distinguishes
direct populated-device evidence from inferred implementation scaffolding.

## Source receipt

Parser command:

```text
python cores/moomsa/tools/parse_moomesa_kicad.py --source-root ../docs/moomesa --output cores/moomsa/doc/moomesa-kicad-audit.json --check
```

The source tree contains 14 schematic sheets and an intentionally empty
79-byte `moomesa.kicad_pcb` layout file. The parser found 206 component
records (185 non-power), 3,430 pins, 2,931 labels and two unresolved
label-anchor nodes in `main.kicad_sch`. Duplicate references are retained
because KiCad multi-units and standalone sheets are evidence records, not a
flattened BOM. The parser's direct geometry checks also prove the Q5 main-ROM
address fanout and the identity 16-bit T8/T10 graphics data lanes; no bit
swizzle is inferred at this boundary. The same checks now cover the direct P6
PAL20RS10 pin boundary without asserting its equations, the K053252
L4 AB/DB/clock/select/INT1 boundary, the K054156 G4 A/D/RA buses and labeled
clock/reset terms, all four proven CPU input 74LS257 maps, the populated object
ROM/latch/buffer/SRAM glue, the three RGB palette SRAM lanes, and the selected
C14/D13/E7/E4/G3/U2 sound boundaries. The separate O4/R4 control function
remains unlabeled and open. The sound checks preserve E4's direct A0..A7/A9
address labels and both 18CLK/1.54CLK fanouts without inferring its unlabeled
A8 boundary. Object/DMA, K054157 and K054338 internal timing remains open.
The current receipt is schema v4 and includes 285 direct KiCad
`no_connect` markers. Its fail-closed M6B assertion checks the direct O3/O4
no-connect coordinates as well as the O0/O1/O2/O5/O6/O7 pin nets; this is the
authority for the decoder correction recorded below.


| Sheet | SHA-256 | Components | Pins | Labels | Buses | Junctions | Bus entries |
|---|---|---:|---:|---:|---:|---:|---:|
| `053252.kicad_sch` | `b3efed545d78d34ca32417e7d5be31504df409321b16b958ee1b3e3d0c589b25` | 25 | 343 | 250 | 165 | 25 | 167 |
| `054986A.kicad_sch` | `8f597347ab56fcea1b1666a8998a9f6efcbfa83ebfb8623353c809df920c8382` | 6 | 191 | 132 | 16 | 9 | 16 |
| `capacitors.kicad_sch` | `69397ccfe2e7fc3142d0c132344e74eb61bf9265e9760f35408fcf831f04ff44` | 16 | 32 | 2 | 0 | 30 | 0 |
| `colmix.kicad_sch` | `04f642d6896603bf5bf8532ee2d72d2555402f889d6e28f65393543478d3c2e4` | 0 | 0 | 30 | 19 | 0 | 0 |
| `io_cabinet.kicad_sch` | `6d521ac157c276a1028d967be34e3d4793829a62f4ec6702ad3db196570ee9be` | 28 | 226 | 168 | 25 | 7 | 31 |
| `main.kicad_sch` | `e7296a250aeef1efde5281aa862b4bc128ee1fd97ad1badf82f374bdb1f379d5` | 56 | 662 | 431 | 241 | 42 | 278 |
| `moomesa.kicad_sch` | `5cb26f5aca2a4a1fa1936aec6c77b431a41e8c41f42d66b62c2d3ca4db4934da` | 9 | 86 | 240 | 43 | 0 | 0 |
| `not_populated.kicad_sch` | `40ebe92de081b139299b62f0a55399153d37346cb0ef80f0c9d0fac7c1d2eb75` | 5 | 200 | 100 | 79 | 2 | 69 |
| `objects.kicad_sch` | `ec076a56c8ed8c462c976bcf81a23f80b0cc48290726c509539a191445794ef6` | 23 | 683 | 602 | 511 | 43 | 572 |
| `pcm.kicad_sch` | `1ebf1827cc12826fd896c4b3e62bfba0770e7a3f0a695e1c1272b33f3f96e52d` | 0 | 0 | 0 | 0 | 0 | 0 |
| `rgb.kicad_sch` | `1bb704d2961cacaf516d94ef0c901e5b0bd477fd8377aa9dc669a832a855d9f1` | 8 | 77 | 266 | 207 | 24 | 198 |
| `scroll.kicad_sch` | `1b327c1f9b7379fe67c390e594039f63625934a7a2efd2f6154ec8d3e36e5119` | 9 | 490 | 394 | 324 | 55 | 316 |
| `sound.kicad_sch` | `205d5dfd73144fb42ece479e0b1778475327f614cd2954641ab3112ea42842b1` | 20 | 439 | 303 | 185 | 42 | 190 |
| `untitled.kicad_sch` | `4e39ee24955214ea0f3d7993d5dddbb0872291048cbd826b254747e4a145f446` | 1 | 1 | 13 | 0 | 0 | 0 |

PCB receipt: KiCad `20240108`, generator `pcbnew`, SHA-256
`0eca9549fd8d33c355e253ce7c1f265df09087f1861bfa15f8617040e2eb116a`, with
zero footprints, tracks, vias, zones and nets. This is an **empty layout
source**, not evidence that the schematic nets are unpopulated.

## Direct-source correction record

The scroll-sheet G4 `054156` address boundary is `MAIN_A[13..1]`. The
isolated control wrapper and its testbench now expose `[13:1]`; the internal
register index remains `{ab[7:1],1'b0}` because that is the separately
verified register-window use. This closes a real width mismatch at the
schematic/RTL boundary without asserting any unproven 054156 register timing,
VRAM arbitration or fetch behavior.

Evidence: `scroll.kicad_sch` G4 pin/net labels, the corrected parser receipt,
and the strict-lint diagnostic that previously truncated 13-bit test vectors
at `[12:1]`. The stale rendered-sheet conflict in
`doc/054156-contract.md` has now been retired in favor of this direct-source
mapping. Verification is recorded in `VERIFICATION.md` and the change ledger.

The direct main-sheet M6B 74LS138 mapping supersedes the older rendered
claim: A0/A1/A2 are MAIN_A13/14/15, O0=ROMCS, O1=~REG,
O2=CR~{CS}, O5=REGCS, O6=PCU~{CS}, and O7=OBJ_REG_SEL. O3 and O4
are explicit KiCad no_connect points (UNNAMED_0070 and
UNNAMED_0069); the direct source contains no OBJCS net.

The decoder now maps only those direct nets. M6B O2 `CR~CS` is routed to the
video object-system read boundary; `m6_objcs` remains an inactive compatibility
output because O3/O4 are no-connects. The object data/`OBJCHA` phase and SRAM
`~EDE`/`ORAM~WE` ownership still require K053246/P6 evidence.
tb_main_decode covers all M6/G7 address terms, including O3/O4 inactive
vectors. The parser receipt is schema v4 and asserts the pin map plus the
two M6B no-connect coordinates.

## Platform timing disposition

This section is a build contract, not additional PCB evidence. The project-owned
`mister/moomsa_derived_clocks.sdc` constrains the JTFRAME DB15 serializer's
`JCLOCKS[3]` keeper as the exact divide-by-16 `joy_db15_clk`; the QSF enables
all-corner TimeQuest analysis. The clean Quartus 17.0.2 Build 602 receipt
reports zero unconstrained clocks and positive setup, hold, recovery, removal
and minimum-pulse-width slack in Slow/Fast 100C/-40C models.

The STA report still lists 20 input and 87 output paths without board-level
I/O delay constraints, including SDRAM, HDMI, audio and framework connector
ports. The KiCad source supplied for the game PCB has no routed physical PCB
geometry or MiSTer board timing contract, so no I/O delay, false path or
multicycle exception is invented. This is a reviewed platform-boundary
limitation; it does not reopen the internal-clock result or establish native
PCB timing.

## Clock, reset and interrupt contract

These rows separate direct PCB net facts from the current framework clock-enable
implementation. A matching frequency does not prove phase, reset release or
interrupt cadence.

The generated JTFRAME integration keeps the direct N6 clock boundary explicit:
`cfg/mem.yaml` requests a separate 6 MHz `cen_6` enable,
`mister/mem_ports.inc` exposes it as a game-module input, and
`mister/jtmoomsa_game_sdram.v` connects the parent enable to that port. The
include closure is a framework contract, not evidence of the physical phase or
duty cycle; those remain open.

| Boundary | Direct KiCad fact | Existing RTL disposition | Open verification |
|---|---|---|---|
| M2 oscillator | `main.kicad_sch` M2 value text names `18.432Mhz 32.000Mhz`, but the direct parsed M2 pins expose only `32CLK`; the physical 18.432 MHz fanout is not proven by the populated symbol | `cfg/mem.yaml` exposes an 18.432 MHz PCM enable as a framework proxy; it is not claimed to be the M2 oscillator pin or phase | Physical oscillator fanout, PLL/divider phase and reset release against the PCB clocks |
| N3 `MC68000FN` | `CLK=M16B`, `RESET=RST`, with `~AS`, `~UDS`, `~LDS`, `R/W`, `DTACK`, `VPA` and `IPL0..2` on the direct bus | `jtmoomsa_main.v` uses the Moo-fixed wrapper around untouched JTFPGA FX68K commit `1217ab8dc600de070c6adb71ea6fe69de8855362`; no alternate CPU is accepted | CPU clock phase, reset release, P6-qualified acknowledge, N4 arbitration/HALT behavior and interrupt cadence |
| L4 `053252` | `CLK=32CLK`, `CLK3=4MCLK`, `SEL0/1/2=VSS`, `~HLDI=VCC`, `~VLDI=VCC`, `INT1→INT1`; CRES/RES/INT2 board behavior is not resolved | `jtmoomsa_053252.v` fixes `sel=00` at the top and now uses the generated `cen_32` enable (`NUM=2,DEN=3` from the 48 MHz framework); INT1 reaches the isolated IRQ boundary, while INT2 is not promoted | exact CLK/CLK3 phase, CRES/reset, CSY/CBK, INT2 and native raster timing |
| G4 `054156` | `~CLK6MHz→~M6`, `~CLK12MHz→M16B`, `CLK3MHz→M3`, `~CLK→LYR_PRIO`, `~SYSRES→~SRES` | The Moo-local K056832 owner preserves the direct CPU/VRAM/tile-ROM observable boundary; the isolated 054156 wrapper remains available for contract tests, not as a second live renderer | register-select equation, latch/fetch phase, VRAM arbitration, reset values and tile timing |
| C14/D13/E4/G3 sound clocks | Z80 `~CLK=S~CLK`, YM2151 `øM=4MCLK`, K054539 has `18CLK` and `1.54CLK`, K051550 `CLK=K051550_CLK`; sound reset labels are `S~RST`/`RES` | `jtmoomsa_sound.v` and JT51 use JTFRAME CEN proxies; the parser now asserts the selected direct device fanout, but no direct physical phase is claimed | Z80/YM/PCM divider phase, WAIT/INT/NMI cadence, K051550 reset/timeout and DAC/sample timing |

## Chip-by-chip matrix

The matrix groups identical physical parts where this keeps the table
reviewable; every reference is listed. “Live path” means instantiated and
consumed by `jtmoomsa_game`, not merely present in `cfg/files.yaml`.

### Main CPU, decode, arbitration and RAM

| Hardware | Direct KiCad evidence | Existing RTL and live-path status | Missing/incomplete behaviour | Verification |
|---|---|---|---|---|
| N3 `MC68000FN` | `main.kicad_sch`: `MAIN_A[23..1]`, `MAIN_D[15..0]`, `~AS`, `~UDS`, `~LDS`, `R/W`, `DTACK`, `VPA`, `IPL0..2`, reset and clock nets | **KNOWN/live:** `jtmoomsa_main.v` wraps JTFRAME/fx68k and exposes the bus; `jtmoomsa_game.v` consumes the device terms and drives CPU `VPA` from P6 | Reset ownership/release phase, final DTACK propagation, exact non-ROM data mux and wait cadence | P6/main/work/tile window benches and the source-complete headless build pass; full hardware CPU acceptance remains open |
| N4 `053990` | `main.kicad_sch`: main address/data bus, `BR/BG/BGACK`, `IPL0`, reset and arbitration-related nets | **KNOWN/partial:** `jtmoomsa_053990_regs` provides the FPGA-native 16-word CPU register/lane/reset/readback boundary behind M6B O7 `OBJ_REG_SEL`; this is not a complete protection device | DMA/protection transform, source/destination memory ownership, bus grant timing, `/DTACK` and interrupt production | **OPEN:** requires board trace or revision-matched device evidence; receipt `doc/k053990-register-boundary-20260825.txt` |
| P6 `PAL20RS10` | `main.kicad_sch`: `R/W`, `MAIN_A[23,22,21,20,19,18,17,16,15,14]`, `~AS` clock, `MAIN_A23` OE; direct outputs are `RAMCS`, `PALE`, `VPA`, `ORAM~WE`, `PRE_~DTACK`, `LYR_PRIO`, `~OE1`, `~OE2`, with O0/O7 unnamed | **KNOWN artifact / INFERRED board match:** `jtmoomsa_p6_decode.v` implements the local 055373 JEDEC's active-low equations once at the P6 boundary and fans normalized selects into the live top; `PALE` qualifies the discrete decoders, `VPA` reaches fx68k, and raw `ORAM~WE` is combined downstream with `R/W`/UDS/LDS | Exact PAL20RS10 versus PAL20L10/G22V10 device/revision identity, propagation or registered phase, O0/O7 physical ownership and final DTACK timing | JEDEC SHA-256 `17B71DEA7134088749DA8427532291DB4AED42FA8AA1DC95D7071A01DC97093D`; exhaustive 1024-vector P6 test plus main/work/tile window tests pass. Untested/non-working-board provenance keeps physical identity **OPEN** |
| Q5/Q6/T5/T6 program ROMs | **KNOWN/conflicting:** `main.kicad_sch` draws `27C010` devices on `MAIN_A[1..17]`, labels Q5/T5 on `MAIN_D[7..0]` and Q6/T6 on `MAIN_D[15..8]`, and gives P6 separate `~OE1`/`~OE2` outputs plus high main-address inputs. Accepted dumps are four non-duplicated 256 KiB files, larger than the drawn symbols; executable reset vectors require the opposite operational word assembly | **INFERRED/live physical select:** `jtmoomsa_p6_decode` supplies the recovered `$000000-$07ffff`/`$100000-$17ffff` OE terms; `jtmoomsa_main_rom_map` packs `{A20,A18:1}` into the generated 1 MiB bank-0 port. MRA operational maps remain Q6/Q5 and T6/T5 with `SWAB=1` | P6 device/OE phase, actual populated ROM type, physical lane polarity, ignored address pins and undocumented aliases. No range outside the two recovered windows is mirrored | Original Q code has 15 upper-window control/data references; focused P6/decode/map/downloader tests and the source-complete one-thread headless build pass. Receipt: `doc/rom-map-20260824.txt` plus current P6 iteration |
| R6/R5_2 `HM62256BLP` | `main.kicad_sch`: two 32K×8 lanes share `MAIN_A[1..15]`; R5_2 is `MAIN_D[15..8]`/`~WEH`, R6 is `MAIN_D[7..0]`/`~WEL`; both `/CS` pins are tied to VSS and `/OE` is `M~RD`. P6 O7 participates in the write-gate chain; the separate `RAMCS` net reaches K054338, not these SRAM `/CS` pins | **KNOWN/live physical capacity and lanes; INFERRED O7 identity:** the recovered O7 equation selects `$180000-$18ffff`; `jtmoomsa_workram_bus` maps physical `[15:1]` and UDS/LDS writes, generated `jtframe_ram16` is the sole live 32K×16 storage, and CPU readback precedes ROM in the data mux | O7's unlabeled physical consumer and phase, board write-pulse width, power-on SRAM contents and any unproven physical aliases | `tb_workram_bus`, `tb_workram_live`, `tb_workram_dtack` and the source-complete one-thread headless build pass. First work read/write remains upper byte at `$180010`; receipt `doc/workram-boot-20260824.txt` plus current P6 iteration |
| M6B 74LS138 | main.kicad_sch: A0/A1/A2=MAIN_A13/14/15, E1=PALE, E2=~AS, E3=UNNAMED_0058; O0=ROMCS, O1=~REG, O2=CR~{CS}, O5=REGCS, O6=PCU~{CS}, O7=OBJ_REG_SEL; O3/O4 are no_connect | **KNOWN/corrected:** `jtmoomsa_main_decode` maps only the direct low TTL terms and is now qualified by P6 `PALE`; O1 `~REG` feeds the video object-register boundary, while O7 is the separate CPU N4/053990 register select | O7/053990 protection ownership and exact PALE propagation phase | Direct parser pin/net assertion plus `tb_main_decode`, `tb_053990_regs` and P6 non-overlap tests pass; live object pixel phase remains OPEN |
| M6B/L6B `74LS138`; M7/Q8/J6/K7/G6B/Q4/D7 `74LS174/74LS74`; G7/H5/H6/H7/J5/K2/K6/K8/L6/M5/M6/Q8 `74xx` | Direct `main.kicad_sch` pins and labels include `A13..A16`, `PALE`, `BDS`, `REG`, object byte strobes, `M~RD`, `IRQ`, `INT1`, `RESET`, `DTACK` and active-low gates | **KNOWN/partial:** `jtmoomsa_main_decode`, `jtmoomsa_oram_gates`, `jtmoomsa_irq`, `jtmoomsa_colmix_n6` and `jtmoomsa_eeprom_io` own selected discrete boundaries | Complete PAL-to-TTL phase, reset release, IRQ latch acknowledge/clear and all NC/diagnostic consumers | Directed decoder/ORAM/IRQ/latch benches pass; board-level phase **OPEN** |
| Q3 `74LS148` | Direct `main.kicad_sch` maps `I4→INT1`, `I5→IRQ`, `I3→~IPL0` and encoder outputs `IPL0/1/2`; enable is tied to `VSS` | **INFERRED/replaced-by-RTL:** `jtmoomsa_irq` synthesizes interrupt levels, but the exact Q3 priority/enable/acknowledge path is not live | Q3 input priority, active polarity, acknowledge/clear and interaction with 053990/P6 | Source continuity only; existing IRQ bench verifies the isolated RTL encoder, not Q3 equivalence |
| G5 `74LS367`; RA11/RA12 resistor networks | Direct `main.kicad_sch` maps G5P3/G5P11/G5P13 and status/bus terms; RA11 exposes `~BGACK/~BR` and RA12 exposes `~LDS/~UDS/~AS/RST/HALT/~DTACK`. Unnamed/NC pins remain source records | **OPEN/isolated:** no complete bus-status/arbitration consumer is live; this is not classified as diagnostic-only | 053990/P6 arbitration, status-output ownership, pull-up/filter behavior and any external diagnostic use | Direct source inventory only; no functional equivalence claim |

### Object subsystem

| Hardware | Direct KiCad evidence | Existing RTL and live-path status | Missing/incomplete behaviour | Verification |
|---|---|---|---|---|
| F10 `053246` | `objects.kicad_sch`: `OBJROMA[19..0]`, `LUTD[15..0]`, `EN[0..7]`, `OBJDMA`, `CLKOBJ'`, HSYNC, main bus and byte controls; four simultaneous 16-bit ROM lanes span the 8 MiB object set | **KNOWN/partial live:** the direct transport modules preserve the ROM/address/latch/SRAM boundaries, `jtmoomsa_objram_addr_map` preserves the F7/F6-to-RAM physical address contract, and the Moo-local `jtmoomsa_obj` wrapper now connects the reused scan/DMA/draw producer to the live object-RAM owner and K1 CI0/OCOL boundary. High-impedance/buffer structure is collapsed FPGA-natively. | Exact Moo DMA cadence, register timing, ROM OE/latch phase, 64-bit dump-to-latch permutation and K053990 arbitration | Direct F10 scalar maps, exhaustive object-RAM address-map test, dynamic bank-3 address-width tests, and object transport benches pass; no Moo sprite-pixel or MAME-equivalence claim |
| J10 `053247` | `objects.kicad_sch`: `MAIN_D[15..0]`, `OBJROMD[15..0]`, `OCOL[8..0]`, `OPRI[4..0]`, `SHD[1..0]`, `~SET0..3`, `~REG`, `CR~CS`, `~HSYNC`, `M16`, `MCLK2` | **KNOWN/isolated:** J10’s direct bus/latch fields are represented by transport and latch contracts; the live Moo video owner currently supplies no sprite pixels | Exact output phase, priority/shadow capture and `CR~CS` integration | Direct J10 scalar maps, isolated latch/buffer tests and the 62-bench receipt pass; live object phase **OPEN** |
| A8/B8/A10/B10 `065A08` | `objects.kicad_sch`: all four receive `OBJROMA[19..0]`; A8/B8 feed `XOBJROMD[31..0]`, A10/B10 feed `YOBJROMD[31..0]`, with `~CE`, `~OE` and `BYTE` tied to VSS | **KNOWN/isolated:** `jtmoomsa_objrom_lanes.v`, `jtmoomsa_objrom_latches.v` preserve the four-lane distinction; not yet the live SDRAM socket owner | Physical word packing, output-enable timing and shared-bus turnaround | Direct ROM scalar maps, `tb_objrom_lanes` and `tb_objrom_latches` pass; live graphics packing **OPEN** |
| F9/E9 `LH5168D-80L`; C8/C9/C10/C11/D8/D9/D10/D11 `74LS374`; F6/F7/G6B/G7B `74LS245` | Direct labels expose `EA[5,1..4]`, `EN[0..7]`, `LUTD`, X/Y captured lanes, `CLKOBJ'`, `~SET0..3`, `~EDE`, `ORAM~WEH/L` and main-bus direction controls | **KNOWN/isolated:** `jtmoomsa_objram_lanes`, `jtmoomsa_obj_addr_buf`, `jtmoomsa_objram_addr_map`, `jtmoomsa_objbus_data` and latch modules; the 245 high-impedance network is behaviorally collapsed. The live CPU owner represents both 8Kx8 lanes as 8K 16-bit words and retains all 13 mapped address bits | DMA ownership, SRAM collision semantics, exact enable phase and connection to the live donor object core | Direct scalar maps, exhaustive physical-address regression, EA5-separated owner readback and object transport benches pass; integration **OPEN** |

### Scroll/tile subsystem

| Hardware | Direct KiCad evidence | Existing RTL and live-path status | Missing/incomplete behaviour | Verification |
|---|---|---|---|---|
| G4 `054156` | `scroll.kicad_sch`: 16-bit CPU bus, `SCRCS`, `ROMCS`, `M16B`, active-low 6 MHz clock, three VRAM lanes, graphics address/data and layer controls | **KNOWN boundary / INFERRED live abstraction:** `jtmoomsa_tilemap.v` is the live producer under the historical `u_k056832` hierarchy. It consumes the K054156 register/decode shell, three VRAM lanes and a bounded `lyrf` response arbiter; P6 `LYR_PRIO`/`PRE_DTACK` now own the CPU VRAM/ROM windows, but internal K054157 packing is not claimed as recovered. | PLD/K8 propagation phase, CPU lane details, VRAM bank/page arbitration, tile-field permutation, fetch phase, reset values and native timing | Existing direct-lane/K054156 tests plus current P6 tile-window test and source-complete headless build pass; MAME pixel equivalence and hardware remain **OPEN** |
| J1 `054157` | `scroll.kicad_sch`: `GFXROMA[19..0]`, `GFXROMD[31..0]`, `CI`, `APAL/BPAL/FPAL`, `ACOL/BCOL/FCOL`, `COLSCR` | **KNOWN external / INFERRED internal:** `jtmoomsa_tilemap.v` owns the live connected F/A/B boundary and shared graphics-response arbitration. Direct continuity fixes F=9 connected bits, A=7 connected bits, and B=8 connected bits; SiliconRE names the physical K054157 outputs ACOL/BCOL/CCOL/DCOL, but exact source selection, board-group correspondence, ROM packing, page schedule and output phase remain open. | K054157 internal field/source permutation, ROM turnaround/deadline and native pixel correlation | Direct parser scalar checks, focused K1 width test, strict headless source-complete build and deterministic replay; hardware and MAME **OPEN** |
| T8/T10 `065A08` | `scroll.kicad_sch`: shared `GFXROMA[19..0]`; direct lane order is T10→upper `GFXROMD[31..16]`, T8→lower `GFXROMD[15..0]` | **KNOWN/isolated/live transport:** `jtmoomsa_gfxrom_lanes.v`; fetch consumer remains donor video | SDRAM word assembly, OE/turnaround and deadline budget | `tb_gfxrom_lanes` passes; live fetch accuracy **OPEN** |
| L10/M10/N10 `MB8464A` | `scroll.kicad_sch`: three 8K×8 VRAMs, common `SCRAMA[12..0]`, `VD[23..0]`, independent `~RWE1..3` and `~ROE1..3` | **KNOWN/isolated:** `jtmoomsa_scroll_vram_lanes.v` | K054156 arbitration, bank timing and read-during-write semantics | Lane bench passes; integration **OPEN** |

### Colour and raster subsystem

| Hardware | Direct KiCad evidence | Existing RTL and live-path status | Missing/incomplete behaviour | Verification |
|---|---|---|---|---|
| K1 `053251` | Direct `053252.kicad_sch` maps `CI`, `OCOL`, `OPRI`, `SHD`, `PR`, palette fields, `M16B` and colour-control labels; K1 CS pin 81 is `UNNAMED_0042`, while `CRAM~CS` is directly present on the support muxes | **KNOWN/partial live digital boundary:** `jtcolmix_053251` is used by the Moo-local video wrapper and its fields feed the behavioral palette/K054338 bridge; the sprite CI and exact per-layer producer ordering remain disabled/open | Exact Moo priority/register map, `CRAM~CS` selection, M16B phase and live connection of every latch output; MIX1/BRI1 remain unnamed on the direct RGB sheet | `tb_053251_colmix`, `tb_color_bridge`, `tb_054338_board`, live K056832 owner and the 62-bench receipt pass; native K1 phase, MAME and hardware integration **OPEN** |
| L4 `053252` | `main.kicad_sch`: 32 MHz/control bus and connected `INT1`; direct raster outputs have no proved external fanout | **KNOWN/partial Moo-local scaffold:** the CPU/INT1 shell remains isolated while the live K056832 wrapper owns the current GX173-family timing scaffold; no donor video timer is live | Register/counter semantics, interrupt cadence, CRES/reset and CPU read-valid/DTACK use | Focused shell, live K056832 owner and 62-bench suite pass; native programmed raster ownership and boot/display equivalence **OPEN** |
| J3 `054338` | `rgb.kicad_sch` symbol and top hierarchy expose distinct `RAMCS`, `REGCS`, 16-bit bus/byte strobes, DOTCK/DTACK and RGB/palette interfaces; J3 receives the direct P6 `RAMCS` and M6B `REGCS` nets | **KNOWN/partial live digital path:** `jtmoomsa_p6_decode` owns the recovered `$1c0000-$1c3fff` `RAMCS` term including its physical mirror, `jtmoomsa_palette_rgb` owns the three RAM lanes, and `jtmoomsa_054338 #(.BOARD_MODE(1))` is the single final RGB producer. `REGCS` remains the K054338 control path | RAMCS propagation phase, separation timing between palette RAM and colour registers, byte-lane/DTACK phase, exact `CRAM~CS`/blanking polarity, K054338 analog transfer and hardware DAC behavior | P6/palette mirror tests plus `tb_palette_rgb`, `tb_color_bridge`, `tb_054338`, `tb_054338_board` and the source-complete headless build pass; native raster, MAME and hardware display remain **OPEN** |
| G4/H4/J4 `HM6116P-3`; U7_1/U7_2/U7_3/U7_4 `054574` | `rgb.kicad_sch`: `RAB[10..0]`, three colour RAM lanes, `ROUT/GOUT/BOUT`, `DBR/DBG/DBB`, `RAMCS`, `REGCS`, `DTACK`, `R/W`, reset | **KNOWN/inferred live digital path:** `jtmoomsa_palette_rgb` consumes CPU lanes and the registered MCOL address and supplies the RGB word to the live board-mode K054338; the discrete mux/latch/DAC boundary is behaviorally collapsed, not instantiated as literal TTL | Exact read/write phase, register select, blanking polarity, `MIX1/BRI1`, K054338 phase and analog DAC scaling | Direct G4/H4/J4 scalar maps, palette/latch/mux benches, `tb_color_bridge`, `tb_054338_board`, 59/59 suite and strict top lint pass; phase, analog and hardware evidence **OPEN** |

### 053252 support network and source-qualified support components

These populated support parts are direct schematic evidence and are listed
separately because their unlabeled controls, duplicate references or analog
connections do not justify promoting them to inferred RTL behavior.

| Hardware | Direct KiCad evidence | Existing RTL/live status | Missing or unresolved | Verification |
|---|---|---|---|---|
| G8/G9/H8/H9/L_B6 `74LS157` | `053252.kicad_sch`: G8/G9 select `COL`/`L7P` fields into `MCOL`; H8/H9 select `NCOL`/`BRIT`/`SDO0/1` and colour fields into `MCOLB`; L_B6 selects `FCOL` versus VSS with `UNNAMED_0003` | **ISOLATED:** no complete Moo support-mux owner is live; colour wrappers are separate | Unnamed selects/outputs, `CRAM~CS` phase, priority/brightness semantics and live fanout | Direct pin inventory only; no behavioral equivalence claim |
| J8 `74LS86` | `053252.kicad_sch`: signal pins are `UNNAMED_0009/0017/0018`; power pins are VCC/VSS | **UNRESOLVED:** no RTL owner | Both Boolean inputs/output and any downstream consumer | Source inventory only |
| J9/K5/K9/L5/L7 `74LS273` | `053252.kicad_sch`: J9/K9 latch `OPRI/OCOL/SHD` on `~M6`; K5/L5 latch `MCOLB/MCOL`; L7 latches `CI` on `MCLK2` | **ISOLATED:** local colour/latch wrappers cover selected boundaries, not the complete support chain | Exact latch phase, reset/enable behavior and pixel alignment | Direct pin records; isolated colour benches do not prove board timing |
| N6 `74LS175` | `053252.kicad_sch`: `MAIN_D[11..8]`, `S~RST`, `~Q0→CRKB`, `~Q2→K051550_CLK`; remaining outputs are unnamed | **PARTIAL/debug-only:** `jtmoomsa_colmix_n6` models the latch, but both named outputs currently feed observation/debug only and have no functional consumer | Unnamed outputs, latch phase, reset polarity and K051550/CRKB consumers | `tb_colmix_n6` proves only the isolated truth table, not live behavior |
| J2 `054986A` board connector; JP1 jumper | `054986A.kicad_sch` J2 carries `SDON`, sound I/O strobes, `SND_A[1..0]`, `SND_D[7..0]`, power and unnamed pins; `sound.kicad_sch` JP1 is an open two-pin jumper | **ISOLATED:** connector/strap continuity is not a live device model | External board connection, strap population and 054986A WAIT/INT/serial behavior | Direct source inventory only |
| R3B `330Ω` | `054986A.kicad_sch`: one side `VCC`, one side `UNNAMED_0000` | **NON-FUNCTIONAL/ANALOG SUPPORT:** no RTL equivalent | Destination net, loading and analog purpose | Source inventory only |
| R2/R3/R4/R5/R6 source-qualified passives | `io_cabinet.kicad_sch`: R2=`470Ω` VCC↔`G5P3`, R3=`100Ω` `~SYNC`↔`G5P3`, R4=`220Ω`, R5=`3.3 kΩ`; `sound.kicad_sch`: R6=`330Ω` VCC↔`4MCLK`. Main R5_2/R6 are HM62256 devices, not these resistors | **NON-FUNCTIONAL/ANALOG SUPPORT:** no resistor behavior is synthesized | Exact loading, filtering and duplicate-reference qualification | Direct source inventory; electrical measurement remains open |
| Decoupling/capacitor records | `capacitors.kicad_sch` contains 16 power/decoupling or multi-unit records; main CP1/CP2/CP3/CC2 are `104`, and sound C1/C2 are `C_Small` | **NON-FUNCTIONAL:** no RTL equivalent | Values/placement and analog power integrity | Receipt records the source components; PCB layout is empty |

### Sound, PCM and analog output

| Hardware | Direct KiCad evidence | Existing RTL and live-path status | Missing/incomplete behaviour | Verification |
|---|---|---|---|---|
| C14 `Z80CPU`, D13 `YM2151` | `sound.kicad_sch`: C14 carries the full sound CPU bus, `S~CLK`, VCC-tied `~WAIT` and `~NMI`; D13 carries the YM bus/`4MCLK`, active-low IRQ and serial audio nets to E4 | **KNOWN/partial live path:** JTFRAME Z80 and JT51 are instantiated; the FM active-low IRQ now enters the NMI latch as `~fm_irq_n`, and the D7/G6B active-low clear path is represented. PCM waits, FM serial/mix output and exact E7 selects remain open | Separate CPU/PCM cadence, physical NMI edge/reset phase, live FM serial/mix path and exact E7 selects | `tb_sound_bank` and the direct-source correction receipt pass; sound acceptance remains **OPEN** |
| E4 `054539` | `sound.kicad_sch`: E4 carries `SND_D[7..0]`, `SND_A[0..7,9]`, `R_A[20..0]`, `R_D[7..0]`, `~PCM`, `S~RD`, `S~WR`, `S~RST`, `18CLK`, `1.54CLK`, YM serial inputs and PCM outputs; A8 is not connected | **KNOWN/incomplete live shell:** `jtmoomsa_054539.v` preserves register/fetch transport but is not an eight-channel PCM/reverb/stereo engine; it duplicates fetched data to L/R and omits YM auxiliary input/PCM serialization | Channel playback, format/pitch/loop/end, pan/volume/reverb/BUSY, arbitration, stereo mix and output framing | Current tests validate the shell/transport assumptions, not K054539 equivalence. Playback **OPEN** |
| F5 `27C020`, C5 `HM62256BLP`, C7 `74LS157`, E7 `PAL16L8`, D7/G6B/G6 `74LS174/74LS74/74LS04` | `sound.kicad_sch`: E7 select inputs/outputs; C7 bank mux; C5 physical RAM address is `{R_A16,R_A13:0}`; D7 bit 4 drives active-low `~NMI_CLR` and G6/G6B form the YM IRQ latch | **MIXED/corrected:** C7 bank mux and the C5 `{R_A16,R_A13:0}` projection are represented; the NMI latch uses the direct active-low assertion/clear polarity. E7 equations and PAL8 output remain inferred | E7 equations/PAL8, select phase, C5 read-during-write and asynchronous edge ordering | `tb_sound_bank`, `tb_054539`, `tb_soundram`, `tb_054539_extaddr` and `doc/sound-c5-nmi-correction-20260825.txt` pass; exact device timing remains open |
| G3 `051550`; D5 `MB8464A`; B6 `HN624116P`; JP1 and support TTL | `sound.kicad_sch`: `K051550_CLK`, `~RESET`, `K51550_SI`, `CNT1/2`, coin counters, sound clock and reset labels | **KNOWN/partial:** N6 clock-latch fanout and pin continuity are recorded; no complete timer/watchdog model is live | Timeout, reset, counter pulse, serial input and D5/B6 ownership | Pin/latch continuity only; device behavior **OPEN** |
| U2 `054321`; 3B1 `054986A`; U1 `AD1868R`; 1B1 `LA4705` | `054986A.kicad_sch`: U2 carries `MAIN_A[4..1]`, `MAIN_D[7..0]`, `PAIR~CS`, `SND~IORQ`, `SND~RD`, `SND~WR`, `SND~PAL8`, `~WAIT`, `~INT`, `S~RST`, `S~CLK`, `1.54CLK`, `PCM[2..0]` and DAC `DL/DR`; connector/amplifier nets are recorded | **KNOWN/partial:** pinned `jt054321` donor is wrapped in `jtmoomsa_sound`; selected U2 continuity is parser-asserted; `054986A`, DAC and amplifier are not modeled as a live analog chain | K054986A serial/WAIT/INT arbitration, SND~CS source, DAC fixed-point transfer, gain/headroom and analog filtering | `doc/sound-boundary-20260824.txt` and K054321 byte bridge tests pass; all remaining stages **OPEN** |

### Cabinet input, EEPROM and connectors

| Hardware | Direct KiCad evidence | Existing RTL and live-path status | Missing/incomplete behaviour | Verification |
|---|---|---|---|---|
| S1/S2/S3/S10/S11/S12/S13/S14/S15/S16 `KONAMI_005273` | `io_cabinet.kicad_sch`: player, start, direction, coin and filtered input nets; external 3.3 kΩ pull-up, 220 Ω series and 100/470 Ω support values | **KNOWN/partial:** digital cabinet boundary and `jtmoomsa_cabinet_mux` are live; no sampled RC/threshold model is invented | Polarity, threshold, transient timing and CPU-visible map | `tb_inputs`/cabinet mux tests pass; electrical filter closure **OPEN** |
| O3/R3_2/S3_2/T3 `74LS257` player read muxes; Q4 `74LS174`; J7 `74LS32`; G6/M6 `74LS04` | Selected player byte is `D0=Left,D1=Right,D2=Down,D3=Up,D4=Button1,D5=Button2,D6=Start,D7=Button3`; Q4 maps Q0/Q1/Q2 to EEPROM `CS/CLK/DI` in the direct latch boundary, Q3 to K051550 SI, Q4 NC and Q5 IRQ_SET | **KNOWN/live boundary:** `jtmoomsa_cabinet_mux` and `jtmoomsa_eeprom_io` now match the direct bit order and Q4 no-connect; latch/reset phase and O4/R4 remain open | Filter threshold/transients, Q4 edge/reset phase, O4/R4 control/output mux behavior and EEPROM persistence | `tb_cabinet` and `tb_eeprom_io` pass; current source regression receipt is `doc/input-eeprom-regression-20260824.txt` |
| O4/R4 `74LS257`, SW1 | **KNOWN scalar only:** direct KiCad gives O4 `S=MAIN_D0` with proven `I0` lanes on `MAIN_D1..3`, and R4 `S=MAIN_D4` with proven `I0` lanes on `MAIN_D5..7`; R4 `I1`/OE and all SW1 pins are isolated or unnamed in the parsed source | **OPEN/provisional:** the current cabinet mux exposes a provisional `dip[3:0]` read mapping for compatibility, but the direct source does not prove SW1-to-R4 continuity; no DIP3/DIP4 swap is asserted and MRA control names are unchanged | Exact OE/select phase, SW1 connectivity, I1 source and CPU-visible DIP map | Parser `--check` PASS; `tb_cabinet` passes only the provisional RTL contract. Re-audit: `doc/cabinet-dip-source-reaudit-20260825.txt` |
| 15A1 `ER5911` serial EEPROM; 16A1 `EVQQ5911` four-pin switch | ER5911 carries `CS/CLK/DI/DO/ORG/RDY`, with ER5911 ORG tied VSS; EVQQ5911 is a separate four-pin switch, not the EEPROM | **KNOWN/partial:** RTL uses one fixed 128x8 `jt5911 #(.PROG(0))`, maps Q0/Q1/Q2 to `CS/CLK/DI`, leaves Q4 NC and drives ORG low; no seed/persistence path is claimed. RDY remains unconsumed at the board boundary | EEPROM initialization/persistence, exact serial phase and switch semantics | `tb_eeprom_io` passes the fixed organization/lane contract; persistence and CPU boot relevance remain open |
| CN1/CN3 and JM1 `JAMMA_CONN` | Root `moomesa.kicad_sch`: cabinet and JAMMA connector hierarchy | **KNOWN:** connector population is recorded; no hidden input mapping is inferred from the connector symbol alone | Complete connector-to-CPU pinout and real cabinet validation | Source inventory only; hardware I/O test **BLOCKED** |

The parser receipt now also asserts the exact direct scalar continuity for J10
`053247`, K1 `053251`, J1 `054157`, L10/M10/N10 scroll SRAM lanes, and the
F5/C5/D5 sound ROM/RAM lanes. Its historical upper-field labels are retained
as board-audit names only; the physical K054157 ACOL/BCOL/CCOL/DCOL pin map,
equations, phase and packing remain intentionally separate from that
continuity receipt.

## Excluded or non-functional source sheets

| Source | Direct result | Disposition |
|---|---|---|
| `not_populated.kicad_sch` | P7 `054000`, A6 `HN624116P`, CN2/CN4 and G6 support logic are on a sheet explicitly named `not_populated` | Excluded from the live hardware model pending a board population decision; no RTL is added |
| `pcm.kicad_sch` | Empty sheet: zero components, pins, labels and buses | No device or behavior is inferred |
| `capacitors.kicad_sch` | Repeated TTL multi-units and power/decoupling symbols; no new functional device beyond the sheets above | Used as package/power continuity context, not as an additional chip implementation |
| `colmix.kicad_sch` and `untitled.kicad_sch` | Hierarchical/duplicate colour labels and a duplicate `054574` unit | Retained in the receipt; duplicate units are not counted as additional physical chips |

## Current architectural conclusion

The KiCad source proves a populated GX151 bus with exact 054156/054157,
053246/053247, `065A08`, 053251, 053252, 054338, 054539, 054321,
054986A/AD1868R/LA4705, 051550 and input/EEPROM parts. It also proves that
several Moo-specific transport wrappers already in the repository are
isolated boundaries, not live consumers. The current live tile owner is `jtmoomsa_tilemap.v`, instantiated under the
historical `u_k056832` hierarchy label so existing diagnostic paths remain
stable. It consumes the direct G4 K054156 plus J1 K054157 boundary. The
K054156/K054157 tile-field, page/line-scroll and colour-field bridges remain
**INFERRED**, not proof of Moo timing or pixel accuracy. JTCORE
X-Men/Simpsons/Aliens sources are donor/reference material, not a second live
video path.

The current status supersedes any older table wording that described the Moo
sprite producer as disabled: `jtmoomsa_obj` is now live at the object-RAM and
K1 CI0/OCOL transport boundary. Its exact DMA cadence, object-ROM
lane/latch/packing, `OPRI`/`SHD` priority/shadow path and visible pixels remain
**OPEN**.

No new device, PAL equation, memory permutation, crop, delay, gain, or
gameplay-specific workaround is justified by the KiCad source alone. The next
hardware edit must identify the first causal mismatch at a live boundary and
carry a focused test plus a complete-path regression.

## JTFRAME/JTCORE reuse audit

The established implementations were inspected before treating any donor as
an implementation shortcut:

| Reused source | Use in Moo | Provenance and limit |
|---|---|---|
| `cores/xmen/hdl/jtxmen_video.v` | Structural video donor only | Pinned JTCORE source inspected for reuse and timing idioms; it is no longer the live Moo video shell. Its Aliens/Simpsons/X-Men ownership and offsets are not promoted into Moo behavior. |
| `cores/simson/hdl/jt053246.sv` and companion object modules | Structural object donor plus Moo-local live transport wrapper | Mature 053246/247-family implementation is reused inside `jtmoomsa_obj`; the live wrapper reaches the proven object-RAM owner and K1 CI0/OCOL at the transport boundary. Direct Moo DMA cadence, ROM/latch phase, object packing, priority/shadow and visible pixels remain unresolved. |
| `cores/simson/hdl/jtcolmix_053251.v` | K053251 primitive reused by Moo-local wrapper | Mature K053251-family register/priority behavior is reused at the digital boundary; direct Moo CI/OCOL/OPRI/SHD producer order and live sprite input remain separately tracked. |
| `cores/riders/hdl/jt054321.v` | K054321 main/Z80 latch bridge | Pinned JTCORE donor reused behind the direct U2 bus contract; K054986A serial/WAIT/INT behavior is not silently inherited. |
| `modules/jt51` and `modules/jteeprom` | YM2151 and ER5911-compatible primitives | Pinned reusable devices; board selects, fixed organization, persistence and analog path remain Moo-specific. |
| JTFRAME `jtframe_m68k`, `jtframe_sysz80`, memory and video helpers | CPU, clock-enable and transport infrastructure | Framework contracts are reused as-is. They do not establish the Moo PAL equations, ROM packing or physical timing. |

No exact pinned implementation for the direct Moo `054156`, `054157`,
`054338`, `054539`, `053990` or `051550` behavior was found in the local
JTCORE sources. The corresponding repository modules therefore remain
isolated boundary contracts until higher-tier evidence closes their timing
and state-machine unknowns; a generic substitute is not promoted merely
because it produces a plausible picture.

## Full-top display-path evidence — 2026-08-25

The direct KiCad audit establishes the K1/palette/K054338 connectivity, while
the current full-top diagnostic establishes only the following live behavior:
the K056832-derived layer produces non-zero pens and reaches non-zero palette
addresses, but the observed palette RGB word remains zero. The schematic does
not by itself prove the CPU write phase, palette RAM read latency or K054338
register transfer phase, so those are still marked open rather than replaced
with a guessed hardware model. This follows the FPGA-native abstraction rule:
the 74LS/latch/high-impedance network is collapsed where the observable bus,
lane and polarity contracts are preserved.

## Full-top CPU/IRQ progression evidence — 2026-08-25

The pre-fix real-bank top reached PC `0x20e6` while control2 bit 5 was set,
with no production level-5 request. The harness-only forced-pulse test proved
that this was causal. The current FPGA-native integration exposes control2
bit 5 and combines `irq5_en && !cr_n_vbk` active-low with the existing DMA
IRQ line. A clean replay now asserts `irq_n=0` during VBlank and reaches
object-RAM initialization. This is a **KNOWN software-visible contract with
INFERRED integration timing**, not a claim that the FPGA literally recreates
the TTL latch network. Exact G6B acknowledge/DMA-end phase remains open.
Receipt: [`doc/irq5-vblank-fix-20260825.txt`](doc/irq5-vblank-fix-20260825.txt).
