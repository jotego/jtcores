<!-- SPDX-FileCopyrightText: 2026 Andrea Bogazzi
     SPDX-License-Identifier: GPL-3.0-or-later
     Date: 18-10-2026 -->

# PAL equations and physical connections

Three decoded programs are available: **Radical Radial**, **Seicross/Sector
Zone** and **Tecfri Sector Zone**. They have different equations. The user
confirmed that PAL 2C has identical input/output wiring in the supplied
**Seicross, Frisky Tom and Radical Radial** schematics. These drawings share
the pin map below; Frisky Tom's program remains unavailable. The standalone
[jtseicro_pal](../hdl/jtseicro_pal.v) implements the decoded physical-pin
equations. [jtseicro_wait](../hdl/jtseicro_wait.v) connects them to the external
latch model and the actual Z80 `/WAIT` pin in `jtseicro_main`.

## Dump identity

The local MAME reference is
[seicross.cpp](mame/src/mame/nichibutsu/seicross.cpp).

| Sets in the reference | Dump member | CRC32 | SHA1 | Availability and qualification |
| --- | --- | --- | --- | --- |
| `radrad`, `radradj` | `pal16h2.2b` | `a356803a` | `a324d3cbe2de5bf54be9aa07c984054149ac3eb0` | Available in local `radrad.zip`; `radradj` borrows it as `BAD_DUMP`. |
| `seicross`, `seicrossa`, `sectrzon`, `sectrzona` | `pal16h2.3b` | `e1a6a86d` | `740a5c2ef8a992f6a794c0fc4c81eb50cfcedc32` | Available at the root of the original merged `~/.mame/roms-local/seicross.zip`; `seicrossa` and `sectrzon` borrow it as `BAD_DUMP`. |
| `sectrzont` | `czt_pal16h2cn.bin` | `7edec1ed` | `1b28cb250875f14a76d84bfc0b23ee02b1862c2c` | Available in the NAS's original `sectrzont.zip` and under `sectrzont/` in the original merged `seicross.zip`. |
| `friskyt`, `friskyta`, `friskytb` | No PAL entry | — | — | No PAL dump declared in this driver snapshot. |

All three available dumps are 68-byte MAME binary fuse maps with 512 fuses;
their sizes, CRC32 and SHA1 match the driver. The prepared
`cores/seicro/ver/game/roms/` Seicross-family ZIPs omit their PALs; these ZIPs
alone do not establish dump availability. The user authorized a recovered
program as a fallback for Frisky Tom. The selected provisional fallback is the
Radical Radial program; this does not establish Frisky Tom's original contents.
The existing Frisky game selector selects this fallback without another header
field or OSD option.

## Reproduce the MAME decode

Run from the repository root, using the existing MAME `jedutil` executable:

```sh
mkdir -p cores/seicro/ver/checks/schematic/pal
unzip -p cores/seicro/ver/game/roms/radrad.zip pal16h2.2b > cores/seicro/ver/checks/schematic/pal/radrad-pal16h2.2b.bin
shasum -a 1 cores/seicro/ver/checks/schematic/pal/radrad-pal16h2.2b.bin
/Users/andreabogazzi/develop/mame/jedutil -view cores/seicro/ver/checks/schematic/pal/radrad-pal16h2.2b.bin PAL16H2 > cores/seicro/ver/checks/schematic/pal/radrad-pal16h2-equations.txt
unzip -p "$HOME/.mame/roms-local/seicross.zip" pal16h2.3b > cores/seicro/ver/checks/schematic/pal/seicross-pal16h2.3b.bin
shasum -a 1 cores/seicro/ver/checks/schematic/pal/seicross-pal16h2.3b.bin
/Users/andreabogazzi/develop/mame/jedutil -view cores/seicro/ver/checks/schematic/pal/seicross-pal16h2.3b.bin PAL16H2 > cores/seicro/ver/checks/schematic/pal/seicross-pal16h2-equations.txt
unzip -p '/Volumes/home/roms/MAME 0.270 ROMs (split)/sectrzont.zip' czt_pal16h2cn.bin > cores/seicro/ver/checks/schematic/pal/sectrzont-czt_pal16h2cn.bin
shasum -a 1 cores/seicro/ver/checks/schematic/pal/sectrzont-czt_pal16h2cn.bin
/Users/andreabogazzi/develop/mame/jedutil -view cores/seicro/ver/checks/schematic/pal/sectrzont-czt_pal16h2cn.bin PAL16H2 > cores/seicro/ver/checks/schematic/pal/sectrzont-pal16h2-equations.txt
```

The extracted dump and raw output stay in ignored verification storage. Decoding
uses MAME `jedutil` directly, without a custom decoder or helper.

## Radical Radial equations

`iN` and `oN` refer to physical pin N, `/` means NOT, `&` means AND, and `+`
means OR. `vcc` is logical one. MAME reports these device modes:

```text
Inputs: 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 17, 18, 19
Output 15: combinatorial, no output feedback, active high
Output 16: combinatorial, no output feedback, active high
```

Complete equations printed by `jedutil`, preserving repeated product terms:

```text
o15 = i4 +
      i4 +
      /i3 & i4 +
      /i3 & i4 & i5 & /i11 +
      i1 & i2 & i3 & i4
o15.oe = vcc

o16 = i6 & i7 & i8 & i9 +
      /i2 & i19 +
      /i2 & i6 & i7 & i8 & i9 & /i11 & i19 +
      /i3 +
      /i3 & i6 & i7 & i8 & i9 & i11 & i12 & i13 & i14 & i17 & /i18 & /i19
o16.oe = vcc
```

By Boolean absorption, these reduce to physical output levels:

```text
o15 = i4
o16 = (i6 & i7 & i8 & i9) + (/i2 & i19) + /i3
o15.oe = vcc
o16.oe = vcc
```

Every omitted term contains an already retained term. Comparison over all
65,536 combinations of the 16 inputs also matched the original product terms.
Both physical outputs are always driven. These equations do not establish the
board net names, external latch sequencing or propagation delays.

## Seicross/Sector Zone equations

MAME reports the same input/output pin roles, active-high combinational mode,
no output feedback and always-enabled outputs as for the Radical Radial device.
Complete `jedutil` equations:

```text
o15 = i4 +
      i4 +
      /i3 & i4 +
      /i3 & i4 & i5 & /i11 +
      i1 & i2 & i3 & i4
o15.oe = vcc

o16 = i19 +
      i6 & i7 & i8 & i9 +
      i6 & i7 & i8 & i9 +
      /i3 +
      /i3 & i6 & i7 & i8 & i9 & i11 & i12 & i13 & i14 & i17 & /i18 & /i19 +
      /i3 +
      /i3 & i6 & i7 & i8 & i9 & i11 & i12 & i13 & i14 & i17 & /i18 & /i19
o16.oe = vcc
```

Boolean absorption yields:

```text
o15 = i4
o16 = i19 + (i6 & i7 & i8 & i9) + /i3
o15.oe = vcc
o16.oe = vcc
```

Unlike Radical Radial, the `i19` term does not require `/i2`.

## Tecfri Sector Zone equations

MAME reports the same pin roles and output modes. Complete `jedutil` equations:

```text
o15 = i4 +
      i4 +
      i4 +
      i1 & i3 & i4
o15.oe = vcc

o16 = i19 +
      /i3 & i19 +
      i3 & i19 +
      /i2 & i3 & i11 & i19
o16.oe = vcc
```

Boolean absorption yields:

```text
o15 = i4
o16 = i19
o15.oe = vcc
o16.oe = vcc
```

The different output-16 logic requires a separate timing derivation for each
program using the established pin map; the programs are not interchangeable.

## Schematic coverage

Supplied originals cover Seicross (`Seicross.pdf`, SZ-1 video and SZ-2 CPU/audio
drawings across PDF pages 8–11), Frisky Tom (`Frisky Tom Schematics.pdf`, video
and CPU/audio sheets) and Radical Radial (`Radical Radial.pdf`, pages 6–7).
Keep these copyrighted originals outside tracked core files. The schematics
do not by themselves provide the internal fuse program. The user compared
PAL 2C across all three drawings and confirmed identical input/output
connections. This confirms pin-map equivalence; it does not establish an
identical fuse program or independently verify every upstream circuit.

## Shared PAL 2C connections and request clocks

Detailed source: Radical Radial PDF page 7, PAL 2C and adjacent 2D. The pin 19
route and three `/MQ` labels were jointly verified. The user subsequently
confirmed the same PAL input/output wiring on the Seicross and Frisky Tom
drawings. Evidence for a net's identity remains distinct from this confirmed
equivalence; remaining scan-derived labels retain their qualifications.

| PAL 2C pin | Connection | Evidence |
| --- | --- | --- |
| 1 | `/MQ1` | User read the label; upstream decoder still being traced. |
| 2 | `/MQ2` | User read the label; upstream decoder still being traced. |
| 3 | `/MQ3` | User read the label; upstream decoder still being traced. |
| 4 | `H2`, without inversion | User reads H2 without a bar or input bubble; adopted common mapping. |
| 6 | `H4` | Legible scan trace. |
| 7 | `H5` | Legible scan trace. |
| 8 | `H6` | Legible scan trace. |
| 9 | `H7` | Legible scan trace. |
| 15 | Lower 2D CK pin 3, with drawn 1000 pF branch to GND | Scan trace. |
| 16 | Upper 2D CK pin 11 | Scan trace. |
| 19 | `/VBLK`, the lower of the two VBLK-labelled lines | User confirmed route and bar. |

Define `MQ2 = NOT(/MQ2)` and `MQ3 = NOT(/MQ3)`, the asserted forms of the
physical active-low inputs, and `T = H4 & H5 & H6 & H7`. Applying the shared
pin map gives:

| Program | PAL15 | PAL16 |
| --- | --- | --- |
| Radical Radial | `H2` | `T + MQ3 + (MQ2 & /VBLK)` |
| Seicross/Sector Zone | `H2` | `T + MQ3 + /VBLK` |
| Tecfri Sector Zone, using this pin map | `H2` | `/VBLK` |
| Frisky Tom provisional Radical fallback | `H2` | `T + MQ3 + (MQ2 & /VBLK)` |

The wiring confirmation covers the three supplied schematic boards; the Tecfri
expression is the result of applying this same map to its separate dump, not
independent evidence from a Tecfri drawing.

The common PAL routes are reviewed once, with each available program evaluated
against the same input waveforms. Input source qualifications and the digital
policy for coincident edges are recorded below.

### Raster phase

The horizontal counters run from 128 through 511 and reload 128. Their H8
falling edge advances the vertical counter. The existing renderer's normalized
H runs from 0 through 383, with horizontal blank beginning after H255. The
physical counter supplied by `jtseicro_video.video_h` is therefore:

```text
physical_H = normalized_H < 256 ? normalized_H + 256 : normalized_H - 128
```

Thus normalized H255->256 is physical H511->128. The raw `VBLK` source is
5F `/Q8`, and `/VBLK` is 5F Q9. The jointly reviewed V4-clocked flip-flop
and NAND of V5/V6/V7 make raw blanking assert at V240 and release at V16.
The existing `cpu_lvbl` has the required `/VBLK` polarity and transition phase.
It must remain separate from the delayed PROM and RGB blanking paths.

`ver/hdl/pal_phase_tb.v` checks the actual video module against an independent
128..511 horizontal counter and 264-line vertical counter for four frames:
405,504 pixels, with all eight blanking edges at physical H128 / V16 or V240.
This establishes the digital raster mapping, not analogue PAL/latch delays.

### Equation implementation and verification

`jtseicro_pal.mode` selects 0=Seicross, 1=Radical Radial, 2=Tecfri. Its `pin`
indices and `q[16:15]` are physical PAL pin numbers. `jtseicro_wait` supplies
unbarred H2 on pin 4, H3..H7 on pins 5..9, `/VBLK` on pin 19, and the
active-low `/MQ1`..`/MQ3` levels on pins 1..3. Other input slots are tied zero
because they do not affect any simplified output; these HDL ties do not assert
that the corresponding physical pins are grounded on the PCB.
The regression `ver/hdl/pal_tb.v` compares both outputs against all original
`jedutil` product terms over all 65,536 input combinations for each program:
196,608 checked cases. Output enables are always asserted for all three dumps.

### Source decoder 2F

Radical Radial CPU sheet, PDF page 6. The user recognizes the `/ZRB` and
`/ZMR` labels and reads the AB15 inverter reference as **4K**. The selector
digits remain difficult to read; the proposed AB13/AB12/AB11 assignment is
provisional, not user-confirmed.

| 2F pin | 74LS138 role | Apparent connection | Evidence |
| --- | --- | --- | --- |
| 1 | A, least significant selector | AB11 | Provisional digits. |
| 2 | B | AB12 | Provisional digits. |
| 3 | C, most significant selector | AB13 | Provisional digits. |
| 4 | `/G2A`, active low, bubble | 4K pin 8, inverted AB15 from pin 9 | AB15 and 4K supported by user reading; route legible. |
| 5 | `/G2B`, active low, bubble | `/ZMR` | Label supported by user reading; pin route legible. |
| 6 | G1, active high, no bubble | `/ZRB` | Label supported by user reading; pin route legible. |
| 14 | `/Y1` | `/MQ1` | Legible scan trace. |
| 13 | `/Y2` | `/MQ2` | Legible scan trace. |
| 12 | `/Y3` | `/MQ3` | Legible scan trace. |

Device pin roles are established by the
[TI SN74LS138 datasheet](https://www.ti.com/lit/ds/symlink/sn74ls138.pdf)
and shared `jt74:74LS138` symbol. The slash in a source net's name is
independent of the destination pin's bubble. With the apparent enable wiring,
`enabled = /ZRB AND NOT(/ZMR) AND AB15`. If the selector digits are confirmed,
the asserted outputs select whole 0x0800-byte windows, with A14 ignored:

| Output | Primary window | A14 mirror |
| --- | --- | --- |
| MQ1 | 0x8800–0x8fff | 0xc800–0xcfff |
| MQ2 | 0x9000–0x97ff | 0xd000–0xd7ff |
| MQ3 | 0x9800–0x9fff | 0xd800–0xdfff |

These physical qualifiers must not be replaced by the HDL's narrower tile/color
RAM selects. `jtseicro_wait` uses this address model and `!mreq_n & rfsh_n`
as its bus qualifier: `/ZMR` is buffered `/MREQ`, while the ambiguous `/ZRB`
association with buffered `/RFSH` remains the previously recorded working
assumption. The selector digits retain their qualified reading. The decoder
tests cover all 65,536 addresses and all four MREQ/RFSH combinations, including
refresh suppression and the A14 mirrors.

## External WAIT latch sequence

The Frisky Tom feedback and D ties in the next section are jointly confirmed;
the Radical Radial and Seicross scans show the same arrangement. On Radical
Radial the user also confirmed both D inputs and both presets share `P`:

| Source | Radical Radial 2D destination | Evidence |
| --- | --- | --- |
| `P` | Upper D pin 12 and `/PRE` pin 10 | User confirmed. |
| `P` | Lower D pin 2 and `/PRE` pin 4 | User confirmed. |

The following normal-operation derivation assumes `P` is high, making the
presets inactive and the D inputs logical one.

Let `A` be upper 2D Q9 and `B` lower 2D Q5. Upper `/CLR13 = NOT B`,
lower `/CLR1 = A`, both D inputs are `P`, and `/WAIT = NOT A`.

| Event | Result |
| --- | --- |
| Idle `A=0` | Lower clear is asserted, holding `B=0`; upper clear is released. |
| Rising PAL16 | Upper Q becomes 1, asserting `/WAIT` low and releasing lower clear. |
| Next rising PAL15 (`H2`) | Lower Q becomes 1 and clears upper Q. Upper Q returning to 0 clears lower Q, restoring the idle state. |

PAL16 is therefore a request **clock**, not the `/WAIT` level. A continuously
high PAL16 does not repeatedly assert wait. The two-edge sequence and the 1000 pF
branch on PAL15 matter when request and release edges coincide; the physical
capacitor delay has not been measured. The HDL uses the master clock with edge
enables, without generated clocks or asynchronous feedback. A request edge sets
`pending`; an H2 rising edge clears it, including when both edges occur on the
same master-clock tick. This release-priority tie policy is a digital modeling
choice, not a measured subcycle propagation result. No numeric capacitor delay
is invented. Framework reset chooses the idle state and samples current PAL
levels; CPU/watchdog reset does not restart this independently clocked circuit.

### Measuring the loaded clock path

The drawn 1000 pF shunt capacitor loads PAL15 and can change edge arrival and
shape. It does not prescribe a lower clock frequency or a known RC delay:
there is no specified series resistor, and the PAL's transient output drive and
the receiving flip-flop's switching behavior matter. An electrical estimate
requires the actual PAL vendor/speed suffix, the exact 2D logic family and a
driver/load model. Static output-current limits alone do not establish this
dynamic delay.

For a working original board, capture these signals with low-capacitance probes
and short ground connections:

| Capture | Probe points | Purpose |
| --- | --- | --- |
| Clock path | H2 at 2C pin 4, loaded PAL15 at 2C pin 15 / lower 2D pin 3 | Measure total input-to-loaded-clock delay and edge shape with the capacitor fitted. |
| Latch ordering | PAL16 at 2C pin 16 / upper 2D pin 11, loaded lower clock at 2D pin 3, `/WAIT` at upper 2D pin 8 | Establish request/release order and resulting WAIT pulse width. |

PAL15 and lower 2D clock pin 3 are the same electrical node; measuring between
those points does not isolate the capacitor's effect. Compare the clock path
against upstream H2, then observe actual latch behavior during memory activity
and around blanking. Record waveforms and the range of observed delays rather
than one guessed time. The guaranteed input-high/low levels in a datasheet are
not a measured switching threshold for that specific chip.

References: [TI 74-family flip-flop datasheet](https://www.ti.com/lit/ds/symlink/sn74ls74a.pdf)
for clocked behavior and family specifications, and
[Tektronix probe-loading guidance](https://www.tek.com/en/documents/application-note/how-oscilloscope-probes-affect-your-measurement).
The exact fitted 2D suffix and physical clock-path delay remain unmeasured.

`jtseicro_main` composes the existing `jtframe_z80wait` ROM recovery logic with
`jtframe_z80.wait_n`. Board waits leave CPU enables and raster clocks running;
SDRAM ROM stalls retain their separate recovery path. Game selection is
Seicross=mode0, Radical=mode1, Tecfri=mode2 and Frisky=mode1 fallback. The
existing ISA/game header bits identify these modes without enlarging the header.

`ver/hdl/wait_tb.v` checks decoder windows, each program, H2 rising versus
falling, held clock levels, reset, periodic requests and the coincident-edge
policy. `ver/hdl/main_wait_tb.v` runs a Z80 program in all four game modes:
it holds an active write through ten live CPU-enable steps, releases it on H2,
then checks video/scroll writes, RAM/ROM reads and independent ROM stalls.

## MCU memory-ready circuit

The adjacent `/MR` circuit arbitrates MCU high-address accesses against the
Z80 bus. The following routes were jointly checked on Radical Radial CPU sheet
6. The shared PAL pin-map confirmation does not independently establish that
every upstream MCU gate is identical on the other boards.

| Source | Destination | Evidence |
| --- | --- | --- |
| MCU 4F E pin 37 | Buffer 5H input 4, output 5, net `ME` | User confirmed; 5H marked 367. |
| MCU 4F VMA pin 5 | Buffer 5H input 14, output 13, net `MVMA` | User corrected the buffer channel and confirmed. |
| `ME`, `MVMA` | 4I inputs 12, 13; output 11 | Jointly traced request qualifier. |
| 4I output 11 | Upper 4I input 4 and lower 4I input 10 | User confirmed both branches. |
| MCU A15 pin 25 | 4J input 11/output 10, then input 13/output 12, then lower 4I input 9 | User confirmed both inversions. |
| Lower 4I output 8 | Upper 5I clock pin 11 | User confirmed. |
| Upper 5I Q9 | Both lower 5J and 5I `/PRE4` | User confirmed, including bubbles. |
| Lower 5I Q5 | Upper 5I `/CLR13` | User confirmed, including bubble. |
| GND | Lower 5J D2 | User confirmed. |
| Lower 5J Q5 | Lower 5I D2 | User confirmed. |
| `P` | Both lower `/CLR1` inputs | User confirmed. |
| 5L output 6 | Lower 5J clock pin 3 and inverter 4J input 5 | User confirmed. |
| Inverter 4J output 6 | Lower 5I clock pin 3 | User confirmed. |
| Upper 5I `/Q8` | MCU 4F `/MR3` | Legible scan trace. |
| `P` | Upper 5I D12 and `/PRE10` | Legible scan trace. |

The request clock is `ME & MVMA & A15`. Let `C` be physical 5L output 6.
The user confirmed `/ZMR` through inverter 4K input 5/output 6 to 5L input 4,
and 5L is marked 00 with inverted output 6. Its other input, pin 5, is retained
as `X`: the user's best label reading is `/ZRB`. Associating that net with
buffered Z80 `/RFSH` remains an explicit working assumption. Thus:

```text
C = /ZMR | !X
if X is buffered /RFSH: C = MREQ_n | !RFSH_n
```

| Event | Latch result |
| --- | --- |
| Idle upper Q9=0 | `/MR` is high; both lower presets hold their Q outputs at 1. |
| Rising `ME & MVMA & A15` | Upper Q9 becomes 1, asserting `/MR` low and releasing both lower presets. |
| Next rising `C` | Lower 5J loads 0. `/MR` remains asserted. |
| Following falling `C` | Inverted `C` clocks that 0 into lower 5I, clearing the upper latch. Its Q9 returning to 0 presets both lower latches, restoring idle. |

An initial falling `C` cannot release a request before lower 5J has seen a
rising edge. A request held high does not retrigger after release. Release
latency therefore depends on Z80 bus activity; the circuit is not a fixed
number of MCU clock enables.

[jtseicro_mr](../hdl/jtseicro_mr.v) models this latch sequence with master-clock
edge enables. Its standalone test compares against three event-driven physical
flip-flops over request qualifiers, held levels, reset and eight relative clock
phases. For an initial request coinciding with a rising `C`, the model ignores
that release edge while the lower presets are active. This is an explicit
digital tie policy, not a measured propagation delay.

Both CPU variants use the shared [jt680x](../../../modules/jt680x/hdl/jt680x.v)
engine, controller, register datapath and ALU. Seicro selects the `jt6802.yaml`
manifest and `JT680X_6802` profile. Instruction definitions, dispatch eligibility,
addressing helpers, ALU controls and physical bus barriers are defined in the
shared [6802.yaml](../../../modules/jt680x/ucode/6802.yaml). The generator retains the output prefix `6801`
because the shared ALU includes `6801_param.vh`; this filename does not select
a 6801 instruction set.

Internal microsteps run on the master clock between external transfers. A YAML
`bus` microinstruction holds the controller until the physical transfer completes;
`valid`, `wr` and address controls describe its VMA, R/W and address. Internal
microsteps therefore do not create extra byte writes or act as extra E cycles.
The generator's microstep-count timing report is disabled because its fixed
microsteps-per-cycle model does not describe these barriers. Nominal `cycles`
metadata and the actual E/transfer sequence are checked independently by tests.

[jt680x_bus](../../../modules/jt680x/hdl/jt680x_bus.v) registers each requested bus
cycle. Each normal E period has four external crystal enables: two low and two
high. Address, VMA, R/W and write data remain stable through E high. MR low
extends the high phase in two-crystal-enable increments. Each valid write
commits once at the completing E falling edge. SDRAM readiness is a separate
input and cannot manufacture another write or MR request. E is not a generated
FPGA clock. Digital MR sampling uses eligible completion edges; analogue
setup-window and chip propagation effects have not been measured.

The traced MCU schematic is for NSC8105. Reusing its functional board interface
for M6802 variants is supported by MAME's explicit HD46802 substitutions and
patched Tecfri MCU program, plus matching E37, VMA5 and MR3 functions in the
Motorola pinout. The exact surrounding logic on those M6802 board variants has
not been independently checked against a separate diagram. Applying documented
M6802 bus phases to ordinary NSC8105 operations is a compatibility model; the
supplied schematics alone do not establish identical silicon or every NSC cycle.

`jtseicro_mcu` connects the physical E/VMA/A15 outputs to the request latch,
and `jtseicro_main.mcu_release_clk` supplies the Z80-derived release level.
The implementation adopts the qualified `/ZRB` = buffered `/RFSH` association
above. Ordinary MCU reset/release and watchdog reset do not reset the
independently clocked MR latch; FPGA reset initializes its digital model to idle.
The bus reset model aborts a transfer, suppresses VMA and keeps the E divider
advancing. A complete new bus cycle is required before another completion can
reach the instruction controller. Electrical reset/MR overlap timing has not
been separately measured.

| Header CPU selector | Sets | MCU path |
| --- | --- | --- |
| M6802 | `sectrzont`, `friskytb` | Shared YAML engine, direct opcode dispatch and connected MR latch. |
| NSC8105 | Remaining eight sets | Same engine and MR latch, with NSC opcode translation and extension microcode. |

The shared engine's NSC8105 adapter swaps opcode bits 7/6 and 1/0. The decoded byte is used at instruction dispatch and to latch the
branch condition. Operand, address and data bytes remain unchanged. YAML's
`entry` flag marks legal instruction starts; helper procedures placed in unused
opcode slots cannot be entered by fetching those bytes. `nscop` restricts the
four extension entries below to NSC mode. Other retained family definitions
without `entry` are not executable board instructions.

| Raw NSC opcode | Internal opcode | Operation | Selected bus cycles |
| --- | --- | --- | --- |
| `B2` | `71` | `STIM`: write the immediate byte to X plus the following byte offset. | 6 |
| `BB` | `7B` | `BTST`: test the immediate mask against X plus the following byte offset. | 6 |
| `EC` | `EC` | `ADCX`: add an immediate byte to X, using the existing MAME-derived flag interpretation. | 5 |
| `FC` | `FC` | `ADDX`: add an extended-addressed word to X. | 5, provisional |

The NSC `ADDX` sequence reads opcode, address high/low and operand high/low:
five transfers under the selected M6802 bus contract. MAME's aggregate cycle
table specifies four cycles and its flags are marked as guesses; that table
does not provide the external waveform needed to reconcile this discrepancy.
The selected extension bus placements, including the idle slots in the other
three extension sequences, remain provisional pending hardware evidence.
No fixed high-address delay or instruction padding is added by the board wrapper.

Frisky Tom set 3 executes `FC FF 62` at MCU address `D9E1` during gameplay.
A local MAME 0.288 run with coin at frame 720 and start at frame 752 logs the
same illegal three-byte opcode there. MAME's `m6800_insn` maps `FC` to
`illegl3`, which skips two operand bytes, preserves registers/flags, and uses
its four-cycle unknown-opcode fallback in `cycles_6800`. Seicro enables the shared engine's optional `FC_COMPAT` parameter. M6802
mode then routes this known byte to YAML's internal `03` `FCCOMPAT` entry; `fccompat` additionally
requires the fetched byte to be `FC` and NSC mode to be inactive. Fetching a
literal `03` cannot invoke the fallback. The default shared profile does not
enable this undocumented compatibility behavior. Its provisional bus sequence reads
the opcode and two operand bytes, then has one VMA-low cycle. Neither Motorola
Table 8 nor the supplied schematics establish the actual HD46802 behavior or
bus sequence for this undefined opcode. Other unsupported bytes fail simulation.

`ver/hdl/m6802_reference.v` preserves the hardware-build checkpoint's manual-cycle
controller as a test-only oracle; it is excluded from the production file list.
`ver/hdl/m6802_compare_tb.v` checks 199 baseline operations over 64 initial flag
patterns for each CPU mode: 25,472 register, flags, memory and transfer-pattern
comparisons. Every completed unstalled E cycle must take four crystal enables,
including instruction boundaries. Undefined DAA V is excluded. Stacked WAI/SWI
CC and SWI return PC retain independent expected-value checks.

`ver/hdl/m6802_decode_tb.v` checks all 512 raw-byte/mode combinations against
baseline ISA eligibility and the four NSC extensions, including procedure-slot
rejection and FC compatibility isolation. `ver/hdl/m6802_compat_tb.v` checks
FC's skipped operands, unchanged state, absence of writes and provisional bus
sequence. `ver/hdl/nsc8105_tb.v` exercises the four NSC extensions, their flags,
unchanged operands and all 256 branch-condition combinations. The independent
M6802 bus fixture checks exact BSR/RTS addresses, single writes, E-high stability,
pause, eight release phases and host stalls. `ver/hdl/mcu_mr_tb.v` connects a
running Z80 to each MCU mode: Z80 WAIT holds the MCU's request pending, and MCU
reset preserves the MR latch while E continues and transfers are suppressed.

The [Motorola MC6802 datasheet](https://datasheets.pl/elementy_czynne/IC/MC/MC6802-2.pdf)
specifies external EXTAL at four times the normal E frequency and memory-ready
stretching of E high in integral half-periods. The cycle-controller checks use
that contract; the latch test alone does not establish CPU bus timing or
independently certify NSC8105 electrical timing.

The [Motorola MC6802 data manual scan](MC6802.pdf)
([download source](https://www.retrodocs.fr/wp-content/uploads/pdf/TexasInstrument-MC6802.pdf))
provides the required bus reference directly: Table 8, PDF pages 18–21 (printed
3-196 through 3-199), lists address, data, VMA and R/W for each instruction
cycle. Figure 15 on PDF page 11 specifies MR setup and E stretching; the EXTAL,
MR and E descriptions are on PDF page 12. For BSR, Table 8 specifies VMA high
on cycles 1, 2, 4 and 5: opcode, displacement, low return-address write and high
return-address write. Cycles 3 and 6–8 have VMA low. These explicit cycle slots
provide an independent target for the local cycle controller; aggregate
instruction counts alone do not specify the bus waveform. NSC8105-specific
instructions still require separate evidence.

## Additional shared PAL pin inventory

The Frisky Tom drawing supplies the remaining scan traces below. Shared PAL
wiring is user-confirmed; an unresolved label remains unresolved even when
its connection is the same on all three boards. These extra inputs do not
survive simplification of any of the three available programs.

| PAL 2C pin | Device role | Schematic net or destination | Evidence |
| --- | --- | --- | --- |
| 5 | Input | `H3` | Legible scan trace. |
| 10 | GND for PAL16H2 | Board supply connection not traced | Device role only. |
| 11 | Input | Appears `/H0` | Label and bar need confirmation. |
| 12 | Input | `V0` | Legible scan trace. |
| 13 | Input | `V1` | Legible scan trace. |
| 14 | Input | `V2` | Legible scan trace. |
| 17 | Input | `V3` | Legible scan trace. |
| 18 | Input | `V4` | Legible scan trace. |
| 20 | VCC for PAL16H2 | Board supply connection not traced | Device role only. |

The following surrounding Frisky Tom 2D connections were jointly confirmed. `/CLR` names
the active-low clear inputs, drawn with bubbles; `/Q` is the inverted output.
`P` is the schematic's named tie net.

| Source | Destination | Evidence |
| --- | --- | --- |
| `P` | Upper 2D D pin 12 | User confirmed. |
| `P` | Lower 2D D pin 2 | User confirmed. |
| Upper 2D Q pin 9 | Lower 2D `/CLR` pin 1 | User confirmed, including clear-input bubble. |
| Lower 2D `/Q` pin 6 | Upper 2D `/CLR` pin 13 | User confirmed, including clear-input bubble. |

Upper 2D `/Q` pin 8 is labelled `/WAIT` on the scan. The CPU-sheet `/WAIT`
route appears to enter 1M pin 13, with pin 12 grounded and output pin 11 feeding
Z80 `/WAIT` pin 24. These CPU-sheet route traces are separate from the confirmed
PAL pin-map equivalence. Both presets were explicitly confirmed tied to `P` on
Radical Radial; their Frisky Tom ties remain scan-derived. The implemented
common latch model uses the normal-operation assumptions above.

## Palette latch and PROM bank/address inputs

On the reviewed Frisky Tom video drawing, the four palette outputs of mux 8D
and two selected-pixel outputs of 7C feed latch 9D, a 74LS273. All pin numbers
below are physical package pins. These data routes and PROM destinations are
jointly confirmed; 9D's D-to-Q pairing agrees with the shared `jt74:74LS273`
symbol. No inversion bubbles occur on the two 7C-to-PROM data routes.

| Source output | 9D input | 9D output | Destination |
| --- | --- | --- | --- |
| 8D pin 12 | 17 | 16 | PROM bank selection through 7D/7E. |
| 8D pin 9 | 14 | 15 | Both PROMs, pin 14 (`A4`). |
| 8D pin 7 | 7 | 6 | Both PROMs, pin 13 (`A3`). |
| 8D pin 4 | 4 | 5 | Both PROMs, pin 12 (`A2`). |
| 7C pin 3 | 13 | 12 | Both PROMs, pin 11 (`A1`). |
| 7C pin 6 | 8 | 9 | Both PROMs, pin 10 (`A0`). |

9D output 16 reaches 7D input 12 directly. It also reaches inverter 7E
input 1; 7E output 2 feeds the other 7D gate's input 1. The already confirmed
qualification network supplies 7D inputs 13 and 2, respectively. Upper 7D
output 11 drives 9C `/CE` pin 15; lower 7D output 3 drives 9B `/CE` pin 15.
With `B = 9D.Q16` and `Q = 9D.Q2 & 9D.Q19`, the enabled conditions are:

```text
9C enabled = Q & NOT B
9B enabled = Q & B
```

Thus the four latched palette outputs select a PROM bank and its three high
address bits. The corresponding flattened six-bit address has the bank at
bit 5 and these address bits at bits 4 through 2. The latched 7C pin 3 and pin 6
signals supply bits 1 and 0, respectively, without inversion. This agrees
with the stable palette/pixel packing in `jtseicro_colmix`.
`ver/hdl/colmix_tb.v` checks both banks, all eight palette rows and all three
nonzero pixel codes through each layer,
plus zero-pixel suppression with every palette value.

These chains establish all palette and pixel routes from the outputs of 8D
and 7C to the PROM bank/address inputs. Upstream source/layer identities and
physical 9D capture ordering remain separate checks. The renderer does not
yet reproduce the complete schematic latch timing.

## Pixel and palette selection

The following 7A/7C and 8D connections are jointly confirmed on the reviewed
video drawings. `a1` and `a0` are readout-bus bits 1 and 0; `n9` and `n12`
are the physical levels at 9O outputs 9 and 12. These names do not assign an
upstream layer identity.

| Source | Destination |
| --- | --- |
| Readout bus bit 1 | 7A input 11, 7A input 6, 7C input 2. |
| Readout bus bit 0 | 7A input 12, 7A input 3, 7C input 4. |
| 9O output 9 | 7A input 2. |
| 9O output 12 | 7A input 5. |
| 7A output 13 | 8D select pin 1. |
| 7A output 1 | 7C input 1. |
| 7A output 4 | 7C input 5. |

7A is type 02. Its top gate has an output bubble and unbubbled inputs 11/12.
The other two gates use AND bodies with bubbles on inputs 2/3 and 5/6, and
unbubbled outputs 1/4: the same NOR function of physical input levels. Both
7C gates are type 32 OR gates without input or output bubbles. Consequently:

```text
8D.S1 = NOT(a1 OR a0)
7A.Y1 = NOT(n9 OR a0)
7A.Y4 = NOT(n12 OR a1)
7C.Y3 = a1 OR 7A.Y1
7C.Y6 = a0 OR 7A.Y4
```

8D is a non-inverting 74LS157 with active-low enable pin 15 tied to ground.
Select 0 chooses its A inputs; select 1 chooses B. Its palette channels are:

| 8D output | A input pin / readout bit | B input pin / upper-bundle bit | B source |
| --- | --- | --- | --- |
| 12 | 14 / bit 5 | 13 / bit 3 | 8N output 2. |
| 9 | 11 / bit 4 | 10 / bit 2 | 8N output 5. |
| 7 | 5 / bit 3 | 6 / bit 1 | 8N output 12. |
| 4 | 2 / bit 2 | 3 / bit 0 | 8N output 15. |

For any nonzero readout pixel `a1:a0`, the selected pixel is `a1:a0` and
8D supplies that bus's palette bits 5 through 2. For readout pixel `00`,
the selected pixel is `NOT(n9):NOT(n12)` and 8D selects the palette from 8N.
Pixel and palette therefore switch together. The downstream 9D latch and
PROM enables described above suppress RGB when the selected pixel is zero.

The current `jtseicro_colmix` implements this relative nonzero-pixel priority.
The focused test drives the readout role through `obj_pxl` and the fallback
role through `scr_pxl`, comparing their result with these physical gate
expressions for all 16 pixel combinations and two contrasting palette pairs.
Together with the palette/address cases, `ver/hdl/colmix_tb.v` checks 172 cases.
This validates the selection function; the upstream source identities and
physical latch/sample timing require their own traces.

## RAM readout bank selection

The two RAM banks and their readout mux connections below are jointly confirmed.
Every listed RAM supplies its bit on physical output pin 7. The six mux outputs
form the same readout bus used by 7A/7C and the A inputs of 8D above.

| Readout bit | Lower RAM | Mux A input | Upper RAM | Mux B input | Mux output |
| --- | --- | --- | --- | --- | --- |
| 5 | 10J | 8A pin 14 | 10D | 8A pin 13 | 8A pin 12. |
| 4 | 10K | 8A pin 11 | 10E | 8A pin 10 | 8A pin 9. |
| 3 | 10L | 8A pin 5 | 10F | 8A pin 6 | 8A pin 7. |
| 2 | 10M | 8A pin 2 | 10G | 8A pin 3 | 8A pin 4. |
| 1 | 10N | 8B pin 14 | 10H | 8B pin 13 | 8B pin 12. |
| 0 | 10O | 8B pin 11 | 10I | 8B pin 10 | 8B pin 9. |

Both active-low enable inputs, 8A/8B pin 15, are grounded. Their select pin 1
is the previously confirmed 6B `/Q6` net, represented as `bank_sel` by the
standalone `jtseicro_blanking` model. Select 0 reads the lower 10J–10O bank;
select 1 reads the upper 10D–10I bank. Readout bits 5 through 2 supply palette
selection, while bits 1 and 0 supply the nonzero-pixel priority network.

`jtseicro_obj` uses `jtframe_obj_buffer` to store, read and clear rendered
pixels. The object-list RAM selector in `jtseicro_obj` is a separate state
from the buffer's alternating line banks. The generic buffer swaps those line
banks at its horizontal-blank input edge and clears the read bank after reads.
This is a functional double-buffer implementation; its reset bank labels,
RAM addressing and write/read/clear phases have not been equated with the
physical banks and controls above. `jtseicro_blanking` remains separate from
that buffer. The sprite-enabled `ver/hdl/video_tb.v` checks rendered pixels
and both flips, rather than the physical bank-control timing. The write-data
routes below establish the available input words; RAM addressing and phase
alignment remain separate schematic checks.

## RAM write data and bank controls

Both banks receive the same six-bit word on their write muxes' A inputs.
The sources are taken before latch 9D. The routes below, including every
RAM data-input pin 11, are jointly confirmed.

| Bit | Source | Upper mux A input | Upper mux output → RAM input | Lower mux A input | Lower mux output → RAM input |
| --- | --- | --- | --- | --- | --- |
| 5 | 8D pin 12 | 9E pin 14 | 9E pin 12 → 10D pin 11 | 9F pin 14 | 9F pin 12 → 10J pin 11 |
| 4 | 8D pin 9 | 9E pin 11 | 9E pin 9 → 10E pin 11 | 9F pin 11 | 9F pin 9 → 10K pin 11 |
| 3 | 8D pin 7 | 9E pin 5 | 9E pin 7 → 10F pin 11 | 9F pin 5 | 9F pin 7 → 10L pin 11 |
| 2 | 8D pin 4 | 9E pin 2 | 9E pin 4 → 10G pin 11 | 9F pin 2 | 9F pin 4 → 10M pin 11 |
| 1 | 7C pin 3 | 9G pin 14 | 9G pin 12 → 10H pin 11 | 9H pin 14 | 9H pin 12 → 10N pin 11 |
| 0 | 7C pin 6 | 9G pin 11 | 9G pin 9 → 10I pin 11 | 9H pin 11 | 9H pin 9 → 10O pin 11 |

Both banks also receive the same B word. These source routes and their fanout
are jointly confirmed:

| Bit | Source | Upper mux B input | Lower mux B input |
| --- | --- | --- | --- |
| 5 | 8E pin 12 | 9E pin 13 | 9F pin 13 |
| 4 | 8E pin 9 | 9E pin 10 | 9F pin 10 |
| 3 | 8E pin 7 | 9E pin 6 | 9F pin 6 |
| 2 | 8E pin 4 | 9E pin 3 | 9F pin 3 |
| 1 | Lower 7C pin 11 | 9G pin 13 | 9H pin 13 |
| 0 | Lower 7C pin 8 | 9G pin 10 | 9H pin 10 |

The write muxes are type 157. A high level on their active-low enable pin 15
forces all outputs low, as specified in the
[TI SN74LS157 function table, page 1](https://www.ti.com/lit/ds/symlink/sn74ls157.pdf).
The confirmed select and enable connections give these physical-level equations,
where `S = 6B./Q6` (`bank_sel`) and `T = 6B.Q9` (`bank_blank`):

```text
9E/9G.S1   = NOT(S)              6B.Q5
9F/9H.S1   = S                   6B./Q6
9E/9G./G15 = NOT(T OR NOT(S))    7B.Y4
9F/9H./G15 = NOT(T OR S)         7B.Y1
```

Applying the 157 select/enable function yields the following input words at the
RAM pins. `A` and `B` denote the six-bit source words in the tables above;
`0` denotes six low data inputs.

| T | S | Readout bank | Upper 10D–10I DIN | Lower 10J–10O DIN |
| --- | --- | --- | --- | --- |
| 0 | 0 | Lower | B | 0 |
| 0 | 1 | Upper | 0 | B |
| 1 | 0 | Lower | B | A |
| 1 | 1 | Upper | A | B |

Thus the readout bank receives A when T is high and zero when T is low;
the other bank receives B. This is a derived data-input truth table, not a
verified RAM write/clear schedule. RAM address multiplexing and source-layer
identities remain separate checks; the confirmed write controls are below.

The standalone `jtseicro_blanking` represents S/T and both mux enable equations.
`ver/hdl/blanking_tb.v` checks all four S/T combinations and their control timing
over 405,504 pixel samples; `ver/hdl/colmix_tb.v` checks 172 selection/palette
cases. The generic game buffer has not been equated with this physical RAM
network, and these tests do not establish its write phases or address mapping.

## RAM write/read control

Both RAM groups, upper 10D–10I and lower 10J–10O, have physical W pin 8
connected to `/MCLK` and CS pin 10 tied to ground. Both routes and the bar
over `/MCLK` are jointly confirmed. Latch 9D clock pin 11 also receives
`/MCLK`, as confirmed separately.

The [Fujitsu MBM2147H datasheet, page 1](https://www.citylan.it/images/1/1a/Mbm2147.pdf)
is the functional family reference for these control/data pins: `/WE8`,
`/CS10`, DIN11 and DOUT7. Its function table specifies write mode for
`/CS=0, /WE=0` and read mode for `/CS=0, /WE=1`; DOUT is high impedance
in write mode. This is a family reference, rather than identification of the
schematic's exact MB8147E variant or speed grade.

With the confirmed wiring and this family function, both banks write while
`/MCLK` is low (MCLK high) and read while `/MCLK` is high (MCLK low).
The digital model of the jointly confirmed 3C wiring divides 18.432 MHz
by three, with MCLK high for one input-clock period and low for two. Ignoring propagation,
the nominal write interval is therefore about 54.3 ns and the read interval
about 108.5 ns. These are logic-level intervals, not measured SRAM margins.
9D's rising `/MCLK` edge coincides logically with the transition from write
to read; the board's propagation and data-capture ordering remain unmeasured.

The data-input table above identifies a zero input word on the readout bank
when `6B.Q9` is low. Actual cleared locations require the RAM address paths
and their phase relationship to this write interval. No physical RAM schedule
has yet been substituted for the game's generic object buffer.

## RAM address outputs and depth

Confirmed mux outputs connect to the RAM address bus as follows. Physical RAM
address pins 12–15 are grounded on both banks.

| Bus bit | Upper mux/output | Lower mux/output | RAM pin |
| --- | --- | --- | --- |
| 7 | 8I/12 | 9I/12 | 16 |
| 6 | 8I/9 | 9I/9 | 17 |
| 5 | 8I/7 | 9I/7 | 1 |
| 4 | 8I/4 | 9I/4 | 2 |
| 3 | 8J/12 | 9J/12 | 3 |
| 2 | 8J/9 | 9J/9 | 4 |
| 1 | 8J/7 | 9J/7 | 5 |
| 0 | 8J/4 | 9J/4 | 6 |

With four address pins grounded, the qualified 2147-family reference gives
256 address combinations per chip. Six one-bit RAMs provide 256 six-bit
locations per bank (1,536 bits, equivalent to 192 bytes of capacity). The
same physical pin permutation is used on the read and write paths, so it needs no address-bit
shuffle by itself. The address-source routing is recorded below; its physical
read/write capture phases remain open. This does not establish phase
equivalence with the game's generic object buffer.

## RAM address-source selection

The jointly confirmed source words cross between the banks' A/B inputs.
Define `C` as the two 161-counter output word and `X` as the combined 9L/9K
output word. Each row lists pins in descending bit order.

| Bits | C source/output pins | X source/output pins |
| --- | --- | --- |
| 7–4 | 8H / 11, 12, 13, 14 | 9L / 6, 3, 11, 8 |
| 3–0 | Lower 161 beside 8J / 11, 12, 13, 14 | 9K / 6, 3, 11, 8 |

The lower counter's designator is not confirmed. All four mux active-low enable
pins 15 are grounded; the input bubbles are confirmed.

| RAM bank | Muxes (high/low nibble) | A inputs 14, 11, 5, 2 | B inputs 13, 10, 6, 3 |
| --- | --- | --- | --- |
| Upper | 8I / 8J | X | C |
| Lower | 9I / 9J | C | X |

With `S = 6B./Q6` and all four address-mux selects driven by
`6B.Q5 = NOT S`, the mux truth table and confirmed readout-bank selection give:

| S | Upper RAM address | Lower RAM address | Readout bank |
| --- | --- | --- | --- |
| 0 | C | X | Lower |
| 1 | X | C | Upper |

Thus the readout bank is addressed by `X` for either value of `S`, while the
other bank is addressed by `C`. This records digital routing only. Counter
input meanings and timing, and the physical read/write capture phases remain
unverified; `X` is not identified as a scan address and `C` is not identified
as a sprite address.

## RAM address XOR inputs

8M and 8L are jointly confirmed as type 163 counters. Their outputs feed
9L and 9K respectively, both confirmed type 86 XOR gates with no inversion
bubbles on the traced inputs or outputs. The other input of every gate joins
one shared wire driven by 8F output pin 5, a type 174 latch. This route passes
the 8M output pin 11 wire without an electrical junction. Both the driver and
the crossing are jointly confirmed. `F` below denotes `8F.5`; the original
board net name has not been identified.

| X bit | Counter/output pin | XOR chip | Counter input pin | Shared F input pin | Output pin |
| --- | --- | --- | --- | --- | --- |
| 7 | 8M/11 | 9L | 4 | 5 | 6 |
| 6 | 8M/12 | 9L | 1 | 2 | 3 |
| 5 | 8M/13 | 9L | 12 | 13 | 11 |
| 4 | 8M/14 | 9L | 9 | 10 | 8 |
| 3 | 8L/11 | 9K | 4 | 5 | 6 |
| 2 | 8L/12 | 9K | 1 | 2 | 3 |
| 1 | 8L/13 | 9K | 12 | 13 | 11 |
| 0 | 8L/14 | 9K | 9 | 10 | 8 |

Define `Q = {8M.11, 8M.12, 8M.13, 8M.14, 8L.11, 8L.12, 8L.13, 8L.14}`
in descending bit order. The confirmed gate function is `X = Q XOR {8{F}}`:
`F=0` preserves the counter word and `F=1` complements all eight bits.
The counters' parallel inputs, common clock and control wiring are recorded
below. The CD source remains a separate check; the load-signal generator is
recorded below.

## RAM address XOR control timing

The jointly confirmed 6C gate is type 08, a flat-base AND symbol without
inversion bubbles on inputs 1/2 or output 3. Pin 1 receives `H8`, without a
bar, and pin 2 receives `INV`. Its output pin 3 connects to 8F data pin 4.
8F clock pin 9 receives `H3`; its circled, active-low clear pin 1 is tied to
P and remains inactive.

On each rising `H3` edge, the type 174 latch therefore updates
`F = 8F.5 = H8 AND INV`. Between those edges, `F` retains its sampled value.
The confirmed source path is AY 1D pin 12 (`H.V.INV`, port B bit 1) through
5H input pin 2 and output pin 3 to video `INV`. 5H is a type 367 non-inverting
buffer; the two net names denote its input and output sides. Both active-low
enable pins, 1 and 15, are circled, joined and tied to ground, so this buffer
is continuously enabled. These ties are jointly confirmed. The existing core's
`flip = portb[1]` agrees with this source bit and polarity.

For stable `INV`, the verified horizontal count sequence 128 through 511
and this sampling rule imply the following ideal steady-state phases:

| Physical horizontal count | F |
| --- | --- |
| 128–135 | INV, retained from the preceding line |
| 136–263 | 0 |
| 264–511 | INV |

The two H8 transitions are reflected eight pixel periods later, about 1.302 us
at 6.144 MHz. This is a derived digital sampling delay, not a measurement of
analogue propagation. The initial latch value before its first clock is
unspecified by the inactive clear wiring. For stable `INV`, these phases also
give `F = INV AND NOT bank_blank` in the ideal model of the previously traced
6B chain; a changing `INV` must still obey 8F's clocked sampling rule.

## 8M/8L counter parallel inputs and clock

Both type 163 counter clock inputs, pin 2, receive `/MCLK`; the bar on this
net name is jointly confirmed. Their parallel-data inputs form the CD byte:

| Counter | CD bits, descending | Physical input pins, in the same order |
| --- | --- | --- |
| 8M | 7, 6, 5, 4 | 6, 5, 4, 3 |
| 8L | 3, 2, 1, 0 | 6, 5, 4, 3 |

These routes establish the parallel-data word and clock polarity. The source
of CD remains a separate check.

## 8M/8L counter load and cascade controls

The following physical routes are jointly confirmed:

| Source | Destinations |
| --- | --- |
| `/CDTALD`, with a bar | Both counters' load pin 9 |
| P | Both counters' clear pin 1; 8L enable pins 7 and 10 |
| 8L carry output pin 15 | Both 8M enable pins, 7 and 10 |

The [TI 163-family reference](https://www.ti.com/product/SN74LS163A)
specifies rising-edge clocking, synchronous active-low clear and load,
load priority over count enables, and counting when both enables are high.
The tied-high clears stay inactive. The lower nibble counts continuously
between loads; its carry enables the upper nibble when the lower value is 15.

Thus, on each rising `/MCLK` edge, the combined eight-bit counter word `Q`
loads CD7–CD0 if `/CDTALD=0`, otherwise it increments modulo 256. Loading
presets both nibbles on the same edge, independently of the carry value.
No clear-driven power-up value is established by the P ties; the first valid
load establishes the programmed count. The CD source and its setup/hold
relationship to `/MCLK` remain to be traced.

## Counter load-request generator

The jointly confirmed type 157 mux 4D drives `/CDTALD` from output pin 12:

| Physical pin | Connection |
| --- | --- |
| B input 13 | 5D output pin 7, `/CDT3` |
| A input 14 | P |
| Select 1 | `/H8`, confirmed by the user |
| Active-low enable 15 | GND |
| Output 12 | `/CDTALD` |

The [TI 157-family reference](https://www.ti.com/product/SN74LS157)
identifies this as a non-inverting selector. With A selected at S=0 and B
at S=1, this wiring gives:

```text
/CDTALD = H8 OR /CDT3
         = NOT(NOT H8 AND H0 AND H1 AND H2 AND NOT H3)
```

For the physical horizontal sequence 128 through 511, this decode is low at
135, 151, 167, 183, 199, 215, 231 and 247: eight nominal one-pixel load-request
windows per line, all in the H8-low horizontal-blank interval. It stays high
through H8-high active video, permitting counting between those requests.
These are combinational decode windows. The actual counter sampling edge
relative to H transitions and CD setup/hold remains a separate timing check.

## Separate video data buses

CD7–CD0 are driven by 3J/3K. They cross the local bus joining 4M, 4N, 4O
and 5N without connecting to it. The isolated RAM-side word feeding the
CD drivers comes from 3I and 2I, as jointly confirmed below. The CD buffer
enable ties and shared RAM-write/CPU-buffer control are recorded below.

For this pin map only, `L[7:0]` denotes that otherwise unnamed local bus:

| Source | Physical pins, in order | Local bits, in the same order |
| --- | --- | --- |
| 4M RAM | 11, 12, 13, 14 | L7, L6, L5, L4 |
| 4N RAM | 11, 12, 13, 14 | L3, L2, L1, L0 |

4O is jointly confirmed as type 245. Its B-side wires are DB7–DB0, and its
A-side wires join `L[7:0]`. Their physical port order is interleaved:

| Bit | DB-side pin | L-side pin |
| --- | --- | --- |
| 7 | 11 | 9 |
| 6 | 13 | 7 |
| 5 | 15 | 5 |
| 4 | 17 | 3 |
| 3 | 12 | 8 |
| 2 | 14 | 6 |
| 1 | 16 | 4 |
| 0 | 18 | 2 |

5N also connects to `L[7:0]`; its individual data pins and capture timing
remain to be checked. The 4O direction/enable controls and RAM write controls
must establish bus ownership before assigning a data-transfer phase.

## CD RAM-to-buffer pin map

3I and 2I feed one isolated RAM-side byte. 3J and 3K are jointly confirmed
as type 367 non-inverting three-state buffers, with these physical routes:

| CD bit | RAM output pin | Buffer | Input pin | Output pin |
| --- | --- | --- | --- | --- |
| 7 | 3I/11 | 3J | 10 | 9 |
| 6 | 3I/12 | 3J | 6 | 7 |
| 5 | 3I/13 | 3J | 12 | 11 |
| 4 | 3I/14 | 3J | 4 | 5 |
| 3 | 2I/11 | 3J | 14 | 13 |
| 2 | 2I/12 | 3J | 2 | 3 |
| 1 | 2I/13 | 3K | 14 | 13 |
| 0 | 2I/14 | 3K | 12 | 11 |

The active-low, circled enables 3J pins 1/15 and 3K pin 15 are jointly
confirmed as grounded. All eight RAM-to-CD buffers are continuously enabled,
so CD follows the RAM-side word without an enable-controlled read window.

This establishes the byte source for the previously traced 8M/8L parallel
inputs. The shared RAM-write/CPU-buffer control is recorded below; its
clock relationship and RAM settling time still determine data validity.
The RAM-side word, CD and the separate 4M/4N/4O/5N local bus are distinct nets.

## CD RAM write and CPU-buffer control

The following Frisky Tom sheet routes and polarities are jointly confirmed:

| Source | Destinations | Destination polarity |
| --- | --- | --- |
| 3F output 12 | 3I and 2I WR pin 10 | Circled, active low |
| Same 3F output 12 net | 2J enable pins 1/15; 2K enable pin 15 | Circled, active low |
| GND | 3I and 2I CS pin 8 | Circled, active low |

3F output pin 12 has no inversion circle. Its shared control net asserts
both RAM write and the CPU-to-RAM buffer enables when low. When high, RAM
write is inactive and those CPU buffers are disabled. Both RAM chip selects
remain asserted, while the separately grounded 3J/3K enables keep the
RAM-to-CD path continuously enabled. There is no additional inversion
between the confirmed 3F output and these write/enable inputs.

This establishes shared logical write ownership. The source decode feeding
3F, propagation around write transitions and CD setup/hold at the receiving
counters remain outside this confirmed control chain.

## CD RAM write-control selector

The 3F type 157 mux selects the shared write-control signal described above.
The following inputs and polarity were jointly confirmed on the Frisky Tom
video sheet:

| 3F pin | Connection |
| --- | --- |
| 13, B input | P |
| 14, A input | `/WR3`, with a bar |
| 1, select | `RAM3S`, without a bar or input circle |
| 15, active-low enable | GND, with a circle |
| 12, output | Shared RAM write and CPU-buffer enable control |

`RAM3S` also connects to select pin 1 of 3H and 2H, with no circles; their
circled enable pins 15 are grounded. With P high and the non-inverting 157
selecting A when select is low, the write-control output is
`RAM3S OR /WR3`. It can therefore go low only when both `RAM3S` and `/WR3`
are low. The user identifies 3E on the same sheet as the source of the
RAM1S/RAM2S/RAM3S signals; the RAM3S connections are recorded below.
The timing of both selector inputs remains to be traced.

## /WR3 decoder source

On the Frisky Tom CPU sheet, 2E is marked 138 and its circled Y3 output is
labelled `/WR3`; the user confirms the label and circle. The drawing indicates
physical output pin 12, as expected for a 138 Y3 output. The user tentatively
reads selector pins 3/2/1 as AB13/AB12/AB11, without circles. The enable
labels top-to-bottom appear AB15, `/ZMA` and `/ZWR`; the middle label is
uncertain and the last is more legible. Comparing 2E pin 5 with the separately
reviewed 2F pin 5, the user reads both as `/ZM(*)`, with the final character
unresolved. Similar lettering alone does not prove net identity. These input
readings are not yet confirmed, so they do not establish an address window
or enable equation.

## RAM3S gate inputs

The upper 3E gate drives `RAM3S` at output pin 11. The user confirmed
its inputs: pin 12 receives 4D output 1Y, pin 4; pin 13 receives `/VBLK`
from 5F Q pin 9. Both inputs and the output have circles; the user confirms an OR-shaped
gate with a curved input side. Therefore `RAM3S = 4D.4 AND /VBLK`.

4D is a 157 with select `/H8` and its active-low enable grounded, as
previously confirmed. The user confirms 4D B input pin 3 receives 4E
output pin 3, which is circled; 4D A input pin 2 receives `/H2`. Thus
`4D.4 = H8 ? /H2 : 4E.3`. 4E is a flat-base AND gate with no input circles, output pin 3 circled,
and inputs H3 at pin 1 and H2 at pin 2. The user confirms these connections
and polarities, giving:

```text
4E.3   = NOT(H3 AND H2)
4D.4   = H8 ? NOT(H2) : NOT(H3 AND H2)
RAM3S  = /VBLK AND (NOT(H2) OR (NOT(H8) AND NOT(H3)))
write_control_n = RAM3S OR /WR3
```

These equations describe ideal logic levels. They do not establish physical
propagation delay, counter-transition ordering or RAM setup and hold times.
